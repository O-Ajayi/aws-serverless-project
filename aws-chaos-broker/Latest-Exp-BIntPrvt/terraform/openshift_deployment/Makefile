.PHONY: help build deploy deploy-kubectl deploy-terraform clean test images

# Variables
REGISTRY ?= localhost:5000
IMAGE_TAG ?= latest
NAMESPACE ?= chaos-broker

help:
	@echo "Chaos Broker OpenShift Deployment"
	@echo ""
	@echo "Available targets:"
	@echo "  make build              - Build container images"
	@echo "  make deploy             - Deploy using kubectl/oc (default)"
	@echo "  make deploy-terraform   - Deploy using Terraform"
	@echo "  make clean              - Remove deployed resources"
	@echo "  make test               - Test handler service"
	@echo "  make images             - List built images"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY=${REGISTRY}"
	@echo "  IMAGE_TAG=${IMAGE_TAG}"
	@echo "  NAMESPACE=${NAMESPACE}"

build:
	@echo "Building container images..."
	REGISTRY=$(REGISTRY) IMAGE_TAG=$(IMAGE_TAG) ./scripts/build-images.sh

deploy: deploy-kubectl

deploy-kubectl:
	@echo "Deploying using kubectl/oc..."
	./scripts/deploy.sh

deploy-terraform:
	@echo "Deploying using Terraform..."
	cd terraform && terraform init && terraform apply

clean:
	@echo "Cleaning up resources..."
	oc delete namespace $(NAMESPACE) || kubectl delete namespace $(NAMESPACE)

test:
	@echo "Testing handler service..."
	@oc port-forward -n $(NAMESPACE) svc/chaos-broker-handler 8080:8080 & \
	sleep 2 && \
	curl -s http://localhost:8080/health | jq . || echo "Service not ready" && \
	pkill -f "port-forward.*chaos-broker-handler"

images:
	@echo "Built images:"
	@docker images | grep chaos-broker || echo "No chaos-broker images found"

