
Create broker, trigger and subscriber
```shell
# create everything
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kafka-broker/kafka-broker.yaml
k apply -f kafka-broker/trigger-v1----kafka-broker----kube-service-knative-event-display.yaml
```

Turn off debug logging in receiver:
```shell
# edit dataplane configmap and set level to INFO
k edit cm -n knative-eventing kafka-config-logging

# restart receiver
k delete pods -n knative-eventing kafka-broker-receiver-85b49f885c-dh8r6
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

Create a large event payload:
```shell
# first create a large payload
rm payload.json || true
echo -n '{"specversion":"1.0","type":"dev.knative.samples.helloworld","source":"dev.knative.samples/helloworldsource","id":"536808d3-88be-4077-9d7a-a3f162705f79","data":{"msg":"Hello Knative!"' >> payload.json

max=25000
for i in `seq 1 $max`
do
  echo -n ',"var'"$i"'":"'"$i"'"' >> payload.json
done

echo -n '}}' >> payload.json

ls -laht payload.json
# max=25000 results in a 442 KB payload
```

Send the large payload N times
```shell
# Send it N times
max=1000
for i in `seq 1 $max`
do
  echo "Sending event $i/$max"
  curl -X POST -H "Content-Type: application/cloudevents+json" "http://kafka-broker-ingress.knative-eventing.svc.cluster.local/default/default" -d @payload.json &
done
```

Create a super large event payload:
```shell
rm payload2.json || true
echo -n '{"specversion":"1.0","type":"dev.knative.samples.helloworld","source":"dev.knative.samples/helloworldsource","id":"536808d3-88be-4077-9d7a-a3f162705f79","data":{"msg":"Hello Knative!"' >> payload2.json

max=500000
for i in `seq 1 $max`
do
  echo -n ',"foo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"koo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"moo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"boo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"zoo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"aoo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"loo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"xoo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo -n ',"soo'"$i"'":"'"$i"' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ' >> payload2.json
  echo "Writing var $i/$max"
done

echo -n '}}' >> payload2.json

ls -laht payload2.json
# max=500000 results in a 750 MB payload
```

Send it once:
```shell
curl -X POST -H "Content-Type: application/cloudevents+json" "http://kafka-broker-ingress.knative-eventing.svc.cluster.local/default/default" -d @payload2.json -v
```

Try sending small and binary event N times to see the difference
```shell
max=10000
for i in `seq 1 $max`
do
  echo "Sending event $i/$max"
  curl -v "http://kafka-broker-ingress.knative-eventing.svc.cluster.local/default/default" \
      -X POST \
      -H "Ce-Specversion: 1.0" \
      -H "Ce-Type: org.apache.camel.event" \
      -H "Ce-Source: knative://endpoint/camel-event-display?apiVersion=serving.knative.dev%2Fv1&kind=Service" \
      -H "Ce-time: 2020-12-02T13:49:13.77Z" \
      -H "Ce-Id: 536808d3-88be-4077-9d7a-a3f162705f79" \
      -H "Content-Type: application/json" \
      -d '{"msg":"Hello Knative!"}' &
done
```


