#!/usr/bin/env bash

set -o pipefail
set -eu
source ./00-common.sh

header_text "Creating Strimzi subscription"
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: strimzi-kafka-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: strimzi-kafka-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: strimzi-cluster-operator.v$VERSION_STRIMZI
EOF

header_text "Sleeping 20 seconds before checking if Strimzi CRD is available"
sleep 20

header_text "Wait for the Strimzi CRD we need to actually be active"
kubectl wait crd --timeout=5m kafkas.kafka.strimzi.io --for=condition=Established

# create kafka namespace
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: kafka
EOF

header_text "Creating Strimzi Kafka cluster"
cat <<EOF | oc apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
spec:
  kafka:
    version: 3.2.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    authorization:
      superUsers:
        - ANONYMOUS
      type: simple
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      inter.broker.protocol.version: "3.2"
      auto.create.topics.enable: "false"
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        deleteClaim: false
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 100Gi
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF

header_text "Waiting for Kafka cluster to become ready"
kubectl wait kafka --all --timeout=10m --for=condition=Ready -n kafka
