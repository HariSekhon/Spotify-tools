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

REPO := HariSekhon/spotify-tools

ifdef TRAVIS
	SUDO2 =
	CPANM = cpanm
else
	SUDO2 = sudo
	CPANM = /usr/local/bin/cpanm
endif

# EUID /  UID not exported in Make
# USER not populated in Docker
ifeq '$(shell id -u)' '0'
	SUDO =
	SUDO2 =
else
	SUDO = sudo
endif


.PHONY: build
build:
	@echo ===================
	@echo Spotify Tools Build
	@echo ===================

	if [ -x /sbin/apk ];        then $(MAKE) apk-packages; fi
	if [ -x /usr/bin/apt-get ]; then $(MAKE) apt-packages; fi
	if [ -x /usr/bin/yum ];     then $(MAKE) yum-packages; fi

	git submodule init
	git submodule update --recursive

	cd lib && $(MAKE)

	#@ [ $$EUID -eq 0 ] || { echo "error: must be root to install cpan modules"; exit 1; }
	yes "" | $(SUDO2) cpan App::cpanminus
	yes "" | $(SUDO2) $(CPANM) --notest \
		LWP::Simple \
		Text::Unidecode \
		URI::Escape \
		XML::Simple
	@echo
	@echo "BUILD SUCCESSFUL (spotify-tools)"

.PHONY: apk-packages
apk-packages:
	$(SUDO) apk update
	$(SUDO) apk add `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/apk-packages.txt`

.PHONY: apk-packages-remove
apk-packages-remove:
	cd lib && $(MAKE) apk-packages-remove
	$(SUDO) apk del `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/apk-packages-dev.txt` || :
	$(SUDO) rm -fr /var/cache/apk/*

.PHONY: apt-packages
apt-packages:
	$(SUDO) apt-get install -y `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/deb-packages.txt`

.PHONY: apt-packages-remove
apt-packages-remove:
	cd lib && $(MAKE) apt-packages-remove
	$(SUDO) apt-get purge -y `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/deb-packages-dev.txt`

.PHONY: yum-packages
yum-packages:
	for x in `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/rpm-packages.txt`; do rpm -q $$x || $(SUDO) yum install -y $$x; done

.PHONY: yum-packages-remove
yum-packages-remove:
	cd lib && $(MAKE) yum-packages-remove
	for x in `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/rpm-packages-dev.txt`; do rpm -q $$x && $(SUDO) yum remove -y $$x; done

.PHONY: test
test:
	cd lib && $(MAKE) test
	tests/all.sh

.PHONY: install
install:
	@echo "No installation needed, just add '$(PWD)' to your \$$PATH"

.PHONY: update
update:
	$(MAKE) update-no-recompile
	$(MAKE)
	@#$(MAKE) test

.PHONY: update2
update2:
	$(MAKE) update-no-recompile

.PHONY: update-no-recompile
update-no-recompile:
	git pull
	git submodule update --init --recursive

.PHONY: update-submodules
update-submodules:
	git submodule update --init --remote
.PHONY: updatem
updatem:
	$(MAKE) update-submodules

.PHONY: clean
clean:
	@echo Nothing to clean

.PHONY: push
push:
	git push
