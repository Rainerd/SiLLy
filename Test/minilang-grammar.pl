#use strict;
use English;

package main;

#my $whitespace= terminal('\s+');
def whitespace, terminal('\s+');
#my $owhite= optional($whitespace);
def owhite, optional($whitespace);

#my $comma= construction($owhite, ',', $owhite);
#def comma, construction($owhite, ',', $owhite);
def comma, terminal(',');
#my $semicolon= construction($owhite, ';', $owhite);
#def semicolon, construction($owhite, ';', $owhite);
def semicolon, terminal(';');

#def lparen, construction($owhite, '(', $owhite);
def lparen, terminal('(');
#def rparen, construction($owhite, ')', $owhite);
def rparen, terminal(')');

def string, terminal('"[^"]*"');
def number, terminal('[.\d]+');
def name, terminal('\w+');

def literal, alternation($string, $number);
#def simple_term, alternation($literal, $name);

def token, alternation($string, $lparen, $number, $comma, $name, $rparen, $semicolon);
def tokenlist, pelist($token, $owhite);

my $chain;

# Possibly empty list (set): list ::+ e
#def exprlist, pelist($expr, $comma);
def exprlist, pelist($chain, $comma);

def tuple, construction($lparen, $exprlist, $rparen);

def term, alternation($literal, $name, $tuple);

def chain, nelist($term, $whitespace);

#def expr, construction($chain);

# Non-empty list: program ::+ expr
#def program, nelist($expr, $semicolon);
def program, nelist($chain, $semicolon);

print("grammar.pl:");
print("program='$program'\n");

$exprlist->{element}= $chain;

1;

# EOF
