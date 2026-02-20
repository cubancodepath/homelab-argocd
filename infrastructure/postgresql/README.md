# PostgreSQL Deployment

Instancia centralizada de PostgreSQL para el cluster homelab.

## Configuración

- **Namespace**: `database`
- **StorageClass**: `longhorn`
- **Tamaño almacenamiento**: 50Gi
- **Usuario admin**: `postgres`

## Credenciales

Las credenciales están almacenadas en `config/postgresql-sealed-secret.yaml` como SealedSecret.

Para ver/cambiar las credenciales:

```bash
# Ver el secret decodificado
kubectl get secret postgresql-secret -n database -o jsonpath='{.data.password}' | base64 -d

# Crear un nuevo sealed secret con contraseña diferente
kubectl create secret generic postgresql-secret \
  --from-literal=password=nueva-contraseña \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml
```

## Conexión desde aplicaciones

Las aplicaciones que usen PostgreSQL deben:

1. Usar como hostname: `postgresql.database.svc.cluster.local`
2. Usuario: `postgres`
3. Contraseña: desde el secret `postgresql-secret`
4. Puerto: `5432`

Ejemplo en application.yaml:

```yaml
env:
  - name: DATABASE_HOST
    value: postgresql.database.svc.cluster.local
  - name: DATABASE_PORT
    value: "5432"
  - name: DATABASE_USER
    value: postgres
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-secret
        key: password
```

## Creación de bases de datos

Para crear una nueva base de datos para una aplicación:

```bash
kubectl exec -it postgresql-0 -n database -- \
  psql -U postgres -c "CREATE DATABASE nombre_app;"
```

## Monitoreo

Las métricas están disponibles pero ServiceMonitor no está habilitado. Para habilitarlo, editar `values.yaml`:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```
