# Minecraft Kubernetes Container Image Build
.PHONY: help build-multi-arch build clean helm-package helm-update-versions

# Automatically detect container engine (docker or podman)
CONTAINER_ENGINE := $(shell which docker 2>/dev/null || which podman 2>/dev/null || echo "")
ifeq ($(CONTAINER_ENGINE),)
    $(error Neither docker nor podman found in PATH)
endif

# Extract just the binary name for display
ENGINE_NAME := $(notdir $(CONTAINER_ENGINE))

# Version configuration
MINECRAFT_VERSION ?= 1.21.6
FABRIC_VERSION ?= 0.16.14
FABRIC_INSTALLER_VERSION ?= 1.0.3

# Default image name and tag
IMAGE_NAME ?= ghcr.io/biftin/minecraft-kube
IMAGE_TAG ?= $(MINECRAFT_VERSION)-fabric-$(FABRIC_VERSION)
IMAGE_TAG_LATEST ?= latest

# Architecture mappings
ARCH_x86_64 = linux/amd64
ARCH_aarch64 = linux/arm64

help: ## Show this help message
	@echo "Using container engine: $(ENGINE_NAME) ($(CONTAINER_ENGINE))"
	@echo ""
	@echo "Version Configuration:"
	@echo "  Minecraft: $(MINECRAFT_VERSION)"
	@echo "  Fabric: $(FABRIC_VERSION)"
	@echo "  Fabric Installer: $(FABRIC_INSTALLER_VERSION)"
	@echo "  Image Tag: $(IMAGE_TAG)"
	@echo ""
	@echo "Available targets:"
	@echo "  build-multi-arch     Build multi-architecture container image"
	@echo "  build                Build container image for current architecture"
	@echo "  clean                Remove local container images"
	@echo "  helm-package         Package the Helm chart"
	@echo "  helm-update-versions Update Helm chart versions to match build versions"
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME               Container image name (default: $(IMAGE_NAME))"
	@echo "  IMAGE_TAG                Container image tag (default: $(IMAGE_TAG))"
	@echo "  MINECRAFT_VERSION        Minecraft version (default: $(MINECRAFT_VERSION))"
	@echo "  FABRIC_VERSION           Fabric version (default: $(FABRIC_VERSION))"
	@echo "  FABRIC_INSTALLER_VERSION Fabric installer version (default: $(FABRIC_INSTALLER_VERSION))"
	@echo ""
	@echo "Examples:"
	@echo "  make build MINECRAFT_VERSION=1.21.4 FABRIC_VERSION=0.16.10"
	@echo "  make build-multi-arch IMAGE_TAG=1.21.6-fabric-0.16.14"

build-multi-arch: ## Build multi-architecture container image
	@echo "Building multi-architecture container image using $(ENGINE_NAME)..."
	@echo "Minecraft: $(MINECRAFT_VERSION), Fabric: $(FABRIC_VERSION), Tag: $(IMAGE_TAG)"
ifeq ($(ENGINE_NAME),docker)
	$(CONTAINER_ENGINE) buildx build \
		--platform $(ARCH_x86_64),$(ARCH_aarch64) \
		--build-arg MINECRAFT_VERSION=$(MINECRAFT_VERSION) \
		--build-arg FABRIC_VERSION=$(FABRIC_VERSION) \
		--build-arg FABRIC_INSTALLER_VERSION=$(FABRIC_INSTALLER_VERSION) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):$(IMAGE_TAG_LATEST) \
		--push .
else
	$(CONTAINER_ENGINE) build \
		--platform $(ARCH_x86_64),$(ARCH_aarch64) \
		--build-arg MINECRAFT_VERSION=$(MINECRAFT_VERSION) \
		--build-arg FABRIC_VERSION=$(FABRIC_VERSION) \
		--build-arg FABRIC_INSTALLER_VERSION=$(FABRIC_INSTALLER_VERSION) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):$(IMAGE_TAG_LATEST) \
		--manifest $(IMAGE_NAME):$(IMAGE_TAG) .
	$(CONTAINER_ENGINE) manifest push $(IMAGE_NAME):$(IMAGE_TAG)
	$(CONTAINER_ENGINE) manifest push $(IMAGE_NAME):$(IMAGE_TAG_LATEST)
endif

build: ## Build container image for current architecture
	@echo "Building container image for current architecture using $(ENGINE_NAME)..."
	@echo "Minecraft: $(MINECRAFT_VERSION), Fabric: $(FABRIC_VERSION), Tag: $(IMAGE_TAG)"
	$(CONTAINER_ENGINE) build \
		--build-arg MINECRAFT_VERSION=$(MINECRAFT_VERSION) \
		--build-arg FABRIC_VERSION=$(FABRIC_VERSION) \
		--build-arg FABRIC_INSTALLER_VERSION=$(FABRIC_INSTALLER_VERSION) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):$(IMAGE_TAG_LATEST) .

clean: ## Remove local container images
	@echo "Removing local container images using $(ENGINE_NAME)..."
	-$(CONTAINER_ENGINE) rmi $(IMAGE_NAME):$(IMAGE_TAG)
	-$(CONTAINER_ENGINE) rmi $(IMAGE_NAME):$(IMAGE_TAG_LATEST)

helm-update-versions: ## Update Helm chart versions to match build versions
	@echo "Updating Helm chart versions..."
	@echo "Setting appVersion to: $(MINECRAFT_VERSION)-fabric-$(FABRIC_VERSION)"
	@sed -i.bak 's/^appVersion: .*/appVersion: "$(MINECRAFT_VERSION)-fabric-$(FABRIC_VERSION)"/' chart/Chart.yaml
	@rm -f chart/Chart.yaml.bak
	@echo "Helm chart appVersion updated successfully"

helm-package: helm-update-versions ## Package the Helm chart
	@echo "Packaging Helm chart..."
	@helm package chart/
	@echo "Helm chart packaged successfully"