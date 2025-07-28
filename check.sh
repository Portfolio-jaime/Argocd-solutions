#!/bin/bash
echo "=== DIAGNÓSTICO POST-INCIDENTE ==="
echo "Fecha: $(date)"
echo ""

echo "1. Estado Helm:"
helm list -n argocd
echo ""

echo "2. Historial Helm:"
helm history argocd -n argocd
echo ""

echo "3. Estado Pods:"
kubectl get pods -n argocd
echo ""

echo "4. Aplicaciones:"
kubectl get applications -A --no-headers | wc -l
echo ""

echo "5. Redis HA Test:"
kubectl exec -n argocd argocd-redis-ha-server-0 -c redis -- redis-cli ping 2>/dev/null || echo "Redis HA FAILED"