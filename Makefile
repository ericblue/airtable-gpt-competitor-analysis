# Docker image settings
IMAGE_NAME := airtable-gpt-competitor-analysis
REGISTRY := ericblue
TAG ?= "latest"

all: install

# Usage: make release VERSION=v0.1
#
# This will create an updated Version.pm file, git tag and push it to the remote repository
#
release:
	test -n "$(VERSION)" || (echo "VERSION is required" && exit 1)
	@echo "Updating Version.pm to $(VERSION)"
	@if git status --porcelain | grep -v "lib/AirtableGPT/Version.pm"; then \
		echo "There are uncommitted changes in files other than lib/AirtableGPT/Version.pm. Please commit and push these changes before releasing."; \
		exit 1; \
	fi
	perl update_version.pl --version $(VERSION)
	@if git status --porcelain | grep -q "lib/AirtableGPT/Version.pm"; then \
		echo "Committing version changes before releasing."; \
		git add lib/AirtableGPT/Version.pm; \
		git commit -m "Update version to $(VERSION)"; \
		git tag -f -a $(VERSION) -m "Release $(VERSION)"; \
		git push origin $(VERSION); \
	else \
		echo "lib/AirtableGPT/Version.pm has not been modified."; \
	fi

# Rollback a specific release
rollbackRelease:
	@test -n "$(VERSION)" || (echo "VERSION is required" && exit 1)
	@echo "Rolling back release $(VERSION)"
	@if git tag | grep -q $(VERSION); then \
		git tag -d $(VERSION); \
		git push origin $(VERSION); \
	fi
	@git push origin :$(VERSION)
	@if git ls-remote --tags origin | grep -q $(VERSION); then \
		echo "Failed to delete tag $(VERSION) from the remote repository."; \
		exit 1; \
	else \
		echo "Successfully deleted tag $(VERSION) from the remote repository."; \
	fi

getVersion:
	@perl -Mlib=lib -MAirtableGPT::Version -e 'print "$$AirtableGPT::Version::VERSION\n"'

updateVersion:
	@test -n "$(VERSION)" || (echo "VERSION is required" && exit 1)
	@echo "Updating Version.pm to $(VERSION)"
	perl update_version.pl --version $(VERSION)

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

# Clean the React build
cleanReactApp:
	rm -rf resources/public/static
	rm -rf resources/public/app

# Clean the React build
cleanReactBuild:
	rm -rf react-app/build
	rm -rf react-app/node_modules
	rm -rf react-app/package-lock.json

# Build the React application
buildReactApp:
	mkdir -p resources/public/app
	cd react-app && npm install && npm run build && cd -

# Run the React application in dev mode
# Runs 'npm start' from react-app on another port instead of through the Mojolicious app
# Proxy is configured to support a passthrough on port 3000
runReactDev:
	cd react-app && npm start && cd -

# Display usage information
help:
	@echo "Makefile for generating releases and building/pushing Docker images"
	@echo ""
	@echo "Repo Admin Tasks:"
	@echo "make release VERSION=v0.1 - Create an updated Version.pm file, git tag and push it to the remote repository"
	@echo "make rollbackRelease VERSION=v0.1 - Rollback a specific release"
	@echo "make getVersion - Get the current version"
	@echo "make updateVersion VERSION=v0.1 - Update the version"
	@echo "make pushDocker [TAG=tag] - Push Docker image to registry with optional tag (default: 'latest')"
	@echo ""
	@echo "Developer/User Tasks:"
	@echo "make cpanfile - Generate a cpanfile"
	@echo "make install - Install the dependencies listed in the cpanfile"
	@echo "make cleanJson - Clean the json directory"
	@echo "make runWeb - Run the web application"
	@echo "make buildDocker [TAG=tag] - Build Docker image with optional tag (default: 'latest')"
	@echo "make stopDocker - Stop the running Docker container"
	@echo "make removeDocker - Remove the Docker container"
	@echo "make runDocker [TAG=tag] - Run Docker image with optional tag (default: 'latest')"
	@echo "make attachDocker - Attach to the running Docker container"
	@echo "make logsDocker - View the Docker container logs"
	@echo "make cleanReactApp - Remove the static and app directories under resources/public"
	@echo "make cleanReactBuild - Remove the build directory, node_modules, and package-lock.json from react-app"
	@echo "make buildReactApp - Build the React application"
	@echo "make runReactDev - Run the React application in dev mode"
	@echo "make help - Display this message"
	@echo ""
	@echo "Example:"
	@echo "make buildDocker TAG=0.1"
	@echo "make runDocker TAG=0.1"
	@echo "make attachDocker"
	@echo "make pushDocker TAG=0.1"
	@echo "make cleanReactApp"
	@echo "make cleanReactBuild"
	@echo "make buildReactApp"
	@echo "make runReactDev"

# Define default goal
.DEFAULT_GOAL := help

.PHONY: all install