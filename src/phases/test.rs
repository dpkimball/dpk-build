use crate::context::{Language, RunContext};
use crate::error::ErrorInfo;
use crate::executor::{run_program, ExecRequest};
use crate::phases::PhaseResult;
use crate::skip::{SkipFlags, SkipReason};
use std::ffi::OsString;
use std::sync::{atomic::AtomicBool, Arc};
use std::time::Instant;

pub fn run(ctx: &RunContext, skips: &SkipFlags, cancelled: &Arc<AtomicBool>) -> PhaseResult {
    if ctx.dry_run {
        return PhaseResult::skipped(SkipReason::DryRun);
    }
    if let Some(reason) = skips.should_skip_tests() {
        return PhaseResult::skipped(reason);
    }

    let start = Instant::now();
    let timeout = ctx.project_cfg.as_ref().and_then(|c| c.timeout_for("test"));
    let env = super::lint::base_env(ctx, skips);

    match ctx.language {
        Language::Python => {
            let test_dir = std::env::var("TEST_DIRECTORY").unwrap_or_else(|_| "tests".into());
            let req = ExecRequest {
                program: OsString::from("uv"),
                args: ["run", "python", "-m", "pytest", &test_dir]
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
                Ok(mut outcome) => {
                    // pytest exit code 5 = no tests collected → treat as success
                    if outcome.exit_code == 5 {
                        outcome.exit_code = 0;
                    }
                    let mut r = super::lint::outcome_to_result(outcome);
                    r.duration_ms = start.elapsed().as_millis() as u64;
                    r
                }
            }
        }
        Language::Rust => {
            let req = ExecRequest {
                program: OsString::from("cargo"),
                args: ["test", "--all"].iter().map(OsString::from).collect(),
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
                op: "test".into(),
                language: "node".into(),
            };
            PhaseResult::failure(0, ErrorInfo::from(&e))
        }
    }
}
