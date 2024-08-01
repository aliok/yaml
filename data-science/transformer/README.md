Please refer to [kafka example](https://github.com/kserve/website/blob/main/docs/modelserving/kafka/kafka.md)

USER=aliok
docker build -t $USER/mnist-transformer:latest -f ./transformer.Dockerfile .
docker push $USER/mnist-transformer:latest
