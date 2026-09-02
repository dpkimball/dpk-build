use crate::error::DpkError;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
#[allow(dead_code)]
pub enum ClusterType {
    Kind { cluster_name: String },
    RancherDesktop,
    DockerDesktop,
    Minikube,
    Unknown { context: String },
}

#[allow(dead_code)]
pub fn detect(_cwd: &Path) -> Result<ClusterType, DpkError> {
    let context = kubectl_output(&["config", "current-context"])?;
    let cluster = kubectl_output(&[
        "config",
        "view",
        "--minify",
        "-o",
        "jsonpath={.clusters[0].name}",
    ])
    .unwrap_or_default();

    let combined = format!("{}{}", context, cluster).to_lowercase();

    if combined.contains("kind") {
        let cluster_name = cluster.trim().to_string();
        Ok(ClusterType::Kind { cluster_name })
    } else if combined.contains("rancher-desktop") {
        Ok(ClusterType::RancherDesktop)
    } else if combined.contains("docker-desktop") {
        Ok(ClusterType::DockerDesktop)
    } else if combined.contains("minikube") {
        Ok(ClusterType::Minikube)
    } else {
        Ok(ClusterType::Unknown {
            context: context.trim().to_string(),
        })
    }
}

#[allow(dead_code)]
pub fn load_image(cluster: &ClusterType, image: &str) -> Result<(), DpkError> {
    match cluster {
        ClusterType::Kind { cluster_name } => {
            let kind_cluster =
                std::env::var("KIND_CLUSTER").unwrap_or_else(|_| cluster_name.clone());
            let status = std::process::Command::new("kind")
                .args(["load", "docker-image", image, "--name", &kind_cluster])
                .status()
                .map_err(|_| DpkError::ToolNotFound {
                    name: "kind".into(),
                })?;
            if !status.success() {
                return Err(DpkError::Other(format!(
                    "kind load docker-image failed for {}",
                    image
                )));
            }
        }
        ClusterType::RancherDesktop | ClusterType::DockerDesktop => {
            // shared daemon — no load needed
        }
        ClusterType::Minikube => {
            let status = std::process::Command::new("minikube")
                .args(["image", "load", image])
                .status()
                .map_err(|_| DpkError::ToolNotFound {
                    name: "minikube".into(),
                })?;
            if !status.success() {
                return Err(DpkError::Other(format!(
                    "minikube image load failed for {}",
                    image
                )));
            }
        }
        ClusterType::Unknown { context } => {
            eprintln!(
                "WARNING: unknown cluster type for context '{}', skipping image load",
                context
            );
        }
    }
    Ok(())
}

fn kubectl_output(args: &[&str]) -> Result<String, DpkError> {
    let out = std::process::Command::new("kubectl")
        .args(args)
        .output()
        .map_err(|_| DpkError::ToolNotFound {
            name: "kubectl".into(),
        })?;
    if !out.status.success() {
        return Err(DpkError::Other(format!(
            "kubectl {} failed: {}",
            args.join(" "),
            String::from_utf8_lossy(&out.stderr).trim()
        )));
    }
    Ok(String::from_utf8_lossy(&out.stdout).to_string())
}
