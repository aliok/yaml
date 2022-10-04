
Create broker, trigger and subscriber
```shell
# create everything
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kafka-broker/kafka-broker.yaml
k apply -f kafka-broker/trigger-v1----kafka-broker----kube-service-knative-event-display.yaml
```

Start watching event-display:
```shell
stern -n default event-display
```

Start watching Kafka topic:
```shell
kubectl -n kafka exec -it my-cluster-kafka-0 -- bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic knative-broker-default-default --from-beginning
```

Start watching KafkaBroker receiver:
```shell
stern -n knative-eventing kafka-broker-receiver
```

Get inside a pod in the Kube cluster:
```shell
kubectl run curl -it --rm --image=ellerbrock/alpine-bash-curl-ssl -- sh
```

Send a sample event:
```shell
curl -X POST -H "Content-Type: application/cloudevents+json" "http://kafka-broker-ingress.knative-eventing.svc.cluster.local/default/default" \
-d '{"specversion":"1.0","type":"dev.knative.samples.helloworld","source":"dev.knative.samples/helloworldsource","id":"536808d3-88be-4077-9d7a-a3f162705f79","data":{"msg":"Hello Knative!"}}'
```

Turn off debug logging in receiver:
```shell
# edit dataplane configmap and set level to INFO
k edit cm -n knative-eventing kafka-config-logging

# restart receiver
k delete pods -n knative-eventing kafka-broker-receiver-85b49f885c-dh8r6
```

Create a large event payload:
```shell
# first create a large payload
rm payload.json || true
echo -n '{"specversion":"1.0","type":"dev.knative.samples.helloworld","source":"dev.knative.samples/helloworldsource","id":"536808d3-88be-4077-9d7a-a3f162705f79","data":{"msg":"Hello Knative!"' >> payload.json

max=100000
for i in `seq 1 $max`
do
  echo -n ',"var'"$i"'":"'"$i"'"' >> payload.json
done

echo -n '}}' >> payload.json

ls -laht payload.json
# max=100000 results in a 1.8 MB payload
```

Send the large payload N times
```shell
# Send it N times
max=100
for i in `seq 1 $max`
do
  echo "Sending event $i/$max"
  curl -X POST -H "Content-Type: application/cloudevents+json" "http://kafka-broker-ingress.knative-eventing.svc.cluster.local/default/default" -d @payload.json &
done
```
