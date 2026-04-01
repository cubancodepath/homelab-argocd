# Plane Patches

## Ingress /plane-uploads route

The Plane Helm chart doesn't include a route for `/plane-uploads` by default, which causes file uploads to fail with 405 Method Not Allowed.

### Manual patch applied:

```bash
kubectl patch ingress plane-ingress -n plane --type merge -p '{
  "spec": {
    "rules": [{
      "host": "plane.cubancodelab.net",
      "http": {
        "paths": [
          {"backend": {"service": {"name": "plane-web", "port": {"number": 3000}}}, "path": "/", "pathType": "Prefix"},
          {"backend": {"service": {"name": "plane-api", "port": {"number": 8000}}}, "path": "/api", "pathType": "Prefix"},
          {"backend": {"service": {"name": "plane-api", "port": {"number": 8000}}}, "path": "/auth", "pathType": "Prefix"},
          {"backend": {"service": {"name": "plane-api", "port": {"number": 8000}}}, "path": "/plane-uploads", "pathType": "Prefix"},
          {"backend": {"service": {"name": "plane-live", "port": {"number": 3000}}}, "path": "/live/", "pathType": "Prefix"},
          {"backend": {"service": {"name": "plane-space", "port": {"number": 3000}}}, "path": "/spaces", "pathType": "Prefix"},
          {"backend": {"service": {"name": "plane-admin", "port": {"number": 3000}}}, "path": "/god-mode", "pathType": "Prefix"}
        ]
      }
    }]
  }
}'
```

**Note:** This patch must be reapplied if the Ingress is recreated (e.g., after cluster redeploy).

To make this permanent in GitOps, the Plane Application should use a Kustomize overlay or patch strategy to modify the Helm-generated Ingress.
