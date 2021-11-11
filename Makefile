build:
	docker buildx build -t data61/elasticsearch:6.5.4 --platform=linux/amd64,linux/arm64 --push .