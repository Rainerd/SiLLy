default:

PROGRAMS+=parse
MODULES+=lib/Parse/SiLLy/Compare

# --------------------------------------------------------------------
# Tests

default: test

parse=perl parse.pl

#test: xml-namespace-test
test: xml-test

xml-test:
	${parse} Test/xml-grammar.pl Test/XML/example.xml

xml-namespace-test:
	${parse} Test/xml-grammar.pl Test/XML/namespace.xml

# --------------------------------------------------------------------
# Documentation

POD_TXTS=${MODULES:%=%.txt} ${PROGRAMS:%=%.txt}
POD_HTMLS=${MODULES:%=%.html} ${PROGRAMS:%=%.html}

pod2text=podchecker -warnings -warnings "$<"; pod2text "$<" > "$@"; cat "$@"

%.txt: %.pm Makefile
	${pod2text};
%.txt: %.pl Makefile
	${pod2text};

pod2html=pod2html --title="$<" "$<" > "$@"

%.html: %.pm Makefile
	${pod2html};
%.html: %.pl Makefile
	${pod2html};

docs: ${POD_TXTS}
docs: ${POD_HTMLS}

clean-docs:
	rm ${POD_TXTS} ${POD_HTMLS}

# --------------------------------------------------------------------
# EOF
