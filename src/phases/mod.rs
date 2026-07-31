pub mod build;
pub mod deploy;
pub mod image;
pub mod lint;
pub mod test;
pub mod verify;

use crate::error::ErrorInfo;
use crate::skip::SkipReason;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PhaseStatus {
    Success,
    Failure,
    Skipped,
    TimedOut,
    Cancelled,
}

#[derive(Debug, Clone, Serialize)]
pub struct PhaseResult {
    pub status: PhaseStatus,
    pub duration_ms: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<SkipReason>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorInfo>,
}

impl PhaseResult {
    pub fn success(duration_ms: u64) -> Self {
        Self {
            status: PhaseStatus::Success,
            duration_ms,
            reason: None,
            error: None,
        }
    }
    pub fn skipped(reason: SkipReason) -> Self {
        Self {
            status: PhaseStatus::Skipped,
            duration_ms: 0,
            reason: Some(reason),
            error: None,
        }
    }
    pub fn failure(duration_ms: u64, error: ErrorInfo) -> Self {
        Self {
            status: PhaseStatus::Failure,
            duration_ms,
            reason: None,
            error: Some(error),
        }
    }
    pub fn timed_out(duration_ms: u64, limit_secs: u64) -> Self {
        let error = ErrorInfo {
            code: "process_timeout".into(),
            message: format!("phase exceeded {}s limit", limit_secs),
            details: serde_json::json!({ "limit_secs": limit_secs }),
        };
        Self {
            status: PhaseStatus::TimedOut,
            duration_ms,
            reason: None,
            error: Some(error),
        }
    }
    pub fn cancelled(duration_ms: u64) -> Self {
        Self {
            status: PhaseStatus::Cancelled,
            duration_ms,
            reason: Some(SkipReason::Cancelled),
            error: None,
        }
    }

    pub fn is_terminal(&self) -> bool {
        matches!(
            self.status,
            PhaseStatus::Failure | PhaseStatus::TimedOut | PhaseStatus::Cancelled
        )
    }
}
