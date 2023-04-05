# Place your commands here
#!/bin/bash

# Create a Kind cluster
echo "Creating a Kind cluster..."
kind create cluster --name kind-1 --config ./k8s/kind/cluster-config.yaml

# Function to check if the cluster nodes are ready
is_cluster_ready() {
  kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep "True"
}

# Wait for the cluster to be ready
echo "Waiting for the cluster nodes to be ready..."
until is_cluster_ready; do
  echo "Cluster nodes not ready, sleeping for 10 seconds..."
  sleep 10
done
echo "Cluster nodes are ready."

# Load the Docker image into the Kind cluster
echo "Loading the Docker image into the Kind cluster..."
kind load docker-image aaron/node-app:latest --name kind-1

# Deploy the Ingress Nginx controller
echo "Deploying the Ingress Nginx controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for the Ingress Nginx controller to be ready
echo "Waiting for the Ingress Nginx controller to be ready..."
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# Function to check if the webhook is ready
is_webhook_ready() {
  kubectl -n ingress-nginx get deploy ingress-nginx-controller -o jsonpath='{.status.readyReplicas}' | grep 1
}

# Wait for the webhook to be ready
echo "Waiting for the Ingress-NGINX webhook to be ready..."
until is_webhook_ready; do
  echo "Webhook not ready, sleeping for 10 seconds..."
  sleep 10
done
echo "Ingress-NGINX webhook is ready."

# Apply the deployment, service, and ingress manifests
echo "Applying the deployment, service, and ingress manifests..."
kubectl apply -f ./k8s/manifests/k8s/backend-deployment.yaml
kubectl apply -f ./k8s/manifests/k8s/backend-service.yaml
kubectl apply -f ./k8s/manifests/k8s/backend-ingress.yaml

# Wait for the backend pods to be running
echo "Waiting for the backend pods to be running..."
kubectl wait --for=condition=ready pod -l app=backend --timeout=120s

echo "Deployment complete. Access the app via the Ingress."
