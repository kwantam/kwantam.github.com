# this Makefile was borrowed from Thomas Sutton, passingcuriosity.com
# http://passingcuriosity.com/2008/literate-haskell-with-markdown-syntax-hightlighting/

.SUFFIXES: .md .lhs .html

MDTARGETS = $(subst md,html,$(wildcard *.md))
LHSTARGETS = $(subst lhs,html,$(wildcard *.lhs))

HTMLOUTPUTDIR := ../

HSCOLOUR_CMD = hscolour -lit -css -partial
PANDOC_CMD = pandoc --no-wrap -sS -t html -H head.html -A tail.html

.lhs.html:
	cat $< | sed 's/^< /> /' | ${HSCOLOUR_CMD} | ${PANDOC_CMD} > ${HTMLOUTPUTDIR}/$@

.md.html:
	cat $< | ${PANDOC_CMD} > ${HTMLOUTPUTDIR}/$@

%.md: %.html

%.lhs: %.html

all: $(MDTARGETS) $(LHSTARGETS)
