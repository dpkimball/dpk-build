use anyhow::Result;
use async_trait::async_trait;
use chrono::{DateTime, Utc};

use crate::dal::schema::storage_models::EntityIdentified;

#[async_trait]
pub trait IEntityIdentifiedRepository: Send + Sync {
    async fn create(&self, entity_identified: &EntityIdentified) -> Result<EntityIdentified>;
    async fn get_by_id(&self, id: &str) -> Result<Option<EntityIdentified>>;
    async fn update(&self, entity_identified: &EntityIdentified) -> Result<EntityIdentified>;
    async fn delete(&self, id: &str) -> Result<bool>;
    async fn list(
        &self,
        user_id: Option<&str>,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<EntityIdentified>>;
    async fn find_by_entity(&self, entity_id: &str) -> Result<Vec<EntityIdentified>>;
    async fn find_by_user(&self, user_id: &str) -> Result<Vec<EntityIdentified>>;
    async fn find_by_confidence_range(
        &self,
        min_confidence: f64,
        max_confidence: f64,
    ) -> Result<Vec<EntityIdentified>>;
    async fn find_by_date_range(
        &self,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> Result<Vec<EntityIdentified>>;
    async fn count_by_user(&self, user_id: &str) -> Result<u64>;
    async fn count_by_entity(&self, entity_id: &str) -> Result<u64>;
    async fn exists(&self, id: &str) -> Result<bool>;
    async fn get_recent_entity_identifieds(&self, user_id: &str, limit: u32) -> Result<Vec<EntityIdentified>>;
}

