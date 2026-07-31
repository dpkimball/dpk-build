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
fn test_doctor_produces_valid_json() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["doctor"]);
    let trimmed = stdout.trim();
    assert!(!trimmed.is_empty());
    let v: serde_json::Value =
        serde_json::from_str(trimmed).expect("doctor output should be valid JSON");
    assert_eq!(v["schema_version"], 1);
    assert_eq!(v["operation"], "doctor");
    assert!(
        v["checks"].is_array(),
        "doctor output should have a checks array"
    );
}

#[test]
fn test_doctor_checks_array_has_required_fields() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["doctor"]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    let checks = v["checks"].as_array().expect("checks should be array");
    assert!(!checks.is_empty(), "checks should not be empty");
    for check in checks {
        assert!(check["name"].is_string(), "each check must have a name");
        assert!(
            check["found"].is_boolean(),
            "each check must have found boolean"
        );
        assert!(
            check["required"].is_boolean(),
            "each check must have required boolean"
        );
    }
}
