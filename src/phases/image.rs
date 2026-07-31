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

    let script = match ctx.language {
        Language::Python => ctx.build_root.join("python/build-docker.sh"),
        Language::Rust => ctx.build_root.join("rust/build-docker.sh"),
        Language::Node => {
            let e = crate::error::DpkError::OperationNotSupported {
                op: "image".into(),
                language: "node".into(),
            };
            return PhaseResult::failure(0, ErrorInfo::from(&e));
        }
    };

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
