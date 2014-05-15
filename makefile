PROGRAM := your-program-name
LIBRARYFILES := ../compiler/bin/wakeobj/std.o
LIBRARYTABLES := $(filter-out $(wildcard ../compiler/bin/waketable/*Test.table), $(wildcard ../compiler/bin/waketable/*.table) )
TESTLIBRARYFILES :=

TABLEDIR := bin/waketable
OBJECTDIR := bin/wakeobj
SRCDIR := src
TESTDIR := test

SOURCEFILES := $(wildcard $(SRCDIR)/*.wk)
TESTFILES := $(wildcard $(TESTDIR)/*.wk)

DEPFILES := ${SOURCEFILES:.wk=.d} ${TESTFILES:.wk=.d}
OBJECTFILES := $(subst $(SRCDIR),$(OBJECTDIR),${SOURCEFILES:.wk=.o})
TESTOBJECTFILES := $(subst $(TESTDIR),$(OBJECTDIR),${TESTFILES:.wk=.o})
TABLEFILES := $(subst $(SRCDIR),$(TABLEDIR),${SOURCEFILES:.wk=.table})
TESTTABLEFILES := $(subst $(TESTDIR),$(TABLEDIR),${TESTFILES:.wk=.table})

bin/$(PROGRAM): $(OBJECTFILES) $(TABLEFILES) $(LIBRARYFILES) tests
	wake -l -d $(TABLEDIR) -o bin/$(PROGRAM) $(OBJECTFILES) $(LIBRARYFILES)

.PHONY:
tests: bin/$(PROGRAM)-test
	node bin/$(PROGRAM)-test

bin/$(PROGRAM)-test: $(OBJECTFILES) $(TESTLIBRARYFILES) $(LIBRARYFILES) $(TABLEFILES) $(TESTOBJECTFILES) $(TESTTABLEFILES)
	wunit-compiler
	wake bin/TestSuite.wk -d $(TABLEDIR) -o bin/TestSuite.o
	wake -l -d $(TABLEDIR) $(OBJECTFILES) $(TESTOBJECTFILES) $(TESTLIBRARYFILES) $(LIBRARYFILES) bin/TestSuite.o -o bin/$(PROGRAM)-test -c TestSuite -m 'tests()'

to-md5 = $1 $(addsuffix .md5,$1)

%.md5: % FORCE
	@$(if $(filter-out $(shell cat $@ 2>/dev/null),$(shell md5sum $*)),md5sum $* > $@)

FORCE:

$(addprefix $(TABLEDIR)/,$(notdir $(LIBRARYTABLES))): $(LIBRARYTABLES)
	cp $(LIBRARYTABLES) $(TABLEDIR)

$(SRCDIR)/%.d: $(SRCDIR)/%.wk
	@./generate-makefile.sh $< $(TABLEDIR) > $@

$(TESTDIR)/%.d: $(TESTDIR)/%.wk
	@./generate-makefile.sh $< $(TABLEDIR) > $@

$(TABLEDIR)/%.table: $(SRCDIR)/%.wk
	wake $< -d $(TABLEDIR) -t

$(OBJECTDIR)/%.o: $(SRCDIR)/%.wk
	wake $< -d $(TABLEDIR) -o $@

$(TABLEDIR)/%Test.table: $(TESTDIR)/%Test.wk
	wake $< -d $(TABLEDIR) -t

$(OBJECTDIR)/%Test.o: $(TESTDIR)/%Test.wk
	wake $< -d $(TABLEDIR) -o $@

ifneq "$(MAKECMDGOALS)" "clean"
-include ${SOURCEFILES:.wk=.d}
endif

clean:
	rm $(TABLEFILES) || :
	rm $(TESTTABLEFILES) || :
	rm $(DEPFILES) || :
	rm $(TESTOBJECTFILES) || :
	rm $(OBJECTFILES) || :
	rm bin/TestSuite.wk || :
	rm bin/TestSuite.o || :
	rm bin/$(PROGRAM) || :
	rm bin/$(PROGRAM)-test || :
	find . -name '*.md5' -delete
