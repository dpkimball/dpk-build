mod cli;
mod cluster;
mod commands;
mod config;
mod context;
mod env_resolver;
mod error;
mod executor;
mod lock;
mod maven;
mod output;
mod phases;
mod pypi;
mod skip;

use clap::Parser;
use cli::{Cli, Command, VersionAction};
use error::ErrorInfo;
use executor::OutputMode;
use output::OperationResult;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use std::time::Instant;

fn main() {
    let cancelled = Arc::new(AtomicBool::new(false));
    let cancelled_clone = Arc::clone(&cancelled);
    ctrlc::set_handler(move || {
        cancelled_clone.store(true, Ordering::SeqCst);
    })
    .expect("failed to install Ctrl-C handler");

    let cli = Cli::parse();
    let cwd = std::env::current_dir().expect("cannot determine cwd");

    let output_mode = if cli.quiet {
        OutputMode::Quiet
    } else if cli.verbose {
        OutputMode::Verbose
    } else {
        OutputMode::Default
    };

    let result = dispatch(&cli, &cwd, output_mode, &cancelled);
    let exit_code = match result.status.as_str() {
        "cancelled" => 130,
        "failure" => 1,
        _ => 0,
    };
    result.emit();
    std::process::exit(exit_code);
}

fn dispatch(
    cli: &Cli,
    cwd: &std::path::Path,
    output_mode: OutputMode,
    cancelled: &Arc<AtomicBool>,
) -> OperationResult {
    let project_arg = match &cli.command {
        Command::Lint { project, .. } => project.as_deref(),
        Command::Test { project, .. } => project.as_deref(),
        Command::Build { project } => project.as_deref(),
        Command::Image { project, .. } => project.as_deref(),
        Command::Deploy { project, .. } => project.as_deref(),
        Command::Verify { project } => project.as_deref(),
        Command::Deliver { project, .. } => project.as_deref(),
        Command::Version { action } => match action {
            VersionAction::Show { project } | VersionAction::Bump { project } => project.as_deref(),
        },
        Command::Doctor { project, .. } => project.as_deref(),
    };

    let ctx = match context::resolve(project_arg, cwd, output_mode, cli.dry_run, cli.verbose) {
        Ok(c) => c,
        Err(e) => {
            return OperationResult::with_failure(None, op_name(&cli.command), ErrorInfo::from(&e));
        }
    };

    // Acquire project lock for all commands except version show/bump, doctor, and dry-run.
    // Dry-run is exempt because it makes no state changes and concurrent dry-runs are safe.
    let lock = match &cli.command {
        Command::Version { .. } | Command::Doctor { .. } => None,
        _ if cli.dry_run => None,
        _ => match lock::acquire(&ctx.project_dir) {
            Ok(l) => Some(l),
            Err(e) => {
                return OperationResult::with_failure(
                    ctx.project_name.clone(),
                    op_name(&cli.command),
                    ErrorInfo::from(&e),
                );
            }
        },
    };
    let _lock = lock; // keep alive until end of dispatch

    match &cli.command {
        Command::Lint { skip_lint, .. } => single_phase(
            "lint", &ctx, *skip_lint, false, false, false, false, cancelled,
        ),
        Command::Test { skip_tests, .. } => single_phase(
            "test",
            &ctx,
            false,
            *skip_tests,
            false,
            false,
            false,
            cancelled,
        ),
        Command::Build { .. } => {
            single_phase("build", &ctx, false, false, false, false, false, cancelled)
        }
        Command::Image { skip_image, .. } => single_phase(
            "image",
            &ctx,
            false,
            false,
            false,
            *skip_image,
            false,
            cancelled,
        ),
        Command::Deploy { skip_deploy, .. } => single_phase(
            "deploy",
            &ctx,
            false,
            false,
            false,
            false,
            *skip_deploy,
            cancelled,
        ),
        Command::Verify { .. } => {
            single_phase("verify", &ctx, false, false, false, false, false, cancelled)
        }
        Command::Deliver {
            skip_lint,
            skip_tests,
            skip_build,
            skip_image,
            skip_deploy,
            ..
        } => commands::deliver::run(
            &ctx,
            *skip_lint,
            *skip_tests,
            *skip_build,
            *skip_image,
            *skip_deploy,
            cancelled,
        ),
        Command::Version { action } => commands::version::run(&ctx, action),
        Command::Doctor { online, .. } => commands::doctor::run(&ctx, *online),
    }
}

#[allow(clippy::too_many_arguments)]
fn single_phase(
    phase: &str,
    ctx: &crate::context::RunContext,
    skip_lint: bool,
    skip_tests: bool,
    skip_build: bool,
    skip_image: bool,
    skip_deploy: bool,
    cancelled: &Arc<AtomicBool>,
) -> OperationResult {
    use skip::{read_env_skips, resolve as resolve_skips, CliSkipFlags};
    let start = Instant::now();
    let mut result = OperationResult::new(ctx.project_name.clone(), phase);

    let cli_flags = CliSkipFlags {
        lint: skip_lint,
        tests: skip_tests,
        build: skip_build,
        image: skip_image,
        deploy: skip_deploy,
    };
    let skips = resolve_skips(&cli_flags, &read_env_skips(), None, false);

    let phase_result = match phase {
        "lint" => phases::lint::run(ctx, &skips, cancelled),
        "test" => phases::test::run(ctx, &skips, cancelled),
        "build" => phases::build::run(ctx, &skips, cancelled),
        "image" => phases::image::run(ctx, &skips, cancelled),
        "deploy" => phases::deploy::run(ctx, &skips, cancelled),
        "verify" => phases::verify::run(ctx, &skips, cancelled),
        _ => unreachable!(),
    };

    result.phases.insert(phase.to_string(), phase_result);
    result.duration_ms = start.elapsed().as_millis() as u64;
    result.finalize();
    result
}

fn op_name(cmd: &Command) -> &'static str {
    match cmd {
        Command::Lint { .. } => "lint",
        Command::Test { .. } => "test",
        Command::Build { .. } => "build",
        Command::Image { .. } => "image",
        Command::Deploy { .. } => "deploy",
        Command::Verify { .. } => "verify",
        Command::Deliver { .. } => "deliver",
        Command::Version { action } => match action {
            VersionAction::Show { .. } => "version_show",
            VersionAction::Bump { .. } => "version_bump",
        },
        Command::Doctor { .. } => "doctor",
    }
}
