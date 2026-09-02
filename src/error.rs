use serde::Serialize;

#[derive(Debug, thiserror::Error)]
pub enum DpkError {
    #[error("failed to spawn process: {source}")]
    SpawnFailed { source: std::io::Error },
    #[error("failed to wait on process: {source}")]
    WaitFailed { source: std::io::Error },
    #[error("required tool '{name}' not found on PATH")]
    ToolNotFound { name: String },
    #[error("active kubectl context '{context}' is not in the deploy allowlist")]
    ContextNotAllowed { context: String },
    #[error("deploy requires a workspace manifest with a non-empty local context allowlist")]
    DeployRequiresWorkspaceManifest,
    #[error("failed to parse manifest at {path}: {message}")]
    ManifestParse {
        path: std::path::PathBuf,
        message: String,
    },
    #[error("multiple language indicators found ({files:?}); set project.language in dpk.toml")]
    LanguageAmbiguous { files: Vec<std::path::PathBuf> },
    #[error("language '{name}' is not supported in Phase 1")]
    LanguageUnsupported { name: String },
    #[error("operation '{op}' is not supported for language '{language}'")]
    OperationNotSupported { op: String, language: String },
    #[error("BUILD_ROOT could not be resolved; set the BUILD_ROOT environment variable")]
    BuildRootNotFound,
    #[error("project.version is dynamic; version bump requires a static version")]
    VersionNotStatic { path: std::path::PathBuf },
    #[error("HTTP check failed for {url}: expected {expected}, got {got}")]
    HttpCheckFailed {
        url: String,
        expected: u16,
        got: u16,
    },
    #[error("HTTP request to {url} failed: {message}")]
    HttpRequestFailed { url: String, message: String },
    #[error("{0}")]
    Other(String),
    #[error("another dpk-build process is already running in this project directory")]
    AlreadyRunning,
    #[error("failed to resolve environment from {path}: {message}")]
    EnvResolutionFailed {
        path: std::path::PathBuf,
        message: String,
    },
}

#[derive(Debug, Clone, Serialize)]
pub struct ErrorInfo {
    pub code: String,
    pub message: String,
    pub details: serde_json::Value,
}

impl From<&DpkError> for ErrorInfo {
    fn from(e: &DpkError) -> Self {
        match e {
            DpkError::SpawnFailed { .. } => ErrorInfo {
                code: "spawn_failed".into(),
                message: e.to_string(),
                details: serde_json::Value::Object(Default::default()),
            },
            DpkError::WaitFailed { .. } => ErrorInfo {
                code: "wait_failed".into(),
                message: e.to_string(),
                details: serde_json::Value::Object(Default::default()),
            },
            DpkError::ToolNotFound { name } => ErrorInfo {
                code: "tool_not_found".into(),
                message: e.to_string(),
                details: serde_json::json!({ "tool": name }),
            },
            DpkError::ContextNotAllowed { context } => ErrorInfo {
                code: "context_not_in_allowlist".into(),
                message: e.to_string(),
                details: serde_json::json!({ "context": context }),
            },
            DpkError::DeployRequiresWorkspaceManifest => ErrorInfo {
                code: "deploy_requires_workspace_manifest".into(),
                message: e.to_string(),
                details: serde_json::Value::Object(Default::default()),
            },
            DpkError::ManifestParse { path, message } => ErrorInfo {
                code: "manifest_parse_error".into(),
                message: e.to_string(),
                details: serde_json::json!({ "path": path.display().to_string(), "message": message }),
            },
            DpkError::LanguageAmbiguous { files } => ErrorInfo {
                code: "language_ambiguous".into(),
                message: e.to_string(),
                details: serde_json::json!({ "files": files.iter().map(|f| f.display().to_string()).collect::<Vec<_>>() }),
            },
            DpkError::LanguageUnsupported { name } => ErrorInfo {
                code: "language_unsupported".into(),
                message: e.to_string(),
                details: serde_json::json!({ "language": name }),
            },
            DpkError::OperationNotSupported { op, language } => ErrorInfo {
                code: "language_unsupported_for_operation".into(),
                message: e.to_string(),
                details: serde_json::json!({ "op": op, "language": language }),
            },
            DpkError::BuildRootNotFound => ErrorInfo {
                code: "build_root_not_found".into(),
                message: e.to_string(),
                details: serde_json::Value::Object(Default::default()),
            },
            DpkError::VersionNotStatic { path } => ErrorInfo {
                code: "version_not_static".into(),
                message: e.to_string(),
                details: serde_json::json!({ "path": path.display().to_string() }),
            },
            DpkError::HttpCheckFailed { url, expected, got } => ErrorInfo {
                code: "http_check_failed".into(),
                message: e.to_string(),
                details: serde_json::json!({ "url": sanitize_url(url), "expected": expected, "got": got }),
            },
            DpkError::HttpRequestFailed { url, message } => ErrorInfo {
                code: "http_request_failed".into(),
                message: format!("HTTP request failed: {}", message),
                details: serde_json::json!({ "url": sanitize_url(url) }),
            },
            DpkError::AlreadyRunning => ErrorInfo {
                code: "already_running".into(),
                message: e.to_string(),
                details: serde_json::Value::Object(Default::default()),
            },
            DpkError::EnvResolutionFailed { path, .. } => ErrorInfo {
                code: "env_resolution_failed".into(),
                message: e.to_string(),
                details: serde_json::json!({ "path": path.display().to_string() }),
            },
            _ => ErrorInfo {
                code: "internal_error".into(),
                message: e.to_string(),
                details: serde_json::Value::Object(Default::default()),
            },
        }
    }
}

fn sanitize_url(url: &str) -> String {
    // Strip credentials from URLs before including in output
    if let Some(at_pos) = url.find('@') {
        if let Some(scheme_end) = url.find("://") {
            let scheme = &url[..scheme_end + 3];
            let rest = &url[at_pos + 1..];
            return format!("{}***@{}", scheme, rest);
        }
    }
    url.to_string()
}
