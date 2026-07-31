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

#[test]
fn test_no_project_files_returns_json_failure() {
    // Run from a temp dir with no language indicators
    let tmp = tempfile::tempdir().expect("create tempdir");
    let (stdout, _stderr, code) = run_dpk(&tmp.path().to_path_buf(), &["lint"]);
    assert_ne!(code, 0, "should exit nonzero when language detection fails");
    let trimmed = stdout.trim();
    assert!(
        !trimmed.is_empty(),
        "stdout should not be empty even on failure"
    );
    let v: serde_json::Value =
        serde_json::from_str(trimmed).expect("failure output should still be valid JSON");
    assert_eq!(v["schema_version"], 1);
    assert_eq!(v["status"], "failure");
}

#[test]
fn test_failure_json_has_error_field() {
    let tmp = tempfile::tempdir().expect("create tempdir");
    let (stdout, _stderr, _code) = run_dpk(&tmp.path().to_path_buf(), &["lint"]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert!(
        v["error"].is_object() || v["phases"]["lint"]["error"].is_object(),
        "failure should include error details"
    );
}
