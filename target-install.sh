#! /usr/bin/env bash
HERE="$(realpath $(dirname ${BASH_SOURCE[0]}))"
set -e
source ${HERE}/.vars


# commands
usrexec="sudo -u ${user}"
pyenv=/home/${user}/.pyenv
pip=${pyenv}/bin/pip
configdir=/home/${user}/.config
systemd_unit=${configdir}/systemd/user/${instance}.service
vardir=/home/${user}/.var
appcmd="${usrexec} ${pyenv}/bin/${pypkg} -c ${configdir}/${pypkg}.yml"


# install dependencies
apt install -y \
  nginx \
  build-essential \
  libpq-dev \
  python3-dev \
  python3-venv \
  python3-pip \
  postgresql \
  redis-server \
  certbot \
  python3-certbot-nginx


# create user if not exists
if [ ! -d "/home/${user}" ]; then
  adduser --disabled-password --gecos '' ${user} 
  echo "CREATE USER ${user} WITH CREATEDB" | sudo -u postgres psql
fi


# create python venv if not exists
if [ ! -d "${pyenv}" ]; then
  ${usrexec} python3 -m venv ${pyenv}
fi


# create directories
${usrexec} mkdir -p ${configdir}/systemd/user
${usrexec} mkdir -p ${vardir}/www/media


# fix permissions
chmod -R 755 ${vardir}/www
chmod 755 ${vardir}
chmod 755 /home/${user}


# install the python package(s)
${usrexec} ${pip} -vv install ${HERE}/${pydist}
${usrexec} ${pip} -vv install uwsgi


# deploy assets
if [ -n "$(ls -A ${HERE}/assets)" ]; then
  ${usrexec} mkdir -p ${vardir}/www/assets
  rm ${vardir}/www/assets/*
  chmod -R 755 ${vardir}/www/assets
  cp ${HERE}/assets/* ${vardir}/www/assets

  if [ -f ${HERE}/assets-manifest.json ]; then
    cp ${HERE}/assets-manifest.json ${configdir}/assets-manifest.json
  fi
fi


# yhttp config file
echo "\
debug: false
env: production 

assets:
  serve: false
  manifest: ${configdir}/assets-manifest.json

media:
  serve: false

db:
  url: postgresql://:@/${instance}

mako:
  modules: ${vardir}/mako

auth:
  domain: ${domain}
  blacklist:
    key: yhttp-auth-forbidden

  redis:
    host: localhost
    port: 6379
    db: 0

  accesstoken:
    maxage: 86400    # seconds, one day
    leeway: 100      # seconds
    secret: 'EOfGMU2Y15VHqLmNTt+CGlqtUDfE+nU0'
    cookie:
      key: yhttp-accesstoken
      secure: true
      httponly: true
      samesite: Strict
      path: /

  refreshtoken:
    enabled: true
    maxage: 2592000  # 1 Month
    leeway: 10       # seconds
    algorithm: HS256
    secret: 'p7zcrssMswiWzWLieF+qpgCsXCCFnYfe'
    cookie:
      key: yhttp-refreshtoken
      secure: true
      httponly: true
      samesite: Strict
      path: /apiv1/tokens

  csrftoken:
    size: 1024
    cookie:
      key: yhttp-csrftoken
      secure: true
      httponly: true
      maxage: 60  # 1 Minute
      samesite: Strict
      path: /
" | ${usrexec} tee ${configdir}/${pypkg}.yml > /dev/null


# wsgi file
echo "\
import os
from ${pypkg} import app

app.settings.loadfile('${configdir}/${pypkg}.yml')
app.ready()
" | ${usrexec} tee ${configdir}/${instance}_wsgi.py > /dev/null


# uwsgi config file
echo "\
[uwsgi]
socket = ${vardir}/${instance}.s
module = ${instance}_wsgi:app
chmod-socket = 660
vacuum = true
master = true
workers = 1
threads = 2
chdir = ${configdir}
" | ${usrexec} tee ${configdir}/${instance}_uwsgi.ini > /dev/null


# create database
if sudo -u postgres psql -lqt | cut -d'|' -f1 | grep -qw ${instance} ; then
  echo "database ${instance} already created"
else
  ${appcmd} db create
  ${appcmd} db objects create
  ${appcmd} db basedata insert
fi


# systemd unit
echo "\
[Unit]
Description=${instance} web service
After=network.target

[Service]
User=${user}
Group=www-data
ExecStart=${pyenv}/bin/uwsgi \
  --ini ${configdir}/${instance}_uwsgi.ini \
  --wsgi-file ${instance}_wsgi.py

[Install]
WantedBy=multi-user.target
" | ${usrexec} tee ${systemd_unit} > /dev/null


systemctl daemon-reload
systemctl enable ${systemd_unit}
systemctl restart ${instance}.service
systemctl status ${instance}.service


# ssl
sslcert=/etc/letsencrypt/live/${domain}/fullchain.pem
sslkey=/etc/letsencrypt/live/${domain}/privkey.pem
if [ ! -f ${sslcert} ]; then
  certbot \
    certonly \
    --nginx \
    -d ${domain} \
    --non-interactive \
    --agree-tos \
    -m socialeasygo@gmail.com
fi


echo -n "\
server {
  listen 80;
  listen [::]:80;
  server_name ${domain};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2 ipv6only=on;
  server_name ${domain};

  ssl_certificate ${sslcert};
  ssl_certificate_key ${sslkey};
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  location /assets {
    alias ${vardir}/www/assets;
  }

  location /media {
    alias ${vardir}/www/media;
  }
  
  location / {
    include uwsgi_params;
    uwsgi_pass unix:${vardir}/${instance}.s;
  }
}
" > /etc/nginx/sites-available/${domain}
if [ ! -f "/etc/nginx/sites-enabled/${domain}" ]; then
  ln -s /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled
fi
systemctl reload nginx
