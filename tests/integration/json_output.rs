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

/// Run dpk-build with given args from a given project dir.
/// Returns (stdout, stderr, exit_code).
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
fn test_dry_run_produces_valid_json_python() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["--dry-run", "lint"]);
    let trimmed = stdout.trim();
    assert!(!trimmed.is_empty(), "stdout should not be empty");
    let v: serde_json::Value = serde_json::from_str(trimmed).expect("stdout should be valid JSON");
    assert_eq!(v["schema_version"], 1, "schema_version must be 1");
    assert!(v["operation"].is_string(), "operation must be a string");
    assert!(v["status"].is_string(), "status must be a string");
}

#[test]
fn test_dry_run_produces_valid_json_rust() {
    let dir = fixture_dir("fake_project_rust");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["--dry-run", "lint"]);
    let trimmed = stdout.trim();
    assert!(!trimmed.is_empty(), "stdout should not be empty");
    let v: serde_json::Value = serde_json::from_str(trimmed).expect("stdout should be valid JSON");
    assert_eq!(v["schema_version"], 1);
}

#[test]
fn test_exactly_one_json_object_on_stdout() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["--dry-run", "deliver"]);
    // Should be exactly one line of JSON
    let lines: Vec<&str> = stdout.lines().filter(|l| !l.trim().is_empty()).collect();
    assert_eq!(
        lines.len(),
        1,
        "should emit exactly one JSON line, got: {:?}",
        lines
    );
    let _: serde_json::Value =
        serde_json::from_str(lines[0]).expect("the single line must be valid JSON");
}
