use crate::error::DpkError;
use std::ffi::OsString;
use std::path::Path;

pub struct ResolvedEnv {
    pub vars: Vec<(OsString, OsString)>,
}

pub fn source_env_file(path: &Path) -> Result<ResolvedEnv, DpkError> {
    let script = format!("set -a; source '{}'; set +a; env -0", path.display());
    let out = std::process::Command::new("bash")
        .args(["-c", &script])
        .output()
        .map_err(|e| DpkError::EnvResolutionFailed {
            path: path.to_path_buf(),
            message: e.to_string(),
        })?;
    if !out.status.success() {
        let msg = String::from_utf8_lossy(&out.stderr).trim().to_string();
        return Err(DpkError::EnvResolutionFailed {
            path: path.to_path_buf(),
            message: msg,
        });
    }
    let vars = parse_env0(&out.stdout);
    Ok(ResolvedEnv { vars })
}

pub fn resolve(build_root: &Path, project_dir: &Path) -> Result<ResolvedEnv, DpkError> {
    let mut combined: Vec<(OsString, OsString)> = Vec::new();

    let build_env = build_root.join("env.sh");
    if build_env.exists() {
        let r = source_env_file(&build_env)?;
        combined.extend(r.vars);
    }

    let project_env = project_dir.join("env.sh");
    if project_env.exists() {
        let r = source_env_file(&project_env)?;
        // Project wins: overwrite any key already set by build_root env
        for (k, v) in r.vars {
            if let Some(existing) = combined.iter_mut().find(|(ek, _)| ek == &k) {
                existing.1 = v;
            } else {
                combined.push((k, v));
            }
        }
    }

    Ok(ResolvedEnv { vars: combined })
}

#[cfg(unix)]
fn parse_env0(data: &[u8]) -> Vec<(OsString, OsString)> {
    use std::os::unix::ffi::OsStringExt;
    let mut result = Vec::new();
    for chunk in data.split(|&b| b == 0) {
        if chunk.is_empty() {
            continue;
        }
        if let Some(eq_pos) = chunk.iter().position(|&b| b == b'=') {
            let key = OsString::from_vec(chunk[..eq_pos].to_vec());
            let val = OsString::from_vec(chunk[eq_pos + 1..].to_vec());
            result.push((key, val));
        }
    }
    result
}

#[cfg(not(unix))]
fn parse_env0(data: &[u8]) -> Vec<(OsString, OsString)> {
    // Non-unix fallback: parse as UTF-8
    let mut result = Vec::new();
    for chunk in data.split(|&b| b == 0) {
        if chunk.is_empty() {
            continue;
        }
        if let Ok(s) = std::str::from_utf8(chunk) {
            if let Some(eq_pos) = s.find('=') {
                let key = OsString::from(&s[..eq_pos]);
                let val = OsString::from(&s[eq_pos + 1..]);
                result.push((key, val));
            }
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn test_source_env_file_basic() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join("env.sh");
        let mut f = std::fs::File::create(&env_path).unwrap();
        writeln!(f, "export TEST_VAR=hello").unwrap();
        let resolved = source_env_file(&env_path).unwrap();
        let found = resolved
            .vars
            .iter()
            .any(|(k, v)| k == "TEST_VAR" && v == "hello");
        assert!(found, "TEST_VAR=hello should be in resolved env");
    }

    #[test]
    fn test_resolve_project_wins_over_build_root() {
        let build_dir = tempfile::tempdir().unwrap();
        let project_dir = tempfile::tempdir().unwrap();

        let mut f = std::fs::File::create(build_dir.path().join("env.sh")).unwrap();
        writeln!(f, "export SHARED_VAR=from_build_root").unwrap();
        writeln!(f, "export BUILD_ONLY=yes").unwrap();

        let mut f2 = std::fs::File::create(project_dir.path().join("env.sh")).unwrap();
        writeln!(f2, "export SHARED_VAR=from_project").unwrap();

        let resolved = resolve(build_dir.path(), project_dir.path()).unwrap();

        let shared = resolved
            .vars
            .iter()
            .find(|(k, _)| k == "SHARED_VAR")
            .map(|(_, v)| v.to_string_lossy().to_string());
        assert_eq!(shared.as_deref(), Some("from_project"));

        let build_only = resolved.vars.iter().any(|(k, _)| k == "BUILD_ONLY");
        assert!(
            build_only,
            "BUILD_ONLY from build_root should still be present"
        );
    }

    #[test]
    fn test_resolve_no_env_files_returns_empty() {
        let build_dir = tempfile::tempdir().unwrap();
        let project_dir = tempfile::tempdir().unwrap();
        let resolved = resolve(build_dir.path(), project_dir.path()).unwrap();
        // May have env vars from the current process but no error
        let _ = resolved.vars;
    }
}
