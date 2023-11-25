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
