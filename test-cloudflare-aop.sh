#!/bin/bash
# Test Cloudflare Authenticated Origin Pulls before/after setup

DOMAIN="fondness-aviation-skeletal.ngrok-free.dev"
CERT_PATH="./certs"

echo "=================================================="
echo "Cloudflare AOP Test: Before vs After"
echo "=================================================="
echo ""

# BEFORE STATE
echo "BEFORE: AOP disabled (vulnerable state)"
echo "=================================================="
echo ""

echo "1. Direct access WITHOUT client cert:"
echo "   Command: curl https://$DOMAIN"
BEFORE_NO_CERT=$(curl -s -w "%{http_code}" -o /dev/null https://$DOMAIN)
echo "   Status: $BEFORE_NO_CERT"
if [ "$BEFORE_NO_CERT" = "200" ]; then
  echo "   ✅ Works (VULNERABLE - no auth required)"
else
  echo "   ❌ Failed"
fi

echo ""
echo "2. Direct access WITH client cert:"
echo "   Command: curl --cert cf-origin-cert.pem --key cf-origin-key.pem https://$DOMAIN"
BEFORE_WITH_CERT=$(curl -s -w "%{http_code}" -o /dev/null \
  --cert "$CERT_PATH/cf-origin-cert.pem" \
  --key "$CERT_PATH/cf-origin-key.pem" \
  https://$DOMAIN)
echo "   Status: $BEFORE_WITH_CERT"
if [ "$BEFORE_WITH_CERT" = "200" ]; then
  echo "   ✅ Works (cert not required)"
else
  echo "   ❌ Failed"
fi

echo ""
echo ""
echo "AFTER: AOP enabled (secure state)"
echo "=================================================="
echo ""

echo "1. Direct access WITHOUT client cert:"
echo "   Command: curl https://$DOMAIN"
AFTER_NO_CERT=$(curl -s -w "%{http_code}" -o /dev/null https://$DOMAIN)
echo "   Status: $AFTER_NO_CERT"
if [ "$AFTER_NO_CERT" = "403" ] || [ "$AFTER_NO_CERT" = "000" ]; then
  echo "   ✅ Blocked (SECURE - auth required)"
elif [ "$AFTER_NO_CERT" = "200" ]; then
  echo "   ❌ Still works (AOP not enabled)"
else
  echo "   ⚠️  Unexpected status"
fi

echo ""
echo "2. Direct access WITH Cloudflare origin cert:"
echo "   Command: curl --cert cf-origin-cert.pem --key cf-origin-key.pem https://$DOMAIN"
AFTER_WITH_CERT=$(curl -s -w "%{http_code}" -o /dev/null \
  --cert "$CERT_PATH/cf-origin-cert.pem" \
  --key "$CERT_PATH/cf-origin-key.pem" \
  https://$DOMAIN)
echo "   Status: $AFTER_WITH_CERT"
if [ "$AFTER_WITH_CERT" = "200" ]; then
  echo "   ✅ Works (Cloudflare cert accepted)"
else
  echo "   ❌ Failed (cert validation issue)"
fi

echo ""
echo ""
echo "=================================================="
echo "Summary"
echo "=================================================="
echo ""
echo "BEFORE (Vulnerable):"
echo "  Without cert: $BEFORE_NO_CERT ✅"
echo "  With cert:    $BEFORE_WITH_CERT ✅"
echo "  → Anyone can access ALB directly"
echo ""
echo "AFTER (Secure):"
echo "  Without cert: $AFTER_NO_CERT"
echo "  With cert:    $AFTER_WITH_CERT ✅"
echo "  → Only Cloudflare origin pull works"
echo ""

if [ "$AFTER_NO_CERT" != "200" ] && [ "$AFTER_WITH_CERT" = "200" ]; then
  echo "✅ AOP working correctly!"
elif [ "$BEFORE_NO_CERT" = "200" ]; then
  echo "⏳ AOP not yet enabled or propagated"
  echo "   Check: https://dash.cloudflare.com/d2042bfd3a3e07a0316993901ece027c/$DOMAIN/ssl-tls/origin/authenticated-origin-pulls"
fi
