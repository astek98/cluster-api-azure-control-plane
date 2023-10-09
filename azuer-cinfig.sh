{
  "appId": "41a43a4d-7aa0-4239-9e78-d8d513b9d37c",
  "displayName": "cluster-api",
  "password": "XQP8Q~rSrVO4XoxjEiodqcLaCkLTA7z4e_fwCcbZ",
  "tenant": "a668e2df-779d-476e-b9c4-6273d4211ec3"
}


export AZURE_SUBSCRIPTION_ID="ea23f33b-f226-4c3f-9c14-aabb8b63b8c8"

# Create an Azure Service Principal and paste the output here
export AZURE_TENANT_ID="a668e2df-779d-476e-b9c4-6273d4211ec3"
export AZURE_CLIENT_ID="41a43a4d-7aa0-4239-9e78-d8d513b9d37c"
export AZURE_CLIENT_SECRET="XQP8Q~rSrVO4XoxjEiodqcLaCkLTA7z4e_fwCcbZ"

# Base64 encode the variables
export AZURE_SUBSCRIPTION_ID_B64="$(echo -n "$AZURE_SUBSCRIPTION_ID" | base64 | tr -d '\n')"
export AZURE_TENANT_ID_B64="$(echo -n "$AZURE_TENANT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_ID_B64="$(echo -n "$AZURE_CLIENT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_SECRET_B64="$(echo -n "$AZURE_CLIENT_SECRET" | base64 | tr -d '\n')"

# Settings needed for AzureClusterIdentity used by the AzureCluster
export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
export CLUSTER_IDENTITY_NAME="cluster-identity"
export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"

# Create a secret to include the password of the Service Principal identity created in Azure
# This secret will be referenced by the AzureClusterIdentity used by the AzureCluster
kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}" --namespace "${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}"

# Finally, initialize the management cluster
clusterctl init --infrastructure azure


export AZURE_LOCATION="eastus"

# Select VM types.
export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_D2s_v3"
export AZURE_NODE_MACHINE_TYPE="Standard_D2s_v3"

# [Optional] Select resource group. The default value is ${CLUSTER_NAME}.
export AZURE_RESOURCE_GROUP="aks-capi"

clusterctl generate cluster my-cluster --kubernetes-version v1.26.1


clusterctl generate cluster capi-azure \
  --kubernetes-version v1.26.7 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  > capi-azure.yaml

  helm install --kubeconfig=./capi-azure.kubeconfig \
  --repo https://raw.githubusercontent.com/kubernetes-sigs/cloud-provider-azure/master/helm/repo cloud-provider-azure \
  --generate-name --set infra.clusterName=capi-azure \
  --set cloudControllerManager.clusterCIDR="192.168.0.0/16"

helm repo add projectcalico https://docs.tigera.io/calico/charts --kubeconfig=./capi-azure.kubeconfig && \
helm install calico projectcalico/tigera-operator --kubeconfig=./capi-azure.kubeconfig \
-f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico/values.yaml \
--namespace tigera-operator --create-namespace

helm repo add projectcalico https://docs.tigera.io/calico/charts --kubeconfig=./capi-quickstart.kubeconfig && \
helm install calico projectcalico/tigera-operator --kubeconfig=./capi-quickstart.kubeconfig -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico/values.yaml --namespace tigera-operator --create-namespace

