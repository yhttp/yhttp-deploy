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
