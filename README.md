# SMTP Relay Docker Build

This repository builds and pushes a rootless and distroless Docker image for [grafana/smtprelay](https://github.com/grafana/smtprelay).

## Overview

The action/workflow creates a secure, minimal Docker image by:
- Building a container image from Google Distroless base image
- Running as a nonroot(65532:65532) user for enhanced security

## Docker Image

The resulting image is:
- **Base**: Google Distroless - No shell, minimal dependencies (tzdata, ca-certificates)
- **User**: Non-root user for security
- **Tags**: Based on smtprelay version

### Image Tags
This does not push a latest tag, only specific versions.
- `{version}` - Specific smtprelay version (e.g., `2.3.0`)

## Security Features

- **Distroless base image** - No package manager, shell, or unnecessary binaries
- **Non-root execution** - Runs as unprivileged user
- **Minimal dependencies** - Only runtime essentials included

## How to Use

### Configuration Parameters

The SMTP relay supports extensive configuration through command-line flags:

**Network & Connection Settings:**
- `-listen` - Address and port to listen for incoming SMTP (default: "127.0.0.1:25 [::1]:25")
- `-hostname` - Server hostname (default: "localhost.localdomain")
- `-max_connections` - Max concurrent connections, -1 to disable (default: 100)
- `-metrics_listen` - Address and port for Prometheus metrics exposition (default: ":8080")

**Remote SMTP Server:**
- `-remote_host` - Outgoing SMTP server (default: "smtp.gmail.com:587")
- `-remote_user` - Username for authentication on outgoing SMTP server
- `-remote_pass` - Password for authentication (or set $REMOTE_PASS env var)
- `-remote_sender` - Sender email address on outgoing SMTP server
- `-remote_auth` - Auth method: plain, login (default: "plain")

**Security & Access Control:**
- `-allowed_nets` - Networks allowed to send mails (default: "127.0.0.0/8 ::/128")
- `-allowed_recipients` - Regex for valid 'to' email addresses
- `-allowed_sender` - Regex for valid FROM email addresses
- `-allowed_users` - Path to file with valid users/passwords
- `-denied_recipients` - Regex for email addresses to never deliver

**TLS/SSL:**
- `-local_cert` - SSL certificate for STARTTLS/TLS
- `-local_key` - SSL private key for STARTTLS/TLS
- `-local_forcetls` - Force STARTTLS (requires cert and key)

**Message Limits:**
- `-max_message_size` - Max message size in bytes (default: 51200000)
- `-max_recipients` - Max recipients per email (default: 100)

**Timeouts:**
- `-read_timeout` - Socket timeout for read operations (default: 1m0s)
- `-write_timeout` - Socket timeout for write operations (default: 1m0s)
- `-data_timeout` - Socket timeout for DATA command (default: 5m0s)

**Logging & Monitoring:**
- `-log_level` - Minimum log level: debug, info, warn, error (default: "info")
- `-log_format` - Log format: json or logfmt (default: "json")
- `-log_header` - Log specific mail header values

**Configuration Management:**
- `-config` - Path to ini config file
- `-configUpdateInterval` - Interval for re-reading config file
- `-allowMissingConfig` - Don't terminate if ini file cannot be read
- `-allowUnknownFlags` - Don't terminate if ini file contains unknown flags

### Docker Run Example

```bash
docker run -d \
  --name smtprelay \
  -p 1025:1025 \
  -p 8080:8080 \
  -e REMOTE_PASS="your-gmail-app-password" \
  ghcr.io/burneystarke/smtprelay:2.3.0 \
  -listen="0.0.0.0:1025" \
  -hostname="smtprelay.example.com" \
  -remote_host="smtp.gmail.com:587" \
  -remote_user="your-email@gmail.com" \
  -remote_sender="your-email@gmail.com" \
  -allowed_nets="0.0.0.0/0" \
  -log_level="info"
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  smtprelay:
    image: ghcr.io/burneystarke/smtprelay:2.3.0
    container_name: smtprelay
    ports:
      - "1025:1025"
      - "8080:8080"
    environment:
      - REMOTE_PASS=your-gmail-app-password
    command:
      - "-listen=0.0.0.0:1025"
      - "-hostname=smtprelay.example.com"
      - "-remote_host=smtp.gmail.com:587"
      - "-remote_user=your-email@gmail.com"
      - "-remote_sender=your-email@gmail.com"
      - "-allowed_nets=0.0.0.0/0"
      - "-log_level=info"
      - "-max_connections=50"
      - "-max_message_size=25600000"
    restart: unless-stopped
```

### Kubernetes StatefulSet Example

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: smtprelay
  namespace: default
spec:
  serviceName: smtprelay
  replicas: 1
  selector:
    matchLabels:
      app: smtprelay
  template:
    metadata:
      labels:
        app: smtprelay
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      containers:
      - name: smtprelay
        image: ghcr.io/burneystarke/smtprelay:2.3.0
        ports:
        - containerPort: 1025
          name: smtp
        - containerPort: 8080
          name: metrics
        env:
        - name: REMOTE_PASS
          valueFrom:
            secretKeyRef:
              name: smtprelay-secret
              key: remote-pass
        args:
        - "-listen=0.0.0.0:1025"
        - "-hostname=smtprelay.example.com"
        - "-remote_host=smtp.gmail.com:587"
        - "-remote_user=your-email@gmail.com"
        - "-remote_sender=your-email@gmail.com"
        - "-allowed_nets=0.0.0.0/0"
        - "-log_level=info"
        - "-max_connections=100"
        - "-metrics_listen=0.0.0.0:8080"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          tcpSocket:
            port: 1025
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 1025
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL

---
apiVersion: v1
kind: Service
metadata:
  name: smtprelay
spec:
  selector:
    app: smtprelay
  ports:
  - name: smtp
    port: 1025
    targetPort: 1025
  - name: metrics
    port: 8080
    targetPort: 8080

---
apiVersion: v1
kind: Secret
metadata:
  name: smtprelay-secret
type: Opaque
stringData:
  remote-pass: REALLYCOOLPASSWORD
```
### Manual Testing

To test code or config, start smtprelay, and send test email using `swaks`.

> Tip: you can install `swaks` using `sudo apt install swaks` on Ubuntu.

```console
$ swaks --to=test@example.com --from=noreply@example.com --server=localhost:2525 --h-Subject="Hello from smtprelay" --body="This is test email from smtprelay"
```

To test with trace propagation, start `smtprelay` using `air`, and use [otel-cli](https://github.com/equinix-labs/otel-cli):

```console
$ otel-cli exec -s swaks -n "send e-mail" -- sh -c 'swaks --to alice@example.com --from=bob@example.com --server localhost:2525 --h-Subject: "Hello from smtprelay" -h-Traceparent: "${TRACEPARENT}" --body "This is a test email from smtprelay"'
```

### Acknowledgements

Repackage of [grafana/smtprelay](https://github.com/grafana/smtprelay)
grafana/smtprelay started as a fork of [github.com/decke/smtprelay](https://github.com/decke/smtprelay).
We thank the original authors for their work.
