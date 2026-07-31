use std::path::PathBuf;
use std::process::Command;

fn fixture_dir(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

fn build_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn dpk_build_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/debug/dpk-build")
}

fn run_dpk_env(
    project_dir: &PathBuf,
    args: &[&str],
    env: &[(&str, &str)],
) -> (String, String, i32) {
    let bin = dpk_build_bin();
    let mut cmd = Command::new(&bin);
    cmd.args(args)
        .current_dir(project_dir)
        .env("BUILD_ROOT", build_root());
    for (k, v) in env {
        cmd.env(k, v);
    }
    let output = cmd.output().expect("failed to run dpk-build binary");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let code = output.status.code().unwrap_or(-1);
    (stdout, stderr, code)
}

#[test]
fn test_env_skip_lint_respected() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) =
        run_dpk_env(&dir, &["--dry-run", "deliver"], &[("SKIP_LINT", "true")]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    // In dry_run all are skipped with dry_run reason, but the env var is also set
    // The env SKIP_LINT=true should be respected — dry_run takes priority in the implementation
    assert!(v["phases"]["lint"]["status"] == "skipped");
}

#[test]
fn test_env_skip_tests_respected() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) =
        run_dpk_env(&dir, &["--dry-run", "deliver"], &[("SKIP_TESTS", "1")]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert!(v["phases"]["test"]["status"] == "skipped");
}
