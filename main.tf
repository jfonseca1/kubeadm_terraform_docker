terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

provider "docker" {}

# Create a Docker network for the Kubernetes cluster
resource "docker_network" "k8s_network" {
  name = "k8s-network"
}

# Define the Docker image for kubeadm
resource "docker_image" "ubuntu" {
  name         = "ubuntu:22.04"
  keep_locally = true
}

# Create the Kubernetes master node
resource "docker_container" "k8s_master" {
  name  = "k8s-master"
  image = docker_image.ubuntu.image_id
  
  command = ["/bin/bash", "-c", "while true; do sleep 30; done"]
  
  networks_advanced {
    name = docker_network.k8s_network.name
  }
  
  hostname = "k8s-master"
  
  # Required for kubeadm to work properly
  privileged = true
  
  # Mount /sys/fs/cgroup for systemd
  mounts {
    target = "/sys/fs/cgroup"
    type   = "bind"
    source = "/sys/fs/cgroup"
    bind_options {
      propagation = "rshared"
    }
  }
  
  # Expose Kubernetes API port
  ports {
    internal = 6443
    external = 6443
  }
  
  # Setup for kubeadm
  provisioner "remote-exec" {
    inline = [
      # Update and install dependencies
      "apt-get update",
      "apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release systemd",
      
      # Install Docker
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt-get update",
      "apt-get install -y docker-ce docker-ce-cli containerd.io",
      
      # Install kubeadm, kubelet, and kubectl
      "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main\" | tee /etc/apt/sources.list.d/kubernetes.list",
      "apt-get update",
      "apt-get install -y kubelet kubeadm kubectl",
      "apt-mark hold kubelet kubeadm kubectl",
      
      # Configure containerd
      "mkdir -p /etc/containerd",
      "containerd config default | tee /etc/containerd/config.toml",
      "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml",
      "systemctl restart containerd",
      
      # Configure sysctl settings for Kubernetes
      "cat <<EOF | tee /etc/sysctl.d/k8s.conf\nnet.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nEOF",
      "sysctl --system"
    ]
  }
}

# Create Kubernetes worker nodes
resource "docker_container" "k8s_worker" {
  count = 2
  
  name  = "k8s-worker-${count.index}"
  image = docker_image.ubuntu.image_id
  
  command = ["/bin/bash", "-c", "while true; do sleep 30; done"]
  
  networks_advanced {
    name = docker_network.k8s_network.name
  }
  
  hostname = "k8s-worker-${count.index}"
  
  # Required for kubeadm to work properly
  privileged = true
  
  # Mount /sys/fs/cgroup for systemd
  mounts {
    target = "/sys/fs/cgroup"
    type   = "bind"
    source = "/sys/fs/cgroup"
    bind_options {
      propagation = "rshared"
    }
  }
  
  # Setup for kubeadm worker nodes
  provisioner "remote-exec" {
    inline = [
      # Update and install dependencies
      "apt-get update",
      "apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release systemd",
      
      # Install Docker
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt-get update",
      "apt-get install -y docker-ce docker-ce-cli containerd.io",
      
      # Install kubeadm, kubelet, and kubectl
      "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main\" | tee /etc/apt/sources.list.d/kubernetes.list",
      "apt-get update",
      "apt-get install -y kubelet kubeadm kubectl",
      "apt-mark hold kubelet kubeadm kubectl",
      
      # Configure containerd
      "mkdir -p /etc/containerd",
      "containerd config default | tee /etc/containerd/config.toml",
      "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml",
      "systemctl restart containerd",
      
      # Configure sysctl settings for Kubernetes
      "cat <<EOF | tee /etc/sysctl.d/k8s.conf\nnet.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nEOF",
      "sysctl --system"
    ]
  }
}
