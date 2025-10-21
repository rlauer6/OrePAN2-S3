#-*- mode: makefile; -*-
SHELL := /bin/bash

.SHELLFLAGS := -ec

VERSION := $(shell cat VERSION)

PERL_MODULES = \
    lib/OrePAN2/S3.pm.in

GPERL_MODULES=$(PERL_MODULES:.pm.in=.pm)

%.pm: %.pm.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' < $< > $@

BIN_FILES = \
    bin/orepan2-s3 \
    bin/orepan2-s3-index

TARBALL = OrePAN2-S3-$(VERSION).tar.gz

DEPS = \
    buildspec.yml \
    $(GPERL_MODULES) \
    $(BIN_FILES) \
    requires \
    test-requires \
    README.md

$(TARBALL): $(DEPS)
	make-cpan-dist.pl -b $<

include version.mk

clean:
	rm -f *.gz $(GPERL_MODULES)
