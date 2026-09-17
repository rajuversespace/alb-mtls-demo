# The mTLS Gap: Why Direct ALB Access Works Without Client Certificates

## Problem

You've configured Cloudflare Origin Pull to protect your backend with mTLS. Your ALB has a valid certificate, and Cloudflare sends a client certificate with every request.

But here's the gap: **if someone finds your ALB's IP address or DNS name, they can reach it directly without any client certificate. Your ALB doesn't validate client certs — it only trusts the originating IP.**

## The Vulnerability

```
Attacker finds ALB DNS
       ↓
Direct HTTPS connection
       ↓
ALB accepts connection (no cert validation)
       ↓
Access to backend (no auth needed)
```

**Comparison:**

| Path | Auth | Client Cert | Status |
|------|------|------------|--------|
| Direct ALB | ❌ | ❌ Not required | **VULNERABLE** |
| Cloudflare → ALB | ✅ | ✅ Validated | ✅ Secure |

## Why This Happens

1. **ALB doesn't validate client certificates by default**
   - ALB's listener termination validates the server cert
   - It does NOT require clients to present a certificate
   - Mutual TLS (mTLS) must be explicitly configured

2. **Cloudflare handles one side**
   - Cloudflare SENDS a client cert to your ALB
   - But if your ALB doesn't CHECK it, the cert is ignored

3. **Missing authentication step**
   - Your ALB should validate: "Is this request from Cloudflare?"
   - Without validation, any HTTPS connection is accepted

## The Fix

### Option 1: ALB with Mutual TLS Listener
Configure ALB listener to require and validate client certificates:
```
aws elbv2 modify-listener-attributes \
  --listener-arn <listener-arn> \
  --attributes Key=mutual_authentication_mode,Value=required
```

### Option 2: API Gateway with Client Cert Validation
- Use API Gateway instead of direct ALB
- API Gateway supports request certificate validation
- Route only authenticated requests to backend

### Option 3: Custom Auth Handler
- Keep ALB simple
- Add auth layer at application level
- Validate Cloudflare's origin token header

## Test It Yourself

```bash
# Direct ALB access (vulnerable)
curl https://alb.example.com
# Status: 200 OK (no auth required)

# With Cloudflare auth (secure)
curl https://cdn.example.com
# Status: 200 OK (Cloudflare auth validated)

# Direct ALB with wrong cert (should fail)
curl --cert wrong-cert.pem https://alb.example.com
# With proper mTLS: Status: 403 Forbidden
# Without mTLS: Status: 200 OK (vulnerability!)
```

## Real-World Impact

- **Kubernetes service exposure**: ALB replicas accessible directly
- **Database bypass**: Backend database accessible without auth
- **IP enumeration**: Attackers can find ALB by scanning IP ranges
- **Compliance gap**: Fails SOC 2 / ISO 27001 requirements

## Prevention Checklist

- [ ] Configure ALB listener with `mutual_authentication_mode=required`
- [ ] Upload Cloudflare's origin certificate to ALB
- [ ] Test: `curl <direct-alb-dns>` should fail
- [ ] Test: `curl <cloudflare-dns>` should succeed
- [ ] Document in runbook: ALB is NOT accessible directly
- [ ] Monitor ALB access logs for direct connections

## Summary

The mTLS gap is silent because:
1. Your ALB certificate is valid
2. Cloudflare sends a client cert
3. But the ALB doesn't CHECK the cert
4. So direct access works

**Fix: Configure ALB to validate client certificates from Cloudflare.**
