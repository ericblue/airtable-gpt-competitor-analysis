# Docker image settings
IMAGE_NAME := airtable-gpt-competitor-analysis
REGISTRY := ericblue
TAG ?= "latest"

all: install

cpanfile:
	perl generate_cpanfile.pl > cpanfile

install: cpanfile
	cpanm --installdeps .

cleanJson:
	find ./json -name "*.json" -type f -delete

runWeb:
	perl app.pl daemon

# Build the Docker image
buildDocker:
	@docker build -t $(IMAGE_NAME):$(TAG) .

# Stop the running Docker container
stopDocker:
	-docker stop $(IMAGE_NAME)

# Remove the Docker container
removeDocker:
	@docker rm $(IMAGE_NAME)

# Run the local Docker image
runDocker: stopDocker removeDocker
ifeq ($(MODE),detached)
	@docker run -d --env-file .env -p 8080:80 --name $(IMAGE_NAME) $(IMAGE_NAME):$(TAG)
else
	@docker run -it --env-file .env -p 8080:80 --name $(IMAGE_NAME) $(IMAGE_NAME):$(TAG)
endif

# Attach to the running Docker container
attachDocker:
	@docker exec -it $(shell docker ps -qf "name=$(IMAGE_NAME)") bash

# View the Docker container logs
logsDocker:
	@docker logs -f $(IMAGE_NAME)

# Push the Docker image
pushDocker:
	@docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)
	@docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

# Display usage information
help:
	@echo "Makefile for generating releases and building/pushing Docker images"
	@echo ""
	@echo "Usage:"
	@echo "  make buildDocker [TAG=tag] - Build Docker image with optional tag (default: 'latest')"
	@echo "  make runDocker [TAG=tag] - Run Docker image with optional tag (default: 'latest')"
	@echo "  make attachDocker - Attach to the running Docker container"
	@echo "  make pushDocker [TAG=tag] - Push Docker image to registry with optional tag (default: 'latest')"
	@echo "  make help - Display this message"
	@echo ""
	@echo "Example:"
	@echo "  make buildDocker TAG=0.1"
	@echo "  make runDocker TAG=0.1"
	@echo "  make attachDocker"
	@echo "  make pushDocker TAG=0.1"

# Define default goal
.DEFAULT_GOAL := help

.PHONY: all install