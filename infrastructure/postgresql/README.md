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

## Creación de bases de datos y usuarios

Para crear una nueva base de datos y un usuario dedicado para una aplicación:

```bash
# Obtener la contraseña de admin
export POSTGRES_PASSWORD=$(kubectl get secret postgresql-secret -n database -o jsonpath="{.data.password}" | base64 --decode)

# Crear usuario y base de datos
kubectl exec -it postgresql-0 -n database -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "CREATE USER nombre_app WITH PASSWORD 'password_seguro';"
kubectl exec -it postgresql-0 -n database -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "CREATE DATABASE nombre_app OWNER nombre_app;"
kubectl exec -it postgresql-0 -n database -- env PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE nombre_app TO nombre_app;"
```

## Conexión desde aplicaciones

Las aplicaciones que usen PostgreSQL deben:

1. Usar como hostname: `postgresql.database.svc.cluster.local`
2. Usuario: El usuario dedicado creado (ej. `authentik`)
3. Contraseña: La contraseña definida durante la creación
4. Puerto: `5432`
5. Base de datos: La base de datos dedicada (ej. `authentik`)

Ejemplo en application.yaml:

```yaml
env:
  - name: DATABASE_HOST
    value: postgresql.database.svc.cluster.local
  - name: DATABASE_PORT
    value: "5432"
  - name: DATABASE_USER
    value: nombre_app
  - name: DATABASE_PASSWORD
    value: "password_seguro"
  - name: DATABASE_NAME
    value: nombre_app
```

## Monitoreo

Las métricas están disponibles pero ServiceMonitor no está habilitado. Para habilitarlo, editar `values.yaml`:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```
