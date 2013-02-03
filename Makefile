#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#

.PHONY: install
install:
	@ [ $$EUID -eq 0 ] || { echo "error: must be root to install cpan modules"; exit 1; }
	cpan LWP::Simple
	cpan Text::Unidecode
	cpan URI::Escape
	cpan XML::Simple
	git submodule init
	git sudmodule update
