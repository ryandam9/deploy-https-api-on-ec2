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
    exit 1
fi

# Check if any of the arguments are empty
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <domain_name> <email> <github_repo>"
    exit 1
fi

domain_name="$1"
email="$2"
github_repo="$3"

# This user is created by Terraform (Refer bootstrap.yaml)
remote_host_user="ray"

# ----------------------------------------------------------------------------#
# Create a SSH Key locally                                                    #
# ----------------------------------------------------------------------------#
key_file="./keys/id_rsa"

if [ -z "$(ls -A ./keys)" ]; then
    # -q - quiet mode
    # -t - Type of key to be created
    # -N - Passphrase to be used to encrypt the key
    # -f - Filename of the key file
    ssh-keygen -q -t rsa -N "" -f "${key_file}"
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
