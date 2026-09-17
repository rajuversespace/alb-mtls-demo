# ALB mTLS Vulnerability Demo

Demonstrate the **mTLS gap**: why direct ALB access works without client certificate validation, and how to fix it.

## The Problem

You've configured Cloudflare Origin Pull with mTLS to protect your backend. But here's the gap:

```
Direct ALB Access (Vulnerable)
  curl https://alb.example.com
  → 200 OK ✅ (no client cert required)

Cloudflare-Routed Access (Secure)
  curl https://cdn.example.com → ALB
  → 200 OK ✅ (cert validated)
```

**The vulnerability:** Anyone finding your ALB IP/DNS can bypass Cloudflare entirely.

## Architecture

### BEFORE (Vulnerable)

```
Internet
   ↓
Direct ALB Access
   ↓
No Client Cert Check ❌
   ↓
Backend Accessible (no auth)
```

### AFTER (Secure)

```
Internet
   ├─→ Direct ALB Access
   │      ↓
   │   Requires Client Cert ✅
   │      ↓
   │   Connection Refused (403)
   │
   └─→ Cloudflare Route
          ↓
       Origin Pull Cert
          ↓
       ALB Validates ✅
          ↓
       Backend Access (authenticated)
```

## Infrastructure Stack

```
┌─────────────────────────────────────────────┐
│              Internet (ngrok)               │
│     fondness-aviation-skeletal.ngrok.io     │
└─────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────┐
│          Cloudflare DNS + TLS Auth          │
│      - TLS Client Auth Enabled              │
│      - Origin Certificate Configured        │
└─────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────┐
│     ALB (Floci) Port 443 HTTPS              │
│  - Client Cert Validation Required ✅       │
│  - mutual_authentication_mode=required       │
└─────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────┐
│     k3d Kubernetes Cluster                  │
│  - Traefik Ingress (port 8443)              │
│  - nginx Service (LoadBalancer)             │
│  - cert-manager (self-signed certs)         │
└─────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────┐
│     nginx Pod                               │
│  Serves: Welcome to nginx!                  │
└─────────────────────────────────────────────┘
```

## What This Demo Proves

### Vulnerability (BEFORE)
```bash
$ curl https://alb.example.com
Welcome to nginx!
HTTP 200 OK
```
❌ **No authentication required**

### Fix Applied (AFTER)
```bash
$ curl https://alb.example.com
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL

$ curl --cert cf-origin-cert.pem --key cf-origin-key.pem https://alb.example.com
Welcome to nginx!
HTTP 200 OK
```
✅ **Client certificate required for access**

## Quick Start

### 1. Prerequisites
- Docker Desktop (for k3d and Floci)
- kubectl
- AWS CLI (for Floci)
- ngrok (authenticated account)
- Cloudflare account

### 2. Setup
```bash
cd /Users/pan/Desktop/localstack-alb-eks

# Start k3d cluster + cert-manager
./setup-443.sh

# Start ngrok tunnel
ngrok http localhost:8080

# Enable Cloudflare TLS auth (manual or API)
# See QUICKSTART.md
```

### 3. Run Vulnerability Test
```bash
./test-mtls-vulnerability.sh
```

Expected output:
- BEFORE: Direct access works (200 OK)
- AFTER: Direct access blocked (SSL_ERROR_SYSCALL)
- With cert: Access granted (200 OK)

## Key Findings

### The Gap
1. **ALB doesn't validate client certs by default**
   - Server cert validation: ✅ Yes
   - Client cert validation: ❌ No

2. **Cloudflare sends certs, but ALB ignores them**
   - Cloudflare Origin Pull: ✅ Configured
   - ALB validation: ❌ Not enforced

3. **Direct ALB access bypasses Cloudflare**
   - If someone finds ALB IP → Direct access works
   - Cloudflare protection is useless

### The Risk
- Unauthenticated backend access
- Compliance gap (SOC 2, ISO 27001)
- Data breach via IP discovery
- DDoS on unprotected origin

### The Fix
```bash
# Enable mutual TLS on ALB listener
aws elbv2 modify-listener-attributes \
  --listener-arn <arn> \
  --attributes Key=mutual_authentication_mode,Value=required
```

**Result:**
- ✅ Direct ALB access blocked
- ✅ Only Cloudflare Origin Pull works
- ✅ Backend protected by authentication

## Files

- **BLOG_POST.md** — Full technical explanation
- **QUICKSTART.md** — Setup and reproduction guide
- **test-mtls-vulnerability.sh** — Main vulnerability demo
- **test-cloudflare-aop.sh** — Cloudflare AOP test
- **setup-443.sh** — Infrastructure setup (k3d + certs)
- **cleanup.sh** — Destroy infrastructure
- **certs/** — Public certificates (server + origin)

## Testing

### Run Full Demo
```bash
./test-mtls-vulnerability.sh
```

### Test Cloudflare AOP
```bash
./test-cloudflare-aop.sh
```

### Manual Test
```bash
# Direct access (should fail after fix)
curl -v https://test-alb-4c2eec6961804c60.elb.localhost.floci.io

# With client cert (should succeed)
curl --cert certs/cf-origin-cert.pem \
     --key certs/cf-origin-key.pem \
     https://test-alb-4c2eec6961804c60.elb.localhost.floci.io
```

## Security

### What's NOT in This Repo
- Private keys (.env.local in .gitignore)
- Cloudflare API tokens
- Vault tokens
- kubeconfig files

### What IS in This Repo
- Public server certificates
- Public origin certificates
- Infrastructure code
- Test and demo scripts
- Documentation

### Generate Secrets Locally
```bash
# Create .env.local (git-ignored)
export CF_TOKEN="your-token"
export VAULT_TOKEN="your-token"
source ~/.env.local
```

## References

- **AWS ALB Mutual TLS** — https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-attributes.html
- **Cloudflare Origin Pull** — https://developers.cloudflare.com/ssl-for-saas/security/certificate-authority-bundle/
- **cert-manager** — https://cert-manager.io/docs/
- **k3d** — https://k3d.io/

## Blog Post

Full technical explanation: [The mTLS Gap: Why Direct ALB Access Works Without Client Certificates](https://claude.ai/code/artifact/a8498cad-bef6-4623-aefe-68457f07d38c)

## License

MIT
