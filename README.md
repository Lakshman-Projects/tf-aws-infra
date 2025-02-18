# AWS Networking Setup with Terraform

## Overview

This repository contains Terraform code for setting up networking infrastructure on AWS, including the creation of **Virtual Private Cloud (VPC)**, **Internet Gateway**, **Route Tables**, and **Subnets**. This setup is essential for deploying and managing resources in an isolated network.

## Prerequisites

Before setting up the infrastructure, ensure the following tools are installed and configured:

1. **AWS CLI**:
   - Install the [AWS CLI](https://aws.amazon.com/cli/) and configure it with profiles for different AWS accounts (e.g., `dev` and `demo`).
   
2. **Terraform**:
   - Install [Terraform](https://www.terraform.io/downloads.html) on your local machine.

3. **GitHub Repository**:
   - Clone this repository to your local machine or fork it if necessary.

## Setting Up Your Infrastructure

Follow these steps to set up the networking resources:

### 1. Clone the Repository

If you haven't already, clone this repository to your local machine:

```bash
git clone https://github.com/your-username/tf-aws-infra.git
cd tf-aws-infra
```

### 2. Initialize Terraform

Run the following command to initialize the Terraform working directory. This will download the necessary provider plugins:

```bash
terraform init
```

### 3. Configure Your AWS Profiles

Ensure your AWS CLI is configured with the appropriate profiles. For example:

- `dev`: Your development AWS account.
- `demo`: Your demo AWS account.

You can verify your configuration with:

```bash
aws sts get-caller-identity --profile dev
aws sts get-caller-identity --profile demo
```

### 4. Review and Modify Variables

In the `variables.tf` file, review the default values or modify them as needed for your environment. For example, you might want to change the region or the names of the VPC or subnets.

### 5. Apply the Terraform Configuration

Run the following command to apply the Terraform configuration and create the AWS resources (VPC, Subnets, Internet Gateway, Route Tables):

```bash
terraform apply
```

Terraform will prompt for confirmation. Type `yes` to proceed with the creation of the infrastructure.

### 6. Verify the Infrastructure

Once Terraform has successfully applied the changes, verify the infrastructure in the AWS Management Console:

- VPC should be created.
- Subnets (public and private) should be available in different Availability Zones.
- Internet Gateway and Route Tables should be configured.

### 7. Clean Up the Infrastructure

To tear down the infrastructure and avoid ongoing costs, run the following command:

```bash
terraform destroy
```

Confirm the destruction when prompted by typing `yes`.

## Conclusion

By following these steps, you can set up networking infrastructure on AWS using Terraform.