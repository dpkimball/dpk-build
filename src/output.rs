use crate::error::ErrorInfo;
use crate::phases::PhaseResult;
use indexmap::IndexMap;
use serde::Serialize;

const SCHEMA_VERSION: u32 = 1;

#[derive(Serialize)]
pub struct OperationResult {
    pub schema_version: u32,
    pub project: Option<String>,
    pub operation: String,
    pub status: String,
    pub duration_ms: u64,
    #[serde(skip_serializing_if = "IndexMap::is_empty")]
    pub phases: IndexMap<String, PhaseResult>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorInfo>,
}

impl OperationResult {
    pub fn new(project: Option<String>, operation: &str) -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            project,
            operation: operation.into(),
            status: "success".into(),
            duration_ms: 0,
            phases: IndexMap::new(),
            error: None,
        }
    }

    pub fn with_failure(project: Option<String>, operation: &str, error: ErrorInfo) -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            project,
            operation: operation.into(),
            status: "failure".into(),
            duration_ms: 0,
            phases: IndexMap::new(),
            error: Some(error),
        }
    }

    #[allow(dead_code)]
    pub fn with_cancelled(project: Option<String>, operation: &str) -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            project,
            operation: operation.into(),
            status: "cancelled".into(),
            duration_ms: 0,
            phases: IndexMap::new(),
            error: None,
        }
    }

    pub fn finalize(&mut self) {
        let has_cancelled = self
            .phases
            .values()
            .any(|p| matches!(p.status, crate::phases::PhaseStatus::Cancelled));
        let has_failure = self.phases.values().any(|p| p.is_terminal());
        self.status = if has_cancelled {
            "cancelled".into()
        } else if has_failure || self.error.is_some() {
            "failure".into()
        } else {
            "success".into()
        };
    }

    pub fn emit(&self) {
        // output.rs is the ONLY place that calls println!
        println!(
            "{}",
            serde_json::to_string(self).expect("JSON serialization failed")
        );
    }
}
