# Kellnr Helm-Chart

This repository provides a [Helm](https://helm.sh/) Chart for [Kellnr](https://kellnr.io), the Rust registry for self-hosting crates.

## Installation

Add the _Kellnr_ helm repository which contains _Kellnr_:

```bash
# Add  repository
helm repo add kellnr https://kellnr.github.io/helm

# Update to latest version
helm repo update
```

For a list of possible configuration flags see below: [Configuration](#configuration)

To install a minimal _Kellnr_ installation with in-memory storage run the command below. The in-memory storage variant is useful for testing but not recommended for production as all data (crates, users, ...) will be lost if the container restarts.

```bash
helm install kellnr kellnr/kellnr --set kellnr.origin.hostname="kellnr.example.com"
```

For a persistent _Kellnr_ instance, a _PersistentVolumeClaim_ (PVC) is needed. The helm chart can create a _PersistentVolumeClaim_ and _PersistentVolume_ (PV), if you don't have one already.

```bash
# Use an existing PersistentStorage (storage_name) to get a PersistentStorageClaim.
# The storage class can be overwritten with "pvc.storageClassName" and defaults to "manual".
helm install kellnr kellnr/kellnr \
    --set pvc.enabled=true --set pvc.name="storage_name" \
    --set kellnr.origin.hostname="kellnr.example.com"
```

```bash
# Create a new PersistentVolume and a corresponding claim. The host path e.g. "/mnt/kellnr" has to exists before the PV is created.
helm install kellnr kellnr/kellnr \
    --set pv.enabled=true --set pv.path="/mnt/kellnr" \
    --set pvc.enabled=true \
    --set kellnr.origin.hostname="kellnr.example.com"
```

For information about the _Cargo_ setup and default values, see the official [Kellnr documentation](https://kellnr.io/documentation).

## Upgrade

Upgrade _Kellnr_ by updating the Helm repository and applying the latest version.

```bash
# Update helm repositories
helm repo update

# Upgrade Kellnr
helm upgrade kellnr kellnr/kellnr
```

### Upgrade Notes

#### Chart version 6.0.0

**Breaking change: configuration is now split into a ConfigMap and a Secret.**

> For background on what changed and why, see the blog post:
> [A Safer Kellnr Helm Chart: Splitting Config and Secrets](https://kellnr.io/blog/helm-chart-v6).

Previously, `secret.enabled` switched the *entire* configuration between a ConfigMap
(default) and a Secret. The chart now always renders **both**: non-sensitive settings
go into a ConfigMap and sensitive ones (admin password and token, cookie signing key,
S3 keys, OAuth2 client secret) go into a Secret. Both are mounted into the pod, so
sensitive values are no longer stored in a plaintext ConfigMap.

Migration:

- `secret.enabled` and `secret.useExisting` have been **removed**.
  - If you used `secret.enabled: true` only to keep config out of a ConfigMap, no
    action is needed — sensitive values now live in a Secret automatically.
  - If you used `secret.useExisting: true` with a self-managed (e.g. SOPS-encrypted)
    Secret, set `secret.existingSecret: <your-secret-name>` instead. The chart then
    mounts your Secret in place of its own. Note that the Secret only needs to carry
    the sensitive `KELLNR_*` variables; non-sensitive ones come from the ConfigMap.
- New escape hatches: `extraEnvVars` (raw `EnvVar` list), `extraEnvVarsCM` and
  `extraEnvVarsSecret` (names of existing ConfigMaps/Secrets) let you inject arbitrary
  environment variables or mount your own config/secret alongside the chart's.
- The cookie signing key can now be sourced from an existing Secret via
  `kellnr.registry.cookieSigningKeySecretRef`. See [Cookie signing key](#cookie-signing-key).

Other notable changes in this release:

- **Health probes are now enabled by default**, hitting Kellnr's `/api/v1/health`
  endpoint (startup, liveness, readiness). Tune or disable them via the
  `startupProbe`/`livenessProbe`/`readinessProbe` values.
- **The ServiceAccount token is no longer mounted** (`serviceAccount.automountServiceAccountToken: false`),
  since Kellnr does not use the Kubernetes API. Set it back to `true` if you rely on it.
- New tuning settings exposed: `kellnr.registry.downloadTimeoutSeconds`,
  `downloadMaxConcurrent`, `downloadCounterFlushSeconds`, and
  `kellnr.s3.connectTimeoutSeconds`/`requestTimeoutSeconds`.
- A `values.schema.json` now validates values at install/template time (e.g. it
  requires `kellnr.origin.hostname`).

#### Chart version 5.0.0

The default data directory changed from `/opt/kdata` to `/var/lib/kellnr` to align with the new Kellnr Docker image defaults. If you're upgrading an existing installation and were using the default data directory, explicitly set `kellnr.registry.dataDir=/opt/kdata` in your values to maintain compatibility with your existing persistent volume.

## Testing

After installing or upgrading, you can run the chart's built-in smoke test, which
checks that Kellnr's `/api/v1/health` endpoint is reachable through its Service:

```bash
helm test kellnr
```

## Configuration

All settings can be set with the `--set name=value` flag on `helm install`. Some settings are required and have to be provided other are recommended for security reasons.

### Kellnr

Check the [documentation](https://kellnr.io/documentation) and the [values.yaml](./charts/kellnr/values.yaml) for possible configuration values.

#### Configuration storage (ConfigMap and Secret)

The chart renders Kellnr's configuration into two objects, both mounted into the pod
via `envFrom`:

- a **ConfigMap** (`configMap.name`) holding the non-sensitive settings, and
- a **Secret** (`secret.name`) holding the sensitive ones: the admin password and
  token, the cookie signing key, the S3 keys, and the OAuth2 client secret.

| Setting               | Required | Description                                                                                       | Default         |
|-----------------------|----------|---------------------------------------------------------------------------------------------------|-----------------|
| configMap.name        | No       | Name of the ConfigMap holding non-sensitive configuration.                                        | "kellnr-config" |
| secret.name           | No       | Name of the Secret holding sensitive configuration.                                               | "kellnr-secret" |
| secret.existingSecret | No       | Use an existing Secret (e.g. SOPS-managed) instead of creating one. The chart then mounts yours.  | ""              |

To add your own variables or mount additional ConfigMaps/Secrets, see
[Extra environment variables](#extra-environment-variables).

#### Admin password and token

These credentials can also be set in any other secret and then referenced from this chart.

| Setting                               | Required | Description                                                                                       | Default                            |
|---------------------------------------|----------|---------------------------------------------------------------------------------------------------|------------------------------------|
| kellnr.setup.adminPwd                 | No       | Inline password for the default admin account.                                                    | "admin"                            |
| kellnr.setup.adminPwdSecretRef.name   | No       | Name of an existing Secret holding the password. Takes precedence over the inline value when set. | ""                                 |
| kellnr.setup.adminPwdSecretRef.key    | No       | Key within that Secret.                                                                           | "adminPwd"                         |
| kellnr.setup.adminToken               | No       | Inline read-write token for the default admin account.                                            | "Zy9HhJ02RJmg0GCrgLfaCVfU6IwDfhXD" |
| kellnr.setup.adminTokenSecretRef.name | No       | Name of an existing Secret holding the token. Takes precedence over the inline value when set.    | ""                                 |
| kellnr.setup.adminTokenSecretRef.key  | No       | Key within that Secret.                                                                           | "adminToken"                       |

Notes:

- Both fields have non-empty defaults, so the admin account always has credentials.
  Change them before exposing Kellnr.
- Provide a value inline to have the chart store it in its Secret, or point the
  matching `adminPwdSecretRef`/`adminTokenSecretRef` at a Secret you manage yourself.

#### Cookie signing key

Kellnr uses a cookie signing key to sign its session cookie. Setting it is recommended
for multi-replica setups so every replica shares the same key (otherwise users are
logged out when routed to a different replica). The key is sensitive and is stored in
the chart-managed Secret.

| Setting                                       | Required | Description                                                                                          | Default            |
|-----------------------------------------------|----------|------------------------------------------------------------------------------------------------------|--------------------|
| kellnr.registry.cookieSigningKey              | No       | Inline cookie signing key for `KELLNR_REGISTRY__COOKIE_SIGNING_KEY`. Must be at least 64 characters. | ""                 |
| kellnr.registry.cookieSigningKeySecretRef.name | No      | Name of an existing Secret holding the key. Takes precedence over the inline value when set.         | ""                 |
| kellnr.registry.cookieSigningKeySecretRef.key  | No      | Key within that Secret.                                                                              | "cookieSigningKey" |

Notes:

- If neither value is set, Kellnr generates a random key on startup (per pod).
- Provide the key inline to have the chart store it in its Secret, **or** point
  `cookieSigningKeySecretRef` at a Secret you manage yourself.

Inline example:

````yaml
kellnr:
  registry:
    cookieSigningKey: "<at least 64 characters>"
````

Existing-secret example:

````yaml
kellnr:
  registry:
    cookieSigningKeySecretRef:
      name: my-cookie-secret
      key: cookieSigningKey
````

#### Extra environment variables

To inject arbitrary environment variables or mount your own ConfigMap/Secret alongside
the chart's, use the `extraEnvVars*` settings.

| Setting             | Required | Description                                                        | Default |
|---------------------|----------|--------------------------------------------------------------------|---------|
| extraEnvVars        | No       | List of raw Kubernetes `EnvVar` objects (supports `valueFrom`).    | []      |
| extraEnvVarsCM      | No       | Name of an existing ConfigMap to load via `envFrom`.               | ""      |
| extraEnvVarsSecret  | No       | Name of an existing Secret to load via `envFrom`.                  | ""      |

````yaml
extraEnvVars:
  - name: AWS_REGION
    value: "eu-central-1"
extraEnvVarsSecret: my-aws-credentials
````


### Service

Settings to configure the web-ui/API endpoint service and the crate index service.

| Setting          | Required | Description                                                   | Default   |
|------------------|----------|---------------------------------------------------------------|-----------|
| service.api.type | No       | Type of the service that exports the API and web-ui endpoint. | ClusterIP |
| service.api.port | No       | Port of the service that exports the API and web-ui endpoint. | 8000      |

### Ingress

Setting to configure the ingress route for the web-ui and API.

| Setting                | Required | Description                                      | Default            |
|------------------------|----------|--------------------------------------------------|--------------------|
| ingress.enabled        | No       | Enable an Kubernetes ingress route for _Kellnr_. | true               |
| ingress.className      | No       | Set an ingress className.                        | ""                 |
| ingress.pathType       | No       | Set the ingress pathType.                        | "Prefix"           |
| ingress.path           | No       | Set the ingress path.                            | "/"                |
| ingress.annotations    | No       | Set ingress annotations.                         | {}                 |
| ingress.tls.secretName | No       | Set the secret name for a TLS certificate        | kellnr-cert-secret |

### TLS Certificate

Settings to configure a TLS certificate with cert-manager. **Important** If you use _Kellnr_ with TLS,
make sure to set `kellnr.origin.protocol` to `https`.

| Setting | Required | Description | Default |
| ---------------------- | -------- | ------------------------------------------------------------- | --------- |
| certificate.enabled | No | Enable automatic TLS certificate generation with cert-mananger. | false |
| certificate.secretName | No | The name of the certificate secret which an ingress can refer to. | kellnr-cert-secret |
| certificate.issuerRef.kind | No | The kind of the certificate issuer, e.g. _ClusterIssuer_, or _Issuer_ | ClusterIssuer |
| certificate.issuerRef.name | Yes (if enabled) | The name of the certificate issuer e.g. cert-manager | "" |

### Trust a Certificate

Besides the option of using a certificate to secure the access to _Kellnr_, you can import a certificate into _Kellnr_ which it will trust as a
root certificate.

> Kellnr needs to trust it's own root certificate to be able to generate Rustdocs automatically!

If you use a self-signed certificate that is not trusted by default, you can import it into _Kellnr_ on application startup.

| Setting | Required | Description | Default |
| ---------------------- | -------- | ------------------------------------------------------------- | --------- |
| importCert.enabled | No | Enable the import of a root certificate to trust | false |
| importCert.useExisting | No | If you have an existing _ConfigMap_ that contains a certificate, set this flag to _true_, else a new _ConfigMap_ is created.  | false |
| importCert.configMapName | No | Set the name of the created or existing _ConfigMap_ to use. | "kellnr-cert" |
| importCert.volumeName | No | The volume name under which the _ConfigMap_ is mounted into the pod. | "kellnr-cert-storage" |
| importCert.certificate | No | The certificate to trust in the standard PEM format. See example below. | "" |

Example for `importCert.certificate`:

```yaml
importCert:
  enabled: true
  certificate: |
    —–BEGIN CERTIFICATE—–
    MIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG
    YWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT
    aWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ
    …
    jc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp
    38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP
    HMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==
    —–END CERTIFICATE—–
```

### DNS

You can set DNS servers for _Kellnr_ which should be used instead of the default one.

> Kellnr needs to be able to resolve it's own domain name, to be able to generate Rustdocs automatically.

| Setting                   | Required | Description                      | Default |
|---------------------------|----------|----------------------------------|---------|
| dns.enabled               | No       | Enable an additional _dnsPolicy_ | false   |
| dns.dnsPolicy             | No       | Set the _dnsPolicy_              | "None"  |
| dns.dnsConfig.nameservers | No       | List of nameservers to use.      | - ""    |
| dns.dnsConfig.searches    | No       | List of searches to use.         | - ""    |

### Persistence

A _PersistentVolume_ can be created for _Kellnr_ to hold all stored data.

| Setting             | Required         | Description                                                        | Default |
| ------------------- | ---------------- | ------------------------------------------------------------------ | ------- |
| pv.enabled          | No               | Enable a _PersistentVolume_ to store the data from _Kellnr_        | false   |
| pv.name             | No               | Name of the _PersistentVolume_                                     | kellnr  |
| pv.storageClassName | No               | storageClassName of the _PersistentVolume_                         | manual  |
| pv.storage          | No               | Size of the storage.                                               | 5Gi   |
| pv.path             | Yes (if enabled) | Host path to the storage. Needs to exists before the PV is created | ""      |

A _PersistentVolumeClaim_ can be used by _Kellnr_ to hold all stored data.

| Setting              | Required | Description                                                      | Default |
| -------------------- | -------- | ---------------------------------------------------------------- | ------- |
| pvc.enabled          | No       | Enable a _PersistentVolumeClaim_ to store the data from _Kellnr_ | false   |
| pvc.name             | No       | Name of the _PersistentVolumeClaim_                              | kellnr  |
| pvc.storageClassName | No       | storageClassName of the _PersistentVolumeClaim_                  | manual  |
| pvc.storage          | No       | Size of the storage.                                             | 5Gi   |

For a full set of possible variables see: [values.yaml](./charts/kellnr/values.yaml)

### S3 storage

When _Kellnr_ uses S3-compatible object storage (`kellnr.s3.enabled`), the access and
secret keys are sensitive and stored in the chart-managed Secret. Each can be provided
inline or sourced from an existing Secret you manage yourself.

| Setting                           | Required | Description                                                                                         | Default     |
|-----------------------------------|----------|-----------------------------------------------------------------------------------------------------|-------------|
| kellnr.s3.accessKey               | No       | Inline S3 access key.                                                                               | ""          |
| kellnr.s3.accessKeySecretRef.name | No       | Name of an existing Secret holding the access key. Takes precedence over the inline value when set. | ""          |
| kellnr.s3.accessKeySecretRef.key  | No       | Key within that Secret.                                                                             | "accessKey" |
| kellnr.s3.secretKey               | No       | Inline S3 secret key.                                                                               | ""          |
| kellnr.s3.secretKeySecretRef.name | No       | Name of an existing Secret holding the secret key. Takes precedence over the inline value when set. | ""          |
| kellnr.s3.secretKeySecretRef.key  | No       | Key within that Secret.                                                                             | "secretKey" |

For the full set of S3 options see: [values.yaml](./charts/kellnr/values.yaml)

## Feedback

If the Helm Chart does not work for you for any reason or you need a feature, feel free to create a Github issue.

## Release a new version

Run the following steps to release a new version of the chart.

1. Change the `appVersion` in [Chart.yaml](./charts/kellnr/Chart.yaml) to the current image version.
2. Increase the `version` in [Chart.yaml](./charts/kellnr/Chart.yaml).
3. Push or create a Pull-Request to the `main`/`master` branch.
