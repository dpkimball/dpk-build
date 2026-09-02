use std::path::PathBuf;
use std::process::Command;

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

fn fixture(name: &str) -> PathBuf {
    build_root().join("tests/fixtures").join(name)
}

#[test]
fn test_project_env_sh_sets_skip_flag() {
    // fake_project_python_env/env.sh exports SKIP_TESTS=true.
    // Running `dpk-build test` should pick that up and skip the test phase
    // with reason "environment" rather than trying to run pytest.
    let dir = fixture("fake_project_python_env");
    let (stdout, _stderr, code) = run_dpk(&dir, &["test"]);
    assert_eq!(code, 0, "exit code should be 0 when phase is skipped");
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "success");
    assert_eq!(v["phases"]["test"]["status"], "skipped");
    assert_eq!(
        v["phases"]["test"]["reason"], "environment",
        "SKIP_TESTS from project env.sh should produce reason=environment"
    );
}

#[test]
fn test_build_root_env_sh_sourced() {
    // The build_root (dpk-build repo itself) has an env.sh that exports many
    // defaults. The most observable effect without running real tools is that
    // the binary successfully resolves context without error. Run --dry-run
    // deliver on the standard Python fixture to confirm no env-resolution error.
    let dir = fixture("fake_project_python");
    let (stdout, _stderr, code) = run_dpk(&dir, &["--dry-run", "deliver"]);
    assert_eq!(code, 0);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "success");
}
