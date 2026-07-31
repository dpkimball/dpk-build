use crate::context::RunContext;
use crate::output::OperationResult;
use serde::Serialize;
use std::time::Instant;

#[derive(Debug, Serialize)]
struct ToolCheck {
    name: String,
    found: bool,
    path: Option<String>,
    required: bool,
}

#[derive(Debug, Serialize)]
struct DoctorResult {
    schema_version: u32,
    project: Option<String>,
    operation: String,
    status: String,
    duration_ms: u64,
    checks: Vec<ToolCheck>,
    #[serde(skip_serializing_if = "Option::is_none")]
    online_checks: Option<Vec<OnlineCheck>>,
}

#[derive(Debug, Serialize)]
struct OnlineCheck {
    name: String,
    url: String,
    reachable: bool,
    status_code: Option<u16>,
    error: Option<String>,
}

pub fn run(ctx: &RunContext, online: bool) -> OperationResult {
    let start = Instant::now();

    let required_tools = vec!["bash", "docker", "helm", "kubectl"];
    let optional_tools = vec!["cargo", "uv", "python3", "node", "npm"];

    let mut checks: Vec<ToolCheck> = Vec::new();
    let mut all_required_found = true;

    for tool in &required_tools {
        let found = which::which(tool).is_ok();
        let path = which::which(tool).ok().map(|p| p.display().to_string());
        if !found {
            all_required_found = false;
        }
        checks.push(ToolCheck {
            name: tool.to_string(),
            found,
            path,
            required: true,
        });
    }

    for tool in &optional_tools {
        let found = which::which(tool).is_ok();
        let path = which::which(tool).ok().map(|p| p.display().to_string());
        checks.push(ToolCheck {
            name: tool.to_string(),
            found,
            path,
            required: false,
        });
    }

    // Language-specific required tools
    use crate::context::Language;
    let lang_tools: Vec<(&str, bool)> = match ctx.language {
        Language::Python => vec![("uv", true), ("python3", false)],
        Language::Rust => vec![("cargo", true)],
        Language::Node => vec![("node", true), ("npm", false)],
    };
    for (tool, required) in &lang_tools {
        // Update existing entry if present, or add new
        if let Some(entry) = checks.iter_mut().find(|c| c.name == *tool) {
            if *required && !entry.found {
                all_required_found = false;
            }
            entry.required = *required;
        }
    }

    let online_checks = if online {
        Some(run_online_checks(ctx))
    } else {
        None
    };

    let status = if all_required_found {
        "success"
    } else {
        "failure"
    };

    let result = DoctorResult {
        schema_version: 1,
        project: ctx.project_name.clone(),
        operation: "doctor".into(),
        status: status.into(),
        duration_ms: start.elapsed().as_millis() as u64,
        checks,
        online_checks,
    };

    // Emit custom JSON shape
    println!(
        "{}",
        serde_json::to_string(&result).expect("JSON serialization failed")
    );
    std::process::exit(if all_required_found { 0 } else { 1 });
}

fn run_online_checks(_ctx: &RunContext) -> Vec<OnlineCheck> {
    let mut results = Vec::new();

    // Check build root reachability via env
    let endpoints: Vec<(&str, &str)> = vec![
        ("local-pypi", "http://localhost:31126"),
        ("local-registry", "http://localhost:30500"),
    ];

    for (name, url) in endpoints {
        match ureq::get(url)
            .timeout(std::time::Duration::from_secs(5))
            .call()
        {
            Ok(resp) => {
                results.push(OnlineCheck {
                    name: name.to_string(),
                    url: url.to_string(),
                    reachable: true,
                    status_code: Some(resp.status()),
                    error: None,
                });
            }
            Err(e) => {
                results.push(OnlineCheck {
                    name: name.to_string(),
                    url: url.to_string(),
                    reachable: false,
                    status_code: None,
                    error: Some(e.to_string()),
                });
            }
        }
    }

    results
}
