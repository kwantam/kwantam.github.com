# this Makefile was borrowed from Thomas Sutton, passingcuriosity.com
# http://passingcuriosity.com/2008/literate-haskell-with-markdown-syntax-hightlighting/

.SUFFIXES: .lhs .html

HTMLOUTPUTDIR := ../

.lhs.html:
	cat $< | hscolour -lit -css -partial | pandoc --no-wrap -sS -t html -H head.html -A tail.html > ${HTMLOUTPUTDIR}/$@

all:
	@echo ERROR please choose a file!
