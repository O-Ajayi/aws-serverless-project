output "namespace" {
  description = "Namespace where chaos-broker is deployed"
  value       = kubernetes_namespace.chaos_broker.metadata[0].name
}

output "handler_service_url" {
  description = "Handler service URL"
  value       = "http://${kubernetes_service.handler.metadata[0].name}.${kubernetes_namespace.chaos_broker.metadata[0].name}.svc.cluster.local:8080"
}

output "handler_service_name" {
  description = "Handler service name"
  value       = kubernetes_service.handler.metadata[0].name
}

output "orchestrator_deployment_name" {
  description = "Orchestrator deployment name"
  value       = kubernetes_deployment.orchestrator.metadata[0].name
}

output "storage_pvc_name" {
  description = "Persistent volume claim name"
  value       = kubernetes_persistent_volume_claim.chaos_broker_storage.metadata[0].name
}

