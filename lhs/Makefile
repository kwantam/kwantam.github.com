# this Makefile was borrowed from Thomas Sutton, passingcuriosity.com
# http://passingcuriosity.com/2008/literate-haskell-with-markdown-syntax-hightlighting/

.SUFFIXES: .lhs .html

HTMLOUTPUTDIR := ../
STYLESHEETS := -c 'css/hscolour.css' -c 'css/main.css' -c 'http://fonts.googleapis.com/css?family=Inconsolata' -c 'http://fonts.googleapis.com/css?family=Brawler'

.lhs.html:
	cat $< | hscolour -lit -css -partial | pandoc --no-wrap -sS -t html ${STYLESHEETS} > ${HTMLOUTPUTDIR}/$@

all:
	@echo ERROR please choose a file!
