#!/usr/bin/env bash

set -o pipefail
set -eu
source ./00-common.sh

header_text "Delete old jobs in knative-eventing namespace"
kubectl delete jobs -n knative-eventing --all

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: knative-eventing
EOF

header_text "Creating KnativeEventing installation"

cat <<EOF | oc apply -f -
apiVersion: operator.knative.dev/v1alpha1
kind: KnativeEventing
metadata:
  name: knative-eventing
  namespace: knative-eventing
EOF

header_text "Waiting for KnativeEventing to be ready"
oc wait --for=condition=Ready knativeeventings.operator.knative.dev knative-eventing -n knative-eventing --timeout=900s

header_text "Creating KnativeKafka installation"

cat <<EOF | oc apply -f -
apiVersion: operator.serverless.openshift.io/v1alpha1
kind: KnativeKafka
metadata:
  name: knative-kafka
  namespace: knative-eventing
spec:
  sink:
    enabled: false
  broker:
    enabled: true
    defaultConfig:
      bootstrapServers: my-cluster-kafka-bootstrap.kafka.svc:9092
  source:
    enabled: false
  channel:
    enabled: false
EOF

header_text "Waiting for KnativeKafka to be ready"
oc wait --for=condition=Ready knativekafkas.operator.serverless.openshift.io knative-kafka -n knative-eventing --timeout=900s
