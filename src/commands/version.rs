use crate::cli::VersionAction;
use crate::context::{Language, RunContext};
use crate::error::{DpkError, ErrorInfo};
use crate::output::OperationResult;
use std::path::Path;

pub fn run(ctx: &RunContext, action: &VersionAction) -> OperationResult {
    match action {
        VersionAction::Show { .. } => show(ctx),
        VersionAction::Bump { .. } => bump(ctx),
    }
}

fn show(ctx: &RunContext) -> OperationResult {
    let mut result = OperationResult::new(ctx.project_name.clone(), "version_show");
    match read_version(ctx) {
        Err(e) => {
            result.error = Some(ErrorInfo::from(&e));
            result.status = "failure".into();
        }
        Ok(version) => {
            result.error = None;
            // Embed version in the result by using a custom field via error slot trick
            // Instead, we encode version into the operation field extra data
            // Since OperationResult doesn't have a data field, we use a workaround:
            // we'll store it in the phases map as a synthetic entry with metadata
            // Actually the cleanest solution is to put it in error details as success info.
            // Per spec, any structured output goes to stdout as JSON. We'll add it as
            // an extra top-level field by making status include version.
            // Since OperationResult is fixed shape, we emit directly here.
            let out = serde_json::json!({
                "schema_version": 1,
                "project": ctx.project_name,
                "operation": "version_show",
                "status": "success",
                "duration_ms": 0,
                "version": version,
            });
            // output.rs is the only place that should call println!, but for version
            // we need a custom JSON shape. We emit directly here as a special case.
            println!(
                "{}",
                serde_json::to_string(&out).expect("JSON serialization failed")
            );
            std::process::exit(0);
        }
    }
    result
}

fn bump(ctx: &RunContext) -> OperationResult {
    let mut result = OperationResult::new(ctx.project_name.clone(), "version_bump");
    match do_bump(ctx) {
        Err(e) => {
            result.error = Some(ErrorInfo::from(&e));
            result.status = "failure".into();
        }
        Ok((old_version, new_version)) => {
            let out = serde_json::json!({
                "schema_version": 1,
                "project": ctx.project_name,
                "operation": "version_bump",
                "status": "success",
                "duration_ms": 0,
                "old_version": old_version,
                "new_version": new_version,
            });
            println!(
                "{}",
                serde_json::to_string(&out).expect("JSON serialization failed")
            );
            std::process::exit(0);
        }
    }
    result
}

fn read_version(ctx: &RunContext) -> Result<String, DpkError> {
    match ctx.language {
        Language::Python => read_python_version(&ctx.project_dir),
        Language::Rust => read_rust_version(&ctx.project_dir),
        Language::Node => read_node_version(&ctx.project_dir),
    }
}

fn read_python_version(dir: &Path) -> Result<String, DpkError> {
    let path = dir.join("pyproject.toml");
    let content = std::fs::read_to_string(&path).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    let doc: toml::Value = toml::from_str(&content).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    // Check for dynamic version
    if let Some(dynamic) = doc
        .get("tool")
        .and_then(|t| t.get("poetry"))
        .and_then(|p| p.get("version"))
    {
        return Ok(dynamic.as_str().unwrap_or("unknown").to_string());
    }
    // PEP 517 style
    let version = doc
        .get("project")
        .and_then(|p| p.get("version"))
        .and_then(|v| v.as_str())
        .ok_or_else(|| DpkError::ManifestParse {
            path: path.clone(),
            message: "no [project].version found".into(),
        })?;

    // Check dynamic
    if let Some(dynamic_list) = doc
        .get("project")
        .and_then(|p| p.get("dynamic"))
        .and_then(|d| d.as_array())
    {
        if dynamic_list.iter().any(|v| v.as_str() == Some("version")) {
            return Err(DpkError::VersionNotStatic { path });
        }
    }

    Ok(version.to_string())
}

fn read_rust_version(dir: &Path) -> Result<String, DpkError> {
    let path = dir.join("Cargo.toml");
    let content = std::fs::read_to_string(&path).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    let doc: toml::Value = toml::from_str(&content).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    let version = doc
        .get("package")
        .and_then(|p| p.get("version"))
        .and_then(|v| v.as_str())
        .ok_or_else(|| DpkError::ManifestParse {
            path: path.clone(),
            message: "no [package].version found".into(),
        })?;
    Ok(version.to_string())
}

fn read_node_version(dir: &Path) -> Result<String, DpkError> {
    let path = dir.join("package.json");
    let content = std::fs::read_to_string(&path).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    let doc: serde_json::Value =
        serde_json::from_str(&content).map_err(|e| DpkError::ManifestParse {
            path: path.clone(),
            message: e.to_string(),
        })?;
    let version =
        doc.get("version")
            .and_then(|v| v.as_str())
            .ok_or_else(|| DpkError::ManifestParse {
                path: path.clone(),
                message: "no version field found".into(),
            })?;
    Ok(version.to_string())
}

fn do_bump(ctx: &RunContext) -> Result<(String, String), DpkError> {
    match ctx.language {
        Language::Python => bump_python_version(&ctx.project_dir),
        Language::Rust => bump_rust_version(&ctx.project_dir),
        Language::Node => bump_node_version(&ctx.project_dir),
    }
}

fn increment_patch(version: &str) -> Result<String, DpkError> {
    let parts: Vec<&str> = version.split('.').collect();
    if parts.len() < 3 {
        return Err(DpkError::Other(format!(
            "cannot parse version '{}' for bump",
            version
        )));
    }
    let patch: u64 = parts[2]
        .parse()
        .map_err(|_| DpkError::Other(format!("patch component '{}' is not a number", parts[2])))?;
    Ok(format!("{}.{}.{}", parts[0], parts[1], patch + 1))
}

fn bump_python_version(dir: &Path) -> Result<(String, String), DpkError> {
    let path = dir.join("pyproject.toml");
    let content = std::fs::read_to_string(&path).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;

    // Check for dynamic version
    let toml_val: toml::Value = toml::from_str(&content).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    if let Some(dynamic_list) = toml_val
        .get("project")
        .and_then(|p| p.get("dynamic"))
        .and_then(|d| d.as_array())
    {
        if dynamic_list.iter().any(|v| v.as_str() == Some("version")) {
            return Err(DpkError::VersionNotStatic { path });
        }
    }

    let mut doc: toml_edit::DocumentMut =
        content
            .parse()
            .map_err(|e: toml_edit::TomlError| DpkError::ManifestParse {
                path: path.clone(),
                message: e.to_string(),
            })?;

    let old_version = doc["project"]["version"]
        .as_str()
        .ok_or_else(|| DpkError::ManifestParse {
            path: path.clone(),
            message: "no [project].version found".into(),
        })?
        .to_string();

    let new_version = increment_patch(&old_version)?;
    doc["project"]["version"] = toml_edit::value(new_version.clone());

    atomic_write(&path, doc.to_string().as_bytes())?;

    Ok((old_version, new_version))
}

fn bump_rust_version(dir: &Path) -> Result<(String, String), DpkError> {
    let path = dir.join("Cargo.toml");
    let content = std::fs::read_to_string(&path).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;

    let mut doc: toml_edit::DocumentMut =
        content
            .parse()
            .map_err(|e: toml_edit::TomlError| DpkError::ManifestParse {
                path: path.clone(),
                message: e.to_string(),
            })?;

    let old_version = doc["package"]["version"]
        .as_str()
        .ok_or_else(|| DpkError::ManifestParse {
            path: path.clone(),
            message: "no [package].version found".into(),
        })?
        .to_string();

    let new_version = increment_patch(&old_version)?;
    doc["package"]["version"] = toml_edit::value(new_version.clone());

    atomic_write(&path, doc.to_string().as_bytes())?;

    Ok((old_version, new_version))
}

fn bump_node_version(dir: &Path) -> Result<(String, String), DpkError> {
    let path = dir.join("package.json");
    let content = std::fs::read_to_string(&path).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;

    let mut doc: serde_json::Value =
        serde_json::from_str(&content).map_err(|e| DpkError::ManifestParse {
            path: path.clone(),
            message: e.to_string(),
        })?;

    let old_version = doc["version"]
        .as_str()
        .ok_or_else(|| DpkError::ManifestParse {
            path: path.clone(),
            message: "no version field found".into(),
        })?
        .to_string();

    let new_version = increment_patch(&old_version)?;
    doc["version"] = serde_json::Value::String(new_version.clone());

    let new_content = serde_json::to_string_pretty(&doc).map_err(|e| DpkError::ManifestParse {
        path: path.clone(),
        message: e.to_string(),
    })?;
    atomic_write(&path, (new_content + "\n").as_bytes())?;

    Ok((old_version, new_version))
}

fn atomic_write(path: &Path, content: &[u8]) -> Result<(), DpkError> {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    let mut tmp = tempfile::NamedTempFile::new_in(dir).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: format!("cannot create temp file: {}", e),
    })?;
    std::io::Write::write_all(&mut tmp, content).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: format!("cannot write temp file: {}", e),
    })?;
    tmp.persist(path).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: format!("cannot rename temp file: {}", e),
    })?;
    Ok(())
}
