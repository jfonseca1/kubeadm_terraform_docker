#!/bin/bash

# Run this script after applying the Terraform configuration

# Verify that the tools are installed in the master container
echo "Verifying kubeadm installation on master..."
if ! docker exec k8s-master which kubeadm > /dev/null; then
  echo "Error: kubeadm not found in master container"
  echo "Installing kubeadm on master..."
  docker exec k8s-master bash -c '
    apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg && \
    mkdir -p /usr/share/keyrings && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubelet=1.28.15-1.1 kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1 && \
    apt-mark hold kubelet kubeadm kubectl
'
fi

# Initialize the Kubernetes master node
echo "Initializing Kubernetes master node..."
MASTER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k8s-master)
echo "Master IP: $MASTER_IP"

# Check if kubeadm is already initialized
if ! docker exec k8s-master [ -f /etc/kubernetes/admin.conf ]; then
  docker exec k8s-master kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$MASTER_IP
else
  echo "Kubernetes master appears to be already initialized"
fi

# Set up kubectl on master
echo "Setting up kubectl on master..."
docker exec k8s-master mkdir -p /root/.kube
docker exec k8s-master cp -f /etc/kubernetes/admin.conf /root/.kube/config
docker exec k8s-master chown $(id -u):$(id -g) /root/.kube/config

# Install a pod network add-on (Flannel)
echo "Installing Flannel network..."
docker exec k8s-master kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Wait for the control plane to be ready
echo "Waiting for the control plane to be ready..."
for i in {1..10}; do
  if docker exec k8s-master kubectl get nodes | grep -q "Ready"; then
    echo "Control plane is ready"
    break
  fi
  echo "Waiting... $i/10"
  sleep 10
  if [ $i -eq 10 ]; then
    echo "Timed out waiting for control plane to be ready"
    docker exec k8s-master kubectl get nodes
    docker exec k8s-master kubectl get pods -n kube-system
  fi
done

# Get the join command
echo "Getting kubeadm join command..."
JOIN_COMMAND=$(docker exec k8s-master kubeadm token create --print-join-command)
echo "Join command: $JOIN_COMMAND"

# Join worker nodes to the cluster
echo "Joining worker nodes to the cluster..."
for i in {0..1}; do
  echo "Joining worker $i..."
  # Verify that worker has kubeadm installed
  if ! docker exec k8s-worker-$i which kubeadm > /dev/null; then
    echo "Installing kubeadm on worker $i..."
    docker exec k8s-worker-$i bash -c '
      apt-get update && \
      apt-get install -y apt-transport-https ca-certificates curl gnupg && \
      mkdir -p /usr/share/keyrings && \
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg && \
      echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
      apt-get update && \
      apt-get install -y kubelet=1.28.15-1.1 kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1 && \
      apt-mark hold kubelet kubeadm kubectl
    '
  fi
  docker exec k8s-worker-$i bash -c "$JOIN_COMMAND"
done

echo "Waiting for worker nodes to join..."
sleep 30

echo "Verifying cluster status..."
docker exec k8s-master kubectl get nodes

echo "Kubernetes cluster setup complete!"
