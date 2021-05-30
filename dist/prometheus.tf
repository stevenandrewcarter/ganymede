########################################################################################################################
# Prometheus
# ==========
# Configure and deploy Prometheus to the k8s cluster.
#----------------------------------------------------------------------------------------------------------------------#

# Version is locked to latest. Specific version would be provided as v2.27.0 for example
variable "prometheus_version" {
  type    = string
  default = "latest"
}

#----------------------------------------------------------------------------------------------------------------------#
# Keep the prometheus monitoring in a namespace, but allow it to monitor the entire cluster
resource "kubernetes_namespace" "prometheus" {
  metadata {
    annotations = {
      name = "prometheus"
    }
    labels = {
      "name"    = "prometheus"
      "version" = var.prometheus_version
    }
    name = "prometheus"
  }
}

# Create a cluster role that can read the cluster for monitoring
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
}

resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
}

#----------------------------------------------------------------------------------------------------------------------#
# Store the prometheus configuration as a ConfigMap
resource "kubernetes_config_map" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  data = {
    "prometheus.yml" = "${file("${path.module}/files/prometheus/prometheus.yml")}"
  }
}

#----------------------------------------------------------------------------------------------------------------------#
# Request a deployment of the prometheus container
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name = "prometheus"
    labels = {
      app = "prometheus"
    }
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          image = "prom/prometheus:${var.prometheus_version}"
          name  = "prometheus"
          port {
            container_port = 9090
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
            read_only  = true
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus.metadata[0].name
            items {
              key  = "prometheus.yml"
              path = "prometheus.yml"
            }
          }
        }
      }
    }
  }
}

#----------------------------------------------------------------------------------------------------------------------#
# Service to expose the Prometheus UI outside of the cluster
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.prometheus.metadata.0.labels.app
    }
    port {
      name        = "prometheus"
      protocol    = "TCP"
      port        = 9090
      target_port = 9090
    }
    type = "LoadBalancer"
  }
}
