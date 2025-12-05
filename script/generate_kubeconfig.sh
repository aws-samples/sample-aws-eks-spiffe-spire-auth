#!/bin/bash
# Define namespaces and cluster names
CLUSTER_NAMES=("spire-child-cluster-01" "spire-child-cluster-02")
NAMESPACE="spire-system"

# Store current kubeconfig
ORIGINAL_KUBECONFIG=$KUBECONFIG

# Loop through each cluster
for CLUSTER_NAME in "${CLUSTER_NAMES[@]}"; do
  # Set temporary kubeconfig for this operation
  export KUBECONFIG=$(mktemp)

  # Update the kubeconfig with aws eks update-kubeconfig
  aws eks update-kubeconfig --name ${CLUSTER_NAME} --alias ${CLUSTER_NAME} --kubeconfig ${KUBECONFIG}

  # Get the cluster certificate authority data and endpoint
  CLUSTER_CA=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.certificateAuthority.data' --output text)
  CLUSTER_ENDPOINT=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.endpoint' --output text)

  # Get the service account token from the secret
  AGENT_TOKEN=$(kubectl --kubeconfig=${KUBECONFIG} get secret kubeconfigtoken --namespace=${NAMESPACE} -o jsonpath='{.data.token}' | base64 --decode)

  # Build the kubeconfig and encode it with base64
  cat <<EOF | base64 -w0 > ${CLUSTER_NAME}.kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_ENDPOINT}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${CLUSTER_NAME}
  name: ${CLUSTER_NAME}
current-context: ${CLUSTER_NAME}
users:
- name: ${CLUSTER_NAME}
  user:
    token: ${AGENT_TOKEN}
EOF

  # Output the encoded kubeconfig for use
  echo "Kubeconfig for ${CLUSTER_NAME} generated and encoded as ${CLUSTER_NAME}.kubeconfig"

  # Decode the kubeconfig for verification
  base64 --decode ${CLUSTER_NAME}.kubeconfig > decoded-${CLUSTER_NAME}.kubeconfig

  # Clean up temporary kubeconfig
  rm $KUBECONFIG
done

# Restore original kubeconfig
export KUBECONFIG=$ORIGINAL_KUBECONFIG