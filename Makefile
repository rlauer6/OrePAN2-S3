#-*- mode: makefile; -*-

PERL_MODULES = \
    lib/OrePAN2/S3.pm

VERSION := $(shell perl -I lib -MOrePAN2::S3 -e 'print $$OrePAN2::S3::VERSION;')

TARBALL = OrePAN2-S3-$(VERSION).tar.gz

$(TARBALL): buildspec.yml $(PERL_MODULES) requires test-requires README.md
	make-cpan-dist.pl -b $<

clean:
	rm -f *.gz
