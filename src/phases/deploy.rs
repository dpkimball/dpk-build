use crate::cluster;
use crate::context::{Language, RunContext};
use crate::error::{DpkError, ErrorInfo};
use crate::phases::PhaseResult;
use crate::skip::{SkipFlags, SkipReason};
use std::sync::{atomic::AtomicBool, Arc};

pub fn run(ctx: &RunContext, skips: &SkipFlags, cancelled: &Arc<AtomicBool>) -> PhaseResult {
    if ctx.dry_run {
        return PhaseResult::skipped(SkipReason::DryRun);
    }
    if let Some(reason) = skips.should_skip_deploy() {
        return PhaseResult::skipped(reason);
    }

    // Check workspace manifest requirement
    let allowlist = match ctx
        .workspace_cfg
        .as_ref()
        .and_then(|w| w.context_allowlist())
    {
        Some(list) if !list.is_empty() => list.to_vec(),
        _ => {
            let e = DpkError::DeployRequiresWorkspaceManifest;
            return PhaseResult::failure(0, ErrorInfo::from(&e));
        }
    };

    // Detect cluster and extract the kubectl context string for allowlist check
    let cluster = match cluster::detect(&ctx.project_dir) {
        Ok(c) => c,
        Err(e) => return PhaseResult::failure(0, ErrorInfo::from(&e)),
    };
    let context = match &cluster {
        cluster::ClusterType::Kind { cluster_name } => cluster_name.clone(),
        cluster::ClusterType::RancherDesktop => "rancher-desktop".to_string(),
        cluster::ClusterType::DockerDesktop => "docker-desktop".to_string(),
        cluster::ClusterType::Minikube => "minikube".to_string(),
        cluster::ClusterType::Unknown { context } => context.clone(),
    };

    // Check allowlist
    if !allowlist.contains(&context) {
        let e = DpkError::ContextNotAllowed { context };
        return PhaseResult::failure(0, ErrorInfo::from(&e));
    }

    // Run deploy script
    let script = match ctx.language {
        Language::Python => ctx.build_root.join("python/deploy-k8s.sh"),
        Language::Rust => ctx.build_root.join("rust/deploy-k8s.sh"),
        Language::Node => ctx.build_root.join("python/deploy-k8s.sh"),
    };

    let timeout = ctx
        .project_cfg
        .as_ref()
        .and_then(|c| c.timeout_for("deploy"));
    let env = super::lint::base_env(ctx, skips);

    match crate::executor::run_legacy_script(
        &script,
        &[],
        &ctx.project_dir,
        &env,
        timeout,
        ctx.output_mode,
        cancelled,
    ) {
        Err(e) => PhaseResult::failure(0, ErrorInfo::from(&e)),
        Ok(outcome) => super::lint::outcome_to_result(outcome),
    }
}
