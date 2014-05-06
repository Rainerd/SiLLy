default:
default: test

INC=${HOME}/comp/lang/perl
parse=perl -I"${INC}" -I"${INC}/SVStream/lib" parse.pl

test: xml-test
xml-test:
	${parse} Test/xml-grammar.pl Test/XML/example.xml
