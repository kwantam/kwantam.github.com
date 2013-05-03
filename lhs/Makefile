# this Makefile was borrowed from Thomas Sutton, passingcuriosity.com
# http://passingcuriosity.com/2008/literate-haskell-with-markdown-syntax-hightlighting/

.SUFFIXES: .md .lhs .html

HTMLOUTPUTDIR := ../

HSCOLOUR_CMD = hscolour -lit -css -partial
PANDOC_CMD = pandoc --no-wrap -sS -t html -H head.html -A tail.html

.lhs.html:
	cat $< | sed 's/^< /> /' | ${HSCOLOUR_CMD} | ${PANDOC_CMD} > ${HTMLOUTPUTDIR}/$@

.md.html:
	cat $< | ${PANDOC_CMD} > ${HTMLOUTPUTDIR}/$@

all:
	@echo ERROR please choose a file!
