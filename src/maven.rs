//! Maven project helpers for Java/Flink language support.

use crate::error::DpkError;
use crate::executor::{run_program, ExecOutcome, ExecRequest, OutputMode};
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::sync::{atomic::AtomicBool, Arc};
use std::time::Duration;

/// Resolve the Maven POM for this project.
///
/// Order:
/// 1. `MAVEN_POM` env (absolute or project-relative)
/// 2. `maven_pom` from dpk.toml `[project]` (passed in)
/// 3. `<project>/pom.xml`
/// 4. `<project>/jobs/pom.xml` (PDP multi-module layout)
pub fn resolve_pom(project_dir: &Path, toml_maven_pom: Option<&str>) -> Result<PathBuf, DpkError> {
    if let Ok(env_pom) = std::env::var("MAVEN_POM") {
        let p = PathBuf::from(&env_pom);
        let candidate = if p.is_absolute() {
            p
        } else {
            project_dir.join(p)
        };
        if candidate.is_file() {
            return Ok(candidate);
        }
        return Err(DpkError::Other(format!(
            "MAVEN_POM set but not a file: {}",
            candidate.display()
        )));
    }

    if let Some(rel) = toml_maven_pom {
        let candidate = project_dir.join(rel);
        if candidate.is_file() {
            return Ok(candidate);
        }
        return Err(DpkError::Other(format!(
            "dpk.toml project.maven_pom not a file: {}",
            candidate.display()
        )));
    }

    let root = project_dir.join("pom.xml");
    if root.is_file() {
        return Ok(root);
    }
    let jobs = project_dir.join("jobs/pom.xml");
    if jobs.is_file() {
        return Ok(jobs);
    }

    Err(DpkError::Other(format!(
        "no Maven POM found under {} (expected pom.xml or jobs/pom.xml)",
        project_dir.display()
    )))
}

pub fn toml_maven_pom(cfg: &Option<crate::config::project::ProjectConfig>) -> Option<String> {
    cfg.as_ref()
        .and_then(|c| c.project.as_ref())
        .and_then(|p| p.maven_pom.clone())
}

fn maven_image() -> String {
    std::env::var("MAVEN_IMAGE").unwrap_or_else(|_| "maven:3.9-eclipse-temurin-17".into())
}

/// Arguments for [`run_maven`].
pub struct MavenRun<'a> {
    pub project_dir: &'a Path,
    pub pom: &'a Path,
    pub goals: &'a [&'a str],
    pub extra_args: &'a [&'a str],
    pub env_overrides: Vec<(OsString, OsString)>,
    pub timeout: Option<Duration>,
    pub output_mode: OutputMode,
    pub cancelled: &'a Arc<AtomicBool>,
}

/// Run Maven goals against `pom`.
///
/// Uses `mvn` on PATH when available; otherwise Docker
/// (`MAVEN_IMAGE`, default `maven:3.9-eclipse-temurin-17`) with the project
/// tree and `~/.m2` mounted — same pattern as PDP `make build-job`.
pub fn run_maven(opts: MavenRun<'_>) -> Result<ExecOutcome, DpkError> {
    let pom_rel = opts
        .pom
        .strip_prefix(opts.project_dir)
        .unwrap_or(opts.pom)
        .to_string_lossy()
        .into_owned();

    let mut mvn_args: Vec<OsString> = vec![
        OsString::from("-B"),
        OsString::from("-f"),
        OsString::from(&pom_rel),
    ];
    for a in opts.extra_args {
        mvn_args.push(OsString::from(*a));
    }
    for g in opts.goals {
        mvn_args.push(OsString::from(*g));
    }

    if which::which("mvn").is_ok() {
        let req = ExecRequest {
            program: OsString::from("mvn"),
            args: mvn_args,
            cwd: opts.project_dir.to_path_buf(),
            env_overrides: opts.env_overrides,
            timeout: opts.timeout,
            output_mode: opts.output_mode,
        };
        return run_program(&req, opts.cancelled);
    }

    if which::which("docker").is_err() {
        return Err(DpkError::Other(
            "neither mvn nor docker found on PATH (need one to run Maven)".into(),
        ));
    }

    let m2 = dirs_m2();
    let image = maven_image();
    let project_dir_str = opts.project_dir.to_string_lossy().into_owned();
    let m2_str = m2.to_string_lossy().into_owned();

    let mut args: Vec<OsString> = vec![
        OsString::from("run"),
        OsString::from("--rm"),
        OsString::from("-v"),
        OsString::from(format!("{project_dir_str}:/workspace")),
        OsString::from("-v"),
        OsString::from(format!("{m2_str}:/root/.m2")),
        OsString::from("-w"),
        OsString::from("/workspace"),
        OsString::from(image),
        OsString::from("mvn"),
    ];
    args.extend(mvn_args);

    let req = ExecRequest {
        program: OsString::from("docker"),
        args,
        cwd: opts.project_dir.to_path_buf(),
        env_overrides: opts.env_overrides,
        timeout: opts.timeout,
        output_mode: opts.output_mode,
    };
    run_program(&req, opts.cancelled)
}

fn dirs_m2() -> PathBuf {
    if let Ok(h) = std::env::var("HOME") {
        return PathBuf::from(h).join(".m2");
    }
    PathBuf::from("/tmp/dpk-m2")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn resolves_jobs_pom() {
        let dir = tempfile::tempdir().unwrap();
        fs::create_dir(dir.path().join("jobs")).unwrap();
        fs::write(dir.path().join("jobs/pom.xml"), "<project/>").unwrap();
        let pom = resolve_pom(dir.path(), None).unwrap();
        assert!(pom.ends_with("jobs/pom.xml"));
    }

    #[test]
    fn toml_override_wins() {
        let dir = tempfile::tempdir().unwrap();
        fs::create_dir(dir.path().join("custom")).unwrap();
        fs::write(dir.path().join("custom/pom.xml"), "<project/>").unwrap();
        fs::write(dir.path().join("pom.xml"), "<project/>").unwrap();
        let pom = resolve_pom(dir.path(), Some("custom/pom.xml")).unwrap();
        assert!(pom.ends_with("custom/pom.xml"));
    }
}
