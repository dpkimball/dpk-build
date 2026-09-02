use crate::error::DpkError;
use std::ffi::OsString;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum OutputMode {
    Default,
    Verbose,
    Quiet,
}

pub struct ExecRequest {
    pub program: OsString,
    pub args: Vec<OsString>,
    pub cwd: PathBuf,
    pub env_overrides: Vec<(OsString, OsString)>,
    pub timeout: Option<Duration>,
    pub output_mode: OutputMode,
}

pub struct ExecOutcome {
    pub exit_code: i32,
    #[allow(dead_code)]
    pub stdout_captured: Vec<u8>,
    pub duration_ms: u64,
    pub timed_out: bool,
    pub timeout_limit_secs: Option<u64>,
    pub cancelled: bool,
}

pub fn run_program(
    req: &ExecRequest,
    cancelled: &Arc<AtomicBool>,
) -> Result<ExecOutcome, DpkError> {
    let mut cmd = Command::new(&req.program);
    cmd.args(&req.args)
        .current_dir(&req.cwd)
        .stdout(Stdio::piped())
        .stderr(match req.output_mode {
            OutputMode::Quiet => Stdio::null(),
            _ => Stdio::inherit(),
        });
    for (k, v) in &req.env_overrides {
        cmd.env(k, v);
    }

    let mut child = cmd
        .spawn()
        .map_err(|e| DpkError::SpawnFailed { source: e })?;
    let stdout_pipe = child.stdout.take().expect("stdout is piped");

    let reader = std::thread::spawn(move || {
        let mut buf = Vec::new();
        std::io::BufReader::new(stdout_pipe)
            .read_to_end(&mut buf)
            .ok();
        buf
    });

    let start = Instant::now();
    let timeout_limit_secs = req.timeout.map(|d| d.as_secs());
    let status = loop {
        if let Some(s) = child
            .try_wait()
            .map_err(|e| DpkError::WaitFailed { source: e })?
        {
            break s;
        }
        // Check cancellation
        if cancelled.load(Ordering::Relaxed) {
            kill_process_group(&mut child);
            child.wait().ok();
            let stdout_captured = reader.join().unwrap_or_default();
            return Ok(ExecOutcome {
                exit_code: -130,
                stdout_captured,
                duration_ms: start.elapsed().as_millis() as u64,
                timed_out: false,
                timeout_limit_secs,
                cancelled: true,
            });
        }
        // Check timeout
        if let Some(limit) = req.timeout {
            if start.elapsed() > limit {
                child.kill().ok();
                child.wait().ok();
                let stdout_captured = reader.join().unwrap_or_default();
                return Ok(ExecOutcome {
                    exit_code: -1,
                    stdout_captured,
                    duration_ms: start.elapsed().as_millis() as u64,
                    timed_out: true,
                    timeout_limit_secs,
                    cancelled: false,
                });
            }
        }
        std::thread::sleep(Duration::from_millis(50));
    };

    let stdout_captured = reader.join().unwrap_or_default();
    let duration_ms = start.elapsed().as_millis() as u64;

    // Replay stdout on failure (any mode) or on verbose success
    let should_replay = !stdout_captured.is_empty()
        && (status.code().unwrap_or(-1) != 0 || req.output_mode == OutputMode::Verbose);
    if should_replay {
        let _ = std::io::Write::write_all(&mut std::io::stderr(), &stdout_captured);
    }

    Ok(ExecOutcome {
        exit_code: status.code().unwrap_or(-1),
        stdout_captured,
        duration_ms,
        timed_out: false,
        timeout_limit_secs,
        cancelled: false,
    })
}

pub fn run_legacy_script(
    script: &Path,
    args: &[OsString],
    cwd: &Path,
    env_overrides: &[(OsString, OsString)],
    timeout: Option<Duration>,
    output_mode: OutputMode,
    cancelled: &Arc<AtomicBool>,
) -> Result<ExecOutcome, DpkError> {
    let mut full_args = vec![script.as_os_str().to_os_string()];
    full_args.extend_from_slice(args);
    run_program(
        &ExecRequest {
            program: OsString::from("bash"),
            args: full_args,
            cwd: cwd.to_path_buf(),
            env_overrides: env_overrides.to_vec(),
            timeout,
            output_mode,
        },
        cancelled,
    )
}

#[cfg(unix)]
fn kill_process_group(child: &mut std::process::Child) {
    use nix::sys::signal::{killpg, Signal};
    use nix::unistd::Pid;
    let pid = child.id();
    let _ = killpg(Pid::from_raw(pid as i32), Signal::SIGTERM);
    child.kill().ok();
}

#[cfg(not(unix))]
fn kill_process_group(child: &mut std::process::Child) {
    child.kill().ok();
}
