PREFIX ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin
MANDIR ?= $(PREFIX)/share/man
SYSTEMD_UNIT_DIR ?= $(PREFIX)/lib/systemd/system
DRACUT_MODDIR ?= /usr/lib/dracut/modules.d
# Standard prefix for staged/chroot installs.
DESTDIR ?=

INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL) -m 755
INSTALL_DATA ?= $(INSTALL) -m 644
MKDIR ?= mkdir -p
SED ?= sed
CHMOD ?= chmod

PROGRAM = mount_crypted
SCRIPT = mount_crypted.sh
MANPAGE = mount_crypted.8
MANSECT = 8
SYSTEMD_UNIT = mount_crypted.service
DRACUT_MODULE = $(DRACUT_MODDIR)/90mount_crypted
DRACUT_SRC = dracut/90mount_crypted

all: check

check:
	sh -n $(SCRIPT)
	bash -n $(DRACUT_SRC)/module-setup.sh

install: install-base install-systemd install-dracut

install-base: check
	$(MKDIR) $(DESTDIR)$(SBINDIR) $(DESTDIR)$(MANDIR)/man$(MANSECT)
	$(INSTALL_PROGRAM) $(SCRIPT) $(DESTDIR)$(SBINDIR)/$(PROGRAM)
	$(INSTALL_DATA) $(MANPAGE) $(DESTDIR)$(MANDIR)/man$(MANSECT)/$(MANPAGE)

install-systemd: check
	$(MKDIR) $(DESTDIR)$(SYSTEMD_UNIT_DIR)
	$(SED) 's|@SBINDIR@|$(SBINDIR)|g' systemd/$(SYSTEMD_UNIT) > $(DESTDIR)$(SYSTEMD_UNIT_DIR)/$(SYSTEMD_UNIT)
	$(CHMOD) 644 $(DESTDIR)$(SYSTEMD_UNIT_DIR)/$(SYSTEMD_UNIT)

install-dracut: install-systemd
	$(MKDIR) $(DESTDIR)$(DRACUT_MODULE)
	$(INSTALL_PROGRAM) $(SCRIPT) $(DESTDIR)$(DRACUT_MODULE)/$(PROGRAM)
	$(INSTALL_PROGRAM) $(DRACUT_SRC)/module-setup.sh $(DESTDIR)$(DRACUT_MODULE)/module-setup.sh
	$(SED) 's|@SBINDIR@|$(SBINDIR)|g' systemd/$(SYSTEMD_UNIT) > $(DESTDIR)$(DRACUT_MODULE)/$(SYSTEMD_UNIT)
	$(CHMOD) 644 $(DESTDIR)$(DRACUT_MODULE)/$(SYSTEMD_UNIT)

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/$(PROGRAM)
	rm -f $(DESTDIR)$(MANDIR)/man$(MANSECT)/$(MANPAGE)
	rm -f $(DESTDIR)$(SYSTEMD_UNIT_DIR)/$(SYSTEMD_UNIT)
	rm -f $(DESTDIR)$(DRACUT_MODULE)/$(PROGRAM) \
		$(DESTDIR)$(DRACUT_MODULE)/$(SYSTEMD_UNIT) \
		$(DESTDIR)$(DRACUT_MODULE)/module-setup.sh
	rmdir $(DESTDIR)$(DRACUT_MODULE) 2> /dev/null || :

.PHONY: all check install install-base install-systemd install-dracut uninstall
