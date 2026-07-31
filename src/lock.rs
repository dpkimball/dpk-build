use crate::error::DpkError;
use std::path::Path;

pub struct ProjectLock {
    // Hold the Flock guard so the advisory exclusive lock is held until Drop.
    #[cfg(unix)]
    _guard: nix::fcntl::Flock<std::fs::File>,
    // Non-unix: keep the file open as a placeholder (no real locking).
    #[cfg(not(unix))]
    _file: std::fs::File,
}

pub fn acquire(project_dir: &Path) -> Result<ProjectLock, DpkError> {
    let lock_path = project_dir.join(".dpk-build.lock");
    let file = std::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(false)
        .open(&lock_path)
        .map_err(|e| DpkError::Other(format!("failed to open lock file: {}", e)))?;

    #[cfg(unix)]
    {
        use nix::fcntl::{Flock, FlockArg};
        let guard = Flock::lock(file, FlockArg::LockExclusiveNonblock)
            .map_err(|(_f, _e)| DpkError::AlreadyRunning)?;
        Ok(ProjectLock { _guard: guard })
    }

    #[cfg(not(unix))]
    Ok(ProjectLock { _file: file })
}
