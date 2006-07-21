# --------------------------------------------------------------------
#use strict;
use English;

package main;

# --------------------------------------------------------------------
def Whitespace, terminal('\s+');
def Owhite, optional($Whitespace);

def Period, terminal('\.');
def Comma,  terminal(',');
def Semicolon, terminal(';');

def Lparen, terminal('\(');
def Rparen, terminal('\)');
def Lbrack, terminal('\[');
def Rbrack, terminal('\]');
def Lbrace, terminal('\{');
def Rbrace, terminal('\}');

def String, terminal('"[^"]*"');
def Number, terminal('[\d]+(?:.[\d]+)?');
def Name, terminal('[-\w^!$%&/=?+*#\':<>|@]+');

def Token, alternation($String, $Lparen, $Number, $Comma, $Period, $Name, $Rparen, $Semicolon);

def Tokenlist, pelist($Token, $Owhite);

# --------------------------------------------------------------------
def Literal, alternation($String, $Number);
#def Simple_term, alternation($Literal, $Name);

#my $Chain;

# Possibly empty list (set): list ::+ e
#def Exprlist, pelist($Expr, $Comma);
#def Exprlist, pelist($Chain, $Comma);
def Exprlist, pelist('Chain', $Comma);
#def Exprlist, pelist(undef, $Comma);

def Tuple, construction($Lparen, $Exprlist, $Rparen);

# Term is effectively a reserved name (package 'Term').
def LTerm, alternation($Literal, $Name, $Tuple);

#def Mchain, nelist($LTerm, $Whitespace);
def Mchain, nelist($LTerm, $Period);

#def Expr, construction($Mchain);

# Non-empty list: Program ::+ Expr
#def Program, nelist($Expr, $Semicolon);
def Program, nelist($Mchain, $Semicolon);

print("grammar.pl:");
print("Program='$Program'\n");

$exprlist->{element}= $mchain;

# --------------------------------------------------------------------
# EOF
1;
