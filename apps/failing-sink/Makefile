run:
	npm install
	LATENCY="100" node index.js

build:
	npm install
	docker build . -t aliok/failing-sink --platform=linux/amd64

test-image:
	docker run --name=test-failing-sink --detach=false --rm -p 8080:8080 --env LATENCY="100" aliok/failing-sink:latest

publish:
	npm install
	docker build . -t aliok/failing-sink
	docker push aliok/failing-sink
