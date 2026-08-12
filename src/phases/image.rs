use crate::context::{Language, RunContext};
use crate::error::ErrorInfo;
use crate::executor::run_legacy_script;
use crate::phases::PhaseResult;
use crate::skip::{SkipFlags, SkipReason};
use std::sync::{atomic::AtomicBool, Arc};

pub fn run(ctx: &RunContext, skips: &SkipFlags, cancelled: &Arc<AtomicBool>) -> PhaseResult {
    if ctx.dry_run {
        return PhaseResult::skipped(SkipReason::DryRun);
    }
    if let Some(reason) = skips.should_skip_image() {
        return PhaseResult::skipped(reason);
    }

    // If no docker config, skip
    if !ctx.project_cfg.as_ref().is_some_and(|c| c.image_enabled()) {
        return PhaseResult::skipped(SkipReason::NotConfigured);
    }

    let script = image_script(ctx.language, &ctx.build_root);

    let timeout = ctx
        .project_cfg
        .as_ref()
        .and_then(|c| c.timeout_for("image"));
    let env = super::lint::base_env(ctx, skips);

    match run_legacy_script(
        &script,
        &[],
        &ctx.project_dir,
        &env,
        timeout,
        ctx.output_mode,
        cancelled,
    ) {
        Err(e) => PhaseResult::failure(0, ErrorInfo::from(&e)),
        Ok(outcome) => super::lint::outcome_to_result(outcome),
    }
}

/// Node uses the same docker script as Python/Java: `python/build-docker.sh` is
/// language-agnostic (Dockerfile + IMAGE_NAME + VITE_* build-args). The deleted
/// root `build-docker-image.sh` was a two-line exec wrapper onto that script.
fn image_script(language: Language, build_root: &std::path::Path) -> std::path::PathBuf {
    match language {
        Language::Python | Language::Java | Language::Node => {
            build_root.join("python/build-docker.sh")
        }
        Language::Rust => build_root.join("rust/build-docker.sh"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn node_image_uses_python_docker_script() {
        let root = PathBuf::from("/tmp/dpk-build");
        let py = root.join("python/build-docker.sh");
        let rs = root.join("rust/build-docker.sh");
        assert_eq!(image_script(Language::Python, &root), py);
        assert_eq!(image_script(Language::Java, &root), py);
        assert_eq!(image_script(Language::Node, &root), py);
        assert_eq!(image_script(Language::Rust, &root), rs);
    }
}
