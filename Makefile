YHTTP_DEPLOY_PATH = .
YHTTP_DEPLOY_VERSION_REQUIRED ?=
include _version.mk


PREFIX ?= /usr/local
TARGET ?= yhttp-deploy
INSTALL_FILES = \
	_version.mk \
	target-install.sh \
	bundle.sh \
	deploy.sh


EXECS = \
	bundle.sh \
	deploy.sh


links = $(addprefix $(PREFIX)/bin/yhttp-, $(foreach src,$(EXECS),$(src:.sh=)))


links: $(links)


$(links): $(PREFIX)/bin/yhttp-%: %.sh
	if [ ! -e $@ ] && [ -h $@ ]; then rm $@; fi
	ln -s $(PREFIX)/lib/$(TARGET)/$^ $@


.PHONY: install
install:
	install -D -t $(PREFIX)/lib/$(TARGET) $(INSTALL_FILES)
	make links	
