#-*- mode: makefile; -*-
# make POD=extract
# make POD=remove
# make SCAN=off

SHELL := /bin/bash

.SHELLFLAGS := -ec

VERSION := $(shell test -e VERSION || echo 1.0.0 > VERSION; cat VERSION)

MODULE_NAME  ?= $(shell SOURCE=$(top_srcdir) perl -MCwd=abs_path -MFile::Basename=basename -e '$$m=basename(abs_path($$ENV{SOURCE})); $$m =~s/\-/::/g; print $$m')

MODULE_PATH = lib/$(shell echo $(MODULE_NAME) | perl -npe 's/::/\//g;').pm

PROJECT_NAME ?= $(shell echo $(MODULE_NAME) | sed -e 's/::/-/g;')

UNIT_TEST_NAME = $(shell TEST_NAME=$(PROJECT_NAME) perl -e 'printf q{t/00-%s.t}, lc $$ENV{TEST_NAME}')

MAKE_CPAN_DIST := $(shell command -v make-cpan-dist.pl)
SCANDEPS       := $(shell command -v scandeps-static.pl)
POD2MARKDOWN   := $(shell command -v pod2markdown)
GIT            := $(shell command -v git)
PODEXTRACT     := $(shell command -v podextract)

GIT_NAME     ?= $(shell $(GIT) config --global user.name || echo "Anonymouse")
GIT_EMAIL    ?= $(shell $(GIT) config --global user.email || echo "anonymouse@example.org")
GITHUB_USER  ?= $(shell $(GIT) config --global user.github || echo "anonymouse")

MIN_PERL_VERSION ?= 5.010

BUILDSPEC_TEMPLATE := $(shell perl -MFile::ShareDir=dist_file -e 'print dist_file(q{CPAN-Maker-Bootstrapper}, q{buildspec.yml.tmpl});' 2>/dev/null || echo buildspec.yml.tmpl )

UNIT_TEST_TEMPLATE := $(shell perl -MFile::ShareDir=dist_file -e 'print dist_file(q{CPAN-Maker-Bootstrapper}, q{test.t.tmpl});' 2>/dev/null || echo test.t.tmpl )

SCAN ?= ON

define find-files
$(1) := $(patsubst %.in,%,$(shell find $(2) -type f -name "$(3)"))
endef

$(eval $(call find-files,PERL_MODULES,lib,*.pm.in))
$(eval $(call find-files,BIN_FILES,bin,*.in))
$(eval $(call find-files,TESTS,t,*.t))
$(eval $(call find-files,SOURCE_FILES,lib bin,*.p[ml].in))

POD_MODULES = $(PERL_MODULES:.pm=.pod)

%.pm: %.pm.in
	@module_tmp="$$(mktemp)"; \
	local_cleanfiles="$$module_tmp"; \
	trap 'rm -f $$local_cleanfiles' EXIT; \
	sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' \
	    -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' $< >"$$module_tmp";  \
	if [[ "$$POD" =~ ^(extract|remove)$  ]]; then \
	  nopod_tmp="$$(mktemp)"; \
	  local_cleanfiles="$$local_cleanfiles $$nopod_tmp"; \
	  if [[ "$$POD" = "extract" ]]; then \
	    podout="$@"; podout="$${podout%.pm}.pod"; \
	  else \
	    podout="/dev/null"; \
	  fi; \
	  $(PODEXTRACT) -i "$$module_tmp" -o "$$nopod_tmp" -p "$$podout"; \
	  cp "$$nopod_tmp" "$$module_tmp"; \
	fi; \
	cp "$$module_tmp" "$@"; \

bin/%.pl: bin/%.pl.in
	@sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' \
	    -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' < $< > $@; \
	chmod +x $@

bin/%.sh: bin/%.sh.in
	@sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' \
	    -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' < $< > $@; \
	chmod +x $@

bin/%: bin/%.in
	@sed -e 's/[@]PACKAGE_VERSION[@]/$(VERSION)/' \
	    -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' < $< > $@; \
	chmod +x $@

TARBALL = $(PROJECT_NAME)-$(VERSION).tar.gz

DEPS = \
    buildspec.yml \
    $(MODULE_PATH).in \
    $(PERL_MODULES) \
    $(BIN_FILES) \
    requires \
    test-requires \
    $(UNIT_TEST_NAME) \
    README.md \
    ChangeLog

all: $(TARBALL)

$(TARBALL): $(DEPS)
	$(MAKE_CPAN_DIST) -b $<

module.pm.tmpl:
	@if [[ -n "$(STUB)" ]]; then \
	  cp --preserve=all --update=none $(STUB) $@; \
	  chmod +w $@; \
	else \
	  touch $@; \
	fi; \

$(MODULE_PATH).in: module.pm.tmpl
	@mkdir -p $$(dirname $@); \
	test -e $@ || sed -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' \
	    -e 's/[@]GIT_NAME[@]/$(GIT_NAME)/' \
	    -e 's/[@]GIT_EMAIL[@]/$(GIT_EMAIL)/' < $< > $@

$(UNIT_TEST_NAME): $(UNIT_TEST_TEMPLATE)
	@sed -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' < $< > $@

README.md: $(MODULE_PATH)
	@$(POD2MARKDOWN) $< > $@

.PHONY: modulino
modulino: modulino.tmpl
	@binfile="$(PROJECT_NAME)"; \
	modulino="bin/$${binfile,,}"; \
	sed -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/' $< > "$${modulino}.in"; \
	test -e .gitignore && { grep -q "$$modulino" .gitignore || echo "$$modulino" >> .gitignore; }; \
	echo "$$modulino"

define scan-deps
	dep_requires=$$(mktemp); \
	packages=$$(mktemp); \
	cleanfiles="$$cleanfiles $$dep_requires $$packages $(1).tmp"; \
	for a in $$(find $(2) -name "$(3)"); do \
	  perl -ne 'print "$$1\n" if /^package +(.*?);/' $$a >> $$packages; \
	  $(SCANDEPS) -r --no-core $$a | awk '{printf "%s %s\n", $$1,$$2}' >> $$dep_requires; \
	done; \
	if test -s "$$dep_requires"; then \
	  sort -u $$dep_requires > $(1).tmp; \
	  grep -vFf "$$packages" "$(1).tmp" > $(1); \
	else \
	  touch $(1); \
	fi
endef

define filter_requires = 

  sub get_requires {
    my ($infile) = @_;

    return {}
      if !-s $infile;

    my %requires;

    open my $fh, '<', $infile or
      die "could not open $infile for reading\n";

    while (<$fh>) {
      chomp;
      my ($m,$v) = split ' ', $_;
      $requires{$m} = $v // 0;
    }

    close $fh;

    return \%requires;
  }

  my $skip_requires = get_requires("$ENV{REQUIRES}.skip");
  my $requires_tmp  = get_requires("$ENV{REQUIRES}.xxx");
  my $requires      = get_requires($ENV{REQUIRES});

  my %new_requires;

  # copy preserved modules (ones preceded with '+')
  foreach my $m (keys %{$requires_tmp} ) {
    next if $m !~/^\+/xsm;
    $new_requires{$m} = $requires_tmp->{$m};
  }

  foreach my $m (keys %{$requires} ) {
    # skip modules on skip list
    next if exists $skip_requires->{$m};
    next if exists $requires_tmp->{"+$m"};

    # keep modules from preserved list if versions differ (user must have specified specific version)
    if ( exists $requires_tmp->{$m} && $requires_tmp->{$m} ne $requires->{$m} ) {
      $new_requires{$m} = $requires_tmp->{$m};
    }
    else {
      $new_requires{$m} = $requires->{$m};
   }
  }

  print join q{}, map { "$_ $new_requires{$_}\n" } keys %new_requires;

endef

export s_filter_requires = $(value filter_requires)

requires: $(SOURCE_FILES)
	@cleanfiles="$@.tmp $@.xxx"; \
	trap 'rm -f $$cleanfiles' EXIT; \
	scan="$(SCAN)"; \
	if [[ "$${scan^^}" = "ON" ]]; then \
	  if test -e "$@"; then \
	    cp "$@" "$@.xxx"; \
	  fi; \
	  $(call scan-deps,$@,lib bin,*.p[ml].in); \
	  if test -e "$@.xxx"; then \
	    requires_list=$$(REQUIRES="$@" perl -e "$$s_filter_requires"); \
	    echo "$$requires_list" | sort > "$@"; \
	  fi; \
	fi

test-requires: $(TESTS)
	@cleanfiles="$@.tmp $@.xxx"; \
	trap 'rm -f $$cleanfiles' EXIT; \
	scan="$(SCAN)"; \
	if [[ "$${scan^^}" = "ON" ]]; then \
	  if test -e "$@"; then \
	    cp "$@" "$@.xxx"; \
	  fi; \
	  $(call scan-deps,$@,t,*.t); \
	  if test -e "$@.xxx"; then \
	    requires_list=$$(REQUIRES="$@" perl -e "$$s_filter_requires"); \
	    echo "$$requires_list" | sort > "$@"; \
	  fi; \
	fi

ChangeLog:
	@touch $@

buildspec.yml: $(BUILDSPEC_TEMPLATE)
	@sed -e 's/[@]MODULE_NAME[@]/$(MODULE_NAME)/g' \
	    -e 's/[@]GIT_NAME[@]/$(GIT_NAME)/g' \
	    -e 's/[@]GITHUB_USER[@]/$(GITHUB_USER)/g' \
	    -e 's/[@]GIT_EMAIL[@]/$(GIT_EMAIL)/g' \
	    -e 's/[@]PROJECT_NAME[@]/$(PROJECT_NAME)/g' \
	    -e 's/[@]MIN_PERL_VERSION[@]/$(MIN_PERL_VERSION)/g' $< > $@

include version.mk

include release-notes.mk

CLEANFILES = \
    $(BIN_FILES) \
    $(PERL_MODULES) \
    $(POD_MODULES) \
    *.tar.gz \
    *.tmp \
    *.xxx \
    extra-files \
    provides \
    module.pm.tmpl \
    resources \
    release-*.{lst,diffs}

clean:
	rm -f $(CLEANFILES)
