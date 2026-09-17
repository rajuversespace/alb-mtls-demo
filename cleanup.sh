#!/bin/bash
# Cleanup LocalStack + k3d + certificates

echo "Cleaning up LocalStack + k3d..."

# Delete k3d cluster
echo "Deleting k3d cluster..."
k3d cluster delete test-eks 2>/dev/null || echo "Cluster not found"

# Stop and remove LocalStack containers
echo "Stopping LocalStack..."
docker-compose down 2>/dev/null || echo "Docker-compose not running"

# Optional: Remove generated certificates
echo ""
read -p "Remove generated certificates? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Removing certs/"
  rm -rf certs/
fi

# Remove kubeconfig
echo "Removing kubeconfig.yaml..."
rm -f kubeconfig.yaml

echo "Cleanup complete"
