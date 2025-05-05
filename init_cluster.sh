#!/bin/bash

# Run this script after applying the Terraform configuration

# Initialize the Kubernetes master node
echo "Initializing Kubernetes master node..."
docker exec k8s-master kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k8s-master)

# Set up kubectl on master
echo "Setting up kubectl on master..."
docker exec k8s-master bash -c "mkdir -p /root/.kube && cp /etc/kubernetes/admin.conf /root/.kube/config"

# Install a pod network add-on (Flannel)
echo "Installing Flannel network..."
docker exec k8s-master kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Get the join command
echo "Getting kubeadm join command..."
JOIN_COMMAND=$(docker exec k8s-master kubeadm token create --print-join-command)
echo "Join command: $JOIN_COMMAND"

# Join worker nodes to the cluster
echo "Joining worker nodes to the cluster..."
for i in {0..1}; do
  echo "Joining worker $i..."
  docker exec k8s-worker-$i $JOIN_COMMAND
done

echo "Verifying cluster status..."
docker exec k8s-master kubectl get nodes

echo "Kubernetes cluster setup complete!"
