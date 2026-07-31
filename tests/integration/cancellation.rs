use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;

fn build_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn dpk_build_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/debug/dpk-build")
}

fn fixture(name: &str) -> PathBuf {
    build_root().join("tests/fixtures").join(name)
}

#[test]
fn test_sigint_produces_cancelled_status() {
    // rust_slow fixture has a test that sleeps 60s. We start `dpk-build test`,
    // wait for cargo to compile and launch the test binary, then send SIGINT.
    // dpk-build should exit 130 and emit JSON with status "cancelled".
    let dir = fixture("rust_slow");
    let bin = dpk_build_bin();

    let mut child = Command::new(&bin)
        .args(["test"])
        .current_dir(&dir)
        .env("BUILD_ROOT", build_root())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .spawn()
        .expect("failed to spawn dpk-build");

    // Wait long enough for cargo to compile and start running the slow test.
    // On a warm cache this is ~2s; use 8s to be safe in CI.
    std::thread::sleep(Duration::from_secs(8));

    // Send SIGINT to dpk-build.
    #[cfg(unix)]
    {
        let pid = child.id();
        Command::new("kill")
            .args(["-INT", &pid.to_string()])
            .status()
            .expect("kill -INT failed");
    }

    let output = child.wait_with_output().expect("wait failed");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let code = output.status.code().unwrap_or(-1);

    assert_eq!(
        code, 130,
        "exit code should be 130 on SIGINT; stdout: {}",
        stdout
    );

    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["schema_version"], 1);
    assert_eq!(
        v["status"], "cancelled",
        "top-level status should be cancelled; got: {}",
        v
    );
    assert_eq!(
        v["phases"]["test"]["status"], "cancelled",
        "test phase should be cancelled; got: {}",
        v
    );
}
