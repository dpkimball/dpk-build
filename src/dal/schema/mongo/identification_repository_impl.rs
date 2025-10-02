use anyhow::Result;
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use mongodb::bson::doc;
use mongodb::Collection;

use crate::dal::interfaces::IIdentificationRepository;
use crate::dal::schema::mongo::repository::MongoRepository;
use crate::dal::schema::storage_models::Identification;

pub struct MongoIdentificationRepository {
    repo: MongoRepository<Identification>,
}

impl MongoIdentificationRepository {
    pub fn new(repo: MongoRepository<Identification>) -> Self {
        Self { repo }
    }

    fn collection(&self) -> &Collection<mongodb::bson::Document> {
        self.repo.collection()
    }
}

#[async_trait]
impl IIdentificationRepository for MongoIdentificationRepository {
    async fn create(&self, identification: &Identification) -> Result<Identification> {
        self.repo.create(identification).await?;
        Ok(identification.clone())
    }

    async fn get_by_id(&self, id: &str) -> Result<Option<Identification>> {
        let filter = doc! { "i_id": id };
        self.repo.get(filter).await
    }

    async fn update(&self, identification: &Identification) -> Result<Identification> {
        match self.repo.update(identification).await? {
            Some(updated_identification) => Ok(updated_identification),
            None => Err(anyhow::anyhow!("Identification not found for update")),
        }
    }

    async fn delete(&self, id: &str) -> Result<bool> {
        let filter = doc! { "i_id": id };
        self.repo.delete(filter).await
    }

    async fn list(
        &self,
        user_id: Option<&str>,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<Identification>> {
        let mut filter = doc! {};
        
        if let Some(user_id) = user_id {
            filter.insert("user_id", user_id);
        }

        let identifications = self.repo.list(Some(filter)).await?;

        // Apply pagination
        let offset = offset.unwrap_or(0) as usize;
        let limit = limit.unwrap_or(100) as usize;
        
        let start = offset;
        let end = std::cmp::min(start + limit, identifications.len());
        
        Ok(identifications.into_iter().skip(start).take(end - start).collect())
    }

    async fn find_by_entity(&self, entity_id: &str) -> Result<Vec<Identification>> {
        let filter = doc! { "identified_entity": entity_id };
        self.repo.list(Some(filter)).await
    }

    async fn find_by_user(&self, user_id: &str) -> Result<Vec<Identification>> {
        let filter = doc! { "user_id": user_id };
        self.repo.list(Some(filter)).await
    }

    async fn find_by_confidence_range(
        &self,
        min_confidence: f64,
        max_confidence: f64,
    ) -> Result<Vec<Identification>> {
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
    ) -> Result<Vec<Identification>> {
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
        let identifications = self.repo.list(Some(filter)).await?;
        Ok(identifications.len() as u64)
    }

    async fn count_by_entity(&self, entity_id: &str) -> Result<u64> {
        let filter = doc! { "identified_entity": entity_id };
        let identifications = self.repo.list(Some(filter)).await?;
        Ok(identifications.len() as u64)
    }

    async fn exists(&self, id: &str) -> Result<bool> {
        let filter = doc! { "i_id": id };
        match self.repo.get(filter).await? {
            Some(_) => Ok(true),
            None => Ok(false),
        }
    }

    async fn get_recent_identifications(&self, user_id: &str, limit: u32) -> Result<Vec<Identification>> {
        let filter = doc! { "user_id": user_id };
        let mut identifications = self.repo.list(Some(filter)).await?;
        
        // Sort by created_at descending and limit
        identifications.sort_by(|a, b| b.i_id.cmp(&a.i_id)); // Simple sort by ID for now
        identifications.truncate(limit as usize);
        
        Ok(identifications)
    }
}

