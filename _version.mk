YHTTP_DEPLOY_URL ?= https://github.com/yhttp/yhttp-deploy
YHTTP_DEPLOY_VERSION = 2.6.0

version_greater_equal = $(shell if printf '%s\n%s\n' '$(1)' \
	'$(YHTTP_DEPLOY_VERSION)' | \
    sort -Ct. -k1,1n -k2,2n ; then echo YES; else echo NO; fi )


ifneq ("$(YHTTP_DEPLOY_VERSION_REQUIRED)", "")
ifneq (YES,$(call version_greater_equal,$(YHTTP_DEPLOY_VERSION_REQUIRED)))
  $(error your yhttp-deploy v$(YHTTP_DEPLOY_VERSION) is outdated. \
    install the yhttp-deploy v$(YHTTP_DEPLOY_VERSION_REQUIRED) or \
    higher from "$(YHTTP_DEPLOY_URL)")
endif
endif


.PHONY: version-ok
version-ok:
	@echo yhttp-deploy v$(YHTTP_DEPLOY_VERSION)
