#!/bin/bash
set -e  # Exit immediately if any command fails

# Function to install Kubernetes components
install_kubernetes() {
    local container=$1
    echo "Installing Kubernetes components in $container..."
    docker exec $container bash -c '
        # Update package lists and install dependencies
        apt-get update && \
        apt-get install -y apt-transport-https ca-certificates curl gnupg && \
        
        # Add Kubernetes repository
        mkdir -p /usr/share/keyrings && \
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
        gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg && \
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
        https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list && \
        
        # Install Kubernetes components
        apt-get update && \
        apt-get install -y kubelet=1.28.15-1.1 kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1 && \
        apt-mark hold kubelet kubeadm kubectl
    '
}

# Function to initialize Kubernetes master
init_master() {
    echo "Initializing Kubernetes master node..."
    docker exec k8s-master bash -c '
        # Clean up any previous installation
        kubeadm reset -f --cri-socket=unix:///run/containerd/containerd.sock && \
        
        # Initialize cluster
        kubeadm init \
          --pod-network-cidr=10.244.0.0/16 \
          --ignore-preflight-errors=Swap \
          --cri-socket=unix:///run/containerd/containerd.sock \
          --kubernetes-version=v1.28.15 \
          --control-plane-endpoint=172.18.0.3 \
          --image-repository=registry.k8s.io && \
        
        # Set up kubectl
        mkdir -p $HOME/.kube && \
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
        chown $(id -u):$(id -g) $HOME/.kube/config
    '
    
    # Install Flannel CNI
    echo "Installing Flannel network..."
    docker exec k8s-master kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
}

# Function to join worker nodes
join_workers() {
    # Get join command
    JOIN_CMD=$(docker exec k8s-master kubeadm token create --print-join-command --ttl=1h)
    
    # Join each worker node
    for i in {1..2}; do
        echo "Joining worker node-$i to cluster..."
        docker exec node-$i bash -c "$JOIN_CMD"
    done
}

# Function to verify cluster status
verify_cluster() {
    echo "Verifying cluster status..."
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if docker exec k8s-master kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            echo -e "\nCluster is ready!"
            docker exec k8s-master kubectl get nodes
            return 0
        fi
        
        attempts=$((attempts+1))
        echo "Waiting for cluster to be ready... ($attempts/$max_attempts)"
        sleep 10
    done
    
    echo -e "\nError: Cluster initialization timed out"
    docker exec k8s-master kubectl get pods -A || true
    return 1
}

### Main Execution ###

echo "Waiting for containers to be fully initialized..."
sleep 30

# Install Kubernetes on all nodes
install_kubernetes k8s-master
for i in {1..2}; do
    install_kubernetes node-$i
done

# Initialize cluster
init_master
join_workers

# Verify cluster status
verify_cluster || exit 1

echo "Kubernetes cluster initialized successfully!"
