#!/usr/bin/env bash

set -e

# Turn colors in this script off by setting the NO_COLOR variable in your
# environment to any value:
#
# $ NO_COLOR=1 test.sh
NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi

function header_text {
  echo "$header$*$reset"
}

header_text "Setting up config-kafka with TLS auth"

cat <<EOF | oc apply -f - || return $?
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-kafka
  namespace: knative-eventing
data:
  version: 1.0.0
  eventing-kafka: |
    kafka:
      brokers: my-cluster-kafka-bootstrap.kafka:9093
      authSecretNamespace: default
      authSecretName: my-tls-secret
EOF

header_text "Waiting for Knative Apache Kafka Channel to become ready"
kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-eventing
