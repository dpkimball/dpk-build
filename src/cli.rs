use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(name = "dpk-build", about = "DPK build orchestrator")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,

    #[arg(long, global = true, help = "Suppress live output")]
    pub quiet: bool,

    #[arg(
        long,
        global = true,
        conflicts_with = "quiet",
        help = "Replay captured stdout after each phase"
    )]
    pub verbose: bool,

    #[arg(long, global = true, help = "Resolve configuration but do not execute")]
    pub dry_run: bool,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    Lint {
        project: Option<String>,
        #[arg(long)]
        skip_lint: bool,
    },
    Test {
        project: Option<String>,
        #[arg(long)]
        skip_tests: bool,
    },
    Build {
        project: Option<String>,
    },
    Image {
        project: Option<String>,
        #[arg(long)]
        skip_image: bool,
    },
    Deploy {
        project: Option<String>,
        #[arg(long)]
        skip_deploy: bool,
        #[arg(long, default_value = "local")]
        target: String,
    },
    Verify {
        project: Option<String>,
    },
    Deliver {
        project: Option<String>,
        #[arg(long)]
        skip_lint: bool,
        #[arg(long)]
        skip_tests: bool,
        #[arg(long)]
        skip_build: bool,
        #[arg(long)]
        skip_image: bool,
        #[arg(long)]
        skip_deploy: bool,
    },
    Version {
        #[command(subcommand)]
        action: VersionAction,
    },
    Doctor {
        project: Option<String>,
        #[arg(long)]
        online: bool,
    },
}

#[derive(Subcommand, Debug)]
pub enum VersionAction {
    Show { project: Option<String> },
    Bump { project: Option<String> },
}
