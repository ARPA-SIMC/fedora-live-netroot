-include Makefile.inc

prefix ?= /usr
libdir ?= ${prefix}/lib
datadir ?= ${prefix}/share
pkglibdir ?= ${libdir}/dracut
sysconfdir ?= ${prefix}/etc
bindir ?= ${prefix}/bin
mandir ?= ${prefix}/share/man
#CFLAGS ?= -O2 -g -Wall
#CFLAGS += -std=gnu99 -D_FILE_OFFSET_BITS=64 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 $(KMOD_CFLAGS)
bashcompletiondir ?= ${datadir}/bash-completion/completions
pkgconfigdatadir ?= $(datadir)/pkgconfig

all:

install: all
	mkdir -p $(DESTDIR)$(pkglibdir)
	mkdir -p $(DESTDIR)$(bindir)
#	mkdir -p $(DESTDIR)$(sysconfdir)
	mkdir -p $(DESTDIR)$(pkglibdir)/modules.d
#	mkdir -p $(DESTDIR)$(mandir)/man1 $(DESTDIR)$(man)
	cp -arx dracut/* $(DESTDIR)$(pkglibdir)/modules.d
	install -m 0755 bin/livecd-iso-to-pxenetroot $(DESTDIR)$(bindir)

clean:
	$(RM) *~
	$(RM) */*~
	$(RM) */*/*~
	$(RM) *.tar.bz2 *.tar.xz *.tar.gz

dist: $(PACKAGE)-$(VERSION).tar.gz

$(PACKAGE)-$(VERSION).tar.gz:
	git archive -o $(PACKAGE)-$(VERSION).tar.gz $(VERSION) --prefix=$(PACKAGE)-$(VERSION)/

rpm: $(PACKAGE)-$(VERSION).tar.gz
	rpmbuild=$$(mktemp -d -t rpmbuild-$(PACKAGE).XXXXXX); src=$$(pwd); \
	cp $(PACKAGE)-$(VERSION).tar.gz "$$rpmbuild"; \
	cp $(PACKAGE).spec $$rpmbuild/$(PACKAGE).spec; \
	(cd "$$rpmbuild"; \
	rpmbuild --define "_topdir $$PWD" --define "_sourcedir $$PWD" \
	        --define "_specdir $$PWD" --define "_srcrpmdir $$PWD" \
		--define "_rpmdir $$PWD" -ba $(PACKAGE).spec; ) && \
	( mv "$$rpmbuild"/{,$$(arch)/}*.rpm $(DESTDIR).; rm -fr -- "$$rpmbuild"; ls $(DESTDIR)*.rpm )

.PHONY: clean
