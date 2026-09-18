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
            // clippy (ruff check analog)
            let req = ExecRequest {
                program: OsString::from("cargo"),
                args: rust_clippy_args(),
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

            // cargo fmt --check (ruff format --check analog)
            let req2 = ExecRequest {
                program: OsString::from("cargo"),
                args: rust_fmt_check_args(),
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
        Language::Node => {
            let e = crate::error::DpkError::OperationNotSupported {
                op: "lint".into(),
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
                goals: &["validate", "compile"],
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
                    let mut r = outcome_to_result(outcome);
                    r.duration_ms = start.elapsed().as_millis() as u64;
                    r
                }
            }
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
                set_or_update(&mut env, "IMAGE_NAME", OsString::from(n));
            }
            if let Some(d) = &docker.dockerfile {
                set_or_update(&mut env, "DOCKERFILE", OsString::from(d));
            }
            if let Some(d) = &docker.dockerfile_dir {
                set_or_update(&mut env, "DOCKERFILE_DIR", OsString::from(d));
            }
            if let Some(p) = &docker.platforms {
                set_or_update(&mut env, "DOCKER_PLATFORMS", OsString::from(p.join(",")));
            }
            if let Some(extras) = &docker.extra_image_builds {
                if !extras.is_empty() {
                    set_or_update(
                        &mut env,
                        "EXTRA_IMAGE_BUILDS",
                        OsString::from(extras.join(",")),
                    );
                }
            }
            if let Some(w) = &docker.worker_image_name {
                set_or_update(&mut env, "WORKER_IMAGE_NAME", OsString::from(w));
            }
            if let Some(args) = &docker.extra_args {
                set_or_update(&mut env, "DOCKER_EXTRA_ARGS", OsString::from(args));
            }
        }
        if let Some(dep) = &cfg.deploy {
            if let Some(r) = &dep.helm_release {
                set_or_update(&mut env, "HELM_RELEASE", OsString::from(r));
            }
            if let Some(rs) = &dep.helm_releases {
                set_or_update(&mut env, "HELM_RELEASES", OsString::from(rs.join(",")));
            }
            if let Some(ns) = &dep.k8s_namespace {
                set_or_update(&mut env, "K8S_NAMESPACE", OsString::from(ns));
            }
            if let Some(cp) = &dep.helm_chart_path {
                set_or_update(&mut env, "HELM_CHART_PATH", OsString::from(cp));
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

fn rust_clippy_args() -> Vec<OsString> {
    [
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
    .collect()
}

fn rust_fmt_check_args() -> Vec<OsString> {
    // Do not pass `--all`: that formats local path-based dependencies and
    // loads *their* workspaces. Plugin CI path-deps binder-desktop crates
    // without sibling plugins (bucket-binder, goals-binder), so `--all`
    // fails metadata on binder-app. `cargo fmt` still formats the current
    // package and, for a workspace, all members.
    ["fmt", "--", "--check"]
        .iter()
        .map(OsString::from)
        .collect()
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rust_lint_is_clippy_then_fmt_check() {
        let clippy: Vec<String> = rust_clippy_args()
            .iter()
            .map(|s| s.to_string_lossy().into_owned())
            .collect();
        let fmt: Vec<String> = rust_fmt_check_args()
            .iter()
            .map(|s| s.to_string_lossy().into_owned())
            .collect();
        assert_eq!(
            clippy,
            [
                "clippy",
                "--workspace",
                "--all-targets",
                "--all-features",
                "--",
                "-D",
                "warnings"
            ]
        );
        assert_eq!(fmt, ["fmt", "--", "--check"]);
    }
}
