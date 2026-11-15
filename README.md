# yttp-deploy

## Install

```bash
curl "https://raw.githubusercontent.com/yhttp/yhttp-deploy/master/install.sh" | sudo sh
```

Or 
```bash
cd yhttp-deploy
sudo make install
sudo make install PREFIX=/opt
```

## Creating a bundle

`bundle.sh` requires the package name and distribution, package version, target
user, instance, domain, administrator email, and Python version. For example:

```bash
bundle.sh \
  --pkg-name myapp \
  --pkg-dist dist/myapp-1.0.0.tar.gz \
  --pkg-version 1.0.0 \
  --target-user myapp \
  --target-instance myapp \
  --target-domain app.example.com \
  --admin-email admin@example.com \
  --pyver python3.12 \
  --no-database \
  --nginx-configentry 'client_max_body_size 32m;' \
  --nginx-configentry 'add_header X-Frame-Options SAMEORIGIN;' \
  public/logo.svg
```

The final positional arguments are asset files copied into the bundle. The
`public` directory is included when it contains files.

### `bundle.sh` options

| Option | Description |
| --- | --- |
| `-v` | Enable shell tracing. |
| `--pkg-name NAME` | **Required.** Python package and command name. |
| `--namespace NAME` | Python import namespace; defaults to `--pkg-name`. |
| `--pkg-dist PATH` | **Required.** Path to the built Python distribution. |
| `--pkg-version VERSION` | **Required.** Version used in the bundle filename. |
| `--output-directory DIR` | Bundle output directory; defaults to `bundles`. |
| `--target-user USER` | **Required.** System user that will run the application. |
| `--target-instance NAME` | **Required.** Deployment instance name. |
| `--target-domain DOMAIN` | **Required.** Main application domain. |
| `--target-ssldomain DOMAIN` | Domain used for the TLS certificate; defaults to `--target-domain`. |
| `--target-aliasdomains DOMAINS` | Additional space-separated names for the Nginx `server_name`. |
| `--assets-manifest PATH` | Optional assets manifest to include in the bundle. |
| `--configuration-file PATH` | Production configuration file; defaults to `production.yml`. |
| `--admin-email EMAIL` | **Required.** Email passed to Certbot when requesting a certificate. |
| `--pyver VERSION` | **Required.** Python executable/version installed on the target, such as `python3.12`. |
| `--nginx-configfile NAME` | Nginx site configuration filename; defaults to `--target-domain`. |
| `--nginx-configentry DIRECTIVE` | Add a directive inside the HTTPS virtual host. Repeat to add multiple directives. |
| `--nginx-group GROUP` | Nginx group; defaults to `www-data`. |
| `--public-directory DIR` | Source public directory; defaults to `public`. |
| `--worker NAME=COMMAND` | Add a systemd worker; repeat for multiple workers. |
| `--install-exec COMMAND` | Run a custom command during target installation; repeat as needed. |
| `--no-database` | Skip database packages, role/database creation, and migrations. |
| `ASSET...` | Positional asset files copied into the bundle’s `assets` directory. |

### Deploying a bundle

`deploy.sh` uploads and installs the bundle over SSH as `root@HOST`. The target
instance must match the one used when creating the bundle.

```bash
deploy.sh --host server.example.com \
  --bundle bundles/myapp-bundle-1.0.0-app.example.com.tar.gz \
  --target-instance myapp
```

| Option | Description |
| --- | --- |
| `--host HOST` | **Required.** SSH host to deploy to. |
| `--bundle PATH` | **Required.** Bundle archive to upload. |
| `--target-instance NAME` | **Required.** Instance name used in the bundle. |
| `--no-database` | Skip database setup for this deployment. Can be set here instead of while bundling. |


## Setup your project:
Create a `Makefile` in your project's root:
```make
# Assert the yhttp-deploy version
YHTTP_DEPLOY_VERSION_REQUIRED = 1.0.1


# Ensure the yhttp-deploy is installed
YHTTP_DEPLOY_PATH = /usr/local/lib/yhttp-deploy
ifeq ("", "$(wildcard $(YHTTP_DEPLOY_PATH))")
  MAKELIB_URL = https://github.com/yhttp/yhttp-deploy
  $(error yhttp-deploy is not installed. see "$(MAKELIB_URL)")
endif
```
