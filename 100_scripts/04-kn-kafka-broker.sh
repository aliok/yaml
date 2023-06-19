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

eventing_kafka_broker_version="v1.10.0"
eventing_kafka_broker_url=https://github.com/knative-sandbox/eventing-kafka-broker/releases/download/knative-${eventing_kafka_broker_version}

#while [[ $# -ne 0 ]]; do
#   parameter=$1
#   case ${parameter} in
#     --nightly)
#        nightly=1
#        eventing_kafka_broker_version=nightly
#        eventing_kafka_broker_url=https://knative-nightly.storage.googleapis.com/eventing-kafka/latest
#       ;;
#     *) abort "unknown option ${parameter}" ;;
#   esac
#   shift
# done

function header_text {
  echo "$header$*$reset"
}

header_text "Using Knative Kafka Broker Version:         ${eventing_kafka_broker_version}"

header_text "Setting up Knative Eventing Kafka suite "
curl -L ${eventing_kafka_broker_url}/eventing-kafka.yaml \
  | sed 's/namespace: .*/namespace: knative-eventing/' \
  | sed 's/REPLACE_WITH_CLUSTER_URL/my-cluster-kafka-bootstrap.kafka:9092/' \
  | kubectl apply -f - -n knative-eventing

header_text "Waiting for Knative Apache Kafka suite to become ready"
kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-eventing
