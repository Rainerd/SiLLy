default:
default: test

parse=perl -Ilib parse.pl

#test: xml-namespace-test
test: xml-test

xml-test:
	${parse} Test/xml-grammar.pl Test/XML/example.xml

xml-namespace-test:
	${parse} Test/xml-grammar.pl Test/XML/namespace.xml
