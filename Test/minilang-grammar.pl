# --------------------------------------------------------------------
#package main;
package minilang;

use strict;
#use warnings;
use diagnostics;
#use English;

# --------------------------------------------------------------------
# This package does not export anything by default.
# Instead, all uses of this package's contents should be qualified.

BEGIN { $Exporter::Verbose= 1; }
#use Exporter;
#@::ISA= qw(Exporter);
#%EXPORT_TAGS= ('all' => [qw()]);
#import main qw(Space);
#my $Space;
#*Space= \$::Space;

# --------------------------------------------------------------------
# Import components from package 'Grammar'

#use Grammar; # qw(def terminal construction alternation optional nelist pelist)
#use Grammar ':all';

Grammar::import();

# --------------------------------------------------------------------
# Allow use of barewords

# This is needed to allow bareword arguments to def. Why?
sub def($$);

# This does not prevent the 'Unquoted...' warning:
# Prevent it by using uppercase chars in grammar element names. 
no strict 'subs'; # Allow barewords (used to def grammar elements)

# Barewords appear to denote strings.  Here's a little test that shows this:
#sub test_bareword { print(STDERR "_[0]='$_[0]' ref='".ref($_[0])."'\n"); }
#test_bareword(Bearword);
sub value($) { return ($_[0]); }
::import_from("", "assert");
assert('Bearword' eq Bearword);
assert('Bearword' eq value(Bearword));
assert('' eq ref(Bearword));

# Works, even without the 'sub def;':
#def(Nilly, terminal("Nilly"));

# Works only when the 'sub def' is present:
#def Billy, terminal("Billy");

# --------------------------------------------------------------------
# Allow their use without qualifying their names.
#my ($Program, $Exprlist, $Mchain);

#Grammar::def Whitespace, Grammar::terminal('\s+');

def Whitespace, terminal('\s+');
def Owhite, optional(Whitespace);

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

def Token, alternation(String, Lparen, Number, Comma, Period, Name, Rparen, Semicolon);

def Tokenlist, pelist(Token, Owhite);

# --------------------------------------------------------------------
def Literal, alternation(String, Number);
#def Simple_term, alternation(Literal, Name);

# Possibly empty list (set): list ::+ e

# Note that Chain has not been defined yet, that is further below.
#my $Chain;
#def Exprlist, pelist(Expr, Comma);
def Exprlist, pelist(Chain, Comma);
#def Exprlist, pelist('Chain', Comma);
#def Exprlist, pelist(undef, Comma);

def Tuple, construction(Lparen, Exprlist, Rparen);

# In Perl, 'Term' is effectively a reserved name (package 'Term').
def LTerm, alternation(Literal, Name, Tuple);

#def Mchain, nelist(LTerm, Whitespace);
def Mchain, nelist(LTerm, Period);

#def Expr, construction(Mchain);

# Non-empty list: Program ::+ Expr
#def Program, nelist(Expr, Semicolon);
def Program, nelist(Mchain, Semicolon);

print("grammar.pl:");
print("Program='$minilang::Program'\n");
#print("Program='$Program'\n");

$minilang::Exprlist->{element}= $minilang::Mchain;
#$Exprlist->{element}= $Mchain;

# --------------------------------------------------------------------
# EOF
1;
