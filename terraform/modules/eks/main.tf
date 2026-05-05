# DATA SOURCE - Look up the existing Vocareum LabRole
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# SECURITY GROUP FOR EKS CLUSTER
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
    Environment = var.environment
  }
}

# EKS CLUSTER
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = data.aws_iam_role.lab_role.arn
  version  = "1.32"

  lifecycle {
    ignore_changes = [version]
  }

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}
