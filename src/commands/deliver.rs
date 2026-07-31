use crate::context::RunContext;
use crate::output::OperationResult;
use crate::phases::PhaseResult;
use crate::skip::{
    read_env_skips, resolve as resolve_skips, CliSkipFlags, SkipFlags, SkipReason, TomlSkipDefaults,
};
use std::sync::{atomic::AtomicBool, Arc};
use std::time::Instant;

type PhaseFn = fn(&RunContext, &SkipFlags, &Arc<AtomicBool>) -> PhaseResult;

pub fn run(
    ctx: &RunContext,
    skip_lint: bool,
    skip_tests: bool,
    skip_build: bool,
    skip_image: bool,
    skip_deploy: bool,
    cancelled: &Arc<AtomicBool>,
) -> OperationResult {
    let start = Instant::now();
    let mut result = OperationResult::new(ctx.project_name.clone(), "deliver");

    let cli_flags = CliSkipFlags {
        lint: skip_lint,
        tests: skip_tests,
        build: skip_build,
        image: skip_image,
        deploy: skip_deploy,
    };
    let env_flags = read_env_skips();
    let toml_defaults = ctx
        .project_cfg
        .as_ref()
        .and_then(|c| c.skip.as_ref())
        .map(|s| TomlSkipDefaults {
            lint: s.lint,
            tests: s.tests,
            build: s.build,
            image: s.image,
            deploy: s.deploy,
        });
    let skips = resolve_skips(&cli_flags, &env_flags, toml_defaults.as_ref(), true);

    let phases: &[(&str, PhaseFn)] = &[
        ("lint", crate::phases::lint::run),
        ("test", crate::phases::test::run),
        ("build", crate::phases::build::run),
        ("image", crate::phases::image::run),
        ("deploy", crate::phases::deploy::run),
        ("verify", crate::phases::verify::run),
    ];

    let mut failed = false;
    for (name, phase_fn) in phases {
        let phase_result = if failed {
            PhaseResult::skipped(SkipReason::PreviousPhaseFailed)
        } else {
            phase_fn(ctx, &skips, cancelled)
        };
        if phase_result.is_terminal() {
            failed = true;
        }
        result.phases.insert(name.to_string(), phase_result);
    }

    result.duration_ms = start.elapsed().as_millis() as u64;
    result.finalize();
    result
}
