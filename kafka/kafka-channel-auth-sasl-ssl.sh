#!/usr/bin/env bash

STRIMZI_CRT=$(kubectl -n kafka get secret my-cluster-cluster-ca-cert --template='{{index .data "ca.crt"}}' | base64 --decode )
SASL_PASSWD=$(kubectl -n kafka get secret my-sasl-user --template='{{index .data "password"}}' | base64 --decode )

kubectl create secret --namespace knative-eventing generic strimzi-sasl-secret \
  --from-literal=ca.crt="$STRIMZI_CRT" \
  --from-literal=password="$SASL_PASSWD" \
  --from-literal=user="my-sasl-user" \
  --from-literal=protocol="SASL_SSL" \
  --from-literal=sasl.mechanism="SCRAM-SHA-512" \
  --dry-run=client -o yaml | kubectl apply -n knative-eventing -f -

# ------------- WHAT IS CREATED? --------------------
# apiVersion: v1
# data:
#   ca.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURMVENDQWhXZ0F3SUJBZ0lKQUpKa1hkeGt1b04vTUEwR0NTcUdTSWIzRFFFQkN3VUFNQzB4RXpBUkJnTlYKQkFvTUNtbHZMbk4wY21sdGVta3hGakFVQmdOVkJBTU1EV05zZFhOMFpYSXRZMkVnZGpBd0hoY05Nakl3TVRJMgpNVEV6TkRJNVdoY05Nak13TVRJMk1URXpOREk1V2pBdE1STXdFUVlEVlFRS0RBcHBieTV6ZEhKcGJYcHBNUll3CkZBWURWUVFEREExamJIVnpkR1Z5TFdOaElIWXdNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUIKQ2dLQ0FRRUFvMWtiTWFnVWZvck5Ea2FVOHo3TTlwaEdwbkl1ZGc0RUVHdkhzN3FWY3VnOG5qUUUwemlpNk4vSgpNZjBTWWtxdTlFdmRmRUNHcFI0ZDRJY2dMWUtRWHU0YThmWWp5Q0YvcUtVcWZzclMrQktJbVRSV3VZV0JLV05vCnFDV2QyNk4zK3B2VTl6TUxmVllVd05hSVQ5cTIyS2NxK3pEUkFuWkdJbU02dmpDeDJXMlYwN21EVHNrUTFNOWUKSGFRQXd2ZlV5QmVQU2xsRmRBeWpFSFBWcW1DNks3blcyK1oybXJyYWRHaTJQalRQQjZTenNVWE4yMGRYdWRLSQowSGhybTgyYzUwQldZaGZ1M0t6NGR4OVpnekk2K0xsbko2T2hiRzB5RGs5cEJuOVpWVi9xaUFwU2VOUmhQYWZzCmtjR2FIbDQ2eXFwZWtoRHhOS3hEd2NINHdoZXNWUUlEQVFBQm8xQXdUakFkQmdOVkhRNEVGZ1FVaG9jV28xY28KRmVpUEFXbjNPMURMcFpKaDVLWXdId1lEVlIwakJCZ3dGb0FVaG9jV28xY29GZWlQQVduM08xRExwWkpoNUtZdwpEQVlEVlIwVEJBVXdBd0VCL3pBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQWw3Qm4waE9kbzQxME40Zlp2Sm8xCnhPMnhabjdYWnJmZjhVLzRvQmZiUW1xemxCWS8xaCtSWlBmc1dWNjMwNnM3cU1ESGtQWHg0VjYrTVBkMFQ3T0kKbGx5UUZJU2wrVE93ZDNZU3NLNVdMNC9IQzRmUE9SbHl0Wi9kVVZzWFpCbGl2bXpWYWhrdnZLamlBL09lWWpLQwpRU0s4M2hCL04yNnYwa3dGYW1OaGxNaURRblk3cjc4YlhHczZDMi83dElCMlMyUUIySW53YUlwa0d0c3dSTkwxCjg1Qk9ndXhJTGEvQVY0WGNORG5ydG5yTGM3SVR3ZTlYUE11UzNSQWtVbnF0Y1BzeTdQM0NIZjhtM0FDck14Y0IKLzFHc3pDbmQ1aUhmQkZpUFFpOHdZOWFSNGc0THFONHNac1NvdzRNWEk1Slp1NmN1aEVURGN3azhScDN3bzBDRgowdz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0=
#   password: dWVPME5VVHlaNHJG
#   protocol: U0FTTF9TU0w=
#   sasl.mechanism: U0NSQU0tU0hBLTUxMg==
#   user: bXktc2FzbC11c2Vy
# kind: Secret
# metadata:
#   name: strimzi-sasl-secret
#   namespace: knative-eventing
# type: Opaque

# -------------- HOW IT IS USED? -------------------
#
#  apiVersion: v1
#  data:
#    auth.secret.ref.name: strimzi-sasl-secret
#    bootstrap.servers: my-cluster-kafka-bootstrap.kafka:9094
#    default.topic.partitions: "2"
#    default.topic.replication.factor: "2"
#  kind: ConfigMap
#  metadata:
#    name: config-broker
#    namespace: knative-eventing
