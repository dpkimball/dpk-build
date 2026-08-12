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
    extra_env: &[(&str, &str)],
) -> (serde_json::Value, String, i32) {
    let bin = dpk_build_bin();
    let mut cmd = Command::new(&bin);
    cmd.args(args)
        .current_dir(project_dir)
        .env("BUILD_ROOT", build_root());
    for (k, v) in extra_env {
        cmd.env(k, v);
    }
    let output = cmd.output().expect("failed to run dpk-build binary");
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

#[test]
fn node_lint_without_skip_is_language_unsupported() {
    let dir = fixture_dir("fake_project_node_noskip");
    let (v, stderr, code) = run_dpk_env(&dir, &["deliver", "--skip-image", "--skip-deploy"], &[]);
    assert_ne!(code, 0, "stderr={stderr} json={v}");
    assert_eq!(v["phases"]["lint"]["status"], "failure");
    assert_eq!(
        v["phases"]["lint"]["error"]["code"],
        "language_unsupported_for_operation"
    );
}

#[test]
fn node_deliver_skip_lint_tests_runs_python_image_script() {
    let dir = fixture_dir("fake_project_node");
    let (v, stderr, code) = run_dpk_env(
        &dir,
        &["deliver", "--skip-deploy"],
        &[("DPK_IMAGE_SCRIPT_PROBE", "1")],
    );
    assert_eq!(code, 0, "stderr={stderr} json={v}");
    assert_eq!(v["phases"]["lint"]["status"], "skipped");
    assert_eq!(v["phases"]["test"]["status"], "skipped");
    assert_eq!(v["phases"]["build"]["status"], "skipped");
    assert_eq!(v["phases"]["image"]["status"], "success");
    let err = v["phases"]["image"]["error"]["code"].as_str().unwrap_or("");
    assert_ne!(err, "language_unsupported_for_operation", "{v}");
}

#[test]
fn python_java_rust_node_image_probe_succeeds() {
    let cases = [
        ("consumers/python_plain", "python"),
        ("consumers/python_script_dir_clobber", "python"),
        ("consumers/rust_plain", "rust"),
        ("consumers/node_frontend", "node"),
        ("consumers/java_runtime", "java"),
    ];
    for (name, lang) in cases {
        let dir = fixture_dir(name);
        let (v, stderr, code) = run_dpk_env(
            &dir,
            &[
                "deliver",
                "--skip-lint",
                "--skip-tests",
                "--skip-build",
                "--skip-deploy",
            ],
            &[("DPK_IMAGE_SCRIPT_PROBE", "1")],
        );
        assert_eq!(code, 0, "{lang} {name} stderr={stderr} json={v}");
        assert_eq!(
            v["phases"]["image"]["status"], "success",
            "{lang} {name} image must run the docker script (probe), got {v}"
        );
    }
}
