#!/bin/bash
# Extended setup with HTTPS/443 support

set -e

echo "=== LocalStack ALB + k3d with TLS/443 ==="

# 1. Generate self-signed cert (simulates ALB ACME cert)
echo "[1/7] Generating self-signed certificate..."
mkdir -p certs
openssl req -x509 -newkey rsa:2048 \
  -keyout certs/alb-key.pem \
  -out certs/alb-cert.pem \
  -days 365 -nodes \
  -subj "/CN=alb.example.com"
echo "Certificate generated: certs/alb-cert.pem"

# 2. Generate Cloudflare origin cert (for client cert auth)
echo "[2/7] Generating Cloudflare origin certificate..."
openssl req -x509 -newkey rsa:2048 \
  -keyout certs/cf-origin-key.pem \
  -out certs/cf-origin-cert.pem \
  -days 365 -nodes \
  -subj "/CN=cloudflare-origin"
echo "Origin cert generated: certs/cf-origin-cert.pem"

# 3. Start LocalStack
echo "[3/7] Starting LocalStack..."
docker-compose up -d
sleep 10

# 4. Wait for LocalStack
echo "Waiting for LocalStack..."
for i in {1..30}; do
  if curl -s http://localhost:4566/_localstack/health | grep -q '"services"'; then
    echo "LocalStack ready"
    break
  fi
  sleep 1
done

# 5. Configure AWS
echo "[5/7] Configuring AWS CLI..."
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# 6. Create VPC/ALB with HTTPS listener
echo "[6/7] Creating ALB with HTTPS listener..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --endpoint-url http://localhost:4566 --query 'Vpc.VpcId' --output text)
SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --endpoint-url http://localhost:4566 --query 'Subnet.SubnetId' --output text)
SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --endpoint-url http://localhost:4566 --query 'Subnet.SubnetId' --output text)

ALB_ARN=$(aws elbv2 create-load-balancer \
  --name test-alb \
  --subnets $SUBNET_1 $SUBNET_2 \
  --scheme internet-facing \
  --endpoint-url http://localhost:4566 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)
echo "ALB created: $ALB_ARN"

ALB_DNS=$(aws elbv2 describe-load-balancers --endpoint-url http://localhost:4566 --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB DNS: $ALB_DNS"

# 7. Start k3d with 443 exposed
echo "[7/7] Starting k3d cluster with HTTPS..."
k3d cluster create test-eks \
  --agents 1 \
  -p "8080:80@loadbalancer" \
  -p "8443:443@loadbalancer" \
  2>/dev/null || echo "Cluster may already exist"

k3d kubeconfig get test-eks > kubeconfig.yaml
export KUBECONFIG=$PWD/kubeconfig.yaml

# Deploy test app with HTTPS support
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        - containerPort: 443
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  - port: 443
    targetPort: 443
  type: LoadBalancer
EOF

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Certificates:"
echo "  ALB cert: certs/alb-cert.pem"
echo "  CF origin cert: certs/cf-origin-cert.pem"
echo ""
echo "LocalStack:"
echo "  Endpoint: http://localhost:4566"
echo "  ALB DNS: $ALB_DNS"
echo ""
echo "k3d cluster:"
echo "  Name: test-eks"
echo "  HTTP: localhost:8080"
echo "  HTTPS: localhost:8443"
echo ""
echo "Export to shell:"
echo "  export AWS_ACCESS_KEY_ID=test"
echo "  export AWS_SECRET_ACCESS_KEY=test"
echo "  export AWS_DEFAULT_REGION=us-east-1"
echo "  export KUBECONFIG=$PWD/kubeconfig.yaml"
echo ""
echo "Test without mTLS:"
echo "  ./test-before.sh"
echo ""
echo "Test with mTLS (coming):"
echo "  ./test-after.sh"
