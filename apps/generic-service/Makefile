run:
	npm install
	REPLY_TYPE="reply-event" REPLY_PERCENTAGE="20" SOURCE="event-generator" node index.js

build:
	npm install
	docker build . -t aliok/generic-service --platform=linux/amd64

test-image:
	docker run --name=test-generic-service --detach=false --rm -p 8080:8080 --env REPLY_TYPE="reply-event" --env REPLY_PERCENTAGE="20" --env SOURCE="event-generator" aliok/generic-service:latest

publish:
	npm install
	docker build . -t aliok/generic-service --platform=linux/amd64
	docker push aliok/generic-service
