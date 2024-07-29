run:
	npm install
	K_SINK="https://example.com" EVENT_TYPE="com.example.event" SOURCE="event-generator" SEND_INTERVAL="10000" node index.js

build:
	npm install
	docker build . -t aliok/event-generator --platform=linux/amd64

test-image:
	docker run --name=test-event-generator --detach=false --rm --env K_SINK="https://example.com" --env EVENT_TYPE="com.example.event" --env SOURCE="event-generator" --env SEND_INTERVAL="10000" aliok/event-generator:latest

publish:
	npm install
	docker build . -t aliok/event-generator --platform=linux/amd64
	docker push aliok/event-generator
