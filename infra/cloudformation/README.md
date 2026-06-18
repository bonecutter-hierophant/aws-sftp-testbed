# CloudFormation

This directory owns the CloudFormation template for the disposable SFTP testbed.

The template should eventually define:

- EC2 instance using the current Amazon Linux 2023 SSM public AMI parameter
- security group with caller-provided inbound SFTP CIDR
- IAM instance profile only if runtime bootstrap needs AWS API access
- user data for OpenSSH `internal-sftp`
- resource tags that identify the testbed and support cleanup
- outputs needed by scripts to discover current host and update Parameter Store

Do not commit generated stack outputs or live AWS identifiers.

Current MVP shape:

- uses the public Amazon Linux 2023 SSM AMI parameter
- creates a public EC2 instance in the selected VPC and subnet
- explicitly associates a public IPv4 address with the instance network interface
- allows inbound TCP 22 only from `AllowedCidr`
- requires `AllowPublicCidr=true` when `AllowedCidr` is `0.0.0.0/0`
- accepts configurable project name, instance type, SFTP username, and deploy-supplied password parameters
- configures OpenSSH `internal-sftp` in user data
- creates a chrooted `/data` SFTP path
- disables shell access for the SFTP user
- disables root SSH login for the instance
- disables forwarding and tunneling for the SFTP user
- uses generated password authentication for the MVP
- defers SSH public-key authentication until key material handling is reviewed separately
- avoids Elastic IP, NAT Gateway, load balancer, AWS Transfer Family, and multi-AZ resources
- avoids an EC2 instance profile because user-data bootstrap does not call AWS APIs
- outputs instance ID, public DNS, public IP, VPC ID, subnet ID, security group ID, port, username, remote path, and project name
