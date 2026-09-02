use crate::error::DpkError;
use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Debug, Deserialize, Default)]
pub struct WorkspaceConfig {
    #[serde(default)]
    pub projects: std::collections::HashMap<String, String>,
    #[serde(default)]
    pub deploy: Option<WorkspaceDeployConfig>,
}

#[derive(Debug, Deserialize)]
pub struct WorkspaceDeployConfig {
    pub local: Option<LocalDeployConfig>,
}

#[derive(Debug, Deserialize)]
pub struct LocalDeployConfig {
    pub contexts: LocalContextConfig,
}

#[derive(Debug, Deserialize)]
pub struct LocalContextConfig {
    pub allowlist: Vec<String>,
}

impl WorkspaceConfig {
    pub fn context_allowlist(&self) -> Option<&[String]> {
        self.deploy
            .as_ref()?
            .local
            .as_ref()
            .map(|l| l.contexts.allowlist.as_slice())
    }
}

pub fn load(path: &Path) -> Result<WorkspaceConfig, DpkError> {
    let content = std::fs::read_to_string(path).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: e.to_string(),
    })?;
    toml::from_str(&content).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: e.to_string(),
    })
}

/// Search for dpk-workspace.toml upward from `start`, up to 5 levels.
pub fn find(start: &Path) -> Option<PathBuf> {
    if let Ok(root) = std::env::var("WORKSPACE_ROOT") {
        let candidate = PathBuf::from(root).join("dpk-workspace.toml");
        if candidate.exists() {
            return Some(candidate);
        }
    }
    let mut dir = start.to_path_buf();
    for _ in 0..5 {
        let candidate = dir.join("dpk-workspace.toml");
        if candidate.exists() {
            return Some(candidate);
        }
        if !dir.pop() {
            break;
        }
    }
    None
}
