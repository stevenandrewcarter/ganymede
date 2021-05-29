########################################################################################################################
# Kafka
# =====
# Configure and deploy confluent Kafka / Zookeeper to the k8s cluster.
#----------------------------------------------------------------------------------------------------------------------#

variable "kafka_version" {
  type = string
  default = "6.1.1"
}

#----------------------------------------------------------------------------------------------------------------------#
resource "kubernetes_namespace" "kafka" {
  metadata {
    annotations = {
      name = "kafka"
    }
    labels = {
      "name" = "kafka"
    }
    name = "kafka"
  }
}

#----------------------------------------------------------------------------------------------------------------------#
# Config map to hold the JMX extensions for Kafka to provide Prometheus metrics
resource "kubernetes_config_map" "kafka" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace.kafka.metadata[0].name
  }
  data = {
    "kafka_broker.yml" = "${file("${path.module}/files/jmx_kafka_broker.yml")}"
  }
  binary_data = {
    "jmx_prometheus_javaagent-0.15.0.jar" = "${filebase64("${path.module}/files/jmx_prometheus_javaagent-0.15.0.jar")}"
  }
}

#----------------------------------------------------------------------------------------------------------------------#
resource "kubernetes_deployment" "zookeeper" {
  metadata {
    name = "zookeeper"
    labels = {
      app = "zookeeper"
    }
    namespace = kubernetes_namespace.kafka.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "zookeeper"
      }
    }
    template {
      metadata {
        labels = {
          app = "zookeeper"
        }
      }
      spec {
        container {
          image = "confluentinc/cp-zookeeper:${var.kafka_version}"
          name  = "zookeeper"
          port {
            container_port = 2181
          }
          env {
            name  = "ZOOKEEPER_CLIENT_PORT"
            value = "2181"
          }
          env {
            name  = "ZOOKEEPER_TICK_TIME"
            value = "2000"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = kubernetes_namespace.kafka.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.zookeeper.metadata.0.labels.app
    }
    port {
      protocol    = "TCP"
      port        = 2181
      target_port = 2181
    }
    # port {
    #   protocol    = "TCP"
    #   port        = 2888
    #   target_port = 2888
    # }
    # port {
    #   protocol    = "TCP"
    #   port        = 3888
    #   target_port = 3888
    # }
    # port {
    #   protocol    = "TCP"
    #   port        = 8080
    #   target_port = 8080
    # }
  }
}

resource "kubernetes_deployment" "broker" {
  depends_on = [
  kubernetes_service.zookeeper]
  metadata {
    name = "broker"
    labels = {
      app = "broker"
    }
    namespace = kubernetes_namespace.kafka.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "broker"
      }
    }
    template {
      metadata {
        labels = {
          app = "broker"
        }
      }
      spec {
        container {
          image = "confluentinc/cp-server:${var.kafka_version}"
          name  = "broker"          
          port {
            container_port = 9092
          }
          port {
            container_port = 29092
          }
          port {
            container_port = 9405
          }
          env {
            name  = "KAFKA_BROKER_ID"
            value = "1"
          }
          env {
            name  = "KAFKA_ZOOKEEPER_CONNECT"
            value = "zookeeper:2181"
          }
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://broker:29092,PLAINTEXT_HOST://localhost:9092"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS"
            value = "0"
          }
          env {
            name  = "KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name = "KAFKA_OPTS"
            value = "-javaagent:/opt/prometheus/jmx_prometheus_javaagent-0.15.0.jar=9405:/opt/prometheus/kafka_broker.yml"
          }
          volume_mount {
            name = "config"
            mount_path = "/opt/prometheus"
            read_only = true
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.kafka.metadata[0].name
            items {
              key = "kafka_broker.yml"
              path = "kafka_broker.yml"
            }
            items {
              key = "jmx_prometheus_javaagent-0.15.0.jar"
              path = "jmx_prometheus_javaagent-0.15.0.jar"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "broker" {
  metadata {
    name      = "broker"
    namespace = kubernetes_namespace.kafka.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.broker.metadata.0.labels.app
    }
    port {
      name        = "broker-host"
      protocol    = "TCP"
      port        = 9092
      target_port = 9092
    }
    port {
      name        = "broker"
      protocol    = "TCP"
      port        = 29092
      target_port = 29092
    }
    port {
      name        = "prometheus"
      protocol    = "TCP"
      port        = 9405
      target_port = 9405
    }
    type = "LoadBalancer"
  }
}

# resource "kubernetes_deployment" "schema-registry" {
#   depends_on = [
#     kubernetes_service.broker]
#   metadata {
#     name = "schema-registry"
#     labels = {
#       app = "schema-registry"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "schema-registry"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "schema-registry"
#         }
#       }

#       spec {
#         container {
#           image = "confluentinc/cp-schema-registry:${var.kafka_version}"
#           name = "schema-registry"
#           port {
#             container_port = 8081
#           }
#           env {
#             name = "SCHEMA_REGISTRY_HOST_NAME"
#             value = "schema-registry"
#           }
#           env {
#             name = "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
#             value = "broker:29092"
#           }
#           env {
#             name = "SCHEMA_REGISTRY_LISTENERS"
#             value = "http://0.0.0.0:8081"
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "schema-registry" {
#   metadata {
#     name = "schema-registry"
#   }
#   spec {
#     selector = {
#       app = kubernetes_deployment.schema-registry.metadata.0.labels.app
#     }
#     port {
#       protocol = "TCP"
#       port = 8081
#       target_port = 8081
#     }
#     type = "LoadBalancer"
#   }
# }

# resource "kubernetes_deployment" "connect" {
#   depends_on = [
#     kubernetes_service.broker,
#     kubernetes_service.schema-registry]
#   metadata {
#     name = "connect"
#     labels = {
#       app = "connect"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "connect"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "connect"
#         }
#       }

#       spec {
#         container {
#           image = "cnfldemos/cp-server-connect-datagen:0.4.0-${var.kafka_version}"
#           name = "connect"
#           port {
#             container_port = 8083
#           }
#           env {
#             name = "CONNECT_BOOTSTRAP_SERVERS"
#             value = "broker:29092"
#           }
#           env {
#             name = "CONNECT_REST_ADVERTISED_HOST_NAME"
#             value = "connect"
#           }
#           env {
#             name = "CONNECT_REST_PORT"
#             value = "8083"
#           }
#           env {
#             name = "CONNECT_GROUP_ID"
#             value = "compose-connect-group"
#           }
#           env {
#             name = "CONNECT_CONFIG_STORAGE_TOPIC"
#             value = "docker-connect-configs"
#           }
#           env {
#             name = "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR"
#             value = "1"
#           }
#           env {
#             name = "CONNECT_OFFSET_FLUSH_INTERVAL_MS"
#             value = "10000"
#           }
#           env {
#             name = "CONNECT_OFFSET_STORAGE_TOPIC"
#             value = "docker-connect-offsets"
#           }
#           env {
#             name = "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR"
#             value = "1"
#           }
#           env {
#             name = "CONNECT_STATUS_STORAGE_TOPIC"
#             value = "docker-connect-status"
#           }
#           env {
#             name = "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR"
#             value = "1"
#           }
#           env {
#             name = "CONNECT_KEY_CONVERTER"
#             value = "org.apache.kafka.connect.storage.StringConverter"
#           }
#           env {
#             name = "CONNECT_VALUE_CONVERTER"
#             value = "io.confluent.connect.avro.AvroConverter"
#           }
#           env {
#             name = "CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL"
#             value = "http://schema-registry:8081"
#           }
#           env {
#             name = "CLASSPATH"
#             value = "/usr/share/java/monitoring-interceptors/monitoring-interceptors-6.0.1.jar"
#           }
#           env {
#             name = "CONNECT_PRODUCER_INTERCEPTOR_CLASSES"
#             value = "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor"
#           }
#           env {
#             name = "CONNECT_CONSUMER_INTERCEPTOR_CLASSES"
#             value = "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor"
#           }
#           env {
#             name = "CONNECT_PLUGIN_PATH"
#             value = "/usr/share/java,/usr/share/confluent-hub-components"
#           }
#           env {
#             name = "CONNECT_LOG4J_LOGGERS"
#             value = "org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR"
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "connect" {
#   metadata {
#     name = "connect"
#   }
#   spec {
#     selector = {
#       app = kubernetes_deployment.connect.metadata.0.labels.app
#     }
#     port {
#       protocol = "TCP"
#       port = 8083
#       target_port = 8083
#     }
#     type = "LoadBalancer"
#   }
# }

# resource "kubernetes_deployment" "control-center" {
#   depends_on = [
#     kubernetes_service.broker,
#     kubernetes_service.schema-registry,
#     kubernetes_service.connect,
#     kubernetes_service.ksqldb-server
#   ]
#   metadata {
#     name = "control-center"
#     labels = {
#       app = "control-center"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "control-center"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "control-center"
#         }
#       }

#       spec {
#         container {
#           image = "confluentinc/cp-enterprise-control-center:${var.kafka_version}"
#           name = "control-center"
#           port {
#             container_port = 9021
#           }
#           env {
#             name = "CONTROL_CENTER_BOOTSTRAP_SERVERS"
#             value = "broker:29092"
#           }
#           env {
#             name = "CONTROL_CENTER_CONNECT_CLUSTER"
#             value = "connect:8083"
#           }
#           env {
#             name = "CONTROL_CENTER_KSQL_KSQLDB1_URL"
#             value = "http://ksqldb-server:8088"
#           }
#           env {
#             name = "CONTROL_CENTER_KSQL_KSQLDB1_ADVERTISED_URL"
#             value = "http://localhost:8088"
#           }
#           env {
#             name = "CONTROL_CENTER_SCHEMA_REGISTRY_URL"
#             value = "http://schema-registry:8081"
#           }
#           env {
#             name = "CONTROL_CENTER_REPLICATION_FACTOR"
#             value = "1"
#           }
#           env {
#             name = "CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS"
#             value = "1"
#           }
#           env {
#             name = "CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS"
#             value = "1"
#           }
#           env {
#             name = "CONFLUENT_METRICS_TOPIC_REPLICATION"
#             value = "1"
#           }
#           env {
#             name = "PORT"
#             value = "9021"
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "control-center" {
#   metadata {
#     name = "control-center"
#   }
#   spec {
#     selector = {
#       app = kubernetes_deployment.control-center.metadata.0.labels.app
#     }
#     port {
#       protocol = "TCP"
#       port = 9021
#       target_port = 9021
#     }
#     type = "LoadBalancer"
#   }
# }

# resource "kubernetes_deployment" "ksqldb-server" {
#   depends_on = [
#     kubernetes_service.broker,
#     kubernetes_service.connect
#   ]
#   metadata {
#     name = "ksqldb-server"
#     labels = {
#       app = "ksqldb-server"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "ksqldb-server"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "ksqldb-server"
#         }
#       }

#       spec {
#         container {
#           image = "confluentinc/cp-ksqldb-server:${var.kafka_version}"
#           name = "ksqldb-server"
#           port {
#             container_port = 8088
#           }
#           env {
#             name = "KSQL_CONFIG_DIR"
#             value = "/etc/ksql"
#           }
#           env {
#             name = "KSQL_BOOTSTRAP_SERVERS"
#             value = "broker:29092"
#           }
#           env {
#             name = "KSQL_HOST_NAME"
#             value = "ksqldb-server"
#           }
#           env {
#             name = "KSQL_LISTENERS"
#             value = "http://0.0.0.0:8088"
#           }
#           env {
#             name = "KSQL_KSQL_SCHEMA_REGISTRY_URL"
#             value = "http://schema-registry:8081"
#           }
#           env {
#             name = "KSQL_PRODUCER_INTERCEPTOR_CLASSES"
#             value = "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor"
#           }
#           env {
#             name = "KSQL_CONSUMER_INTERCEPTOR_CLASSES"
#             value = "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor"
#           }
#           env {
#             name = "KSQL_KSQL_CONNECT_URL"
#             value = "http://connect:8083"
#           }
#           env {
#             name = "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_REPLICATION_FACTOR"
#             value = "1"
#           }
#           env {
#             name = "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_AUTO_CREATE"
#             value = "true"
#           }
#           env {
#             name = "KSQL_KSQL_LOGGING_PROCESSING_STREAM_AUTO_CREATE"
#             value = "true"
#           }
#         }
#         container {
#           image = "confluentinc/cp-ksqldb-cli:${var.kafka_version}"
#           name = "ksqldb-cli"
#           command = [
#             "/bin/sh"]
#           tty = true
#         }
#         # container {
#         #   image = "confluentinc/ksqldb-examples:6.0.1"
#         #   name  = "ksql-datagen"
#         #   command = [<<EOT
#         #               bash -c 'echo Waiting for Kafka to be ready... && \
#         #                cub kafka-ready -b broker:29092 1 40 && \
#         #                echo Waiting for Confluent Schema Registry to be ready... && \
#         #                cub sr-ready schema-registry 8081 40 && \
#         #                echo Waiting a few seconds for topic creation to finish... && \
#         #                sleep 11 && \
#         #                tail -f /dev/null'
#         #               EOT
#         #   ]
#         #   env {
#         #     name  = "KSQL_CONFIG_DIR"
#         #     value = "/etc/ksql"
#         #   }
#         #   env {
#         #     name  = "STREAMS_BOOTSTRAP_SERVERS"
#         #     value = "broker:29092"
#         #   }
#         #   env {
#         #     name  = "STREAMS_SCHEMA_REGISTRY_HOST"
#         #     value = "schema-registry"
#         #   }
#         #   env {
#         #     name  = "STREAMS_SCHEMA_REGISTRY_PORT"
#         #     value = "8081"
#         #   }
#         # }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "ksqldb-server" {
#   metadata {
#     name = "ksqldb-server"
#   }
#   spec {
#     selector = {
#       app = kubernetes_deployment.ksqldb-server.metadata.0.labels.app
#     }
#     port {
#       protocol = "TCP"
#       port = 8088
#       target_port = 8088
#     }
#     type = "LoadBalancer"
#   }
# }

# resource "kubernetes_deployment" "rest-proxy" {
#   depends_on = [
#     kubernetes_service.broker,
#     kubernetes_service.schema-registry
#   ]
#   metadata {
#     name = "rest-proxy"
#     labels = {
#       app = "rest-proxy"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "rest-proxy"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "rest-proxy"
#         }
#       }

#       spec {
#         container {
#           image = "confluentinc/cp-kafka-rest:${var.kafka_version}"
#           name = "rest-proxy"
#           port {
#             container_port = 8082
#           }
#           env {
#             name = "KAFKA_REST_HOST_NAME"
#             value = "rest-proxy"
#           }
#           env {
#             name = "KAFKA_REST_BOOTSTRAP_SERVERS"
#             value = "broker:29092"
#           }
#           env {
#             name = "KAFKA_REST_LISTENERS"
#             value = "http://0.0.0.0:8082"
#           }
#           env {
#             name = "KAFKA_REST_SCHEMA_REGISTRY_URL"
#             value = "http://schema-registry:8081"
#           }
#           env {
#             name = "CONTROL_CENTER_SCHEMA_REGISTRY_URL"
#             value = "http://schema-registry:8081"
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "rest-proxy" {
#   metadata {
#     name = "rest-proxy"
#   }
#   spec {
#     selector = {
#       app = kubernetes_deployment.rest-proxy.metadata.0.labels.app
#     }
#     port {
#       protocol = "TCP"
#       port = 8082
#       target_port = 8082
#     }
#     type = "LoadBalancer"
#   }
# }
