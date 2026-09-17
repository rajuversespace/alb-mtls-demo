# Quick Start: ALB mTLS Vulnerability Demo

Demonstrate the mTLS gap where direct ALB access works without client certificate validation.

## Current Setup

Already running:
- **k3d cluster** (test-eks) with nginx pod
- **ngrok tunnel** (fondness-aviation-skeletal.ngrok-free.dev) to localhost:8080
- **cert-manager** in k3d with self-signed certificate

## 1. Verify Infrastructure

```bash
# Check k3d cluster
k3d cluster list

# Check services
kubectl get svc -A | grep test-app

# Check ngrok tunnel
curl -s https://fondness-aviation-skeletal.ngrok-free.dev | head -c 100
```

## 2. Run Vulnerability Test

```bash
cd /Users/pan/Desktop/localstack-alb-eks
chmod +x test-mtls-vulnerability.sh
./test-mtls-vulnerability.sh
```

**Expected output:**
```
TEST 1: Direct ngrok access (vulnerability)
Result: ✅ Works without client certificate (HTTP 200)

TEST 2: Cloudflare-routed access (after fix)
Result: Requires Cloudflare DNS setup

TEST 3: Client certificate validation (desired state)
Result: Currently not enforced (ALB doesn't validate certs)
```

## 3. Configure Cloudflare DNS (Optional)

Update your Cloudflare DNS to route through ngrok:

```
alb.yourdomain.com CNAME https://fondness-aviation-skeletal.ngrok-free.dev
```

Then test:
```bash
curl https://alb.yourdomain.com
# Should route through ngrok to k3d
```

## 4. What the Demo Shows

**Before (Current - Vulnerable):**
- ✅ Direct ALB access works: `curl https://alb-dns` → 200 OK
- ✅ No client cert required
- ❌ Anyone with ALB IP can access backend

**After (Desired - Secure):**
- ❌ Direct ALB access blocked: `curl https://alb-dns` → 403 Forbidden
- ✅ Cloudflare-routed access works with client cert
- ✅ ALB validates client certificate

## 5. Fix: Enable Mutual TLS

Configure ALB listener to require client certificates:

```bash
aws elbv2 modify-listener-attributes \
  --listener-arn <listener-arn> \
  --attributes Key=mutual_authentication_mode,Value=required \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

## Cleanup

```bash
# Stop ngrok
pkill -f ngrok

# Delete k3d cluster
k3d cluster delete test-eks

# Remove generated certs
rm -rf /Users/pan/Desktop/localstack-alb-eks/certs/
```

## Files

- `test-mtls-vulnerability.sh` — Vulnerability demo script
- `BLOG_POST.md` — Full explanation of the gap and fix
- `certs/` — Generated certificates (ALB and Cloudflare origin)
- `setup-443.sh` — Original k3d setup script

## References

- AWS ALB Mutual TLS: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html
- Cloudflare Origin Pull: https://developers.cloudflare.com/ssl-for-saas/security/certificate-authority-bundle/
