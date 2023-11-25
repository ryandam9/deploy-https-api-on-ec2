# Deploying HTTPS enabled FastAPI Services on AWS EC2 Instance

## Overview

> [!info]
> This page talks about setting up a HTTPS enabled web application on AWS EC2 Instance.

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
access_key     ****************WEIL shared-credentials-file    
secret_key     ****************BhoB shared-credentials-file    
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
### 3.Key Pair

A key pair is already created in the required region and corresponding `.pem` is available locally.  Create its corresponding public key using the following command. Output of this command is its public key that will be used later.

```sh
ssh-keygen -y -f <pem-file.pem>
```
****
## GitHub Repo

GitHub Repo - 

```sh
.
├── bootstrap.yaml
├── deploy.sh
├── domain.py
├── main.tf
├── nginx_http.conf
├── nginx_https.conf
├── remote_setup.sh
```

- **deploy.sh**
	- This is a driver shell script. It needs to be executed on the local machine. 
	- It deploys a terraform template, executes a Python script to deal with Route 53, and finally executes a shell script on the EC2 Instance.
- **bootstrap.yaml**
	- This is used in the Terraform template 
	- It is used to bootstrap the EC2 Instance (Cloud Init)
	- It creates a user `ray` on the EC2 Instance 
	- It also installs few packages
- **main.tf**
	- Create few AWS Resources - EC2 Instance, Security groups to allow traffic on ports 22 (SSH), 88 (HTTP), 443 (HTTPS). 
	- It uses Ubuntu AMI (22.10). It identifies the AMI ID using a Data block.
- **domain.py**
	- To reach the API from internet, a Hosted zone needs to be created in Route 53. 
	- Another requirement is to ensure that the Name servers in the Route 53 hosted zone & the ones in the "Registered Domains" section should be same. 
	- This python script performs these activities.
- **nginx_http.conf** & **nginx_https.conf**
	- Very Basic Nginx configuration files to configure http and https
- **remote_setup.sh**
	- This is executed on the EC2 Instance after it is created. 
	- It clones a sample FastAPI repo from GitHub, and executes it using `uvicorn`. 
	- It also obtains a TLS certificate from https://letsencrypt.org/ by using tool **certbot** in batch mode. More details can be found here.
		- https://letsencrypt.org/getting-started/
		- https://certbot.eff.org/
		- [ACME Protocol](https://datatracker.ietf.org/doc/html/rfc8555)

> [!info]
> The certificate expires in 3 months. It will have to renewed at that time.

****
## Where to make changes prior to running this script?

1. Update `bootstrap.yaml` file to configure `ssh_authorized_keys` key. The Public key created from key file (`.pem`) file needs to be placed here. The public key will be copied and placed on the EC2 Instance.  It is needed to enable SSH connectivity (password-less) between local host and EC2 Instance. 
2. Update key pair name in the `main.tf` template file.
3. Make following changes to `deploy.sh`
	1. `key_file` - Local path of pem file
	2. Domain name while calling the python script.
	3. Email for Let's Encrypt.
	4. GitHub Repo name
4. Update domain name `nginx_http.conf` & `nginx_https.conf`
## How to execute the script

```sh
sh deploy.sh
```

Sample output is here:

```sh
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
data.aws_ami.ubuntu: Reading...
...

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

public_ip = "54.252.160.56"
2023-11-22 07:43:23,132 INFO: [@ credentials.py:1255] ==> Found credentials in shared credentials file: ~/.aws/credentials
2023-11-22 07:43:25,351 INFO: [@ domain.py:164] ==> Hosted zone already exists for domain example.com
2023-11-22 07:43:25,352 INFO: [@ domain.py:165] ==> Hosted zone id: /hostedzone/Z03175032C2EFZ1234567
2023-11-22 07:43:26,945 INFO: [@ domain.py:173] ==> Hosted Zone Name servers: ['ns-43.awsdns-05.com', 'ns-1452.awsdns-53.org', 'ns-2045.awsdns-63.co.uk', 'ns-595.awsdns-10.net']
2023-11-22 07:43:28,472 INFO: [@ domain.py:182] ==> Domain registrar name servers: ['ns-43.awsdns-05.com', 'ns-1452.awsdns-53.org', 'ns-2045.awsdns-63.co.uk', 'ns-595.awsdns-10.net']
2023-11-22 07:43:28,473 INFO: [@ domain.py:201] ==> Domain registrar & hosted zone name servers are same. No update required!
2023-11-22 07:43:28,473 INFO: [@ domain.py:206] ==> Creating alias record in hosted zone ...
2023-11-22 07:43:31,145 INFO: [@ domain.py:208] ==> Change id: /change/C01927891134556
2023-11-22 07:43:31,145 INFO: [@ domain.py:209] ==> Done!
nginx_http.conf                                                                                             100%  676    27.4KB/s   00:00    
nginx_https.conf                                                                                            100% 1198    53.5KB/s   00:00    

Using Email: myemail@example.com
Using Domain Name: example.com
Using GitHub Repo: https://github.com/KIVAR/test-web-app
...

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
Package 'certbot' is not installed, so not removed
...

Requesting a certificate for example.com

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/example.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/example.com/privkey.pem
This certificate expires on 2024-02-19.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

Deploying certificate
Successfully deployed certificate for example.com to /etc/nginx/nginx.conf
Congratulations! You have successfully enabled HTTPS on https://example.com
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
HTTPS Certificate Installed Successfully.● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2023-11-21 20:45:48 UTC; 14ms ago
       Docs: man:nginx(8)
    Process: 7510 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 7512 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 7513 (nginx)
      Tasks: 1 (limit: 1121)
     Memory: 2.6M
        CPU: 37ms
     CGroup: /system.slice/nginx.service
             ├─7513 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─7515 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

Nov 21 20:45:48 ip-172-31-9-114 systemd[1]: Starting A high performance web server and a reverse proxy server...
Nov 21 20:45:48 ip-172-31-9-114 systemd[1]: Started A high performance web server and a reverse proxy server.
```
****
## Code walkthrough
### `bootstrap.yaml`

```yaml

```

- This Cloud-init script is used by Terraform when creating the EC2 Instance. 
- It creates a user, installs some packages.
- For more details - https://cloudinit.readthedocs.io/en/latest/reference/examples.html
### `main.tf`

```json

```

- Creates a Security group to allow SSH, HTTP, HTTPS traffic. 
- Spins up an EC2 Instance using latest Ubuntu AMI.
- Bootstraps the instance using `bootstrap.yaml`
### `deploy.sh`

```sh

```
### `remote_setup.sh`

```sh

```

### `nginx_http.conf`

```ruby

```

### `nginx_https.conf`

```ruby

```

### `domain.py`

```python

```

****
