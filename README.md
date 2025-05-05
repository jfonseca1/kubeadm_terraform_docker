# kubeadm_terraform_docker

# Kubernetes in Docker with kubeadm and Terraform

This repository automates the deployment of a Kubernetes cluster using kubeadm in Docker containers, managed by Terraform.

## Repository Structure

```
.
├── .github
│   └── workflows
│       └── github-workflow.yml
├── main.tf
├── init_cluster.sh
└── README.md
```

## How It Works

1. Terraform creates Docker containers that will act as Kubernetes nodes
2. kubeadm is installed on these containers
3. A Kubernetes cluster is initialized with one master node and two worker nodes
4. Flannel is deployed as the network plugin

## GitHub Workflow

The included GitHub workflow automates the following:

1. Setting up Terraform
2. Initializing and validating the Terraform configuration
3. Applying the Terraform plan to create the infrastructure
4. Initializing the Kubernetes cluster using kubeadm
5. Running basic tests to verify the cluster is working

## Manual Deployment

To deploy manually:

1. Clone this repository
   ```bash
   git clone https://github.com/yourusername/k8s-docker-terraform.git
   cd k8s-docker-terraform
   ```

2. Initialize Terraform
   ```bash
   terraform init
   ```

3. Apply the Terraform configuration
   ```bash
   terraform apply
   ```

4. Initialize the Kubernetes cluster
   ```bash
   ./init_cluster.sh
   ```

5. Verify the cluster
   ```bash
   docker exec k8s-master kubectl get nodes
   ```

## Requirements

- Docker
- Terraform >= 1.0.0
- Git

## Notes

- This setup is intended for development and testing purposes
- For production environments, consider using a managed Kubernetes service
- The GitHub workflow requires appropriate permissions to run Docker commands

## Troubleshooting

If you encounter issues with the cluster initialization:

1. Check the kubelet logs:
   ```bash
   docker exec k8s-master journalctl -xeu kubelet
   ```

2. Verify Docker is running correctly inside the containers:
   ```bash
   docker exec k8s-master systemctl status docker
   ```

3. Check for network issues:
   ```bash
   docker exec k8s-master ping k8s-worker-0
   ```
