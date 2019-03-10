SRC_DIRS := 'src' $(shell test -d 'vendor' && echo 'vendor')
ALL_VFILES := $(shell find $(SRC_DIRS) -name "*.v")
TEST_VFILES := $(shell find 'src' -name "*Tests.v")
PROJ_VFILES := $(shell find 'src' -name "*.v")
VFILES := $(filter-out $(TEST_VFILES),$(PROJ_VFILES))

COQARGS :=

coq: $(VFILES:.v=.vo)
test: $(TEST_VFILES:.v=.vo) $(VFILES:.v=.vo)
docs: doc/html/indexpage.html

_CoqProject: libname $(wildcard vendor/*)
	@echo "-R src $$(cat libname)" > $@
	@for libdir in $(wildcard vendor/*); do \
	libname=$$(cat $$libdir/libname); \
	if [ $$? -ne 0 ]; then \
	  echo "Do you need to run git submodule update --init --recursive?" 1>&2; \
		exit 1; \
	fi; \
	echo "-R $$libdir/src $$(cat $$libdir/libname)" >> $@; \
	done
	@echo "_CoqProject:"
	@cat $@

.coqdeps.d: $(ALL_VFILES) _CoqProject
	@echo "COQDEP $@"
	@coqdep -f _CoqProject $(ALL_VFILES) > $@

ifneq ($(MAKECMDGOALS), clean)
-include .coqdeps.d
endif

%.vo: %.v _CoqProject
	@echo "COQC $<"
	@coqc $(COQARGS) $(shell cat '_CoqProject') $< -o $@

COQDOC_ASSETS := doc/coqdocjs-assets
COQDOC_ARGS := --utf8 --html --interpolate \
	--toc --toc-depth 2 \
	--no-lib-name \
  --index indexpage \
	--parse-comments \
	--with-header $(COQDOC_ASSETS)/header.html \
	--with-footer $(COQDOC_ASSETS)/footer.html

ALL_NONTEST_VFILES := $(filter-out $(TEST_VFILES),$(ALL_VFILES))

doc/html/indexpage.html: coq $(ALL_NONTEST_VFILES)
	@rm -rf doc/html
	@mkdir doc/html
	@echo "COQDOC"
	@coqdoc $(COQDOC_ARGS) $(shell cat '_CoqProject') -d doc/html $(ALL_NONTEST_VFILES)
	@cp -r $(COQDOC_ASSETS)/resources doc/html/

clean:
	@echo "CLEAN vo glob aux"
	@rm -f $(ALL_VFILES:.v=.vo) $(ALL_VFILES:.v=.glob)
	@find $(SRC_DIRS) -name ".*.aux" -exec rm {} \;
	rm -f _CoqProject .coqdeps.d

.PHONY: default test clean
.DELETE_ON_ERROR:
