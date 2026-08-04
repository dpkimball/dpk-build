use crate::config::project::ProjectConfig;
use crate::config::workspace::WorkspaceConfig;
use crate::error::DpkError;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Language {
    Python,
    Rust,
    Node,
    /// Flink/Maven services: lint/test/build via Maven; image/deploy via shared docker/helm scripts.
    Java,
}

impl Language {
    pub fn as_str(&self) -> &'static str {
        match self {
            Language::Python => "python",
            Language::Rust => "rust",
            Language::Node => "node",
            Language::Java => "java",
        }
    }
}

#[derive(Debug)]
pub struct RunContext {
    pub project_name: Option<String>,
    pub project_dir: PathBuf,
    pub build_root: PathBuf,
    pub language: Language,
    pub project_cfg: Option<ProjectConfig>,
    pub workspace_cfg: Option<WorkspaceConfig>,
    #[allow(dead_code)]
    pub workspace_manifest_path: Option<PathBuf>,
    pub output_mode: crate::executor::OutputMode,
    pub dry_run: bool,
    #[allow(dead_code)]
    pub verbose: bool,
    pub resolved_env: Vec<(std::ffi::OsString, std::ffi::OsString)>,
}

pub fn resolve_build_root() -> Result<PathBuf, DpkError> {
    if let Ok(v) = std::env::var("BUILD_ROOT") {
        return Ok(PathBuf::from(v));
    }
    if let Ok(v) = std::env::var("KEEPSAKE_SCRIPTS_ROOT") {
        return Ok(PathBuf::from(v));
    }
    #[cfg(debug_assertions)]
    {
        let manifest_dir = env!("CARGO_MANIFEST_DIR");
        if !manifest_dir.is_empty() {
            return Ok(PathBuf::from(manifest_dir));
        }
    }
    Err(DpkError::BuildRootNotFound)
}

pub fn detect_language(dir: &Path, override_lang: Option<&str>) -> Result<Language, DpkError> {
    if let Some(lang) = override_lang {
        return match lang {
            "python" => Ok(Language::Python),
            "rust" => Ok(Language::Rust),
            "node" => Ok(Language::Node),
            "java" => Ok(Language::Java),
            other => Err(DpkError::LanguageUnsupported { name: other.into() }),
        };
    }

    let mut found = Vec::new();
    let indicators = [
        ("Cargo.toml", Language::Rust),
        ("pyproject.toml", Language::Python),
        ("package.json", Language::Node),
        ("pom.xml", Language::Java),
        ("build.gradle", Language::Java),
    ];
    for (file, lang) in &indicators {
        if dir.join(file).exists() {
            found.push((dir.join(file), *lang));
        }
    }

    match found.len() {
        0 => Err(DpkError::LanguageUnsupported {
            name: "unknown".into(),
        }),
        1 => Ok(found.remove(0).1),
        _ => Err(DpkError::LanguageAmbiguous {
            files: found.into_iter().map(|(f, _)| f).collect(),
        }),
    }
}

pub fn resolve(
    project_arg: Option<&str>,
    cwd: &Path,
    output_mode: crate::executor::OutputMode,
    dry_run: bool,
    verbose: bool,
) -> Result<RunContext, DpkError> {
    let build_root = resolve_build_root()?;

    // Find workspace manifest
    let ws_manifest_path = crate::config::workspace::find(cwd);
    let workspace_cfg = ws_manifest_path
        .as_ref()
        .map(|p| crate::config::workspace::load(p))
        .transpose()?;

    // Resolve project directory
    let (project_dir, project_name) = if let Some(name) = project_arg {
        let ws = workspace_cfg.as_ref().ok_or_else(|| {
            DpkError::Other(format!(
                "named project '{}' requires a dpk-workspace.toml",
                name
            ))
        })?;
        let rel = ws.projects.get(name).ok_or_else(|| {
            DpkError::Other(format!(
                "project '{}' not found in dpk-workspace.toml",
                name
            ))
        })?;
        let ws_dir = ws_manifest_path.as_ref().unwrap().parent().unwrap();
        let dir = ws_dir.join(rel);
        if !dir.exists() {
            return Err(DpkError::Other(format!(
                "project directory '{}' does not exist",
                dir.display()
            )));
        }
        (dir, Some(name.to_string()))
    } else {
        (cwd.to_path_buf(), None)
    };

    // Source env.sh files and apply to current process env so BUILD_LANG overrides
    // and other env vars are visible during language detection and downstream scripts.
    let resolved_env = crate::env_resolver::resolve(&build_root, &project_dir)
        .unwrap_or_else(|_| crate::env_resolver::ResolvedEnv { vars: Vec::new() });
    for (k, v) in &resolved_env.vars {
        // Safety: single-threaded at this point; env resolution runs before any threads
        #[allow(unused_unsafe)]
        unsafe {
            std::env::set_var(k, v);
        }
    }
    let resolved_env_vars = resolved_env.vars;

    // Load dpk.toml if present
    let dpk_toml = project_dir.join("dpk.toml");
    let project_cfg = if dpk_toml.exists() {
        Some(crate::config::project::load(&dpk_toml)?)
    } else {
        None
    };

    // Determine project name
    let resolved_name = project_name
        .or_else(|| {
            project_cfg
                .as_ref()
                .and_then(|c| c.project.as_ref())
                .and_then(|p| p.name.clone())
        })
        .or_else(|| {
            project_dir
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
        });

    // Detect language (respects BUILD_LANG env var set from env.sh above)
    let lang_override = std::env::var("BUILD_LANG").ok().or_else(|| {
        project_cfg
            .as_ref()
            .and_then(|c| c.project.as_ref())
            .and_then(|p| p.language.as_deref())
            .map(|s| s.to_string())
    });
    let language = detect_language(&project_dir, lang_override.as_deref())?;

    Ok(RunContext {
        project_name: resolved_name,
        project_dir,
        build_root,
        language,
        project_cfg,
        workspace_cfg,
        workspace_manifest_path: ws_manifest_path,
        output_mode,
        dry_run,
        verbose,
        resolved_env: resolved_env_vars,
    })
}
