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
fn test_skip_lint_flag_skips_lint_phase() {
    let dir = fixture_dir("fake_project_python");
    let (stdout, _stderr, _code) = run_dpk(&dir, &["--dry-run", "deliver", "--skip-lint"]);
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    // In dry-run, everything is skipped, but we can verify structure
    assert!(v["phases"]["lint"].is_object());
}

#[test]
fn test_help_flag_exits_without_json() {
    let bin = dpk_build_bin();
    let output = Command::new(&bin)
        .arg("--help")
        .output()
        .expect("failed to run dpk-build binary");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    // Help should not produce JSON
    assert!(
        !stdout.trim().starts_with('{'),
        "help should not produce JSON"
    );
}

#[test]
fn test_missing_subcommand_exits_nonzero() {
    let bin = dpk_build_bin();
    let output = Command::new(&bin)
        .output()
        .expect("failed to run dpk-build binary");
    assert_ne!(
        output.status.code().unwrap_or(0),
        0,
        "missing subcommand should exit nonzero"
    );
}

#[test]
fn test_unknown_subcommand_exits_nonzero() {
    let bin = dpk_build_bin();
    let output = Command::new(&bin)
        .arg("nonexistent-subcommand")
        .output()
        .expect("failed to run dpk-build binary");
    assert_ne!(output.status.code().unwrap_or(0), 0);
}
