#-*- mode: makefile; -*-

PERL_MODULES = \
    lib/OrePAN2/S3.pm

BIN_FILES = \
    bin/orepan2-s3 \
    bin/orepan2-s3-index

VERSION := $(shell perl -I lib -MOrePAN2::S3 -e 'print $$OrePAN2::S3::VERSION;')

TARBALL = OrePAN2-S3-$(VERSION).tar.gz

DEPS = \
    buildspec.yml \
    $(PERL_MODULES) \
    $(BIN_FILES) \
    requires \
    test-requires \
    README.md

$(TARBALL): $(DEPS)
	make-cpan-dist.pl -b $<

clean:
	rm -f *.gz
