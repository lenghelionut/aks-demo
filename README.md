# aks-demo
The app folder contains a basic python application, created using flask, which shows the version, the environment name, the hostname and the timestamp. The requirements.txt is for installing the python dependencies and the Dockerfile contains the instructions to build the container image.

The k8s directory contains two folders, base and overlays. Base, as the name implies, contains the base manifests, on which, we apply different configurations depending on the environement, which can be found in the overlays directory.

The terraform code creates an AKS cluster with 2 node pools (system and application), deploys ArgoCD for Continuous Deployment, cert-manager for certificates, Prometheus and Grafana for monitoring. 

URLs:
Dev:        https://dev.aksdemo.lenghel.dev/
Staging:    https://staging.aksdemo.lenghel.dev/
Prod:       https://prod.aksdemo.lenghel.dev
ArgoCD:     https://argocd.aksdemo.lenghel.dev/
Grafana:    https://grafana.aksdemo.lenghel.dev/


## Project structure

├── README.md
├── app                             # Flask API (version, health, readiness endpoints)
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── k8s
│   ├── base
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   ├── kustomization.yaml
│   │   ├── pdb.yaml
│   │   └── service.yaml
│   └── overlays
│       ├── dev
│       │   ├── configmap.yaml
│       │   └── kustomization.yaml
│       ├── prod
│       │   ├── configmap.yaml
│       │   └── kustomization.yaml
│       └── staging
│           ├── configmap.yaml
│           └── kustomization.yaml
└── terraform
    ├── argocd-apps.tf              # Used to deploy the ArgoCD Applications that watch for changes in the environments
    ├── argocd.tf                   # Used to deploy ArgoCD and Application CRDs
    ├── backend.tf                  # Instructs terraform to keep the statefile in Azure Storage with versioning enabled
    ├── cert-manager.tf             # Used to deploy cert-manager and Let's Encrypt ClusterIssuer
    ├── ingress.tf                  # Used to deploy nginx Ingress Controller
    ├── main.tf                     # Used to deploy AKS, ACR, VNet, subnet, managed identity
    ├── monitoring.tf               # Used to deploy kube-prometheus-stack (Prometheus + Grafana)
    ├── outputs.tf                  # Contains Terraform outputs and commands
    ├── providers.tf                # Instructs Terraform to initialize the Azure, Helm, Kubernetes and kubectl providers 
    ├── scripts
    │   └── setup-backend.sh        # Used to bootstrap the storage account
    ├── terraform.tfvars            # Has to be created, ignored by git
    └── variables.tf                # Parameterized configuration

## Prerequisites
- Azure account with an active subscription
- Azure CLI installed and logged in
- Terraform >= 1.15
- kubectl and argocd binaries installed
- Docker installed (for local testing)
- A DNS domain with the ability to create A records


## Provisioning the infrastructure

### 1. Bootstrap State Storage
The Terraform state backend must exist before the first `terraform apply`:

```bash
cd terraform/scripts
chmod +x setup-backend.sh
./setup-backend.sh
```

This creates a dedicated resource group, storage account with versioning, and blob container for state files.

### 2. Provision Infrastructure
Create terraform.tfvars with actual values:
```bash
subscription_id    = "your-subscription-id"
project            = "aksdemo"
environment        = "dev"
location           = "germanywestcentral"
kubernetes_version = "1.35"
system_node_count  = 1
app_node_min       = 1
app_node_max       = 3
```

After the terraform.tfvars was created, run:
```bash
terraform init
terraform plan
terraform apply
```
### 3. Configure DNS
Get the Ingress Controller's public IP:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Create a wildcard DNS A record pointing to this IP (or multiple individual records):
```
*.aksdemo.lenghel.dev -> A -> <INGRESS_IP>
```

### 4. Build and Push Initial Image
After the first `terraform apply`, the ACR is empty. Push the initial image:

```bash
az aks get-credentials --resource-group rg-aksdemo-dev --name aks-aksdemo-dev
az acr login --name craksdemodev

cd app
docker build -t craksdemodev.azurecr.io/aks-demo:latest .
docker push craksdemodev.azurecr.io/aks-demo:latest
```

ArgoCD automatically deploys the application to dev and staging once the image is available.

### 5. Sync Production
Production requires manual sync (as a security gate):

```bash
argocd login argocd.aksdemo.lenghel.dev --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d) --grpc-web

argocd app sync aks-demo-prod
```
Or it can be done via ArgoCD UI by clicking on the Sync button on the aks-demo-prod card.

### 6. Access the Services
The 3 environments are publicly open:
Dev app: https://dev.aksdemo.lenghel.dev
Staging app: https://staging.aksdemo.lenghel.dev
Prod app: https://prod.aksdemo.lenghel.dev

The ArgoCD and Grafana passwords can be retrieved by:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
kubectl get secret -n monitoring monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

### 7. Clean Up / Destroy
```bash
# Stop cluster (saves compute costs, preserves configuration):
az aks stop --resource-group rg-aksdemo-dev --name aks-aksdemo-dev

# Start cluster:
az aks start --resource-group rg-aksdemo-dev --name aks-aksdemo-dev

# Destroy everything:
cd terraform
terraform destroy

# Remove state storage:
az group delete --name rg-aksdemo-tfstate
```

## Design decisions
### Why Kustomize over Helm for Application?
Kustomize is native to kubectl (no additional tooling), uses pure YAML, and provides clean environment separation through the base/overlay pattern.

### Why GitHub Actions for CI?
Native integration with the repository — no external CI system to manage. OIDC federation with Azure eliminates stored credentials entirely. Environment protection rules provide approval gates for production.

### Why ArgoCD for GitOps?
ArgoCD provides pull-based deployment — it watches the Git repository and reconciles cluster state automatically. This separates CI (build and validate) from CD (deploy and maintain), and also offers self-healing in case of configuration drifts.

### Why Single NGINX Ingress Controller?
All environments share one NGINX Ingress Controller with host-based routing, using a single public IP and Azure Load Balancer. This is cost-efficient (one public IP instead of four), more secure (single ingress point for TLS termination).

### Why Remote State in Azure Storage?
Terraform state is stored in Azure Blob Storage with versioning enabled. Every `terraform apply` creates a new version, enabling rollback to any previous state. State locking via Azure Blob leases prevents concurrent modifications. Encryption at rest is enabled by default, and public access is disabled at the account level.

### Why Separate Node Pools?
System and application workloads run on separate node pools. System components (CoreDNS, metrics-server, kube-proxy) are isolated from application workloads, preventing resource contention. The application pool has autoscaling enabled to handle variable load.
Note: Due to free-tier vCPU quota limits (4 vCPUs total), the system pool runs with 1 node. In production, the system pool would have a minimum of 2 nodes for high availability.

### CI/CD pipeline:
CI is achieved using Github actions.
Pipeline stages:
1. Checkout — clone the repository
2. Tag — generate image tag from git SHA (immutable, traceable)
3. Build — multi-stage Docker build
4. Scan — Trivy vulnerability scan; fails on CRITICAL/HIGH CVEs
5. Login — OIDC federation to Azure (passwordless)
6. Push — push image to ACR with SHA tag and `latest`
7. Update — update dev and staging Kustomize overlays with new tag
8. Commit — push manifest changes back to repository

CD is achieved using ArgoCD.
- Dev/Staging auto-sync with self-heal — every CI push deploys automatically
- Production: manual sync only — requires explicit human action

A dedicated workflow (`promote.yaml`) creates a PR to update the prod overlay
with a tested image tag. Review, merge, and manually sync in ArgoCD to deploy.

### High Availability:
HA is achieved by configuring:
- Pod Anti-Affinity: pods are spread across different nodes using `preferredDuringSchedulingIgnoredDuringExecution`. If one node fails, not all replicas are lost.
- Pod Disruption Budget (PDB): `minAvailable: 1` ensures at least one pod remains running during voluntary disruptions (node drains, cluster upgrades, pod evictions).
- Multiple Replicas: production runs 3 replicas minimum; dev and staging run 2.
- NGINX Ingress Controller: deployed with 2 replicas for ingress-layer redundancy.

### Autoscaling:
Has been implemented using HPA (Horizontal Pod Autoscaler) and it is configured to:
- Scale based on CPU utilization (target: 70%)
- Scale-down with a stabilization window: 300 seconds (prevents flapping)
- Scale-down at a slower rate: 1 pod per 120 seconds (gradual, safe)
- Has per-environment maximums: dev=10, staging=15, production=20

In case HPA scales pods that can't be scheduled, the Cluster autoscaler addsnodes automatically. Cluster autoscaler also scales between 1 and 3 nodes, based on demand.

### Security

Containr security:
- Non-root user: dedicated `appuser` created in Dockerfile, container runs as UID 1000
- Read-only root filesystem: prevents runtime modification of application binaries; writable `/tmp` mounted as emptyDir for gunicorn worker files
- No privilege escalation: `allowPrivilegeEscalation: false`
- Dropped capabilities: all Linux capabilities dropped with `drop: [ALL]`
- Alpine base image: minimal attack surface, zero critical CVEs confirmed by Trivy
- Multi-stage build: build tools never reach the production image
- tini init process: proper signal handling and zombie process cleanup

IAM & Secrets:
- Managed Identity: AKS authenticates to ACR via system-assigned managed identity with AcrPull role — no Docker credentials stored anywhere
- OIDC Federation: CI pipeline authenticates to Azure using signed JWTs — no long-lived service principal secrets
- No credentials in Git: Terraform state encrypted in Azure Storage; `terraform.tfvars` excluded via `.gitignore`; Grafana and ArgoCD passwords generated by Helm charts and stored as Kubernetes Secrets
- No credentials in Terraform outputs: passwords retrieved via kubectl commands, never exposed in state or console output

TLS:
- Let's Encrypt certificates: automatically provisioned by cert-manager via HTTP-01 challenges
- Automatic renewal: certificates renewed before expiry without manual intervention
- HTTPS everywhere: all services accessible only via HTTPS (`.dev` TLD enforces HSTS)

Image scanning:
- Trivy scans every image in the CI pipeline before pushing to ACR
- Pipeline blocks images with critical or high-severity CVEs from reaching the registry

### Logging and monitoring
Stack: kube-prometheus-stack (Prometheus + Grafana + node-exporter) installed through Helm
- Prometheus: scrapes metrics from all cluster components and workloads via Kubernetes service discovery
- Grafana: pre-configured dashboards for cluster health, namespace resource usage, pod metrics, and node performance
- node-exporter: node-level OS metrics (CPU, memory, disk, network)
- Accessible at: https://grafana.aksdemo.lenghel.dev

Pre-built dashboards include:
- Kubernetes / Compute Resources / Cluster — overall cluster health
- Kubernetes / Compute Resources / Namespace — per-environment comparison
- Kubernetes / Compute Resources / Pod — individual pod metrics
- Node Exporter / Nodes — node-level system metrics

## Bootstrap Sequence (Fresh Deployment)
After a complete `terraform destroy` and `terraform apply`:

1. Infrastructure is provisioned (AKS, ACR, networking, platform tools)
2. ACR is empty — no images exist yet
3. ArgoCD Applications sync, but pods show `ImagePullBackOff`
4. Push the initial image manually (see Provisioning the infrastructure step 4)
5. ArgoCD detects the image and deploys successfully
6. Subsequent deployments are fully automated via the CI pipeline

## Trade-offs
| Decision | Trade-off | Reasoning |
|----------|-----------|-----------|
| Single-node system pool | Reduced HA for system components | Free-tier vCPU quota (4 total); in production, minimum 2 system nodes |
| 24h Prometheus retention | No historical trend analysis | Saves cluster resources; Thanos would provide long-term storage in production |
| Alertmanager disabled | No alert routing | Reduces resource usage; critical in production with PagerDuty/Slack integration |
| HTTP-01 ACME challenge | Requires port 80 accessible | Simpler than DNS-01; no DNS provider API integration needed |
| Single ingress controller | Single point of entry | Cost-efficient; in production, would add WAF and DDoS protection |
| Manual bootstrap image | First deployment requires manual push | ACR is empty after fresh terraform apply; CI automates all subsequent builds |


## Production Improvements
If this were a production deployment, I would add:

- Network Policies: default-deny per namespace with selective allow rules for pod-to-pod communication, matching the defense-in-depth approach used at the infrastructure level
- Kyverno Policy Engine: enforce CIS Benchmark controls as admission policies — require non-root containers, resource limits, trusted registries, and standard labels across all namespaces
- Alertmanager: alert routing, grouping, and notification (Slack, PagerDuty) with SLO-based burn rate alerts rather than threshold-based alerting
- Thanos: long-term metric storage in Azure Blob, enabling multi-cluster querying and cost-efficient retention beyond the 24h demo default
- External Secrets Operator: sync secrets from Azure Key Vault into Kubernetes Secrets, keeping sensitive values out of Git entirely
- Disaster Recovery: cross-region AKS cluster with Azure Traffic Manager for DNS failover, async database replication, and Velero for cluster state backup. RTO target: 5 minutes
- mTLS via Service Mesh: Istio or Linkerd for encrypted, authenticated service-to-service communication within the cluster
- Pod Identity (Workload Identity): federate Kubernetes ServiceAccounts with Azure Managed Identities for per-pod Azure resource access without cluster-wide credentials
- Multi-region deployment: active-passive with automated failover for geographic redundancy and data sovereignty compliance
- Log aggregation: Grafana Loki for centralized log collection alongside Prometheus metrics, queried through the same Grafana dashboards
- RBAC hardening: namespace-scoped Roles for development teams with read-only ClusterRoles for cross-namespace visibility
- Terraform modules: refactor into reusable modules (networking, AKS, monitoring) for multi-environment/multi-region deployment
