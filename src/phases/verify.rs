use crate::context::RunContext;
use crate::error::ErrorInfo;
use crate::phases::PhaseResult;
use crate::skip::{SkipFlags, SkipReason};
use std::ffi::OsString;
use std::sync::{atomic::AtomicBool, Arc};
use std::time::{Duration, Instant};

pub fn run(ctx: &RunContext, skips: &SkipFlags, _cancelled: &Arc<AtomicBool>) -> PhaseResult {
    if ctx.dry_run {
        return PhaseResult::skipped(SkipReason::DryRun);
    }

    let verify_cfg = match ctx.project_cfg.as_ref().and_then(|c| c.verify.as_ref()) {
        Some(v) => v.clone(),
        None => return PhaseResult::skipped(SkipReason::NotConfigured),
    };

    let start = Instant::now();
    let phase_timeout = ctx
        .project_cfg
        .as_ref()
        .and_then(|c| c.timeout_for("verify"));

    // HTTP check
    if let Some(http) = &verify_cfg.http {
        let http_timeout = parse_duration_secs(&http.timeout).unwrap_or(30);
        let remaining = phase_timeout.map(|pt| pt.saturating_sub(start.elapsed()).as_secs().max(1));
        let effective_secs = remaining.unwrap_or(http_timeout).min(http_timeout);

        match ureq::get(&http.url)
            .timeout(Duration::from_secs(effective_secs))
            .call()
        {
            Err(e) => {
                let err = crate::error::DpkError::HttpRequestFailed {
                    url: http.url.clone(),
                    message: e.to_string(),
                };
                return PhaseResult::failure(
                    start.elapsed().as_millis() as u64,
                    ErrorInfo::from(&err),
                );
            }
            Ok(resp) => {
                let status = resp.status();
                if status != http.expected_status {
                    let err = crate::error::DpkError::HttpCheckFailed {
                        url: http.url.clone(),
                        expected: http.expected_status,
                        got: status,
                    };
                    return PhaseResult::failure(
                        start.elapsed().as_millis() as u64,
                        ErrorInfo::from(&err),
                    );
                }
            }
        }
    }

    // Project command
    if let Some(cmd_parts) = &verify_cfg.command {
        if !cmd_parts.is_empty() {
            let program = OsString::from(&cmd_parts[0]);
            let args: Vec<OsString> = cmd_parts[1..].iter().map(OsString::from).collect();
            let remaining_timeout = phase_timeout.map(|pt| pt.saturating_sub(start.elapsed()));
            let env = super::lint::base_env(ctx, skips);
            let req = crate::executor::ExecRequest {
                program,
                args,
                cwd: ctx.project_dir.clone(),
                env_overrides: env,
                timeout: remaining_timeout,
                output_mode: ctx.output_mode,
            };
            match crate::executor::run_program(&req, _cancelled) {
                Err(e) => {
                    return PhaseResult::failure(
                        start.elapsed().as_millis() as u64,
                        ErrorInfo::from(&e),
                    )
                }
                Ok(outcome) => {
                    if outcome.exit_code != 0 {
                        let error = ErrorInfo {
                            code: "process_exit_nonzero".into(),
                            message: format!(
                                "verify command exited with code {}",
                                outcome.exit_code
                            ),
                            details: serde_json::json!({ "exit_code": outcome.exit_code }),
                        };
                        return PhaseResult::failure(start.elapsed().as_millis() as u64, error);
                    }
                }
            }
        }
    }

    PhaseResult::success(start.elapsed().as_millis() as u64)
}

fn parse_duration_secs(s: &Option<String>) -> Option<u64> {
    let s = s.as_deref()?;
    if let Some(n) = s.strip_suffix('s') {
        n.parse().ok()
    } else if let Some(n) = s.strip_suffix('m') {
        n.parse::<u64>().ok().map(|v| v * 60)
    } else {
        s.parse().ok()
    }
}
