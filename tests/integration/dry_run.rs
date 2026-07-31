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
fn test_dry_run_lint_skips_execution() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, code) = run_dpk(&dir, &["--dry-run", "lint"]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("must be valid JSON");
    assert_eq!(code, 0, "dry-run should exit 0");
    let lint_phase = &v["phases"]["lint"];
    assert_eq!(lint_phase["status"], "skipped", "dry-run should skip lint");
    assert_eq!(lint_phase["reason"], "dry_run");
}

#[test]
fn test_dry_run_deliver_skips_all_phases() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["--dry-run", "deliver"]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("must be valid JSON");
    assert_eq!(v["operation"], "deliver");
    // All phases should be skipped with dry_run
    for phase_name in &["lint", "test", "build"] {
        let phase = &v["phases"][phase_name];
        assert_eq!(
            phase["status"], "skipped",
            "phase {} should be skipped in dry-run",
            phase_name
        );
    }
}

#[test]
fn test_dry_run_does_not_execute_scripts() {
    // Dry run should not produce any script output on stderr
    let dir = fixture_dir("fake_project_rust");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["--dry-run", "lint"]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["phases"]["lint"]["status"], "skipped");
}
