#!/usr/bin/env bash
set -euo pipefail

# export DEBIAN_FRONTEND=noninteractive

# use motd approach to send message for user on login
# echo "# motd ..."
# curl -L -o 01-custom 'https://raw.githubusercontent.com/astek98/cluster-api-azure-control-plane/main/01-custom'
# mv 01-custom /etc/update-motd.d/
# sudo chmod +x /etc/update-motd.d/01-custom
echo "# Installing prerequisites ..."

echo "# Install kubectl..."
VERSION_KUBECTL="v1.26.9"
# VERSION_KUBECTL=(curl -L -s https://dl.k8s.io/release/stable.txt)
curl  -o kubectl -fsSL "https://dl.k8s.io/release/${VERSION_KUBECTL}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# kubectl version -o json

echo "# Install clusterctl..."
VERSION_CLUSTERCTL="v1.5.2"
curl -o clusterctl -fsSL https://github.com/kubernetes-sigs/cluster-api/releases/download/${VERSION_CLUSTERCTL}/clusterctl-linux-amd64
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
# clusterctl version -o json

echo "# Install helm..."
curl -o get-helm-3.sh -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo sh get-helm-3.sh
# helm version

# Maybe will require to change to package installatiom
echo "# Install docker by script..."
curl -o get-docker.sh -fsSL https://get.docker.com
sudo sh get-docker.sh
# docker version

echo "# Install kind..."
VERSION_KIND="v0.20.0"
curl -o kind -fsSL https://kind.sigs.k8s.io/dl/${VERSION_KIND}/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
# kind version

echo "# complete!"

