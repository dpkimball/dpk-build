use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn build_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn dpk_build_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/debug/dpk-build")
}

const UGLY: &str = "pub fn add(a:i32,b:i32)->i32{a+b}\n";
const PRETTY: &str = "pub fn add(a: i32, b: i32) -> i32 {\n    a + b\n}\n";

fn write_crate(dir: &Path, lib_src: &str) {
    fs::write(
        dir.join("Cargo.toml"),
        "[package]\nname = \"fmt-probe\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .unwrap();
    fs::create_dir_all(dir.join("src")).unwrap();
    fs::write(dir.join("src/lib.rs"), lib_src).unwrap();
}

fn lint(project_dir: &Path) -> (serde_json::Value, String, i32) {
    let target = project_dir.join("target");
    let output = Command::new(dpk_build_bin())
        .args(["lint"])
        .current_dir(project_dir)
        .env("BUILD_ROOT", build_root())
        .env("CARGO_TARGET_DIR", &target)
        .env("CARGO_TERM_COLOR", "never")
        .output()
        .expect("run dpk-build");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let code = output.status.code().unwrap_or(-1);
    let json_line = stdout
        .lines()
        .rev()
        .find(|l| l.trim().starts_with('{'))
        .unwrap_or(stdout.trim());
    let v: serde_json::Value = serde_json::from_str(json_line).unwrap_or_else(|_| {
        panic!("stdout must be JSON, got stdout={stdout:?} stderr={stderr:?} code={code}")
    });
    (v, stderr, code)
}

fn cargo(dir: &Path, args: &[&str]) -> (i32, String) {
    let output = Command::new("cargo")
        .args(args)
        .current_dir(dir)
        .env("CARGO_TARGET_DIR", dir.join("target"))
        .env("CARGO_TERM_COLOR", "never")
        .output()
        .expect("run cargo");
    let combined = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    (output.status.code().unwrap_or(-1), combined)
}

/// rust deliver lint must fail rustfmt --check, not only clippy.
#[test]
fn rust_lint_fails_when_sources_are_unformatted() {
    let tmp = tempfile::tempdir().unwrap();
    write_crate(tmp.path(), UGLY);

    let (clippy, clippy_out) = cargo(
        tmp.path(),
        &[
            "clippy",
            "--workspace",
            "--all-targets",
            "--all-features",
            "--",
            "-D",
            "warnings",
        ],
    );
    assert_eq!(
        clippy, 0,
        "fixture must be clippy-clean so lint failure is fmt: {clippy_out}"
    );

    let (fmt, fmt_out) = cargo(tmp.path(), &["fmt", "--all", "--", "--check"]);
    assert_ne!(fmt, 0, "fixture must be unformatted: {fmt_out}");
    assert!(
        fmt_out.contains("Diff") || fmt_out.contains("rustfmt"),
        "cargo fmt --check should report a rustfmt diff, got: {fmt_out}"
    );

    let (v, stderr, code) = lint(tmp.path());
    assert_ne!(code, 0, "stderr={stderr} json={v}");
    assert_eq!(v["status"], "failure", "{v}");
    assert_eq!(v["phases"]["lint"]["status"], "failure", "{v}");
    assert_eq!(
        v["phases"]["lint"]["error"]["code"], "process_exit_nonzero",
        "fmt --check must fail the lint phase, got {v}"
    );
}

/// Formatted, clippy-clean crate must pass the new two-step rust lint.
#[test]
fn rust_lint_passes_when_fmt_and_clippy_clean() {
    let tmp = tempfile::tempdir().unwrap();
    write_crate(tmp.path(), PRETTY);
    let (v, stderr, code) = lint(tmp.path());
    assert_eq!(code, 0, "stderr={stderr} json={v}");
    assert_eq!(v["status"], "success", "{v}");
    assert_eq!(v["phases"]["lint"]["status"], "success", "{v}");
}
