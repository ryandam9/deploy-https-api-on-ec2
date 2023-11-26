# Deploying HTTPS enabled FastAPI Services on AWS EC2 Instance

## Overview

> [!info]
> This page talks about setting up a HTTPS enabled FastAPI web application on AWS EC2 Instance. It assumes that, a Domain is already purchased using AWS Route 53.

## Prerequisites
### 1.Software
This deployment uses [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) to create resources on AWS.  Below commands can be used to verify their setup.

```sh
aws --version
aws configure list
```

```sh
aws-cli/2.13.36 Python/3.11.6 Linux/6.2.0-36-generic exe/x86_64.ubuntu.22 prompt/off
```

A user with admin privileges is configured using `aws configure` command.

```sh
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ****************ABCD shared-credentials-file    
secret_key     ****************XYZA shared-credentials-file    
    region           ap-southeast-2      config-file    ~/.aws/config
```

Terraform is also installed 

```sh
terraform --version
```

```sh
Terraform v1.6.4
on linux_amd64
```
### 2.Domain name

A Domain is already registered using Route 53.  Following output should verify this:

```sh
aws route53domains get-domain-detail --region us-east-1 --domain-name example.com
```

### 3. Python

```sh
python3 --version
```

```sh
Python 3.10.12
```

****
## GitHub Repo

GitHub Repo - [https://github.com/ryandam9/deploy-https-api-on-ec2](https://github.com/ryandam9/deploy-https-api-on-ec2)

```sh
ls -l deploy-https-api-on-ec2/infrastructure
```

```sh
.
├── deploy.sh
├── domain.py
├── keys
├── reference_files
│   ├── cloud_init_template.yaml
│   ├── nginx_http.conf
│   └── nginx_https.conf
├── remote_setup.sh
├── terraform_templates
│   └── main.tf
└── working_dir
```
##### deploy.sh
- This is a driver shell script. It needs to be executed on the local machine.
- It deploys a Terraform template, executes a Python script to deal with Route 53, and finally executes a shell script on the EC2 Instance to configure Nginx.
##### domain.py
- To reach the API from internet, a Hosted zone needs to be created in Route 53.
- Another requirement is to ensure that the Name servers in the Route 53 hosted zone & the ones in the "**Registered Domains**" section should be same. 
- This python script performs these activities.
##### reference_files/cloud_init_template.yaml
- This is used in the Terraform template
- It is used to bootstrap EC2 Instance (Cloud Init)
- It creates a user `ray` on the EC2 Instance
- It also installs few packages
##### reference_files/nginx_http.conf & reference_files/nginx_https.conf
- Very Basic Nginx configuration files to configure http and https
##### remote_setup.sh
- This is executed on the EC2 Instance after it is created.
- It clones a sample FastAPI repo from GitHub, and executes it using `uvicorn`. 
- It also obtains a TLS certificate from [https://letsencrypt.org/](https://letsencrypt.org/) by using tool **certbot** in batch mode. More details can be found here.
	- [https://letsencrypt.org/getting-started/](https://letsencrypt.org/getting-started/)
	- [https://certbot.eff.org/](https://certbot.eff.org/)
	- [ACME Protocol](https://datatracker.ietf.org/doc/html/rfc8555)
##### terraform_templates/main.tf
- Create few AWS Resources - EC2 Instance, Security groups to allow traffic on ports 22 (SSH), 88 (HTTP), 443 (HTTPS).
- It uses Ubuntu AMI (22.10). It identifies the AMI ID using a Data block.

> [!info]
> - To shell into the EC2 Instance, a private key is needed.  `deploy.sh` creates a RSA key and stores it (Both private & public key) in the `keys` directory.  The public is also used to setup user `ray`'s `ssh_authorized_keys` file in the EC2 Instance (Can be found under `/home/ray/.ssh/`)
> - `working_dir` contains working copies of Bootstrap YAML file & Nginx configuration files.

> [!info]
> The TLS certificate expires in 3 months. It will have to renewed at that time.

****
## Where to make changes prior to running this script?

- No changes are needed.

****
## How to execute the script

```sh
Usage: deploy.sh <domain_name> <email> <github_repo>
```

- The web domain already purchased using Route 53 (Sample - `example.com`)
- Email - This is needed to register with Let's Encrypt.
- GitHub Repo - This repo will be deployed on the EC2 Instance. It is expected to be a FastAPI Python app.

```sh
cd deploy-https-api-on-ec2/infrastructure
sh ./deploy.sh "example.com" "example@example.com" "https://github.com/ryandam9/test-web-app"
```

Sample output is here:

```sh
Private key doesn't exist. Creating one...

Initializing the backend...
Initializing modules...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.26.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
module.ec2-instance.data.aws_partition.current: Reading...
...

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

public_ip = "3.26.97.12"
2023-11-26 18:33:40,121 INFO: [@ credentials.py:1255] ==> Found credentials in shared credentials file: ~/.aws/credentials
2023-11-26 18:33:41,495 INFO: [@ domain.py:170] ==> Hosted zone already exists for domain example.com
2023-11-26 18:33:41,495 INFO: [@ domain.py:171] ==> Hosted zone id: /hostedzone/Z03175032C2EFZXCEO8TF
2023-11-26 18:33:43,050 INFO: [@ domain.py:179] ==> Hosted Zone Name servers: ['ns-43.awsdns-05.com', 'ns-1452.awsdns-53.org', 'ns-2045.awsdns-63.co.uk', 'ns-595.awsdns-10.net']
2023-11-26 18:33:44,521 INFO: [@ domain.py:188] ==> Domain registrar name servers: ['ns-43.awsdns-05.com', 'ns-1452.awsdns-53.org', 'ns-2045.awsdns-63.co.uk', 'ns-595.awsdns-10.net']
2023-11-26 18:33:44,522 INFO: [@ domain.py:207] ==> Domain registrar & hosted zone name servers are same. No update required!
2023-11-26 18:33:44,522 INFO: [@ domain.py:212] ==> Creating alias record in hosted zone using example.com and 3.26.97.12
2023-11-26 18:33:47,531 INFO: [@ domain.py:214] ==> Change id: /change/C02452623U12345678
2023-11-26 18:33:47,532 INFO: [@ domain.py:215] ==> Done!
Warning: Permanently added '3.26.97.12' (ED25519) to the list of known hosts.
nginx_http.conf                                                                                      100%  676    27.1KB/s   00:00    
nginx_https.conf                                                                                     100% 1198    51.3KB/s   00:00    

Using Email: example@example.com
Using Domain Name: example.com
Using GitHub Repo: https://github.com/ryandam9/test-web-app
Cloning into 'test-web-app'...
Collecting fastapi
  Downloading fastapi-0.104.1-py3-none-any.whl (92 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 92.9/92.9 KB 1.7 MB/s eta 0:00:00
...

Installing collected packages: typing-extensions, sniffio, exceptiongroup, annotated-types, pydantic-core, anyio, starlette, pydantic, fastapi
Successfully installed annotated-types-0.6.0 anyio-3.7.1 exceptiongroup-1.2.0 fastapi-0.104.1 pydantic-2.5.2 pydantic-core-2.14.5 sniffio-1.3.0 starlette-0.27.0 typing-extensions-4.8.0
WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
The following packages were automatically installed and are no longer required:
  python3-acme python3-certbot python3-configargparse python3-icu
  python3-josepy python3-parsedatetime python3-requests-toolbelt
  python3-rfc3339 python3-zope.component python3-zope.event
  python3-zope.hookable python3-zope.interface
Use 'sudo apt autoremove' to remove them.
INFO:     Started server process [11336]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
The following packages will be REMOVED:
  certbot
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
After this operation, 63.5 kB disk space will be freed.
(Reading database ... 91231 files and directories currently installed.)
Removing certbot (1.21.0-1build1) ...
debconf: unable to initialize frontend: Dialog
debconf: (Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.)
debconf: falling back to frontend: Readline
certbot 2.7.4 from Certbot Project (certbot-eff**) installed
certbot 2.7.4
Account registered.
Requesting a certificate for example.com

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/example.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/example.com/privkey.pem
This certificate expires on 2024-02-24.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

Deploying certificate
Successfully deployed certificate for example.com to /etc/nginx/nginx.conf
Congratulations! You have successfully enabled HTTPS on https://example.com

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Saving debug log to /var/log/letsencrypt/letsencrypt.log
HTTPS Certificate Installed Successfully.● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2023-11-26 07:36:43 UTC; 9ms ago
       Docs: man:nginx(8)
    Process: 11831 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 11832 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 11833 (nginx)
      Tasks: 1 (limit: 1121)
     Memory: 2.6M
        CPU: 37ms
     CGroup: /system.slice/nginx.service
             ├─11833 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─11835 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"

Nov 26 07:36:42 ip-172-31-31-16 systemd[1]: Starting A high performance web server and a reverse proxy server...
Nov 26 07:36:43 ip-172-31-31-16 systemd[1]: Started A high performance web server and a reverse proxy server.
```
****
## Destroying resources

```sh
cd deploy-https-api-on-ec2/infrastructure
terraform -chdir=./terraform_templates destroy
```

****
## Code walkthrough
### `cloud_init_template.yaml`

```yaml
#cloud-config

groups:
  - ubuntu: [root,sys]
  - testgroup

users:
  - default
  - name: ray
    gecos: Ra.y
    shell: /bin/bash
    primary_group: testgroup
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    lock_passwd: false
    ssh_authorized_keys:
      # Place the public key generated from the pem file here.
      - PUBLIC_KEY

package_update: true
package_upgrade: true

packages:
  - nginx
  - git
  - python3-pip
  - vim
  - net-tools
  - certbot
  - uvicorn
  - lsof

runcmd:
    # In Ubuntu 22.04, after a package is installed, it is asking for an interactive confirmation.
    # This is a workaround to avoid the interactive confirmation. 
  - sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
  - nginx -s reload
  - sudo systemctl restart nginx
```

- This Cloud-init script is used by Terraform when creating the EC2 Instance. 
- It creates a user, installs some packages.
- For more details - https://cloudinit.readthedocs.io/en/latest/reference/examples.html
### `main.tf`

```ruby
#-----------------------------------------------------------------------------#
# Create an EC2 Instance using Ubuntu Image                                   #
#   Following resources will be deployed:                                     #
#       - EC2 Instance                                                        #
#                                                                             #
# Prerequisites:                                                              #
#   - A Key pair key                                                          #
#-----------------------------------------------------------------------------#
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.26.0"
    }
  }

  required_version = ">= 1.6.4"
}

provider "aws" {
  region = "ap-southeast-2"
}

#-----------------------------------------------------------------------------#
# Varibles                                                                    #
#-----------------------------------------------------------------------------#
variable "instance_type" {
  description = "Type of EC2 Instance"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Key pair name"
  type        = string
  default     = "ray"
}

variable "public_key_file_name" {
  description = "Location of public key file"
  type        = string
  default     = "../keys/id_rsa.pub"
}

#-----------------------------------------------------------------------------#
# Locals
#-----------------------------------------------------------------------------#
locals {
  inbound_ports = [22, 80, 443]
  user_data     = file("../working_dir/bootstrap.yaml")
  name          = "ex-${basename(path.cwd)}"

  tags = {
    Name       = local.name
    Example    = local.name
  }
}

#-----------------------------------------------------------------------------#
# Data
#-----------------------------------------------------------------------------#
# Find latest Ubuntu AMI
# https://ubuntu.com/server/docs/cloud-images/amazon-ec2
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  name_regex  = "^.*22.04.*$"

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "hypervisor"
    values = ["xen"]
  }

  filter {
    name   = "creation-date"
    values = ["2023-09-*"]
  }
}

#-----------------------------------------------------------------------------#
# Resources
#-----------------------------------------------------------------------------#
# Security group to accept traffic from the internet
# on http & https
resource "aws_security_group" "sg_webserver" {
  name        = "webserver-sg"
  description = "Security Group for Web Servers"

  dynamic "ingress" {
    for_each = local.inbound_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

# Create a Key using locally generated public key
resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair_name
  public_key = trimspace(file(var.public_key_file_name))
}

# Spin up an EC2 instance
module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.5.0"

  name                        = local.name
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.sg_webserver.id]
  associate_public_ip_address = true
  disable_api_stop            = false
  create_iam_instance_profile = true
  user_data                   = local.user_data
  user_data_replace_on_change = true
  enable_volume_tags          = false
  key_name                    = aws_key_pair.key_pair.key_name
  tags                        = local.tags
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}

#-----------------------------------------------------------------------------#
# Outputs
#-----------------------------------------------------------------------------#
output "public_ip" {
  value       = module.ec2-instance.public_ip
  description = "The public IP address of the web server"
}
```

- Creates a Security group to allow SSH, HTTP, HTTPS traffic. 
- Spins up an EC2 Instance using latest Ubuntu AMI.
- Bootstraps the instance using `bootstrap.yaml`
### `deploy.sh`

```sh
#!/bin/sh

# ----------------------------------------------------------------------------#
# deploy.sh                                                                   #
#   Script to deploy a FastAPI application on an EC2 instance.                #
#                                                                             #
#   This is a script that combines multiple commands to deploy the FastAPI    #
#   application on EC2 instance.                                              #
#                                                                             #
# Summary:                                                                    #
#    1. Execute a Terraform template to create EC2 instance                   #
#    2. Creates Route53 hosted zone & creates an A record                     #
#    3. Deploy application git repo and start server on port 8000             #
#    4. Install Certbot to get TLS certificate for HTTPS                      #
#    5. Get HTTPS certificate & configure Nginx                               #
#                                                                             #
# Prerequisites:                                                              #
#  1. A Domain name registered with AWS Route53.                              #
#  2. A key pair created in AWS EC2 console & private key is available (pem)  #
#      Its public key needs to be updated in the following places:            #
#            a. Terraform template                                            #
#                                                                             #
#  To generate public key from pem file:  "ssh-keygen -y -f <pem-file.pem>"   #
# ----------------------------------------------------------------------------#

# Check if all the arguments are passed
if [ $# -ne 3 ]; then
    echo "Usage: $0 <domain_name> <email> <github_repo>"
    echo "sh deploy.sh example.com email@example.com https://github.com/ryandam9/test-web-app"
    exit 1
fi

# Check if any of the arguments are empty
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <domain_name> <email> <github_repo>"
    echo "sh deploy.sh example.com email@example.com https://github.com/ryandam9/test-web-app"
    exit 1
fi

domain_name="$1"
email="$2"
github_repo="$3"

# This user is created by Terraform (Refer bootstrap.yaml)
remote_host_user="ray"

mkdir -p "./keys"
mkdir -p "./working_dir"

# ----------------------------------------------------------------------------#
# Create a SSH Key locally                                                    #
# ----------------------------------------------------------------------------#
key_file="./keys/id_rsa"

# If the key file doesn't exist, create one
# otherwise, use the existing key
if [ ! -f ./keys/id_rsa ] && [ ! -f ./keys/id_rsa.pub ]; then
    # -q - quiet mode
    # -t - Type of key to be created
    # -N - Passphrase to be used to encrypt the key
    # -f - Filename of the key file
    echo "Private key doesn't exist. Creating one..."
    ssh-keygen -q -t rsa -N "" -f "${key_file}"
else
    echo "Private key already exists in ./keys directory. Using the existing key..."
fi

public_key=$(cat ./keys/id_rsa.pub)

# Use awk to replace the text in the target file
awk -v r="$public_key" '{gsub(/PUBLIC_KEY/, r)}1' ./reference_files/cloud_init_template.yaml > temp_file.txt && \
mv temp_file.txt ./working_dir/bootstrap.yaml

# ----------------------------------------------------------------------------#
# 1. Execute a Terraform template to create EC2 instance                      #
# ----------------------------------------------------------------------------#
terraform -chdir=./terraform_templates init
terraform -chdir=./terraform_templates apply -auto-approve

# Get EC2 Public IP from Terrafform output
ec2_public_ip=$(terraform output -state=./terraform_templates/terraform.tfstate -raw public_ip)

# ----------------------------------------------------------------------------#
# 2. Creates Route53 hosted zone & creates an A record                        #
# ----------------------------------------------------------------------------#
python3 domain.py "${domain_name}" "${ec2_public_ip}"

if [ $? -ne 0 ]; then
    print "Failed to create Route53 hosted zone & A record"
    exit 1
fi

# Wait a bit prior to SSHing to the instance
# Cloud-init might still be running to download few packages and installing
# them. There should be a better way to do this.
sleep 120

# ----------------------------------------------------------------------------#
# 3. Copy nginx.conf to remote host.                                          #
# ----------------------------------------------------------------------------#
sed "s/example.com/${domain_name}/g" ./reference_files/nginx_http.conf >./working_dir/nginx_http.conf
sed "s/example.com/${domain_name}/g" ./reference_files/nginx_https.conf >./working_dir/nginx_https.conf

scp -o StrictHostKeyChecking=no -i "${key_file}" \
    ./working_dir/nginx_http.conf \
    "${remote_host_user}@${ec2_public_ip}:/tmp"

scp -i "${key_file}" \
    ./working_dir/nginx_https.conf \
    "${remote_host_user}@${ec2_public_ip}:/tmp"

# This runs on EC2 instance
ssh -i "${key_file}" \
    "${remote_host_user}@${ec2_public_ip}" \
    "sudo bash -s" < ./remote_setup.sh "${email}" "${domain_name}" "${github_repo}"

exit 0
```
### `remote_setup.sh`

```sh
#!/bin/sh

# ----------------------------------------------------------------------------#
# This script runs on EC2.                                                    #
#                                                                             #
#   1. It downloads code from GitHub repo and starts the server on port 8000. #
#   2. It installs Certbot to get TLS certificate for HTTPS.                  #
#   3. Configures Nginx to serve HTTPS traffic.                               #
# ----------------------------------------------------------------------------#

EMAIL="$1"
DOMAIN_NAME="$2"
GITHUB_REPO="$3"

printf "\nUsing Email: %s" "${EMAIL}"
printf "\nUsing Domain Name: %s" "${DOMAIN_NAME}"
printf "\nUsing GitHub Repo: %s\n" "${GITHUB_REPO}"

# ----------------------------------------------------------------------------#
# 1. Deploy application git repo and start server on port 8000                #
# ----------------------------------------------------------------------------#
cd ~ || exit
git clone "${GITHUB_REPO}"
cd "test-web-app" || exit
pip3 install -r requirements.txt

# Kill any process running on port 8000
port_to_kill=8000; lsof -i :$port_to_kill -t | xargs -I {} kill {}

uvicorn app:app &
cd ~ || exit

# ----------------------------------------------------------------------------#
# 2. Install Certbot to get TLS certificate for HTTPS                         #
# ----------------------------------------------------------------------------#
cp /tmp/nginx_http.conf /etc/nginx/nginx.conf
apt -y remove certbot
snap install --classic certbot
certbot --version
ln -s /snap/bin/certbot /usr/bin/certbot

# ----------------------------------------------------------------------------#
# Get HTTPS certificate & configure Nginx                                     #
# ----------------------------------------------------------------------------#
# This step generates a certificate for the domain name
certbot run -n --nginx -m "${EMAIL}" --agree-tos -d "${DOMAIN_NAME}"

if [ $? -ne 0 ]; then
    printf "Unable to Install HTTPS Certificate."
    exit 1
else
    printf "HTTPS Certificate Installed Successfully."
fi

rm -rf /etc/nginx/nginx.conf
mv /tmp/nginx_https.conf /etc/nginx/nginx.conf
systemctl restart nginx
systemctl status nginx

exit 0
```

### `nginx_http.conf`

```ruby
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;

    server {
        if ($host = example.com) {
            return 301 https://$host$request_uri;
        }
 
        listen 80;
        server_name example.com;
        return 404;
    }
}
```

### `nginx_https.conf`

```ruby
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;

    server {
        listen 443 ssl; # managed by Certbot
        ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem; # managed by Certbot
        ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem; # managed by Certbot
        include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
        ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

	location / {
            proxy_pass http://127.0.0.1:8000;
        }
    }

    server {
        if ($host = example.com) {
            return 301 https://$host$request_uri;
        }
        # managed by Certbot
        listen 80;
        server_name example.com;
        return 404; # managed by Certbot
    }
}
```

### `domain.py`

```python
# --------------------------------------------------------------------------------------------------#
# This script deals with the Route53 to perform the following:                                      #
#     1. Create a Route53 hosted zone if it does not exist for the domain                           #                                                                              #
#     2. Identifies the Name servers from NS records from the hosted zone                           #
#     4. Update the Name servers in the domain registrar, if required                               #
#     2. Creates an Alias (A) record in the hosted zone to point the Public IP of the               #
#        EC2 instance                                                                               #
#                                                                                                   #
#  Assumption:                                                                                      #
#     Prior to running this script, the domain name should be registered with AWS Route53           #
#     Domain Registrar and the domain name should be visible in the "Registered domains" section    #
#     of the Route53 console.                                                                       #
#                                                                                                   #
# --------------------------------------------------------------------------------------------------#
import boto3
import argparse
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: [@ %(filename)s:%(lineno)d] ==> %(message)s",
)
logger = logging.getLogger(__name__)


def flatten_json(json_doc):
    out = {}

    def flatten(x, name=""):
        if type(x) is dict:
            for a in x:
                flatten(x[a], name + a + ".")
        elif type(x) is list:
            i = 0
            for a in x:
                flatten(a, name + str(i) + ".")
                i += 1
        else:
            out[name[:-1]] = x

    flatten(json_doc)
    return out


def print_dict(d: dict) -> None:
    """
    Prints a dictionary
    """
    for k, v in d.items():
        logger.debug("{}: {}".format(k, v))


def check_hosted_zone(domain_name: str) -> bool:
    """Check if the hosted zone exists in Route53"""
    client = boto3.client("route53")
    response = client.list_hosted_zones_by_name(DNSName=domain_name)

    print_dict(flatten_json(response))

    zone_found = False
    zone_id = None

    for zone in response["HostedZones"]:
        if zone["Name"][:-1] == domain_name:
            zone_found = True
            zone_id = zone["Id"]

    return (zone_found, zone_id)


def create_hosted_zone(domain_name: str) -> str:
    """Create a hosted zone in Route53"""
    client = boto3.client("route53")
    response = client.create_hosted_zone(Name=domain_name, CallerReference="string")

    print_dict(flatten_json(response))

    return response["HostedZone"]["Id"]


def get_hosted_zone_id(domain_name: str) -> str:
    """Get the hosted zone id"""
    client = boto3.client("route53")
    response = client.list_hosted_zones_by_name(DNSName=domain_name)
    print_dict(flatten_json(response))

    return response["HostedZones"][0]["Id"]


def get_hosted_zone_name_servers(hosted_zone_id: str) -> list:
    """Get the name servers from the hosted zone"""
    client = boto3.client("route53")
    response = client.get_hosted_zone(Id=hosted_zone_id)
    print_dict(flatten_json(response))
    return response["DelegationSet"]["NameServers"]


def get_domain_registrar_name_servers(domain_name: str) -> list:
    """Get the name servers from the domain registrar"""
    client = boto3.client("route53domains", region_name="us-east-1")
    response = client.get_domain_detail(DomainName=domain_name)
    print_dict(flatten_json(response))
    return response["Nameservers"]


def create_alias_record(domain_name: str, public_ip: str) -> str:
    """
    Create Alias record in Hosted Zone
    """
    try:
        client = boto3.client("route53")
        hosted_zone_id_full = get_hosted_zone_id(domain_name)
        hosted_zone_id = hosted_zone_id_full.split("/")[-1]

        response = client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                "Comment": "Alias record for EC2 instance",
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": domain_name,
                            "Type": "A",
                            "TTL": 60,
                            "ResourceRecords": [
                                {
                                    "Value": public_ip,
                                },
                            ],
                        },
                    },
                ],
            },
        )

        print_dict(flatten_json(response))

        return response["ChangeInfo"]["Id"]

    except Exception as err:
        logger.error("Unable to create alias record in hosted zone")
        logger.error(err)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process domain name")
    parser.add_argument("domain_name", type=str, help="domain name")
    parser.add_argument("public_ip", type=str, help="public ip of the ec2 instance")

    args = parser.parse_args()

    domain_name = args.domain_name
    public_ip = args.public_ip

    if domain_name is None:
        logger.error("Domain name is required")
        sys.exit(1)

    if public_ip is None:
        logger.error("Public IP is required")
        sys.exit(1)

    # Check if the hosted zone exists
    zone_flag, hosted_zone_id = check_hosted_zone(domain_name)

    if zone_flag:
        logger.info(f"Hosted zone already exists for domain {domain_name}")
        logger.info(f"Hosted zone id: {hosted_zone_id}")
    else:
        logger.info("Hosted zone does not exist yet for domain {domain_name}")
        hosted_zone_id = create_hosted_zone(domain_name)
        logger.info(f"Hosted zone created: {hosted_zone_id}")

    # Get name servers from hosted zone
    hosted_zone_name_servers = get_hosted_zone_name_servers(hosted_zone_id)
    logger.info(f"Hosted Zone Name servers: {hosted_zone_name_servers}")

    # Get name servers from domain registrar
    name_servers = get_domain_registrar_name_servers(domain_name)
    domain_registrar_name_servers = list()

    for ns in name_servers:
        domain_registrar_name_servers.append(ns["Name"])

    logger.info(f"Domain registrar name servers: {domain_registrar_name_servers}")

    # If Hosted zone name servers and domain registrar name servers are different,
    # update the domain registrar.
    if sorted(hosted_zone_name_servers) != sorted(domain_registrar_name_servers):
        logger.info("Updating domain registrar name servers ...")
        client = boto3.client("route53domains", region_name="us-east-1")

        response = client.update_domain_nameservers(
            DomainName=domain_name,
            Nameservers=[
                {"Name": hosted_zone_name_servers[0]},
                {"Name": hosted_zone_name_servers[1]},
                {"Name": hosted_zone_name_servers[2]},
                {"Name": hosted_zone_name_servers[3]},
            ],
        )
        logger.info("Domain registrar name servers updated")
    else:
        logger.info(
            "Domain registrar & hosted zone name servers are same. No update required!"
        )

    # Create alias record in hosted zone
    logger.info(f"Creating alias record in hosted zone using {domain_name} and {public_ip}")
    change_id = create_alias_record(domain_name, public_ip)
    logger.info(f"Change id: {change_id}")
    logger.info("Done!")

    sys.exit(0)
```

****
