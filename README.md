# test-node-app

A Node.js (Express) app that demonstrates the full homelab deployment pattern:

```
source ──docker build──►  Nexus registry (nexus.ibstorm.com/test-node-app)
                                   │  (imagePullSecret: nexus-pull, user k8spull)
                                   ▼
                           Kubernetes Deployment (ns: test-node-app)
                             ├─ ConfigMap  test-node-config   -> env (GREETING, LOG_LEVEL)
                             └─ Secret     test-node-secret   -> env (API_KEY, DB_PASSWORD)
                                   ▲
                                   │  External Secrets Operator (ClusterSecretStore vault-backend)
                           Vault KV v2: secret/test-node-app
```

`GET /` returns the pod name, the ConfigMap values, and whether the Vault secret loaded.

## Prerequisites (already set up in the cluster)
- Nexus Docker registry at `nexus.ibstorm.com` (repo `docker-hosted`), users `ci` (push) / `k8spull` (pull).
- `nexus-pull` image-pull secret in the `test-node-app` namespace.
- ESO + `vault-backend` ClusterSecretStore (Vault Kubernetes auth), role `eso-reader`.

## One-time per app
```bash
# 1. put the secret in Vault
curl -H "X-Vault-Token: $VT" -X POST \
  -d '{"data":{"API_KEY":"...","DB_PASSWORD":"..."}}' \
  https://vault.ibstorm.com/v1/secret/data/test-node-app

# 2. image-pull secret (once per namespace)
kubectl -n test-node-app create secret docker-registry nexus-pull \
  --docker-server=nexus.ibstorm.com --docker-username=k8spull --docker-password='...'
```

## Build + deploy
```bash
./deploy.sh v1        # builds on the Docker host, pushes to Nexus, deploys & rolls out
```

## Verify
```bash
kubectl -n test-node-app get pods
kubectl -n test-node-app port-forward svc/test-node-app 8080:80 &
curl -s localhost:8080 | jq     # expect secretsLoaded: true + config values
```

## Update
- Code: `./deploy.sh v2` (new tag; repo is ALLOW_ONCE so tags are immutable).
- Config: edit `k8s/10-configmap.yaml`, apply, `kubectl rollout restart`.
- Secret: update in Vault; ESO re-syncs within refreshInterval, then `kubectl rollout restart`.

## Files
- `server.js`, `package.json`, `Dockerfile`, `.dockerignore`
- `k8s/10-configmap.yaml` — non-secret config
- `k8s/20-externalsecret.yaml` — Vault -> Secret (via ESO)
- `k8s/30-deployment.yaml` — Deployment (Nexus image + pull secret + env) + Service
- `deploy.sh` — build/push/deploy
