# Authentik Deployment

Authentik es un servidor de autenticación y autorización OpenSource que proporciona SSO y gestión de identidades.

## Configuración

- **Namespace**: `authentik`
- **Dominio**: `auth.cubancodelab.net`
- **Base de datos**: PostgreSQL centralizado (`postgresql.database.svc.cluster.local`)
- **Cache**: Redis integrado en el chart

## Credenciales

Las credenciales están almacenadas en `config/authentik-sealed-secret.yaml` como SealedSecret.

### Credenciales iniciales:

- **Usuario admin**: `akadmin`
- **Contraseña**: Cambiar en la variable `AUTHENTIK_BOOTSTRAP_PASSWORD`

Para cambiar las credenciales después del despliegue:

```bash
# Acceder a la interfaz web en https://auth.cubancodelab.net
# El token de bootstrap se encuentra en la variable AUTHENTIK_BOOTSTRAP_TOKEN
```

## Base de datos

Authentik usa la instancia PostgreSQL centralizada:

```
Host: postgresql.database.svc.cluster.local
Puerto: 5432
Usuario: postgres
Base de datos: authentik
```

Si la base de datos no existe, crear con:

```bash
kubectl exec -it postgresql-0 -n database -- \
  psql -U postgres -c "CREATE DATABASE authentik;"
```

## Actualizar credenciales

Para cambiar las contraseñas, actualiza el sealed secret:

```bash
kubectl create secret generic authentik \
  --from-literal=AUTHENTIK_SECRET_KEY="$(openssl rand -base64 32)" \
  --from-literal=AUTHENTIK_BOOTSTRAP_PASSWORD="nueva-contraseña" \
  --from-literal=AUTHENTIK_BOOTSTRAP_TOKEN="$(openssl rand -base64 32)" \
  --from-literal=AUTHENTIK_POSTGRESQL__HOST="postgresql.database.svc.cluster.local" \
  --from-literal=AUTHENTIK_POSTGRESQL__NAME="authentik" \
  --from-literal=AUTHENTIK_POSTGRESQL__USER="postgres" \
  --from-literal=AUTHENTIK_POSTGRESQL__PASSWORD="postgres-homelab-password" \
  --from-literal=AUTHENTIK_POSTGRESQL__PORT="5432" \
  --from-literal=AUTHENTIK_REDIS__HOST="authentik-redis-master" \
  --from-literal=AUTHENTIK_REDIS__PASSWORD="nueva-contraseña-redis" \
  --from-literal=redis-password="nueva-contraseña-redis" \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > config/authentik-sealed-secret.yaml
```

## Verificar estado

```bash
# Verificar pods
kubectl get pods -n authentik

# Logs del servidor
kubectl logs -n authentik -l app.kubernetes.io/name=authentik -c authentik

# Acceder a la interfaz
# https://auth.cubancodelab.net/
```

## Integración con otras aplicaciones

Una vez desplegado, configurar OIDC en tus aplicaciones:

```
OIDC Provider URL: https://auth.cubancodelab.net/application/o/
Client ID: [Tu application ID]
Client Secret: [Tu application secret]
```
