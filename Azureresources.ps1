az login
az account set --subscription 6b8ab91c-076a-4902-8afc-7a8f3f777754

az group create -n kubeadm -l eastus

# n/w setup

az network vnet create --resource-group kubeadm --name kubeadm --address-prefix 192.168.0.0/16 --subnet-name kube --subnet-prefix 192.168.0.0/16

az network nsg create --resource-group kubeadm --name kubeadm

az network nsg rule create --resource-group kubeadm --nsg-name kubeadm --name kubeadmssh --protocol tcp --priority 1000 --destination-port-range 22 --access allow

az network nsg rule create --resource-group kubeadm --nsg-name kubeadm --name kubeadmWeb --protocol tcp --priority 1001 --destination-port-range 6443 --access allow

az network vnet subnet update -g kubeadm -n kube --vnet-name kubeadm --network-security-group kubeadm

# Generate SSH keys

ssk-keygen <pass phrase> ssh
    Your identification has been saved in C:\Users\A240595/.ssh/id_rsa
    Your public key has been saved in C:\Users\A240595/.ssh/id_rsa.pub
    The key fingerprint is:
    SHA256:MbpmXmmpLgS9fF4nJTgPA3+o8HLN3d5DoX+5h750sD8 geico\a240595@GEIJY7ZP73

# Setup VMs

az vm create -n kube-master-1 -g kubeadm -l eastus --image UbuntuLTS `
--vnet-name kubeadm --subnet kube `
--admin-username bbadmin `
--ssk-key-values @C:\Users\A240595/.ssh/id_rsa.pub `
--size Standard_D2s_v3 `
--nsg kubeadm `
--public-ip-sku Standard --no-wait

az vm create -n kube-worker-1 -g kubeadm \
--image UbuntuLTS \
--vnet-name kubeadm --subnet kube \
--admin-username bbadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2s_v3 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

# ILB setup

az network public-ip create --resource-group kubeadm --name controlplaneip --sku Standard --dns-name bbkubeadm

{
  "publicIp": {
    "ddosSettings": {
      "protectionMode": "VirtualNetworkInherited"
    },
    "dnsSettings": {
      "domainNameLabel": "bbkubeadm",
      "fqdn": "bbkubeadm.eastus.cloudapp.azure.com"
    },
    "etag": "W/\"af13ea4a-6c92-44cf-9292-a4c7b8dddb19\"",
    "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/publicIPAddresses/controlplaneip",
    "idleTimeoutInMinutes": 4,
    "ipAddress": "20.169.229.253",
    "ipTags": [],
    "location": "eastus",
    "name": "controlplaneip",
    "provisioningState": "Succeeded",
    "publicIPAddressVersion": "IPv4",
    "publicIPAllocationMethod": "Static",
    "resourceGroup": "kubeadm",
    "resourceGuid": "2fa03130-ac22-4473-aea5-79c904b9926b",
    "sku": {
      "name": "Standard",
      "tier": "Regional"
    },
    "type": "Microsoft.Network/publicIPAddresses"
  }
}

az network lb create --resource-group kubeadm --name kubemaster --sku Standard --public-ip-address controlplaneip --frontend-ip-name controlplaneip --backend-pool-name masternodes

{
  "loadBalancer": {
    "backendAddressPools": [
      {
        "etag": "W/\"2f0d7359-9c3b-45de-9aeb-32cf194f4e77\"",
        "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/backendAddressPools/masternodes",
        "name": "masternodes",
        "properties": {
          "loadBalancerBackendAddresses": [],
          "provisioningState": "Succeeded"
        },
        "resourceGroup": "kubeadm",
        "type": "Microsoft.Network/loadBalancers/backendAddressPools"
      }
    ],
    "frontendIPConfigurations": [
      {
        "etag": "W/\"2f0d7359-9c3b-45de-9aeb-32cf194f4e77\"",
        "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/frontendIPConfigurations/controlplaneip",
        "name": "controlplaneip",
        "properties": {
          "privateIPAllocationMethod": "Dynamic",
          "provisioningState": "Succeeded",
          "publicIPAddress": {
            "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/publicIPAddresses/controlplaneip",
            "resourceGroup": "kubeadm"
          }
        },
        "resourceGroup": "kubeadm",
        "type": "Microsoft.Network/loadBalancers/frontendIPConfigurations"
      }
    ],
    "inboundNatPools": [],
    "inboundNatRules": [],
    "loadBalancingRules": [],
    "outboundRules": [],
    "probes": [],
    "provisioningState": "Succeeded",
    "resourceGuid": "2847637c-f32b-4c99-8154-970853f61d75"
  }
}

az network lb probe create --resource-group kubeadm --lb-name kubemaster --name kubemasterweb --protocol tcp --port 6443

{
  "etag": "W/\"a1a3c775-5475-4bed-b24d-da927c6a8320\"",
  "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/probes/kubemasterweb",
  "intervalInSeconds": 15,
  "name": "kubemasterweb",
  "numberOfProbes": 2,
  "port": 6443,
  "probeThreshold": 1,
  "protocol": "Tcp",
  "provisioningState": "Succeeded",
  "resourceGroup": "kubeadm",
  "type": "Microsoft.Network/loadBalancers/probes"
}

az network lb rule create --resource-group kubeadm --lb-name kubemaster --name kubemaster `
--protocol tcp --frontend-port 6443 --backend-port 6443 --frontend-ip-name controlplaneip --backend-pool-name masternodes `
--probe-name kubemasterweb --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true

{
  "backendAddressPool": {
    "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/backendAddressPools/masternodes",
    "resourceGroup": "kubeadm"
  },
  "backendAddressPools": [
    {
      "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/backendAddressPools/masternodes",
      "resourceGroup": "kubeadm"
    }
  ],
  "backendPort": 6443,
  "disableOutboundSnat": true,
  "enableFloatingIP": false,
  "enableTcpReset": true,
  "etag": "W/\"4821901d-1207-4825-acd3-2e4a8e3f4e21\"",
  "frontendIPConfiguration": {
    "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/frontendIPConfigurations/controlplaneip",
    "resourceGroup": "kubeadm"
  },
  "frontendPort": 6443,
  "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/loadBalancingRules/kubemaster",
  "idleTimeoutInMinutes": 15,
  "loadDistribution": "Default",
  "name": "kubemaster",
  "probe": {
    "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/probes/kubemasterweb",
    "resourceGroup": "kubeadm"
  },
  "protocol": "Tcp",
  "provisioningState": "Succeeded",
  "resourceGroup": "kubeadm",
  "type": "Microsoft.Network/loadBalancers/loadBalancingRules"
}

az network nic ip-config address-pool add `
    --address-pool masternodes `
    --ip-config-name ipconfig1 `
    --nic-name kube-master-1490_z1 `
    --resource-group kubeadm `
    --lb-name kubemaster

{
  "etag": "W/\"3daf3e6a-3698-4dce-a831-f60e54542319\"",
  "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/networkInterfaces/kube-master-1490_z1/ipConfigurations/ipconfig1",
  "loadBalancerBackendAddressPools": [
    {
      "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/loadBalancers/kubemaster/backendAddressPools/masternodes",
      "resourceGroup": "kubeadm"
    }
  ],
  "name": "ipconfig1",
  "primary": true,
  "privateIPAddress": "192.168.0.4",
  "privateIPAddressVersion": "IPv4",
  "privateIPAllocationMethod": "Dynamic",
  "provisioningState": "Succeeded",
  "publicIPAddress": {
    "deleteOption": "Detach",
    "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/publicIPAddresses/kube-master-1-ip",
    "resourceGroup": "kubeadm"
  },
  "resourceGroup": "kubeadm",
  "subnet": {
    "id": "/subscriptions/6b8ab91c-076a-4902-8afc-7a8f3f777754/resourceGroups/kubeadm/providers/Microsoft.Network/virtualNetworks/kubeadm/subnets/kube",
    "resourceGroup": "kubeadm"
  },
  "type": "Microsoft.Network/networkInterfaces/ipConfigurations"
}

# Installing kubeadm and kubectl

sudo apt update
sudo apt -y install curl apt-transport-https;

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd;

sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version

# setup CRI

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# final kubeadm blow

sudo kubeadm init --control-plane-endpoint "bbkubeadm.eastus.cloudapp.azure.com:6443" --upload-certs

Your Kubernetes control-plane has initialized successfully!

# -- Begin O/P
To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join bbkubeadm.eastus.cloudapp.azure.com:6443 --token n3ctik.elcykr7lp89xrk98 \
        --discovery-token-ca-cert-hash sha256:fa94cef5c0ef78e6aec202d1a59b5ff5530a7c4fe4ab8ae601f02e5ab77e88ec \
        --control-plane --certificate-key f34d50cf109097477ad8ec19b0f65dca9692f1f16b48614781b301a25b99aec8

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join bbkubeadm.eastus.cloudapp.azure.com:6443 --token n3ctik.elcykr7lp89xrk98 \
        --discovery-token-ca-cert-hash sha256:fa94cef5c0ef78e6aec202d1a59b5ff5530a7c4fe4ab8ae601f02e5ab77e88ec

# End O/P

# Setup CNI

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Set worker

sudo apt update
sudo apt -y install curl apt-transport-https </dev/null


curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd </dev/null


sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Test app deployment

kubectl create -f https://github.com/Azure-Samples/azure-voting-app-redis/blob/master/azure-vote-all-in-one-redis.yaml
kubectl port-forward service/azure-vote-front 8080:80

