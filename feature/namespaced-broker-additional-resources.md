## Test additional resources feature upstream

Make KafkaController able to create/delete a random cluster scoped resource, such as a ClusterRole:
```shell
cat <<EOF | k apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: random-role
rules:
  - apiGroups:
      - "rbac.authorization.k8s.io"
    resources:
      - clusterroles
    verbs:
      - get
      - list
      - create
      - update
      - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: random-role-binding
subjects:
  - kind: ServiceAccount
    name: kafka-controller
    namespace: knative-eventing
roleRef:
  kind: ClusterRole
  name: random-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

Modify the additional resources configmap so that the namespaced broker controller creates a ClusterRole:
```shell
cat <<EOF | k apply -f -
apiVersion: v1
data:
  resources: |
    - apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: test-role
        labels:
          foo: "bar-{{.Namespace}}"
      rules:
        - apiGroups:
            - ""
          resources:
            - pods
          verbs:
            - get
kind: ConfigMap
metadata:
  name: config-namespaced-broker-resources
  namespace: knative-eventing
EOF
```

Create a namespaced broker and config for it:
```shell
cat <<EOF | k apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: foo
  namespace: foo
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-broker-config
  namespace: foo
data:
  bootstrap.servers: my-cluster-kafka-bootstrap.kafka:9092
  default.topic.partitions: "10"
  default.topic.replication.factor: "3"
EOF

cat <<EOF | k apply -f -
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  annotations:
    eventing.knative.dev/broker.class: KafkaNamespaced
    hello: world
  name: broker1
  namespace: foo
spec:
  config:
    apiVersion: v1
    kind: ConfigMap
    name: kafka-broker-config
    namespace: foo
---
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  annotations:
    eventing.knative.dev/broker.class: KafkaNamespaced
    hello: world
  name: broker2
  namespace: foo
spec:
  config:
    apiVersion: v1
    kind: ConfigMap
    name: kafka-broker-config
    namespace: foo
EOF
```

This would create a ClusterRole with the name `test-role` and the label `foo: bar-foo`:
```shell
❯ k get clusterroles test-role -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  ...
  name: test-role
  ownerReferences:
  - apiVersion: v1
    blockOwnerDeletion: false
    controller: true
    kind: Namespace
    name: foo
    uid: 740161db-8633-485d-97dc-0da5fda48a54
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
```

It would also create data plane in namespace `foo`:
```shell
❯ k get pods -n foo
NAME                                       READY   STATUS    RESTARTS   AGE
kafka-broker-dispatcher-758ffc69cf-9bbmx   1/1     Running   0          4m1s
kafka-broker-receiver-5f5bc8d4cf-2vw9h     1/1     Running   0          4m1s
```


## Tests

* Delete 1 broker and check that the ClusterRole is NOT deleted
* Delete 2 brokers and check that the ClusterRole is deleted
* Delete brokers with `--cascade=foreground`
* Create everything again and delete the namespace and check that the ClusterRole is deleted
* Create everything again and delete the namespace with foreground cascading and check that the ClusterRole is deleted
```shell
k delete namespace foo --cascade=foreground
```
