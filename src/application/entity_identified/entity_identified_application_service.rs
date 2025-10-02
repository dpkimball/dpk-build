use anyhow::Result;
use std::sync::Arc;

use crate::dal::interfaces::IEntityIdentifiedRepository;
use crate::dal::schema::storage_models::EntityIdentified;
use crate::domain::entityidentified::to_proto_entity_identified;
use crate::proto_gen::memorygraph::{
    CreateEntityIdentifiedRequest, DeleteEntityIdentifiedRequest, ListEntityIdentifiedsRequest, 
    ListEntityIdentifiedsResponse, UpdateEntityIdentifiedRequest, EntityIdentified as ProtoEntityIdentified,
};

pub struct EntityIdentifiedApplicationService {
    repository: Arc<dyn IEntityIdentifiedRepository>,
}

impl EntityIdentifiedApplicationService {
    pub fn new(repository: Arc<dyn IEntityIdentifiedRepository>) -> Self {
        Self { repository }
    }

    pub async fn create_entity_identified(&self, req: CreateEntityIdentifiedRequest) -> Result<ProtoEntityIdentified> {
        let ei_id = uuid::Uuid::new_v4().to_string();
        let entity_identified = EntityIdentified {
            ei_id: ei_id.clone(),
            identified_entity: req.e_id,
            label: req.label,
            confidence: req.confidence,
            user_id: req.user_id,
        };
        
        self.repository.create(&entity_identified).await?;
        Ok(to_proto_entity_identified(&entity_identified))
    }

    pub async fn get_entity_identified(&self, ei_id: &str) -> Result<Option<ProtoEntityIdentified>> {
        let entity_identified = self.repository.get_by_id(ei_id).await?;
        Ok(entity_identified.map(|e| to_proto_entity_identified(&e)))
    }

    pub async fn update_entity_identified(&self, req: UpdateEntityIdentifiedRequest) -> Result<ProtoEntityIdentified> {
        let mut entity_identified = self
            .repository
            .get_by_id(&req.ei_id)
            .await?
            .ok_or_else(|| anyhow::anyhow!("EntityIdentified not found"))?;

        entity_identified.identified_entity = req.e_id;
        entity_identified.label = req.label;
        entity_identified.confidence = req.confidence;
        entity_identified.user_id = req.user_id;

        let updated_entity_identified = self.repository.update(&entity_identified).await?;
        Ok(to_proto_entity_identified(&updated_entity_identified))
    }

    pub async fn delete_entity_identified(&self, ei_id: &str) -> Result<bool> {
        self.repository.delete(ei_id).await
    }

    pub async fn list_entity_identifieds(&self, _req: ListEntityIdentifiedsRequest) -> Result<ListEntityIdentifiedsResponse> {
        // ListEntityIdentifiedsRequest is empty, so we'll list all entity identifieds
        let entity_identifieds = self.repository.list(None, None, None).await?;

        let proto_entity_identifieds: Vec<ProtoEntityIdentified> = entity_identifieds
            .into_iter()
            .map(|entity_identified| to_proto_entity_identified(&entity_identified))
            .collect();

        Ok(ListEntityIdentifiedsResponse {
            entity_identifieds: proto_entity_identifieds,
        })
    }

    pub async fn find_entity_identifieds_by_entity(&self, entity_id: &str) -> Result<Vec<ProtoEntityIdentified>> {
        let entity_identifieds = self.repository.find_by_entity(entity_id).await?;
        Ok(entity_identifieds.into_iter().map(|e| to_proto_entity_identified(&e)).collect())
    }

    pub async fn find_entity_identifieds_by_user(&self, user_id: &str) -> Result<Vec<ProtoEntityIdentified>> {
        let entity_identifieds = self.repository.find_by_user(user_id).await?;
        Ok(entity_identifieds.into_iter().map(|e| to_proto_entity_identified(&e)).collect())
    }

    pub async fn find_entity_identifieds_by_confidence_range(
        &self,
        min_confidence: f64,
        max_confidence: f64,
    ) -> Result<Vec<ProtoEntityIdentified>> {
        let entity_identifieds = self.repository.find_by_confidence_range(min_confidence, max_confidence).await?;
        Ok(entity_identifieds.into_iter().map(|e| to_proto_entity_identified(&e)).collect())
    }

    pub async fn get_recent_entity_identifieds(&self, user_id: &str, limit: u32) -> Result<Vec<ProtoEntityIdentified>> {
        let entity_identifieds = self.repository.get_recent_entity_identifieds(user_id, limit).await?;
        Ok(entity_identifieds.into_iter().map(|e| to_proto_entity_identified(&e)).collect())
    }

    pub async fn count_entity_identifieds_by_user(&self, user_id: &str) -> Result<u64> {
        self.repository.count_by_user(user_id).await
    }

    pub async fn count_entity_identifieds_by_entity(&self, entity_id: &str) -> Result<u64> {
        self.repository.count_by_entity(entity_id).await
    }

    pub async fn entity_identified_exists(&self, ei_id: &str) -> Result<bool> {
        self.repository.exists(ei_id).await
    }
}

