use std::io::Write;
use std::path::{Path, PathBuf};
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

/// Spawn dpk-build with child-only env control (no parent set_var/remove_var).
fn run_dry_lint(build_root: Option<&str>) -> (String, i32) {
    run_dry_lint_in(&fixture_dir("fake_project_python"), build_root)
}

fn run_dry_lint_in(project: &Path, build_root: Option<&str>) -> (String, i32) {
    let bin = dpk_build_bin();
    let mut cmd = Command::new(&bin);
    cmd.args(["--dry-run", "lint"])
        .current_dir(project)
        .env_remove("BUILD_ROOT");
    if let Some(v) = build_root {
        cmd.env("BUILD_ROOT", v);
    }
    let output = cmd.output().expect("failed to run dpk-build binary");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let code = output.status.code().unwrap_or(-1);
    (stdout, code)
}

fn decoy_build_root() -> tempfile::TempDir {
    let dir = tempfile::tempdir().expect("tempdir");
    let mut f = std::fs::File::create(dir.path().join("env.sh")).expect("create decoy env.sh");
    writeln!(f, "export BUILD_LANG=not-a-language").expect("write decoy env.sh");
    dir
}

#[test]
fn resolve_build_root_prefers_build_root_only() {
    let root = build_root();
    let (stdout, code) = run_dry_lint(Some(root.to_str().unwrap()));
    assert_eq!(code, 0, "stdout={stdout}");
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "success");
}

/// BUILD_ROOT pointing at a decoy build root (with a bad language) must fail,
/// proving the variable is actually read rather than ignored.
#[test]
fn resolve_build_root_decoy_fails() {
    let decoy = decoy_build_root();
    let (stdout, code) = run_dry_lint(Some(decoy.path().to_str().unwrap()));
    assert_ne!(code, 0, "decoy BUILD_ROOT must fail; stdout={stdout}");
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "failure");
    assert_eq!(
        v["error"]["code"], "language_unsupported",
        "expected language_unsupported from decoy BUILD_LANG; got {v}"
    );
}

/// Without BUILD_ROOT, the debug fallback resolves to CARGO_MANIFEST_DIR (this
/// repository). env.sh there sets no BUILD_LANG, so a project with no language
/// indicators fails — confirming fallback is active but non-magical.
#[test]
fn resolve_build_root_no_var_uses_debug_fallback() {
    let project = tempfile::tempdir().expect("tempdir");
    let (stdout, code) = run_dry_lint_in(project.path(), None);
    assert_ne!(
        code, 0,
        "debug fallback must not satisfy an indicator-less project; stdout={stdout}"
    );
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "failure");
    assert_eq!(
        v["error"]["code"], "language_unsupported",
        "expected language_unsupported from debug fallback; got {v}"
    );
}
