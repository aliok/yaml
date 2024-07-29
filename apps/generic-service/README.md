Test:
```shell
make run
#or
make test-image
# or
kubectl port-forward -n default svc/payment-processor 8080:8080

curl -i 'http://localhost:8080/'                      \
  -H 'ce-time: 2023-09-26T12:35:14.372688+00:00'      \
  -H 'ce-type: com.mycompany.paymentreceived'           \
  -H 'ce-source: test'   \
  -H 'ce-id: a9254f41-4d32-45d2-8293-e90d96876de1'    \
  -H 'ce-specversion: 1.0'                            \
  -H 'accept: */*'                                    \
  -H 'accept-encoding: gzip, deflate'                 \
  -H 'content-type: '                                 \
  -d $'{"foo": "bar"}'
```
