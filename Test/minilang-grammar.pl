# --------------------------------------------------------------------
#use strict;
use English;

package main;

# --------------------------------------------------------------------
def whitespace, terminal('\s+');
def owhite, optional($whitespace);

def period, terminal('\.');
def comma,  terminal(',');
def semicolon, terminal(';');

def lparen, terminal('\(');
def rparen, terminal('\)');
def lbrack, terminal('\[');
def rbrack, terminal('\]');
def lbrace, terminal('\{');
def rbrace, terminal('\}');

def string, terminal('"[^"]*"');
def number, terminal('[\d]+(?:.[\d]+)?');
def name, terminal('[-\w^!$%&/=?+*#\':<>|@]+');

def token, alternation($string, $lparen, $number, $comma, $period, $name, $rparen, $semicolon);
def tokenlist, pelist($token, $owhite);

# --------------------------------------------------------------------
def literal, alternation($string, $number);
#def simple_term, alternation($literal, $name);

my $chain;

# Possibly empty list (set): list ::+ e
#def exprlist, pelist($expr, $comma);
def exprlist, pelist($chain, $comma);

def tuple, construction($lparen, $exprlist, $rparen);

def term, alternation($literal, $name, $tuple);

#def mchain, nelist($term, $whitespace);
def mchain, nelist($term, $period);

#def expr, construction($mchain);

# Non-empty list: program ::+ expr
#def program, nelist($expr, $semicolon);
def program, nelist($mchain, $semicolon);

print("grammar.pl:");
print("program='$program'\n");

$exprlist->{element}= $mchain;

# --------------------------------------------------------------------
# EOF
1;
