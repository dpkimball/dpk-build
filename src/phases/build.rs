use crate::context::{Language, RunContext};
use crate::error::ErrorInfo;
use crate::executor::{run_legacy_script, run_program, ExecRequest};
use crate::phases::PhaseResult;
use crate::skip::{SkipFlags, SkipReason};
use std::ffi::OsString;
use std::sync::{atomic::AtomicBool, Arc};
use std::time::Instant;

pub fn run(ctx: &RunContext, skips: &SkipFlags, cancelled: &Arc<AtomicBool>) -> PhaseResult {
    if ctx.dry_run {
        return PhaseResult::skipped(SkipReason::DryRun);
    }
    if let Some(reason) = skips.should_skip_build() {
        return PhaseResult::skipped(reason);
    }

    let start = Instant::now();
    let timeout = ctx
        .project_cfg
        .as_ref()
        .and_then(|c| c.timeout_for("build"));
    let env = super::lint::base_env(ctx, skips);

    match ctx.language {
        Language::Python => {
            // Python build uses the existing shell script (pypi integration is complex)
            let script = ctx.build_root.join("python/build-wheel.sh");
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
        Language::Rust => {
            let req = ExecRequest {
                program: OsString::from("cargo"),
                args: ["build", "--release", "--workspace"]
                    .iter()
                    .map(OsString::from)
                    .collect(),
                cwd: ctx.project_dir.clone(),
                env_overrides: env,
                timeout,
                output_mode: ctx.output_mode,
            };
            match run_program(&req, cancelled) {
                Err(e) => {
                    PhaseResult::failure(start.elapsed().as_millis() as u64, ErrorInfo::from(&e))
                }
                Ok(outcome) => {
                    let mut r = super::lint::outcome_to_result(outcome);
                    r.duration_ms = start.elapsed().as_millis() as u64;
                    r
                }
            }
        }
        Language::Node => {
            let e = crate::error::DpkError::OperationNotSupported {
                op: "build".into(),
                language: "node".into(),
            };
            PhaseResult::failure(0, ErrorInfo::from(&e))
        }
        Language::Java => {
            let pom = match crate::maven::resolve_pom(
                &ctx.project_dir,
                crate::maven::toml_maven_pom(&ctx.project_cfg).as_deref(),
            ) {
                Ok(p) => p,
                Err(e) => {
                    return PhaseResult::failure(0, ErrorInfo::from(&e));
                }
            };
            match crate::maven::run_maven(crate::maven::MavenRun {
                project_dir: &ctx.project_dir,
                pom: &pom,
                goals: &["package"],
                extra_args: &["-DskipTests"],
                env_overrides: env,
                timeout,
                output_mode: ctx.output_mode,
                cancelled,
            }) {
                Err(e) => {
                    PhaseResult::failure(start.elapsed().as_millis() as u64, ErrorInfo::from(&e))
                }
                Ok(outcome) => {
                    let mut r = super::lint::outcome_to_result(outcome);
                    r.duration_ms = start.elapsed().as_millis() as u64;
                    r
                }
            }
        }
    }
}
