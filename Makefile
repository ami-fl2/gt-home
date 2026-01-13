.PHONY: help local-cluster-create local-cluster-delete local-cluster-load helm-install helm-uninstall test-endpoint health-check local-test clean

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
BLUE=\033[0;34m
NC=\033[0m

# Variables
CLUSTER_NAME=local
NAMESPACE=fibonacci
IMAGE_REPO=ghcr.io/ami-fl2/fibs
IMAGE_TAG=1.0.2
FULL_IMAGE=$(IMAGE_REPO):$(IMAGE_TAG)
CHART_PATH=./chart
SERVICE_PORT=8000

help: ## Show help message
	@echo "$(BLUE)=== Fibonacci Local Cluster Makefile ===$(NC)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  make local-cluster-create  # Create KinD cluster named 'local'"
	@echo "  make helm-install          # Deploy Fibonacci with Helm"
	@echo "  make test-endpoint         # Test the service"
	@echo "  make local-cluster-delete  # Delete cluster"
	@echo ""
	@echo "$(GREEN)All targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*## ' Makefile | awk 'BEGIN {FS = ":.*## "}; {printf "  $(BLUE)%-25s$(NC) %s\n", $$1, $$2}'

local-cluster-create: ## Create KinD cluster named 'local'
	@echo "$(BLUE)Creating KinD cluster '$(CLUSTER_NAME)'...$(NC)"
	kind create cluster --name $(CLUSTER_NAME) --image kindest/node:v1.34.0
	@echo "$(GREEN)✓ Cluster created$(NC)"

local-cluster-delete: ## Delete KinD cluster
	@echo "$(BLUE)Deleting cluster '$(CLUSTER_NAME)'...$(NC)"
	kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "$(GREEN)✓ Cluster deleted$(NC)"

local-cluster-load: ## Load image into cluster
	@echo "$(BLUE)Loading $(FULL_IMAGE)...$(NC)"
	@if ! kind load docker-image $(FULL_IMAGE) --name $(CLUSTER_NAME) 2>/dev/null; then \
		docker pull $(FULL_IMAGE) && kind load docker-image $(FULL_IMAGE) --name $(CLUSTER_NAME); \
	fi
	@echo "$(GREEN)✓ Image loaded$(NC)"

helm-install: local-cluster-load ## Install Fibonacci with Helm
	@echo "$(BLUE)Installing Fibonacci...$(NC)"
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm install fibonacci $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--set image.repository=$(IMAGE_REPO) \
		--set image.tag=$(IMAGE_TAG) \
		--set replicaCount=2 \
		--set autoscaling.enabled=false \
		--set pdb.enabled=false
	@echo "$(GREEN)✓ Helm installed$(NC)"
	@echo "$(BLUE)Waiting for pods...$(NC)"
	kubectl rollout status deployment/fibonacci -n $(NAMESPACE) --timeout=5m
	@echo "$(GREEN)✓ Deployment ready$(NC)"

helm-uninstall: ## Uninstall Fibonacci
	@echo "$(BLUE)Uninstalling...$(NC)"
	helm uninstall fibonacci --namespace $(NAMESPACE) || true
	kubectl delete namespace $(NAMESPACE) || true
	@echo "$(GREEN)✓ Uninstalled$(NC)"

test-endpoint: ## Test Fibonacci endpoint
	@echo ""
	@echo "$(BLUE)=== Testing Fibonacci ===$(NC)"
	@echo "$(BLUE)n=10:$(NC)" && curl -s "http://localhost:$(SERVICE_PORT)?n=10" && echo ""
	@echo "$(BLUE)n=5:$(NC)" && curl -s "http://localhost:$(SERVICE_PORT)?n=5" && echo ""

health-check: ## Test health endpoint
	@echo "$(BLUE)Health Check:$(NC)"
	@curl -s "http://localhost:$(SERVICE_PORT)/healthz" && echo ""

port-forward: ## Start port-forward (background)
	@kubectl port-forward -n $(NAMESPACE) svc/fibonacci $(SERVICE_PORT):$(SERVICE_PORT) > /dev/null 2>&1 &
	@sleep 2
	@echo "$(GREEN)✓ Port-forward started$(NC)"

local-test: helm-install port-forward test-endpoint health-check ## Full local test
	@echo ""
	@echo "$(GREEN)✅ Local test complete!$(NC)"
	@echo "$(BLUE)Service:$(NC) http://localhost:$(SERVICE_PORT)?n=10"
	@echo "$(BLUE)Health:$(NC) http://localhost:$(SERVICE_PORT)/healthz"

logs: ## Show pod logs
	@kubectl logs -f deployment/fibonacci -n $(NAMESPACE)

clean: helm-uninstall local-cluster-delete ## Cleanup everything

.DEFAULT_GOAL := help

