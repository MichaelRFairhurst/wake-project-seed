PROGRAM := your-program-name

# set to false or it will be linked with a main()
EXECUTABLE := true

# Include all wake libraries by default since there aren't many just yet
LIBRARYFILES := $(wildcard lib/obj/*.o)
LIBRARYTABLES := $(wildcard lib/table/*.table)
TESTLIBRARYFILES :=

##
# You can edit these directories if you wish
##
SRCDIR := src
TESTDIR := test
GENDIR := gen
TABLEDIR := bin/waketable
OBJECTDIR := bin/wakeobj
SRCDEPDIR := bin/srcdep
TESTDEPDIR := bin/testdep

##
# Use command names based on OS
##
ifeq ($(OS),Windows_NT)
	WAKE := wake.exe
	NODE := node.exe
	WUNIT := node.exe wunit-compiler
	WOCKITO := node.exe wockito-generator
	MD5SUM := win/md5sums.exe -u
	WGET := win/wget.exe
	UNZIP := win/tar.exe -xvf
else
	WAKE := wake
	NODE := node
	WUNIT := node wunit-compiler
	WOCKITO := node wockito-generator
	UNZIP := tar -xvf
	RM := rm -f
endif
ifeq ($(shell uname),Linux)
	MD5SUM := md5sum
	WGET := wget
endif
ifeq ($(shell uname),Darwin)
	MD5SUM := md5
	WGET := curl -o libs-latest.tar
endif

##
# Download lib sources if they don't exist
##
ifeq ($(strip $(wildcard lib/*)),)
	FORCESHELL := $(shell $(WGET) http://wakelang.com/libs-latest.tar)
	FORCESHELL := $(shell $(UNZIP) libs-latest.tar)
	FORCESHELL := $(shell $(RM) libs-latest.tar )
	FORCESHELL := $(shell mv bundle lib)
endif

##
# Gather the current code
##
SOURCEFILES := $(wildcard $(SRCDIR)/*.wk)
TESTFILES := $(wildcard $(TESTDIR)/*.wk)

##
# Calculate our artifacts
##
DEPFILES := $(subst $(SRCDIR),$(SRCDEPDIR),${SOURCEFILES:.wk=.d}) $(subst $(TESTDIR),$(TESTDEPDIR),${TESTFILES:.wk=.d})
OBJECTFILES := $(subst $(SRCDIR),$(OBJECTDIR),${SOURCEFILES:.wk=.o})
TESTOBJECTFILES := $(subst $(TESTDIR),$(OBJECTDIR),${TESTFILES:.wk=.o})
TABLEFILES := $(subst $(SRCDIR),$(TABLEDIR),${SOURCEFILES:.wk=.table})
TESTTABLEFILES := $(subst $(TESTDIR),$(TABLEDIR),${TESTFILES:.wk=.table})

## ENTRY POINT ##
all: bin/$(PROGRAM)

##
# Include dynamic makefiles generated for each source file
#
# Each source and test file creates a makefile which specifies
# mocks needed, and imported files. This allows wockito to
# generate minimal mocks incrementally, and allows make to
# build sources in the correct order.
##
ifneq "$(MAKECMDGOALS)" "clean"
-include $(DEPFILES)
endif

##
# Calculate the mock artifacts based on what our dynamic
# makefiles counted.
##
MOCKOBJECTFILES := $(subst .table.md5,.o,$(subst $(TABLEDIR),$(OBJECTDIR),$(MOCKS)))
MOCKCLASSNAMES := $(subst Mock.table.md5,,$(subst $(TABLEDIR)/,,$(MOCKS)))
# only link MockProvider if we have at least one mock
ifneq ($(MOCKCLASSNAMES),)
	MOCKPROVIDEROBJ := $(OBJECTDIR)/MockProvider.o
endif

## Compile our main executable ##
bin/$(PROGRAM): $(OBJECTFILES) $(TABLEFILES) $(LIBRARYFILES) tests
ifeq ($(EXECUTABLE), true)
		$(WAKE) -l -d $(TABLEDIR) -o bin/$(PROGRAM) $(OBJECTFILES) $(LIBRARYFILES)
endif

##
# Run test suite. The test suite is built whenever any source files or
# test files change. Uses wUnit, which uses reflection to generate a
# test suite based on existing tablefiles.
##
.PHONY:
tests: bin/$(PROGRAM)-test
	$(NODE) bin/$(PROGRAM)-test

bin/$(PROGRAM)-test: $(OBJECTFILES) $(TESTLIBRARYFILES) $(LIBRARYFILES) $(TABLEFILES) $(TESTOBJECTFILES) $(TESTTABLEFILES)
	$(WUNIT)
	$(WAKE) bin/TestSuite.wk -d $(TABLEDIR) -o bin/TestSuite.o
	$(WAKE) -l -d $(TABLEDIR) $(OBJECTFILES) $(TESTOBJECTFILES) $(TESTLIBRARYFILES) $(LIBRARYFILES) $(MOCKOBJECTFILES) $(MOCKPROVIDEROBJ) bin/TestSuite.o -o bin/$(PROGRAM)-test -c TestSuite -m 'tests()'

##
# MD5 features. This lets make decide not to rebuild sources that depend
# on other sources which changed, but only when the interface of that source
# also changed.
##
to-md5 = $1 $(addsuffix .md5,$1)

%.md5: % FORCE
	@$(if $(filter-out $(shell cat $@ 2>/dev/null),$(shell $(MD5SUM) $*)),$(MD5SUM) $* > $@)

FORCE:

##
# Copy our library table files into our table dir
##
$(addprefix $(TABLEDIR)/,$(notdir $(LIBRARYTABLES))): $(LIBRARYTABLES)
	cp $(LIBRARYTABLES) $(TABLEDIR)

##
# Generate the dynamic makefiles that determine compilation
# order and mock creation
##
$(SRCDEPDIR)/%.d: $(SRCDIR)/%.wk
	@$(NODE) generate-makefile $< $(TABLEDIR) > $@

$(TESTDEPDIR)/%.d: $(TESTDIR)/%.wk
	@$(NODE) generate-makefile $< $(TABLEDIR) > $@

##
# Wake compiler commands
##
$(OBJECTDIR)/%.o: $(SRCDIR)/%.wk
	$(WAKE) $< -d $(TABLEDIR) -o $@

$(OBJECTDIR)/%Test.o: $(TESTDIR)/%Test.wk
	$(WAKE) $< -d $(TABLEDIR) -o $@

##
# Don't do anything, but tell make that .table files are created with .o files
##
$(TABLEDIR)/%Test.table: $(TESTDIR)/%Test.wk $(OBJECTDIR)/%Test.o
	@:

$(TABLEDIR)/%.table: $(SRCDIR)/%.wk $(OBJECTDIR)/%.o
	@:

##
# Compile our mocks. This first rule generates a .o file and three
# .table files. The last three rules tell make that the .table files
# are made when the .o file is made.
##
$(OBJECTDIR)/%Mock.o: $(GENDIR)/%Mock.wk
	$(WAKE) $< -d $(TABLEDIR) -o $@

$(TABLEDIR)/%Mock.table: $(GENDIR)/%Mock.wk $(OBJECTDIR)/%Mock.o
	@:

$(TABLEDIR)/%Stubber.table: $(OBJECTDIR)/%Mock.o
	@:

$(TABLEDIR)/%Verifier.table: $(OBJECTDIR)/%Mock.o
	@:

##
# Mock source generation
##
$(GENDIR)/%Mock.wk: $(TABLEDIR)/%.table.md5
	$(WOCKITO) -d $(TABLEDIR) -o $@ $*

$(GENDIR)/MockProvider.wk: $(MOCKS)
	$(WOCKITO) -p -d $(TABLEDIR) -o $@ $(MOCKCLASSNAMES)

##
# Mock provider compilation
##
$(OBJECTDIR)/MockProvider.o: $(GENDIR)/MockProvider.wk
	$(WAKE) $< -d $(TABLEDIR) -o $@

$(TABLEDIR)/MockProvider.table: $(OBJECTDIR)/MockProvider.o

##
# And clean up after our selves. Woo!
##
clean:
	$(RM) $(TABLEDIR)/* || :
	$(RM) $(SRCDEPDIR)/* || :
	$(RM) $(TESTDEPDIR)/* || :
	$(RM) $(OBJECTDIR)/* || :
	$(RM) bin/TestSuite.wk || :
	$(RM) bin/TestSuite.o || :
	$(RM) bin/$(PROGRAM) || :
	$(RM) bin/$(PROGRAM)-test || :
	$(RM) $(GENDIR)/* || :
	find . -name '*.md5' -delete
