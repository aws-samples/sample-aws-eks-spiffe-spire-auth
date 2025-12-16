# SPIRE Nested Deployment on AWS EKS: A Complete Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Infrastructure Components](#infrastructure-components)
5. [Configuration Details](#configuration-details)
6. [Deployment Process](#deployment-process)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Introduction

SPIRE (SPIFFE Runtime Environment) is an open-source implementation of the SPIFFE (Secure Production Identity Framework for Everyone) specification. This guide demonstrates how to deploy SPIRE in a nested configuration across multiple AWS EKS clusters, providing secure workload identity and attestation in a distributed environment.

### Critical Configuration Note: Service Name Length Constraints

**IMPORTANT**: When deploying SPIRE nested, the cluster identifiers used in Helm commands must be **7 characters or fewer**. This is due to Internet Assigned Numbers Authority (IANA) that constraints the limit  of the service names to 15 characters maximum.

[RFC 6335 Section 5.1](https://www.rfc-editor.org/rfc/rfc6335.html#section-5.1):

- Valid service names are hereby normatively defined as follows:
  - MUST be at least 1 character and no more than 15 characters long


The SPIRE Helm chart appends these identifiers to service names, causing deployment failures if too long.

**Example of the constraint:**

```bash
# ❌ This will FAIL - "ABCDEFG-qa-01" is too long (12 characters)
--set "external-spire-server.kubeConfigs.ABCDEFG-qa-01.kubeConfigBase64=..."

# ✅ This will WORK - "child01" is short enough (7 characters)  
--set "external-spire-server.kubeConfigs.child01.kubeConfigBase64=..."
```

The cluster identifier (e.g., `child01`) is:

- Used only for Helm configuration - it doesn't need to match the actual EKS cluster name
- Appended to service names by the Helm template
- Must comply with RFC 6335 naming constraints

### What is SPIRE Nested?

SPIRE Nested is a deployment pattern where:

- A **root SPIRE server** runs on a dedicated cluster and acts as the certificate authority
- **Child SPIRE servers** run on separate clusters and obtain their identity from the root server
- **SPIRE agents** on each cluster facilitate workload attestation and SVID (SPIFFE Verifiable Identity Document) distribution

This architecture provides:

- Centralized identity management across multiple clusters
- Scalable workload identity distribution
- Secure inter-cluster communication
- Simplified certificate management

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Root Cluster                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              SPIRE Root Server                              ││
│  │  - Certificate Authority                                    ││
│  │  - Manages child server identities                         ││
│  │  - Connected to RDS MySQL datastore                        ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ Trust relationship
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼─────────┐    ┌────────▼────────┐    ┌────────▼────────┐
│  Child Cluster 1│    │  Child Cluster 2│    │  Child Cluster N│
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Child Server │ │    │ │Child Server │ │    │ │Child Server │ │
│ │SPIRE Agent  │ │    │ │SPIRE Agent  │ │    │ │SPIRE Agent  │ │
│ │Workloads    │ │    │ │Workloads    │ │    │ │Workloads    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Components

1. **Root Cluster** (`spire-root-cluster`): Hosts the root SPIRE server
2. **Child Clusters** (`spire-child-01`, `spire-child-02`): Host child SPIRE servers and workloads
3. **RDS MySQL**: Persistent datastore for the root SPIRE server
4. **Kubeconfig Generator**: Script to create secure cluster access configurations

## Prerequisites

Before starting the deployment, ensure you have:

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Helm 3.x installed
- kubectx (optional but recommended for context switching)
- Terraform (for infrastructure deployment)
- Access to create EKS clusters, RDS instances, and associated networking resources

### Required AWS Permissions

Your AWS credentials need permissions for:

- EKS cluster creation and management
- RDS instance creation and management
- VPC and networking resource management
- IAM role and policy management
- Secrets Manager (for database credentials)

## Infrastructure Components

### 1. EKS Clusters

The deployment consists of three EKS clusters:

#### Root Cluster (`infrastructure/eks/spire-root-cluster/`)

- **Purpose**: Hosts the root SPIRE server
- **Name**: `spire-root-cluster`
- **Region**: `us-east-1`
- **Node Groups**: Optimized for SPIRE server workloads
- **Networking**: Dedicated VPC with private subnets

#### Child Cluster 1 (`infrastructure/eks/spire-child-cluster-01/`)

- **Purpose**: Hosts child SPIRE server and application workloads
- **Name**: `spire-child-01`
- **Region**: `us-east-1`
- **Node Groups**: Mixed instance types for diverse workloads

#### Child Cluster 2 (`infrastructure/eks/spire-child-cluster-02/`)

- **Purpose**: Hosts child SPIRE server and application workloads
- **Name**: `spire-child-02`
- **Region**: `us-east-1`
- **Node Groups**: Mixed instance types for diverse workloads

### 2. RDS MySQL Datastore (`infrastructure/rds/spire-datastore/`)

The root SPIRE server requires persistent storage for:

- Registration entries
- Node attestation data
- Certificate authority information
- Audit logs

**Configuration:**

- **Engine**: MySQL 8.0
- **Instance Class**: Serverless v2 (auto-scaling)
- **Storage**: Encrypted with AWS KMS
- **Backup**: Automated daily backups
- **Multi-AZ**: Enabled for high availability

### 3. Networking Architecture

Each cluster is deployed in its own VPC with:

- **Public Subnets**: For load balancers and NAT gateways
- **Private Subnets**: For EKS nodes and RDS instances
- **Security Groups**: Restrictive rules for inter-cluster communication
- **VPC Peering**: Enables secure communication between clusters

## Configuration Details

### Helm Values Structure

The deployment uses multiple Helm values files:

#### `your-values.yaml`

Contains common configuration shared across all clusters:

- Image registry settings (for private registries)
- Resource limits and requests
- Security contexts
- Logging configuration

#### `root-values.yaml`

Specific configuration for the root SPIRE server:

- Database connection settings
- Trust domain configuration
- External cluster access settings
- Certificate authority configuration

#### `spire-child-cluster-01.yaml` and `spire-child-cluster-02.yaml`

Child-specific configurations:

- Parent server connection details
- Local cluster settings
- Node attestation configuration

### Key Configuration Parameters

#### Root Server Configuration

```yaml
spire-server:
  dataStore:
    sql:
      databaseType: mysql
      databaseName: sharedqaspireserver
      host: "demo-serverless-mysqlv2.cluster-abc123def456.us-east-1.rds.amazonaws.com"
      port: 3306
      region: "us-east-1"
      username: spireadmin
      externalSecret:
        enabled: true
        name: spire-db-secret
        key: password

  trustDomain: "spireserver.example.com"
  
  nodeAttestor:
    k8sPSAT:
      serviceAccountAllowList:
        - "spire-mgmt:spire-agent"
        - "default:default"
```

#### Child Server Configuration

```yaml
spire-server:
  upstreamAuthority:
    spire:
      enabled: true
      upstreamDriver: "spire-plugin"
      serverAddress: "spire-server.spire-mgmt.svc.cluster.local"
      serverPort: 8081
      
  trustDomain: "spireserver.example.com"
```

## Deployment Process

### Step 1: Deploy Infrastructure

Deploy the infrastructure components using Terraform:

#### 1a. Deploy Aurora MySQL

```bash
cd infrastructure/rds/spire-datastore/
terraform init
terraform plan
terraform apply
```

#### 1b. Deploy Root EKS Cluster

```bash
cd ../../eks/spire-root-cluster/
terraform init
terraform plan
terraform apply
```

#### 1c. Deploy Child Cluster 01

```bash
cd ../spire-child-cluster-01/
terraform init
terraform plan
terraform apply
```

#### 1d. Deploy Child Cluster 02

```bash
cd ../spire-child-cluster-02/
terraform init
terraform plan
terraform apply
```

### Step 2: Setup Kubeconfigs Locally

Update your kubeconfig files for all three clusters:

```bash
aws eks --region us-east-1 update-kubeconfig --name spire-root-cluster
aws eks --region us-east-1 update-kubeconfig --name spire-child-cluster-01
aws eks --region us-east-1 update-kubeconfig --name spire-child-cluster-02
```

### Step 3: Run the Generate Kubeconfig Script

In the `nested/script` directory, execute the script to generate base64-encoded kubeconfigs:

```bash
cd script
./generate_kubeconfig.sh
```

**What this script does:**

1. Creates temporary kubeconfig files for each child cluster
2. Extracts cluster certificate authority data and endpoints
3. Retrieves service account tokens from the `spire-system` namespace
4. Generates base64-encoded kubeconfig files for secure cluster access
5. Creates both encoded and decoded versions for verification

### Step 4: Use the Root Cluster Context

Switch to the root cluster context:

```bash
kubectx arn:aws:eks:us-east-1:111122223333:cluster/spire-root-cluster
```

### Step 5: Install CRDs on the Root Cluster

Navigate back to the `nested/helm` directory and install the CRDs on the root cluster:

```bash
cd ../helm
helm upgrade --install --create-namespace -n spire-mgmt spire-crds spire-crds \
--repo https://spiffe.github.io/helm-charts-hardened/
```

### Step 6: Install the Root Server

Install the root server using the encoded kubeconfigs for child clusters:

```bash
helm upgrade --install -n spire-mgmt spire spire-nested --repo https://spiffe.github.io/helm-charts-hardened/ \
--set "external-spire-server.kubeConfigs.child01.kubeConfigBase64=$(cat ../script/spire-child-cluster-01.kubeconfig)" \
--set "external-spire-server.kubeConfigs.child02.kubeConfigBase64=$(cat ../script/spire-child-cluster-02.kubeconfig)" \
-f your-values.yaml -f root-values.yaml
```

**Command Explanation:**

- `child01` and `child02` are short identifiers (≤7 chars) to avoid service name length issues
- These identifiers are used internally by Helm and don't need to match cluster names
- The actual cluster access is provided by the base64-encoded kubeconfig files
- Each `kubeConfigBase64` parameter contains the complete authentication information for accessing the respective child cluster

### Step 7: Setup Child Cluster spire-child-cluster-01

#### 7a. Switch to spire-child-cluster-01 Cluster

Switch to the `spire-child-cluster-01` cluster context:

```bash
kubectx arn:aws:eks:us-east-1:111122223333:cluster/spire-child-cluster-01
```

#### 7b. Mark spire-system namespace as Helm-managed for the spire release

```bash
kubectl label namespace spire-system app.kubernetes.io/managed-by=Helm --overwrite && kubectl annotate namespace spire-system meta.helm.sh/release-name=spire meta.helm.sh/release-namespace=spire-mgmt --overwrite
```

#### 7c. Install CRDs and Server for spire-child-cluster-01

Install the CRDs and server for `spire-child-cluster-01`:

```bash
helm upgrade --install --create-namespace -n spire-mgmt spire-crds spire-crds \
--repo https://spiffe.github.io/helm-charts-hardened/
helm upgrade --install -n spire-mgmt spire spire-nested --repo https://spiffe.github.io/helm-charts-hardened/ \
-f your-values.yaml -f spire-child-cluster-01.yaml
```

### Step 8: Setup Child Cluster spire-child-cluster-02

#### 8a. Switch to spire-child-cluster-02 Cluster

Switch to the `spire-child-cluster-02` cluster context:

```bash
kubectx arn:aws:eks:us-east-1:111122223333:cluster/spire-child-cluster-02
```

#### 8b. Mark spire-system namespace as Helm-managed for the spire release

```bash
kubectl label namespace spire-system app.kubernetes.io/managed-by=Helm --overwrite && kubectl annotate namespace spire-system meta.helm.sh/release-name=spire meta.helm.sh/release-namespace=spire-mgmt --overwrite
```

#### 8c. Install CRDs and Server for spire-child-cluster-02

Install the CRDs and server for `spire-child-cluster-02` using the specific child values file:

```bash
helm upgrade --install --create-namespace -n spire-mgmt spire-crds spire-crds \
--repo https://spiffe.github.io/helm-charts-hardened/
helm upgrade --install -n spire-mgmt spire spire-nested --repo https://spiffe.github.io/helm-charts-hardened/ \
-f your-values.yaml -f spire-child-cluster-02.yaml
```

### Step 9: Deploy Envoy Test Application

#### 9a. Switch to spire-child-cluster-01

Ensure you're connected to the child cluster:

```bash
kubectx arn:aws:eks:us-east-1:111122223333:cluster/spire-child-cluster-01
```

#### 9b. Update SPIFFE Trust Domain in ConfigMaps

Before deploying, update the trust domain in each `configmap.yaml` file under the `envoy/` directory to match your root cluster's trust domain.

For example, change:

```yaml
- name: "spiffe://spirenested.example.com/ns/ecommerce/sa/edge-proxy-service-account"
```

The domain must match the `trustDomain` value in `helm/root-values.yaml`:

```yaml
trustDomain: spirenested.example.com
```

#### 9c. Create Namespace and Deploy

Create the ecommerce namespace and deploy the application:

```bash
kubectl create ns ecommerce
kubectl apply -R -f envoy/
```

#### 9d. Get Network Load Balancer DNS

Wait for the NLB to provision, then retrieve its DNS:

```bash
kubectl get svc -n ecommerce edge-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

#### 9e. Test the Application

Access the GraphQL endpoint using the NLB DNS:

```text
http://<NLB-DNS>:8081/v1/graphql
```

Example:

```text
http://k8s-ecommerc-edgeprox-a1b2c3d4e5-f6g7h8i9j0k1l2m3.elb.us-east-1.amazonaws.com:8081/v1/graphql
```

Run this query to verify the deployment:

```graphql
query {
  orders {
    id
    orderFor
    product {
      id
      name
    }
  },
  products {
    id
    name
  }
}
```

You should see data for orders and products returned successfully.

#### 9f. Introduce a SPIFFE ID Mismatch

Edit `envoy/graphql/configmap.yaml` line 182 and change the SPIFFE ID from plural to singular:

```yaml
exact: "spiffe://spirenested.example.com/ns/ecommerce/sa/order-service-account"
```

Apply the change and restart the deployment:

```bash
kubectl apply -f envoy/graphql/configmap.yaml
kubectl rollout restart deployment graphql -n ecommerce
```

#### 9g. Observe the Error

Run the same GraphQL query. You'll see an error for orders:

```json
{
  "errors": [
    {
      "message": "Request failed with status code 503",
      "locations": [
        {
          "line": 2,
          "column": 3
        }
      ],
      "path": [
        "orders"
      ]
    }
  ]
}
```

This occurs because the SPIFFE ID no longer matches the orders service.

#### 9h. Fix the Issue

Revert the change back to the correct SPIFFE ID:

```yaml
exact: "spiffe://spirenested.example.com/ns/ecommerce/sa/orders-service-account"
```

Apply and restart:

```bash
kubectl apply -f envoy/graphql/configmap.yaml
kubectl rollout restart deployment graphql -n ecommerce
```

The query should now work correctly again.

## Cleanup

To tear down the infrastructure, run terraform destroy in reverse order:

### 1. Destroy Child Cluster 02

```bash
cd infrastructure/eks/spire-child-cluster-02/
terraform destroy
```

### 2. Destroy Child Cluster 01

```bash
cd ../spire-child-cluster-01/
terraform destroy
```

### 3. Destroy Root EKS Cluster

```bash
cd ../spire-root-cluster/
terraform destroy
```

### 4. Destroy Aurora MySQL

```bash
cd ../../rds/spire-datastore/
terraform destroy
```

## Security Considerations

1. **Network Policies**: Implement Kubernetes network policies to restrict traffic
2. **RBAC**: Use least-privilege service accounts
3. **Secrets Management**: Store sensitive data in AWS Secrets Manager
4. **Encryption**: Enable encryption at rest and in transit
5. **Audit Logging**: Enable comprehensive audit logging

## Troubleshooting

### Common Issues and Solutions

#### 1. Service Name Length Constraints

**Problem**: Helm template generates service names exceeding 15 characters (RFC 6335 limit)
**Error**: `must be no more than 15 characters`

**Root Cause**: The SPIRE Helm chart appends cluster identifiers to service names. For example:

- Template generates: `prom-cm-{CLUSTER_ID}`  
- With `ABCDEFG-qa-01`: becomes `prom-cm-ABCDEFG-qa-01` (21 characters) ❌
- With `child01`: becomes `prom-cm-child01` (15 characters) ✅

**Solution**: Use cluster identifiers of 7 characters or fewer:

```bash
# ❌ Too long - will cause deployment failure
--set "external-spire-server.kubeConfigs.routing-qa-01.kubeConfigBase64=..."

# ✅ Correct - short identifier
--set "external-spire-server.kubeConfigs.child01.kubeConfigBase64=..."
```

**Important**: The cluster identifier is only used for Helm templating and doesn't need to match the actual EKS cluster name.

#### 2. Image Registry Issues

**Problem**: Cannot pull images from public registries
**Solution**: Configure private registry in `your-values.yaml`:

```yaml
global:
  spire:
    image:
      registry: "your-private-registry.com"
```

#### 3. Storage Class Issues

**Problem**: `pod has unbound immediate PersistentVolumeClaims`
**Solution**: Ensure default storage class is configured:

```bash
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

#### 4. IP Exhaustion

**Problem**: Not enough IP addresses in VPC CIDR
**Solution**:

- Use larger CIDR blocks for VPCs
- Implement IP address management (IPAM)
- Consider using AWS VPC CNI with prefix delegation

#### 5. IMDSv2 Compatibility Issue

SPIRE does not currently support IMDSv2 when strictly enforced. The Terraform configuration sets `http_tokens = "optional"` to allow both IMDSv1 and IMDSv2:

```hcl
eks_managed_node_groups = {
  general-instances = {
    ...
    metadata_options = {
      http_endpoint = "enabled"
      http_tokens   = "optional"
    }
  }
}
```

For more details, see: [IMDSv2 Requirement Breaks aws_mysql and aws_postgres Authentication](https://github.com/spiffe/spire/issues/6118)

### Verification Commands

Check SPIRE server status:

```bash
kubectl exec -n spire-mgmt spire-server-0 -- /opt/spire/bin/spire-server healthcheck
```

List registration entries:

```bash
kubectl exec -n spire-mgmt spire-server-0 -- /opt/spire/bin/spire-server entry show
```

Check agent status:

```bash
kubectl exec -n spire-mgmt daemonset/spire-agent -- /opt/spire/bin/spire-agent healthcheck
```

## Best Practices

### 1. Infrastructure Management

- Use Infrastructure as Code (Terraform) for reproducible deployments
- Implement proper tagging strategies for resource management
- Use separate AWS accounts for different environments

### 2. Security

- Rotate certificates regularly
- Implement comprehensive monitoring and alerting
- Use AWS IAM roles for service accounts (IRSA)
- Enable AWS CloudTrail for audit logging

### 3. Operations

- Implement automated backup strategies for RDS
- Use GitOps for configuration management
- Implement proper CI/CD pipelines for updates
- Monitor resource utilization and costs

### 4. Scalability

- Plan for cluster growth and additional child clusters
- Implement horizontal pod autoscaling
- Use cluster autoscaling for dynamic node management
- Consider multi-region deployments for disaster recovery

## Conclusion

This SPIRE nested deployment provides a robust foundation for secure workload identity management across multiple Kubernetes clusters. The architecture scales well and provides the flexibility needed for complex microservices environments while maintaining strong security postures.

The combination of AWS managed services (EKS, RDS) with the SPIRE nested architecture creates a production-ready identity infrastructure that can support enterprise-scale applications with stringent security requirements.

For additional support and advanced configurations, refer to the [SPIRE documentation](https://spiffe.io/docs/) and the [Helm charts repository](https://github.com/spiffe/helm-charts-hardened).

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
