use crate::error::DpkError;
use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Deserialize, Default, Clone)]
pub struct ProjectConfig {
    pub project: Option<ProjectSection>,
    pub docker: Option<DockerSection>,
    pub deploy: Option<DeploySection>,
    pub verify: Option<VerifySection>,
    pub skip: Option<SkipSection>,
    pub timeout: Option<TimeoutSection>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ProjectSection {
    pub name: Option<String>,
    pub language: Option<String>,
    #[allow(dead_code)]
    pub version: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DockerSection {
    pub image_name: Option<String>,
    #[allow(dead_code)]
    pub dockerfile_dir: Option<String>,
    #[allow(dead_code)]
    pub dockerfile: Option<String>,
    pub platforms: Option<Vec<String>>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DeploySection {
    pub helm_release: Option<String>,
    pub helm_releases: Option<Vec<String>>,
    pub k8s_namespace: Option<String>,
    pub helm_chart_path: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct VerifySection {
    pub command: Option<Vec<String>>,
    pub http: Option<HttpVerifySection>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct HttpVerifySection {
    pub url: String,
    pub expected_status: u16,
    pub timeout: Option<String>,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct SkipSection {
    #[serde(default)]
    pub lint: bool,
    #[serde(default)]
    pub tests: bool,
    #[serde(default)]
    pub build: bool,
    #[serde(default)]
    pub image: bool,
    #[serde(default)]
    pub deploy: bool,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct TimeoutSection {
    pub lint_secs: Option<u64>,
    pub test_secs: Option<u64>,
    pub build_secs: Option<u64>,
    pub image_secs: Option<u64>,
    pub deploy_secs: Option<u64>,
    pub verify_secs: Option<u64>,
}

impl ProjectConfig {
    pub fn validate(&self) -> Result<(), DpkError> {
        if let Some(dep) = &self.deploy {
            if dep.helm_release.is_some() && dep.helm_releases.is_some() {
                return Err(DpkError::Other(
                    "dpk.toml: helm_release and helm_releases are mutually exclusive".into(),
                ));
            }
        }
        if let Some(proj) = &self.project {
            if let Some(lang) = &proj.language {
                match lang.as_str() {
                    "python" | "rust" | "node" => {}
                    "java" => {
                        return Err(DpkError::LanguageUnsupported {
                            name: "java".into(),
                        })
                    }
                    other => return Err(DpkError::LanguageUnsupported { name: other.into() }),
                }
            }
        }
        Ok(())
    }

    pub fn image_enabled(&self) -> bool {
        self.docker.is_some()
    }
    #[allow(dead_code)]
    pub fn deploy_enabled(&self) -> bool {
        self.deploy.is_some()
    }
    #[allow(dead_code)]
    pub fn verify_enabled(&self) -> bool {
        self.verify.is_some()
    }

    pub fn timeout_for(&self, phase: &str) -> Option<std::time::Duration> {
        let t = self.timeout.as_ref()?;
        let secs = match phase {
            "lint" => t.lint_secs,
            "test" => t.test_secs,
            "build" => t.build_secs,
            "image" => t.image_secs,
            "deploy" => t.deploy_secs,
            "verify" => t.verify_secs,
            _ => None,
        }?;
        Some(std::time::Duration::from_secs(secs))
    }
}

pub fn load(path: &Path) -> Result<ProjectConfig, DpkError> {
    let content = std::fs::read_to_string(path).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: e.to_string(),
    })?;
    let cfg: ProjectConfig = toml::from_str(&content).map_err(|e| DpkError::ManifestParse {
        path: path.to_path_buf(),
        message: e.to_string(),
    })?;
    cfg.validate()?;
    Ok(cfg)
}
