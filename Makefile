#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#

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


.PHONY: make
make:
	if [ -x /usr/bin/apt-get ]; then make apt-packages; fi
	if [ -x /usr/bin/yum ];     then make yum-packages; fi

	git submodule init
	git submodule update

	cd lib && make

	#@ [ $$EUID -eq 0 ] || { echo "error: must be root to install cpan modules"; exit 1; }
	yes "" | $(SUDO2) cpan App::cpanminus
	yes "" | $(SUDO2) $(CPANM) --notest \
		LWP::Simple \
		Text::Unidecode \
		URI::Escape \
		XML::Simple
	@echo
	@echo BUILD SUCCESSFUL (spotify)


.PHONY: apt-packages
apt-packages:
	$(SUDO) apt-get install -y gcc
	# needed to fetch the library submodule at end of build
	$(SUDO) apt-get install -y git

.PHONY: yum-packages
yum-packages:
	rpm -q gcc || $(SUDO) yum install -y gcc
	# needed to fetch the library submodule and CPAN modules
	rpm -q perl-CPAN git || $(SUDO) yum install -y perl-CPAN git


.PHONY: test
test:
	cd lib && make test
	tests/all.sh

.PHONY: install
install:
	@echo "No installation needed, just add '$(PWD)' to your \$$PATH"

.PHONY: update
update:
	git pull
	git submodule update
	make
	make test
