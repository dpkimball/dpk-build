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
fn run_dry_lint(build_root: Option<&str>, keepsake_scripts_root: Option<&str>) -> (String, i32) {
    run_dry_lint_in(
        &fixture_dir("fake_project_python"),
        build_root,
        keepsake_scripts_root,
    )
}

fn run_dry_lint_in(
    project: &Path,
    build_root: Option<&str>,
    keepsake_scripts_root: Option<&str>,
) -> (String, i32) {
    let bin = dpk_build_bin();
    let mut cmd = Command::new(&bin);
    cmd.args(["--dry-run", "lint"])
        .current_dir(project)
        .env_remove("BUILD_ROOT")
        .env_remove("KEEPSAKE_SCRIPTS_ROOT");
    if let Some(v) = build_root {
        cmd.env("BUILD_ROOT", v);
    }
    if let Some(v) = keepsake_scripts_root {
        cmd.env("KEEPSAKE_SCRIPTS_ROOT", v);
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

/// A usable build root that is distinguishable from the debug fallback: its
/// env.sh forces a language, so sourcing it changes the outcome for a project
/// that has no language indicators of its own.
fn build_root_forcing_rust() -> tempfile::TempDir {
    let dir = tempfile::tempdir().expect("tempdir");
    let mut f = std::fs::File::create(dir.path().join("env.sh")).expect("create env.sh");
    writeln!(f, "export BUILD_LANG=rust").expect("write env.sh");
    dir
}

/// Acceptance only: with BUILD_ROOT pointing at this repository the run
/// succeeds. Selection is proved by the decoy cases below, not by this one.
#[test]
fn resolve_build_root_prefers_build_root_only() {
    let root = build_root();
    let (stdout, code) = run_dry_lint(Some(root.to_str().unwrap()), None);
    assert_eq!(code, 0, "stdout={stdout}");
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "success");
}

/// The legacy alias must be *selected*, not merely tolerated. Pointing it at
/// this repository would prove nothing, because a debug build falls back to
/// CARGO_MANIFEST_DIR — the same directory — when neither variable is set, so
/// that version of this test passed whether or not the alias was ever read.
/// Instead the legacy value points at a build root whose env.sh forces a
/// language, and the project has no language indicators of its own: the run can
/// only succeed if that env.sh was sourced.
#[test]
fn resolve_build_root_selects_legacy_keepsake_scripts_root_over_debug_fallback() {
    let project = tempfile::tempdir().expect("tempdir");
    let legacy = build_root_forcing_rust();

    let (stdout, code) =
        run_dry_lint_in(project.path(), None, Some(legacy.path().to_str().unwrap()));
    assert_eq!(
        code, 0,
        "legacy KEEPSAKE_SCRIPTS_ROOT must be resolved and its env.sh sourced; stdout={stdout}"
    );
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "success");

    // Control: without either variable the debug fallback resolves to this
    // repository, whose env.sh sets no BUILD_LANG, so the identical project
    // fails. The divergence is what makes the case above discriminating.
    let (stdout, code) = run_dry_lint_in(project.path(), None, None);
    assert_ne!(
        code, 0,
        "debug fallback must not satisfy an indicator-less project; stdout={stdout}"
    );
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "failure");
    assert_eq!(
        v["error"]["code"], "language_unsupported",
        "expected the fallback to fail language detection; got {v}"
    );
}

#[test]
fn resolve_build_root_canonical_wins_over_decoy_legacy() {
    let root = build_root();
    let decoy = decoy_build_root();
    let (stdout, code) = run_dry_lint(
        Some(root.to_str().unwrap()),
        Some(decoy.path().to_str().unwrap()),
    );
    assert_eq!(
        code, 0,
        "canonical BUILD_ROOT must win over decoy legacy; stdout={stdout}"
    );
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "success");
}

#[test]
fn resolve_build_root_decoy_canonical_fails_even_with_valid_legacy() {
    let root = build_root();
    let decoy = decoy_build_root();
    let (stdout, code) = run_dry_lint(
        Some(decoy.path().to_str().unwrap()),
        Some(root.to_str().unwrap()),
    );
    assert_ne!(
        code, 0,
        "decoy BUILD_ROOT must win (and fail); stdout={stdout}"
    );
    let v: serde_json::Value = serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(v["status"], "failure");
    assert_eq!(
        v["error"]["code"], "language_unsupported",
        "expected language_unsupported from decoy BUILD_LANG; got {v}"
    );
}
