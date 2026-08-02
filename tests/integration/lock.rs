use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;

fn build_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn dpk_build_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/debug/dpk-build")
}

fn run_dpk(project_dir: &PathBuf, args: &[&str]) -> (String, String, i32) {
    let bin = dpk_build_bin();
    let output = Command::new(&bin)
        .args(args)
        .current_dir(project_dir)
        .env("BUILD_ROOT", build_root())
        .output()
        .expect("failed to run dpk-build binary");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let code = output.status.code().unwrap_or(-1);
    (stdout, stderr, code)
}

#[test]
fn test_second_invocation_returns_already_running() {
    let tmp = tempfile::tempdir().expect("tempdir");
    let lock_path = tmp.path().join(".dpk-build.lock");
    let ready_path = tmp.path().join(".lock-ready");

    // Hold the lock externally with python3 (always available on macOS/Linux).
    // Signal readiness via a side file so CI load cannot race the 200ms sleep.
    let lock_holder = Command::new("python3")
        .args([
            "-c",
            "import fcntl,time,sys; \
             f=open(sys.argv[1],'w'); \
             fcntl.flock(f.fileno(), fcntl.LOCK_EX); \
             open(sys.argv[2],'w').write('1'); \
             time.sleep(10)",
            lock_path.to_str().unwrap(),
            ready_path.to_str().unwrap(),
        ])
        .spawn()
        .expect("spawn python3 lock holder");

    // Wait until the holder has the exclusive flock (not a fixed sleep).
    let deadline = std::time::Instant::now() + Duration::from_secs(5);
    while !ready_path.exists() {
        assert!(
            std::time::Instant::now() < deadline,
            "python3 lock holder did not acquire flock in time"
        );
        std::thread::sleep(Duration::from_millis(20));
    }

    // tmp has no language files, so language detection will fail before we even
    // try to acquire the lock. Create a pyproject.toml so detection succeeds.
    std::fs::write(
        tmp.path().join("pyproject.toml"),
        "[project]\nname=\"t\"\nversion=\"0\"\n",
    )
    .unwrap();

    let (stdout, _stderr, code) = run_dpk(&tmp.path().to_path_buf(), &["lint"]);

    // Kill the lock holder now that we have our result.
    let _ = Command::new("kill")
        .arg(lock_holder.id().to_string())
        .status();
    let _ = lock_holder.wait_with_output();

    assert_ne!(code, 0, "should exit nonzero when lock is held");
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "failure");
    assert_eq!(
        v["error"]["code"], "already_running",
        "error code should be already_running; got: {}",
        v
    );
}
