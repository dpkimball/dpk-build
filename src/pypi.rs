#![allow(dead_code)]
use crate::error::DpkError;
use crate::executor::{run_program, ExecRequest, OutputMode};
use std::ffi::OsString;
use std::path::Path;
use std::sync::{atomic::AtomicBool, Arc};

pub struct PypiConfig {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub password: String,
}

impl PypiConfig {
    pub fn from_env(resolved_env: &[(OsString, OsString)]) -> Self {
        let get = |key: &str| -> Option<String> {
            resolved_env
                .iter()
                .find(|(k, _)| k == key)
                .map(|(_, v)| v.to_string_lossy().into_owned())
                .or_else(|| std::env::var(key).ok())
        };
        PypiConfig {
            host: get("PYPI_HOST").unwrap_or_else(|| "localhost".into()),
            port: get("PYPI_PORT")
                .and_then(|p| p.parse().ok())
                .unwrap_or(31126),
            username: get("PYPI_USERNAME").unwrap_or_else(|| "admin".into()),
            password: get("PYPI_PASSWORD").unwrap_or_else(|| "your-secret-password".into()),
        }
    }
}

pub fn get_latest_version(
    cfg: &PypiConfig,
    package_name: &str,
) -> Result<Option<[u64; 3]>, DpkError> {
    let normalized = package_name.replace('-', "_");
    let url = format!("http://{}:{}/simple/{}/", cfg.host, cfg.port, normalized);

    let response = ureq::get(&url)
        .set("Authorization", &basic_auth(&cfg.username, &cfg.password))
        .call()
        .map_err(|e| DpkError::HttpRequestFailed {
            url: url.clone(),
            message: e.to_string(),
        })?;

    let body = response
        .into_string()
        .map_err(|e| DpkError::HttpRequestFailed {
            url: url.clone(),
            message: e.to_string(),
        })?;

    let mut versions: Vec<[u64; 3]> = Vec::new();

    for href in extract_hrefs(&body) {
        if let Some(ver) = parse_wheel_version(&href, &normalized) {
            versions.push(ver);
        }
    }

    Ok(versions.into_iter().max_by(|a, b| a.cmp(b)))
}

pub fn next_patch(v: [u64; 3]) -> [u64; 3] {
    [v[0], v[1], v[2] + 1]
}

pub fn upload_wheel(
    cfg: &PypiConfig,
    wheel_path: &Path,
    cwd: &Path,
    output_mode: OutputMode,
    cancelled: &Arc<AtomicBool>,
) -> Result<(), DpkError> {
    let publish_url = format!("http://{}:{}/", cfg.host, cfg.port);
    let req = ExecRequest {
        program: OsString::from("uv"),
        args: vec![
            OsString::from("publish"),
            OsString::from("--publish-url"),
            OsString::from(&publish_url),
            OsString::from("--username"),
            OsString::from(&cfg.username),
            OsString::from("--password"),
            OsString::from(&cfg.password),
            OsString::from(wheel_path),
        ],
        cwd: cwd.to_path_buf(),
        env_overrides: Vec::new(),
        timeout: None,
        output_mode,
    };

    let outcome = run_program(&req, cancelled)?;
    if outcome.cancelled {
        return Ok(()); // Will be handled by caller
    }
    if outcome.exit_code != 0 {
        // Check for 409 conflict (already uploaded) - tolerate it
        let stderr = String::from_utf8_lossy(&outcome.stdout_captured);
        if stderr.contains("409") || stderr.contains("already exists") {
            return Ok(());
        }
        return Err(DpkError::Other(format!(
            "wheel upload failed with exit code {}",
            outcome.exit_code
        )));
    }
    Ok(())
}

fn basic_auth(username: &str, password: &str) -> String {
    let credentials = format!("{}:{}", username, password);
    let encoded = base64_encode(credentials.as_bytes());
    format!("Basic {}", encoded)
}

fn base64_encode(data: &[u8]) -> String {
    const CHARS: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut result = String::new();
    let mut i = 0;
    while i < data.len() {
        let b0 = data[i] as u32;
        let b1 = if i + 1 < data.len() {
            data[i + 1] as u32
        } else {
            0
        };
        let b2 = if i + 2 < data.len() {
            data[i + 2] as u32
        } else {
            0
        };
        result.push(CHARS[((b0 >> 2) & 0x3f) as usize] as char);
        result.push(CHARS[(((b0 << 4) | (b1 >> 4)) & 0x3f) as usize] as char);
        if i + 1 < data.len() {
            result.push(CHARS[(((b1 << 2) | (b2 >> 6)) & 0x3f) as usize] as char);
        } else {
            result.push('=');
        }
        if i + 2 < data.len() {
            result.push(CHARS[(b2 & 0x3f) as usize] as char);
        } else {
            result.push('=');
        }
        i += 3;
    }
    result
}

fn extract_hrefs(html: &str) -> Vec<String> {
    let mut hrefs = Vec::new();
    let mut pos = 0;
    while let Some(href_start) = html[pos..].find("href=\"") {
        let start = pos + href_start + 6;
        if let Some(end_offset) = html[start..].find('"') {
            hrefs.push(html[start..start + end_offset].to_string());
            pos = start + end_offset + 1;
        } else {
            break;
        }
    }
    hrefs
}

fn parse_wheel_version(href: &str, package_name: &str) -> Option<[u64; 3]> {
    // href is like: my_package-1.2.3-py3-none-any.whl#sha256=...
    let filename = href.split('#').next()?;
    let filename = filename.rsplit('/').next().unwrap_or(filename);
    if !filename.ends_with(".whl") {
        return None;
    }
    let prefix = format!("{}-", package_name);
    if !filename.starts_with(&prefix) {
        return None;
    }
    let rest = &filename[prefix.len()..];
    let version_str = rest.split('-').next()?;
    let parts: Vec<&str> = version_str.split('.').collect();
    if parts.len() < 3 {
        return None;
    }
    let major = parts[0].parse().ok()?;
    let minor = parts[1].parse().ok()?;
    let patch = parts[2].parse().ok()?;
    Some([major, minor, patch])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_base64_encode() {
        // "admin:your-secret-password" encoded
        let encoded = base64_encode(b"admin:password");
        assert_eq!(encoded, "YWRtaW46cGFzc3dvcmQ=");
    }

    #[test]
    fn test_parse_wheel_version() {
        let ver = parse_wheel_version(
            "/packages/my_pkg-1.2.3-py3-none-any.whl#sha256=abc",
            "my_pkg",
        );
        assert_eq!(ver, Some([1, 2, 3]));
    }

    #[test]
    fn test_parse_wheel_version_wrong_package() {
        let ver = parse_wheel_version("/packages/other_pkg-1.2.3-py3-none-any.whl", "my_pkg");
        assert!(ver.is_none());
    }

    #[test]
    fn test_next_patch() {
        assert_eq!(next_patch([1, 2, 3]), [1, 2, 4]);
        assert_eq!(next_patch([0, 0, 0]), [0, 0, 1]);
    }

    #[test]
    fn test_extract_hrefs() {
        let html = r#"<a href="foo-1.0.0.whl">foo</a><a href="bar-2.0.0.whl">bar</a>"#;
        let hrefs = extract_hrefs(html);
        assert_eq!(hrefs, vec!["foo-1.0.0.whl", "bar-2.0.0.whl"]);
    }
}
