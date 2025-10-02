use anyhow::Result;
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use mongodb::bson::doc;
use mongodb::Collection;

use crate::dal::interfaces::IEntityIdentifiedRepository;
use crate::dal::schema::mongo::repository::MongoRepository;
use crate::dal::schema::storage_models::EntityIdentified;

pub struct MongoEntityIdentifiedRepository {
    repo: MongoRepository<EntityIdentified>,
}

impl MongoEntityIdentifiedRepository {
    pub fn new(repo: MongoRepository<EntityIdentified>) -> Self {
        Self { repo }
    }

    fn collection(&self) -> &Collection<mongodb::bson::Document> {
        self.repo.collection()
    }
}

#[async_trait]
impl IEntityIdentifiedRepository for MongoEntityIdentifiedRepository {
    async fn create(&self, entity_identified: &EntityIdentified) -> Result<EntityIdentified> {
        self.repo.create(entity_identified).await?;
        Ok(entity_identified.clone())
    }

    async fn get_by_id(&self, id: &str) -> Result<Option<EntityIdentified>> {
        let filter = doc! { "ei_id": id };
        self.repo.get(filter).await
    }

    async fn update(&self, entity_identified: &EntityIdentified) -> Result<EntityIdentified> {
        match self.repo.update(entity_identified).await? {
            Some(updated_entity_identified) => Ok(updated_entity_identified),
            None => Err(anyhow::anyhow!("EntityIdentified not found for update")),
        }
    }

    async fn delete(&self, id: &str) -> Result<bool> {
        let filter = doc! { "ei_id": id };
        self.repo.delete(filter).await
    }

    async fn list(
        &self,
        user_id: Option<&str>,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<EntityIdentified>> {
        let mut filter = doc! {};
        
        if let Some(user_id) = user_id {
            filter.insert("user_id", user_id);
        }

        let entity_identifieds = self.repo.list(Some(filter)).await?;

        // Apply pagination
        let offset = offset.unwrap_or(0) as usize;
        let limit = limit.unwrap_or(100) as usize;
        
        let start = offset;
        let end = std::cmp::min(start + limit, entity_identifieds.len());
        
        Ok(entity_identifieds.into_iter().skip(start).take(end - start).collect())
    }

    async fn find_by_entity(&self, entity_id: &str) -> Result<Vec<EntityIdentified>> {
        let filter = doc! { "identified_entity": entity_id };
        self.repo.list(Some(filter)).await
    }

    async fn find_by_user(&self, user_id: &str) -> Result<Vec<EntityIdentified>> {
        let filter = doc! { "user_id": user_id };
        self.repo.list(Some(filter)).await
    }

    async fn find_by_confidence_range(
        &self,
        min_confidence: f64,
        max_confidence: f64,
    ) -> Result<Vec<EntityIdentified>> {
        let filter = doc! {
            "confidence": {
                "$gte": min_confidence,
                "$lte": max_confidence
            }
        };
        
        self.repo.list(Some(filter)).await
    }

    async fn find_by_date_range(
        &self,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> Result<Vec<EntityIdentified>> {
        let filter = doc! {
            "created_at": {
                "$gte": start_date.to_rfc3339(),
                "$lte": end_date.to_rfc3339()
            }
        };
        
        self.repo.list(Some(filter)).await
    }

    async fn count_by_user(&self, user_id: &str) -> Result<u64> {
        let filter = doc! { "user_id": user_id };
        let entity_identifieds = self.repo.list(Some(filter)).await?;
        Ok(entity_identifieds.len() as u64)
    }

    async fn count_by_entity(&self, entity_id: &str) -> Result<u64> {
        let filter = doc! { "identified_entity": entity_id };
        let entity_identifieds = self.repo.list(Some(filter)).await?;
        Ok(entity_identifieds.len() as u64)
    }

    async fn exists(&self, id: &str) -> Result<bool> {
        let filter = doc! { "ei_id": id };
        match self.repo.get(filter).await? {
            Some(_) => Ok(true),
            None => Ok(false),
        }
    }

    async fn get_recent_entity_identifieds(
        &self,
        user_id: &str,
        limit: u32,
    ) -> Result<Vec<EntityIdentified>> {
        let filter = doc! { "user_id": user_id };
        let mut entity_identifieds = self.repo.list(Some(filter)).await?;
        
        // Sort by ei_id descending and limit (simple sort for now)
        entity_identifieds.sort_by(|a, b| b.ei_id.cmp(&a.ei_id));
        entity_identifieds.truncate(limit as usize);
        
        Ok(entity_identifieds)
    }
}

