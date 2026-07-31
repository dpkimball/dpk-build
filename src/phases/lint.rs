use crate::context::{Language, RunContext};
use crate::error::ErrorInfo;
use crate::executor::{run_program, ExecOutcome, ExecRequest};
use crate::phases::PhaseResult;
use crate::skip::{SkipFlags, SkipReason};
use std::ffi::OsString;
use std::sync::{atomic::AtomicBool, Arc};
use std::time::Instant;

pub fn run(ctx: &RunContext, skips: &SkipFlags, cancelled: &Arc<AtomicBool>) -> PhaseResult {
    if ctx.dry_run {
        return PhaseResult::skipped(SkipReason::DryRun);
    }
    if let Some(reason) = skips.should_skip_lint() {
        return PhaseResult::skipped(reason);
    }

    let start = Instant::now();
    let timeout = ctx.project_cfg.as_ref().and_then(|c| c.timeout_for("lint"));
    let env = base_env(ctx, skips);

    match ctx.language {
        Language::Python => {
            let lint_dir = std::env::var("LINT_DIRECTORY").unwrap_or_else(|_| ".".into());

            // ruff check
            let req = ExecRequest {
                program: OsString::from("uv"),
                args: ["run", "ruff", "check", &lint_dir]
                    .iter()
                    .map(OsString::from)
                    .collect(),
                cwd: ctx.project_dir.clone(),
                env_overrides: env.clone(),
                timeout,
                output_mode: ctx.output_mode,
            };
            match run_program(&req, cancelled) {
                Err(e) => {
                    return PhaseResult::failure(
                        start.elapsed().as_millis() as u64,
                        ErrorInfo::from(&e),
                    )
                }
                Ok(outcome) => {
                    let r = outcome_to_result(outcome);
                    if r.is_terminal() {
                        return r;
                    }
                }
            }

            // ruff format --check
            let req2 = ExecRequest {
                program: OsString::from("uv"),
                args: ["run", "ruff", "format", &lint_dir, "--check"]
                    .iter()
                    .map(OsString::from)
                    .collect(),
                cwd: ctx.project_dir.clone(),
                env_overrides: env,
                timeout,
                output_mode: ctx.output_mode,
            };
            match run_program(&req2, cancelled) {
                Err(e) => {
                    PhaseResult::failure(start.elapsed().as_millis() as u64, ErrorInfo::from(&e))
                }
                Ok(outcome) => {
                    let mut r = outcome_to_result(outcome);
                    r.duration_ms = start.elapsed().as_millis() as u64;
                    r
                }
            }
        }
        Language::Rust => {
            let req = ExecRequest {
                program: OsString::from("cargo"),
                args: [
                    "clippy",
                    "--workspace",
                    "--all-targets",
                    "--all-features",
                    "--",
                    "-D",
                    "warnings",
                ]
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
                    let mut r = outcome_to_result(outcome);
                    r.duration_ms = start.elapsed().as_millis() as u64;
                    r
                }
            }
        }
        Language::Node => {
            let e = crate::error::DpkError::OperationNotSupported {
                op: "lint".into(),
                language: "node".into(),
            };
            PhaseResult::failure(0, ErrorInfo::from(&e))
        }
    }
}

pub(crate) fn base_env(ctx: &RunContext, skips: &SkipFlags) -> Vec<(OsString, OsString)> {
    // Start with resolved env (from env.sh files), then overlay our explicit vars
    let mut env: Vec<(OsString, OsString)> = ctx.resolved_env.clone();

    // These override whatever came from env.sh
    set_or_update(
        &mut env,
        "BUILD_ROOT",
        ctx.build_root.as_os_str().to_os_string(),
    );
    set_or_update(
        &mut env,
        "PROJECT_ROOT",
        ctx.project_dir.as_os_str().to_os_string(),
    );
    set_or_update(
        &mut env,
        "BUILD_LANG",
        OsString::from(ctx.language.as_str()),
    );

    env.extend(crate::skip::env_overrides_for_child(skips));

    // Map dpk.toml deploy/docker fields to env vars for shell scripts
    if let Some(cfg) = &ctx.project_cfg {
        if let Some(docker) = &cfg.docker {
            if let Some(n) = &docker.image_name {
                env.push((OsString::from("IMAGE_NAME"), OsString::from(n)));
            }
            if let Some(p) = &docker.platforms {
                env.push((
                    OsString::from("DOCKER_PLATFORMS"),
                    OsString::from(p.join(",")),
                ));
            }
        }
        if let Some(dep) = &cfg.deploy {
            if let Some(r) = &dep.helm_release {
                env.push((OsString::from("HELM_RELEASE"), OsString::from(r)));
            }
            if let Some(rs) = &dep.helm_releases {
                env.push((
                    OsString::from("HELM_RELEASES"),
                    OsString::from(rs.join(",")),
                ));
            }
            if let Some(ns) = &dep.k8s_namespace {
                env.push((OsString::from("K8S_NAMESPACE"), OsString::from(ns)));
            }
            if let Some(cp) = &dep.helm_chart_path {
                env.push((OsString::from("HELM_CHART_PATH"), OsString::from(cp)));
            }
        }
    }
    env
}

/// Set a key in env vec, overwriting if already present, or appending.
fn set_or_update(env: &mut Vec<(OsString, OsString)>, key: &str, val: OsString) {
    let k = OsString::from(key);
    if let Some(existing) = env.iter_mut().find(|(ek, _)| ek == &k) {
        existing.1 = val;
    } else {
        env.push((k, val));
    }
}

pub(crate) fn outcome_to_result(outcome: ExecOutcome) -> PhaseResult {
    if outcome.cancelled {
        return PhaseResult::cancelled(outcome.duration_ms);
    }
    if outcome.timed_out {
        let limit_secs = outcome.timeout_limit_secs.unwrap_or(0);
        return PhaseResult::timed_out(outcome.duration_ms, limit_secs);
    }
    if outcome.exit_code != 0 {
        let error = crate::error::ErrorInfo {
            code: "process_exit_nonzero".into(),
            message: format!("process exited with code {}", outcome.exit_code),
            details: serde_json::json!({ "exit_code": outcome.exit_code }),
        };
        return PhaseResult::failure(outcome.duration_ms, error);
    }
    PhaseResult::success(outcome.duration_ms)
}
