#  vim:ts=4:sts=4:sw=4:noet
#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#
#  https://github.com/harisekhon/spotify-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#  to help improve or steer this or other code I publish
#
#  http://www.linkedin.com/in/harisekhon
#

ifneq ("$(wildcard bash-tools/Makefile.in)", "")
	include bash-tools/Makefile.in
endif

REPO := HariSekhon/spotify-tools

CODE_FILES := $(shell find . -type f -name '*.pl' -o -type f -name '*.pm' -o -type f -name '*.sh' -o -type f -name '*.t' | grep -v -e bash-tools -e Hbase)

ifndef CPANM
	CPANM := cpanm
endif

.PHONY: build
build: init
	@echo ===================
	@echo Spotify Tools Build
	@echo ===================
	@$(MAKE) git-summary
	echo

	if [ -x /sbin/apk ];        then $(MAKE) apk-packages; fi
	if [ -x /usr/bin/apt-get ]; then $(MAKE) apt-packages; fi
	if [ -x /usr/bin/yum ];     then $(MAKE) yum-packages; fi

	git submodule init
	git submodule update --recursive

	cd lib && $(MAKE)

	$(MAKE) system-packages-perl
	$(MAKE) perl

	@echo
	@echo "BUILD SUCCESSFUL (spotify-tools)"
	@echo
	@echo

.PHONY: init
init:
	git submodule update --init --recursive

.PHONY: perl
perl:
	perl -v

	#(echo y; echo o conf prerequisites_policy follow; echo o conf commit) | cpan
	which $(CPANM) || { yes "" | $(SUDO_PERL) cpan App::cpanminus; }
	$(CPANM) -V | head -n2

	cd lib && $(MAKE)

	$(MAKE) cpan

.PHONY: test
test:
	cd lib && $(MAKE) test
	tests/all.sh

.PHONY: install
install: build
	@echo "No installation needed, just add '$(PWD)' to your \$$PATH"

.PHONY: clean
clean:
	@echo Nothing to clean
