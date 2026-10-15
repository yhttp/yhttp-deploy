YHTTP_DEPLOY_PATH = .
YHTTP_DEPLOY_VERSION_REQUIRED ?=
include _version.mk


PREFIX ?= /usr/local
TARGET ?= yhttp-deploy
INSTALL_FILES = \
	_version.mk \
	target-install.sh \
	target-uninstall.sh \
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
	mkdir -p $(PREFIX)/lib/$(TARGET)
	install -D $(INSTALL_FILES) $(PREFIX)/lib/$(TARGET)
	make links	

.PHONY: uninstall
uninstall:
	$(RM) $(links)
	rm -rf $(PREFIX)/lib/$(TARGET)
