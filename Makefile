.PHONY: help local-cluster-create local-cluster-delete helm-install helm-uninstall port-forward logs clean

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
BLUE=\033[0;34m
NC=\033[0m

# Variables
CLUSTER_NAME=local
NAMESPACE=fibonacci
IMAGE_REPO=ghcr.io/ami-fl2/fibs
IMAGE_TAG=1.0.0
FULL_IMAGE=$(IMAGE_REPO):$(IMAGE_TAG)
CHART_PATH=./chart
SERVICE_PORT=8000

help: ## Show help message
	@echo "$(BLUE)=== Fibonacci Local Cluster Makefile ===$(NC)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  make local-cluster-create  # Create KinD cluster named 'local'"
	@echo "  make helm-install          # Deploy Fibonacci with Helm"
	@echo "  make port-forward          # Start port-forward"
	@echo "  make logs                  # Show pod logs"
	@echo "  make local-cluster-delete  # Delete cluster"
	@echo ""
	@echo "$(GREEN)Test in another terminal:$(NC)"
	@echo "  curl http://localhost:8000?n=10"
	@echo "  curl http://localhost:8000/healthz"
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

helm-install: ## Install Fibonacci with Helm
	@echo "$(BLUE)Installing Fibonacci with dev values...$(NC)"
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install fibonacci $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		-f $(CHART_PATH)/value-files/values-dev.yaml
	@echo "$(GREEN)✓ Helm installed$(NC)"
	@echo "$(BLUE)Waiting for pods...$(NC)"
	kubectl rollout status deployment/fibonacci -n $(NAMESPACE) --timeout=5m
	@echo "$(GREEN)✓ Deployment ready$(NC)"

helm-uninstall: ## Uninstall Fibonacci
	@echo "$(BLUE)Uninstalling...$(NC)"
	helm uninstall fibonacci --namespace $(NAMESPACE) || true
	kubectl delete namespace $(NAMESPACE) || true
	@echo "$(GREEN)✓ Uninstalled$(NC)"

port-forward: ## Start port-forward (background)
	@kubectl port-forward -n $(NAMESPACE) svc/fibonacci $(SERVICE_PORT):$(SERVICE_PORT) > /dev/null 2>&1 &
	@sleep 2
	@echo "$(GREEN)✓ Port-forward started on http://localhost:$(SERVICE_PORT)$(NC)"

logs: ## Show pod logs
	@kubectl logs -f deployment/fibonacci -n $(NAMESPACE)

clean: helm-uninstall local-cluster-delete ## Cleanup everything

.DEFAULT_GOAL := help
