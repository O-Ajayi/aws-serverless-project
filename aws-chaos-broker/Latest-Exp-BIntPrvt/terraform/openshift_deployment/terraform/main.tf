# Create namespace
resource "kubernetes_namespace" "chaos_broker" {
  metadata {
    name = var.namespace
    labels = var.tags
  }
}

# ConfigMap
resource "kubernetes_config_map" "chaos_broker_config" {
  metadata {
    name      = "chaos-broker-config"
    namespace = kubernetes_namespace.chaos_broker.metadata[0].name
    labels    = var.tags
  }

  data = {
    HANDLER_SERVICE_URL    = "http://chaos-broker-handler:8080"
    PORT                   = "8080"
    FUNCTION_NAME          = "chaos-broker-handler"
    FUNCTION_VERSION       = "$LATEST"
    MEMORY_LIMIT           = "512"
    ORCHESTRATOR_PORT      = "8081"
    MAX_CONCURRENCY        = "1"
    PERSISTENT_VOLUME_PATH = "/app/local_only"
    local_mode             = tostring(var.local_mode)
    execution_mode         = "openshift"
    execution_provider     = "openshift"
    skip_aws_services      = "true"
    openshift_storage_path = var.openshift_storage_path
    LOG_LEVEL              = "INFO"
  }
}

# Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "chaos_broker_storage" {
  metadata {
    name      = "chaos-broker-storage"
    namespace = kubernetes_namespace.chaos_broker.metadata[0].name
    labels    = var.tags
  }

  spec {
    access_modes = ["ReadWriteMany"]
    
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    
    storage_class_name = var.storage_class != "" ? var.storage_class : null
  }
}

# Handler Service Deployment
resource "kubernetes_deployment" "handler" {
  metadata {
    name      = "chaos-broker-handler"
    namespace = kubernetes_namespace.chaos_broker.metadata[0].name
    labels = merge(var.tags, {
      component = "handler"
    })
  }

  spec {
    replicas = var.handler_replicas

    selector {
      match_labels = {
        app       = "chaos-broker"
        component = "handler"
      }
    }

    template {
      metadata {
        labels = {
          app       = "chaos-broker"
          component = "handler"
        }
      }

      spec {
        container {
          name  = "handler"
          image = var.handler_image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
            name           = "http"
            protocol       = "TCP"
          }

          env {
            name = "PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "PORT"
              }
            }
          }

          env {
            name = "FUNCTION_NAME"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "FUNCTION_NAME"
              }
            }
          }

          env {
            name = "FUNCTION_VERSION"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "FUNCTION_VERSION"
              }
            }
          }

          env {
            name = "local_mode"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "local_mode"
              }
            }
          }

          env {
            name = "execution_mode"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "execution_mode"
              }
            }
          }

          env {
            name = "execution_provider"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "execution_provider"
              }
            }
          }

          env {
            name = "OPENSHIFT_STORAGE_PATH"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "PERSISTENT_VOLUME_PATH"
              }
            }
          }

          volume_mount {
            name       = "storage"
            mount_path = "/app/local_only"
          }

          volume_mount {
            name       = "experiments"
            mount_path = "/app/experiments"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 2
          }
        }

        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.chaos_broker_storage.metadata[0].name
          }
        }

        volume {
          name = "experiments"
          empty_dir {}
        }
      }
    }
  }
}

# Handler Service
resource "kubernetes_service" "handler" {
  metadata {
    name      = "chaos-broker-handler"
    namespace = kubernetes_namespace.chaos_broker.metadata[0].name
    labels = merge(var.tags, {
      component = "handler"
    })
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app       = "chaos-broker"
      component = "handler"
    }
  }
}

# Orchestrator Deployment (optional, can run as job or separate service)
resource "kubernetes_deployment" "orchestrator" {
  metadata {
    name      = "chaos-broker-orchestrator"
    namespace = kubernetes_namespace.chaos_broker.metadata[0].name
    labels = merge(var.tags, {
      component = "orchestrator"
    })
  }

  spec {
    replicas = var.orchestrator_replicas

    selector {
      match_labels = {
        app       = "chaos-broker"
        component = "orchestrator"
      }
    }

    template {
      metadata {
        labels = {
          app       = "chaos-broker"
          component = "orchestrator"
        }
      }

      spec {
        container {
          name  = "orchestrator"
          image = var.orchestrator_image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8081
            name           = "http"
            protocol       = "TCP"
          }

          env {
            name = "HANDLER_SERVICE_URL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "HANDLER_SERVICE_URL"
              }
            }
          }

          env {
            name = "ORCHESTRATOR_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "ORCHESTRATOR_PORT"
              }
            }
          }

          env {
            name = "MAX_CONCURRENCY"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "MAX_CONCURRENCY"
              }
            }
          }

          env {
            name = "PERSISTENT_VOLUME_PATH"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "PERSISTENT_VOLUME_PATH"
              }
            }
          }

          env {
            name = "LOG_LEVEL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.chaos_broker_config.metadata[0].name
                key  = "LOG_LEVEL"
              }
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "250m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8081
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8081
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 2
          }
        }
      }
    }
  }
}

# Orchestrator Service
resource "kubernetes_service" "orchestrator" {
  metadata {
    name      = "chaos-broker-orchestrator"
    namespace = kubernetes_namespace.chaos_broker.metadata[0].name
    labels = merge(var.tags, {
      component = "orchestrator"
    })
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app       = "chaos-broker"
      component = "orchestrator"
    }
  }
}

