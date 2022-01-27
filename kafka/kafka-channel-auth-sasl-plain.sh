#!/usr/bin/env bash

SASL_PASSWD=$(kubectl -n kafka get secret my-sasl-user --template='{{index .data "password"}}' | base64 --decode )

kubectl create secret --namespace knative-eventing generic strimzi-sasl-plain-secret \
  --from-literal=password="$SASL_PASSWD" \
  --from-literal=user="my-sasl-user" \
  --from-literal=protocol="SASL_PLAINTEXT" \
  --from-literal=sasl.mechanism="SCRAM-SHA-512" \
  --dry-run=client -o yaml | kubectl apply -n knative-eventing -f -

# ------------- WHAT IS CREATED? --------------------
# apiVersion: v1
# data:
#   password: dWVPME5VVHlaNHJG
#   protocol: U0FTTF9QTEFJTlRFWFQ=
#   sasl.mechanism: U0NSQU0tU0hBLTUxMg==
#   user: bXktc2FzbC11c2Vy
# kind: Secret
# metadata:
#   name: strimzi-sasl-plain-secret
#   namespace: knative-eventing
# type: Opaque

# -------------- HOW IT IS USED? -------------------
#
#  apiVersion: v1
#  data:
#    auth.secret.ref.name: strimzi-sasl-plain-secret
#    bootstrap.servers: my-cluster-kafka-bootstrap.kafka:9095
#    default.topic.partitions: "2"
#    default.topic.replication.factor: "2"
#  kind: ConfigMap
#  metadata:
#    name: config-broker
#    namespace: knative-eventing
