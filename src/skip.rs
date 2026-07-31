use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SkipReason {
    Cli,
    Environment,
    ProjectDefault,
    NotConfigured,
    PreviousPhaseFailed,
    DryRun,
    Cancelled,
}

#[derive(Debug, Default, Clone)]
pub struct SkipFlags {
    pub lint: Option<(bool, SkipReason)>,
    pub tests: Option<(bool, SkipReason)>,
    pub build: Option<(bool, SkipReason)>,
    pub image: Option<(bool, SkipReason)>,
    pub deploy: Option<(bool, SkipReason)>,
}

impl SkipFlags {
    pub fn should_skip_lint(&self) -> Option<SkipReason> {
        skip_reason(&self.lint)
    }
    pub fn should_skip_tests(&self) -> Option<SkipReason> {
        skip_reason(&self.tests)
    }
    pub fn should_skip_build(&self) -> Option<SkipReason> {
        skip_reason(&self.build)
    }
    pub fn should_skip_image(&self) -> Option<SkipReason> {
        skip_reason(&self.image)
    }
    pub fn should_skip_deploy(&self) -> Option<SkipReason> {
        skip_reason(&self.deploy)
    }
}

fn skip_reason(flag: &Option<(bool, SkipReason)>) -> Option<SkipReason> {
    flag.as_ref()
        .and_then(|(skip, reason)| if *skip { Some(reason.clone()) } else { None })
}

#[derive(Debug, Default)]
pub struct CliSkipFlags {
    pub lint: bool,
    pub tests: bool,
    pub build: bool,
    pub image: bool,
    pub deploy: bool,
}
#[derive(Debug, Default)]
pub struct EnvSkipFlags {
    pub lint: bool,
    pub tests: bool,
    pub build: bool,
    pub image: bool,
    pub deploy: bool,
}
#[derive(Debug, Default)]
pub struct TomlSkipDefaults {
    pub lint: bool,
    pub tests: bool,
    pub build: bool,
    pub image: bool,
    pub deploy: bool,
}

pub fn read_env_skips() -> EnvSkipFlags {
    EnvSkipFlags {
        lint: env_bool("SKIP_LINT"),
        tests: env_bool("SKIP_TESTS"),
        build: env_bool("SKIP_BUILD"),
        image: env_bool("SKIP_DOCKER_IMAGE") || env_bool("SKIP_IMAGE"),
        deploy: env_bool("SKIP_K8S_DEPLOY"),
    }
}

fn env_bool(key: &str) -> bool {
    std::env::var(key)
        .map(|v| v == "true" || v == "1")
        .unwrap_or(false)
}

pub fn resolve(
    cli: &CliSkipFlags,
    env: &EnvSkipFlags,
    toml: Option<&TomlSkipDefaults>,
    is_deliver: bool,
) -> SkipFlags {
    SkipFlags {
        lint: resolve_one(cli.lint, env.lint, toml.map(|t| t.lint), is_deliver),
        tests: resolve_one(cli.tests, env.tests, toml.map(|t| t.tests), is_deliver),
        build: resolve_one(cli.build, env.build, toml.map(|t| t.build), is_deliver),
        image: resolve_one(cli.image, env.image, toml.map(|t| t.image), is_deliver),
        deploy: resolve_one(cli.deploy, env.deploy, toml.map(|t| t.deploy), is_deliver),
    }
}

fn resolve_one(
    cli: bool,
    env: bool,
    toml: Option<bool>,
    is_deliver: bool,
) -> Option<(bool, SkipReason)> {
    if cli {
        return Some((true, SkipReason::Cli));
    }
    if env {
        return Some((true, SkipReason::Environment));
    }
    if is_deliver {
        if let Some(true) = toml {
            return Some((true, SkipReason::ProjectDefault));
        }
    }
    None
}

pub fn env_overrides_for_child(flags: &SkipFlags) -> Vec<(std::ffi::OsString, std::ffi::OsString)> {
    let mut out = Vec::new();
    let set = |k: &str, v: bool| -> (std::ffi::OsString, std::ffi::OsString) {
        (k.into(), if v { "true" } else { "false" }.into())
    };
    out.push(set(
        "SKIP_LINT",
        flags.lint.as_ref().is_some_and(|(v, _)| *v),
    ));
    out.push(set(
        "SKIP_TESTS",
        flags.tests.as_ref().is_some_and(|(v, _)| *v),
    ));
    out.push(set(
        "SKIP_BUILD",
        flags.build.as_ref().is_some_and(|(v, _)| *v),
    ));
    out.push(set(
        "SKIP_DOCKER_IMAGE",
        flags.image.as_ref().is_some_and(|(v, _)| *v),
    ));
    out.push(set(
        "SKIP_K8S_DEPLOY",
        flags.deploy.as_ref().is_some_and(|(v, _)| *v),
    ));
    out
}
