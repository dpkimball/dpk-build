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
    pub version: Option<String>,
    /// Optional path to the Maven POM relative to the project root (e.g. `jobs/pom.xml`).
    pub maven_pom: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DockerSection {
    pub image_name: Option<String>,
    pub dockerfile_dir: Option<String>,
    pub dockerfile: Option<String>,
    pub platforms: Option<Vec<String>>,
    /// Companion images built after the primary image.
    /// Each entry is `image_name:path/to/Dockerfile` (comma-joined into EXTRA_IMAGE_BUILDS).
    pub extra_image_builds: Option<Vec<String>>,
    /// Companion image name pinned into Helm as `config.workerImage` (WORKER_IMAGE_NAME).
    pub worker_image_name: Option<String>,
    /// Extra args forwarded to `docker build` / buildx (DOCKER_EXTRA_ARGS), e.g. BuildKit
    /// `--build-context` siblings for Rust services.
    pub extra_args: Option<String>,
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
                    "python" | "rust" | "node" | "java" => {}
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_companion_image_and_extra_args() {
        let cfg: ProjectConfig = toml::from_str(
            r#"
[docker]
image_name = "security-audit-api"
dockerfile = "Dockerfile.runtime"
dockerfile_dir = "."
extra_image_builds = ["security-audit-runner:containers/security-audit-runner/Dockerfile"]
worker_image_name = "security-audit-runner"
extra_args = "--build-context dpk2=../dpk2 --build-context bindb=../bindb"
"#,
        )
        .unwrap();
        let docker = cfg.docker.expect("docker section");
        assert_eq!(docker.image_name.as_deref(), Some("security-audit-api"));
        assert_eq!(docker.dockerfile.as_deref(), Some("Dockerfile.runtime"));
        assert_eq!(docker.dockerfile_dir.as_deref(), Some("."));
        assert_eq!(
            docker.extra_image_builds.as_ref().map(|v| v.join(",")),
            Some("security-audit-runner:containers/security-audit-runner/Dockerfile".to_string())
        );
        assert_eq!(
            docker.worker_image_name.as_deref(),
            Some("security-audit-runner")
        );
        assert_eq!(
            docker.extra_args.as_deref(),
            Some("--build-context dpk2=../dpk2 --build-context bindb=../bindb")
        );
    }

    #[test]
    fn accepts_java_language() {
        let cfg: ProjectConfig = toml::from_str(
            r#"
[project]
name = "pdp"
language = "java"
maven_pom = "jobs/pom.xml"
"#,
        )
        .unwrap();
        cfg.validate().expect("java should be allowed");
        assert_eq!(
            cfg.project.as_ref().and_then(|p| p.language.as_deref()),
            Some("java")
        );
        assert_eq!(
            cfg.project.as_ref().and_then(|p| p.maven_pom.as_deref()),
            Some("jobs/pom.xml")
        );
    }
}
