# this Makefile was borrowed from Thomas Sutton, passingcuriosity.com
# http://passingcuriosity.com/2008/literate-haskell-with-markdown-syntax-hightlighting/

.SUFFIXES: .lhs .mkd .html .tex .pdf

PANDOC := pandoc --no-wrap -sS
HSCOLOUR := hscolour -lit
HTMLOUTPUTDIR := ../
STYLESHEETS := -c 'css/hscolour.css' -c 'css/main.css' -c 'http://fonts.googleapis.com/css?family=Inconsolata' -c 'http://fonts.googleapis.com/css?family=Brawler'

.lhs.mkd:
	cat $< | $(HSCOLOUR) -css > $@

.lhs.html:
	cat $< | $(HSCOLOUR) -css | $(PANDOC) -t html ${STYLESHEETS} > ${HTMLOUTPUTDIR}/$@

.lhs.tex:
	cat $< | $(HSCOLOUR) -latex | $(PANDOC) -t latex> $@

.tex.pdf:
	pdflatex $< && pdflatex $< && pdflatex $<

