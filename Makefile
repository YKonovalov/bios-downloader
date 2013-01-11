prefix        ?= /usr
bindir        ?= $(prefix)/bin
datadir       ?= $(prefix)/share/bios-downloader

spec           = "pkg/rpm/bios-downloader.spec"
spec_version  := "$(shell sed -n 's/Version:[[:blank:]]\+\([[:digit:].]\+\)/\1/p' ${spec})"
spec_name     := "$(shell sed -n 's/Name:[[:blank:]]\+\([[:alpha:]-]\+\)/\1/p' ${spec})"

.PHONY : all
all:

distpath:
	sed -i 's:MDIR="../modules":MDIR="$(datadir)/modules":' tool/bios-downloader tool/samsung-platformid tool/samsung-update-platformid-stats

srpm:
	git archive -9 --format=tar.gz --prefix=${spec_name}-${spec_version}/ --output=${spec_name}-${spec_version}.tar.gz master
	rpmbuild -D '%_sourcedir ./' -D '%_srcrpmdir ./' --rmsource -bs pkg/rpm/bios-downloader.spec


install:
	@mkdir -p -- $(DESTDIR)$(bindir) $(DESTDIR)$(datadir)/modules
	cp -a -- tool/* $(DESTDIR)$(bindir)
	cp -a -- modules/* $(DESTDIR)$(datadir)/modules
