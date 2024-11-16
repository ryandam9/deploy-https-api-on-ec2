# Deploying HTTPS enabled API on AWS EC2

- Description - Deploy HTTPS enabled API on AWS EC2
- Created - 2023/02/20
- Tags - AWS, FastAPI, EC2, HTTPS, SSL Cert
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
### `deploy.sh`
- This is a driver shell script. It needs to be executed on the local machine.
- It deploys a Terraform template, executes a Python script to deal with Route 53, and finally executes a shell script on the EC2 Instance to configure Nginx.
### `domain.py`
- To reach the API from internet, a Hosted zone needs to be created in Route 53.
- Another requirement is to ensure that the Name servers in the Route 53 hosted zone & the ones in the "**Registered Domains**" section should be same. 
- This python script performs these activities.
### `reference_files/cloud_init_template.yaml`
- This is used in the Terraform template
- It is used to bootstrap EC2 Instance (Cloud Init)
- It creates a user `ray` on the EC2 Instance
- It also installs few packages
### `reference_files/nginx_http.conf` & `reference_files/nginx_https.conf`
- Very Basic Nginx configuration files to configure http and https
### `remote_setup.sh`
- This is executed on the EC2 Instance after it is created.
- It clones a sample FastAPI repo from GitHub, and executes it using `uvicorn`. 
- It also obtains a TLS certificate from [https://letsencrypt.org/](https://letsencrypt.org/) by using tool **certbot** in batch mode. More details can be found here.
	- [https://letsencrypt.org/getting-started/](https://letsencrypt.org/getting-started/)
	- [https://certbot.eff.org/](https://certbot.eff.org/)
	- [ACME Protocol](https://datatracker.ietf.org/doc/html/rfc8555)
### `terraform_templates/main.tf`
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
