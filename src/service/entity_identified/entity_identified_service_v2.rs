use anyhow::Result;
use async_trait::async_trait;
use std::sync::Arc;
use tonic::{Request, Response, Status};

use crate::application::entity_identified::entity_identified_application_service::EntityIdentifiedApplicationService;
use crate::dal::interfaces::IEntityIdentifiedRepository;
use crate::dal::schema::storage_models::EntityIdentified;
use crate::domain::entityidentified::to_proto_entity_identified;
use crate::proto_gen::memorygraph::entity_identified_service_server::EntityIdentifiedService as GrpcEntityIdentifiedService;
use crate::proto_gen::memorygraph::{
    CreateEntityIdentifiedRequest, DeleteEntityIdentifiedRequest, DeleteResponse, GetEntityIdentifiedRequest,
    ListEntityIdentifiedsRequest, ListEntityIdentifiedsResponse, UpdateEntityIdentifiedRequest, 
    EntityIdentified as ProtoEntityIdentified,
};

#[derive(Clone)]
pub struct EntityIdentifiedServiceV2 {
    app_service: EntityIdentifiedApplicationService,
}

impl EntityIdentifiedServiceV2 {
    pub fn new(app_service: EntityIdentifiedApplicationService) -> Self {
        Self { app_service }
    }
}

#[tonic::async_trait]
impl GrpcEntityIdentifiedService for EntityIdentifiedServiceV2 {
    async fn create_entity_identified(
        &self,
        request: Request<CreateEntityIdentifiedRequest>,
    ) -> Result<Response<ProtoEntityIdentified>, Status> {
        let req = request.into_inner();
        match self.app_service.create_entity_identified(req).await {
            Ok(entity_identified) => Ok(Response::new(entity_identified)),
            Err(e) => Err(Status::internal(format!("Failed to create entity identified: {}", e))),
        }
    }

    async fn get_entity_identified(
        &self,
        request: Request<GetEntityIdentifiedRequest>,
    ) -> Result<Response<ProtoEntityIdentified>, Status> {
        let req = request.into_inner();
        match self.app_service.get_entity_identified(&req.ei_id).await {
            Ok(Some(entity_identified)) => Ok(Response::new(entity_identified)),
            Ok(None) => Err(Status::not_found(format!("EntityIdentified with ID {} not found", req.ei_id))),
            Err(e) => Err(Status::internal(format!("Failed to get entity identified: {}", e))),
        }
    }

    async fn update_entity_identified(
        &self,
        request: Request<UpdateEntityIdentifiedRequest>,
    ) -> Result<Response<ProtoEntityIdentified>, Status> {
        let req = request.into_inner();
        match self.app_service.update_entity_identified(req).await {
            Ok(entity_identified) => Ok(Response::new(entity_identified)),
            Err(e) => Err(Status::internal(format!("Failed to update entity identified: {}", e))),
        }
    }

    async fn delete_entity_identified(
        &self,
        request: Request<DeleteEntityIdentifiedRequest>,
    ) -> Result<Response<DeleteResponse>, Status> {
        let req = request.into_inner();
        let ei_id = req.ei_id.clone();
        
        match self.app_service.delete_entity_identified(&ei_id).await {
            Ok(deleted) => {
                let response = DeleteResponse {
                    id: ei_id,
                    success: deleted,
                };
                Ok(Response::new(response))
            }
            Err(e) => Err(Status::internal(format!("Failed to delete entity identified: {}", e))),
        }
    }

    async fn list_entity_identifieds(
        &self,
        request: Request<ListEntityIdentifiedsRequest>,
    ) -> Result<Response<ListEntityIdentifiedsResponse>, Status> {
        let req = request.into_inner();
        match self.app_service.list_entity_identifieds(req).await {
            Ok(entity_identifieds) => Ok(Response::new(entity_identifieds)),
            Err(e) => Err(Status::internal(format!("Failed to list entity identifieds: {}", e))),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto_gen::memorygraph::{CreateEntityIdentifiedRequest, GetEntityIdentifiedRequest};

    #[derive(Clone)]
    struct MockEntityIdentifiedRepository {
        entity_identifieds: Vec<EntityIdentified>,
    }

    impl MockEntityIdentifiedRepository {
        fn new() -> Self {
            Self { entity_identifieds: Vec::new() }
        }
    }

    #[async_trait::async_trait]
    impl IEntityIdentifiedRepository for MockEntityIdentifiedRepository {
        async fn create(&self, entity_identified: &EntityIdentified) -> Result<EntityIdentified, anyhow::Error> {
            Ok(entity_identified.clone())
        }

        async fn get_by_id(&self, id: &str) -> Result<Option<EntityIdentified>, anyhow::Error> {
            if id == "test_id" {
                Ok(Some(EntityIdentified {
                    ei_id: "test_id".to_string(),
                    identified_entity: "test_entity".to_string(),
                    label: "Test Entity Identified".to_string(),
                    confidence: 0.95,
                    user_id: "test_user".to_string(),
                }))
            } else {
                Ok(None)
            }
        }

        async fn update(&self, entity_identified: &EntityIdentified) -> Result<EntityIdentified, anyhow::Error> {
            Ok(entity_identified.clone())
        }

        async fn delete(&self, _id: &str) -> Result<bool, anyhow::Error> {
            Ok(true)
        }

        async fn list(
            &self,
            _user_id: Option<&str>,
            _limit: Option<u32>,
            _offset: Option<u32>,
        ) -> Result<Vec<EntityIdentified>, anyhow::Error> {
            Ok(vec![
                EntityIdentified {
                    ei_id: "id1".to_string(),
                    identified_entity: "entity1".to_string(),
                    label: "Label1".to_string(),
                    confidence: 0.8,
                    user_id: "user1".to_string(),
                },
                EntityIdentified {
                    ei_id: "id2".to_string(),
                    identified_entity: "entity2".to_string(),
                    label: "Label2".to_string(),
                    confidence: 0.9,
                    user_id: "user2".to_string(),
                },
            ])
        }

        async fn find_by_entity(&self, _entity_id: &str) -> Result<Vec<EntityIdentified>, anyhow::Error> {
            Ok(vec![])
        }
        async fn find_by_user(&self, _user_id: &str) -> Result<Vec<EntityIdentified>, anyhow::Error> {
            Ok(vec![])
        }
        async fn find_by_confidence_range(
            &self,
            _min_confidence: f64,
            _max_confidence: f64,
        ) -> Result<Vec<EntityIdentified>, anyhow::Error> {
            Ok(vec![])
        }
        async fn find_by_date_range(
            &self,
            _start_date: chrono::DateTime<chrono::Utc>,
            _end_date: chrono::DateTime<chrono::Utc>,
        ) -> Result<Vec<EntityIdentified>, anyhow::Error> {
            Ok(vec![])
        }
        async fn count_by_user(&self, _user_id: &str) -> Result<u64, anyhow::Error> {
            Ok(0)
        }
        async fn count_by_entity(&self, _entity_id: &str) -> Result<u64, anyhow::Error> {
            Ok(0)
        }
        async fn exists(&self, _id: &str) -> Result<bool, anyhow::Error> {
            Ok(false)
        }
        async fn get_recent_entity_identifieds(
            &self,
            _user_id: &str,
            _limit: u32,
        ) -> Result<Vec<EntityIdentified>, anyhow::Error> {
            Ok(vec![])
        }
    }

    #[tokio::test]
    async fn test_entity_identified_service_creation() {
        let mock_repo = Arc::new(MockEntityIdentifiedRepository::new());
        let app_service = EntityIdentifiedApplicationService::new(mock_repo);
        let _service = EntityIdentifiedServiceV2::new(app_service);
        assert!(true);
    }

    #[tokio::test]
    async fn test_create_entity_identified() {
        let mock_repo = Arc::new(MockEntityIdentifiedRepository::new());
        let app_service = EntityIdentifiedApplicationService::new(mock_repo);
        let service = EntityIdentifiedServiceV2::new(app_service);

        let request = CreateEntityIdentifiedRequest {
            e_id: "test_entity".to_string(),
            label: "Test Entity Identified".to_string(),
            confidence: 0.95,
            user_id: "test_user".to_string(),
        };

        let result = service.create_entity_identified(Request::new(request)).await;
        assert!(result.is_ok());

        let response = result.unwrap();
        let entity_identified = response.into_inner();
        assert_eq!(entity_identified.label, "Test Entity Identified");
        assert_eq!(entity_identified.confidence, 0.95);
    }
}

