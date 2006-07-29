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

#use Grammar; # qw(def Terminal Construction Alternation Optional Nelist Pelist)
#use Grammar ':all';

Grammar::import();

# --------------------------------------------------------------------
# Allow use of barewords

# Why isn't this allowed?:
#perl -e 'use diagnostics; sub f{print "@_\n"} f x1 a b c d e F G;'

# This is needed to allow bareword arguments to def. Why?
sub def($$@);
#sub Terminal;
#sub Optional;
#sub Construction;
#sub Alternation;
#sub Nelist;
#sub Pelist;

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
#def(Nilly, Terminal("Nilly"));

# Works only when the 'sub def' is present:
#def Billy, Terminal("Billy");

# --------------------------------------------------------------------
# Allow their use without qualifying their names.
#my ($Program, $Exprlist, $Mchain);

#Grammar::def Whitespace, Grammar::Terminal('\s+');

def Terminal, Whitespace, '\s+';
def Optional, Owhite, Whitespace;

def Terminal, Period, '\.';
def Terminal, Comma, ',';
def Terminal, Semicolon, ';';

def Terminal, Lparen, '\(';
def Terminal, Rparen, '\)';
def Terminal, Lbrack, '\[';
def Terminal, Rbrack, '\]';
def Terminal, Lbrace, '\{';
def Terminal, Rbrace, '\}';

def Terminal, String, '"[^"]*"';
def Terminal, Number, '[\d]+(?:.[\d]+)?';
def Terminal, Name, '[-\w^!$%&/=?+*#\':<>|@]+';

def Alternation, Token, String, Lparen, Number, Comma, Period, Name, Rparen, Semicolon;

def Pelist, Tokenlist, Token, Owhite;

# --------------------------------------------------------------------
def Alternation, Literal, String, Number;
#def Alternation, Simple_term, Literal, Name;

# Possibly empty list (set): list ::+ e

# Note that Chain has not been defined yet, that is further below.
#my $Chain;
#def Pelist, Exprlist, Expr, Comma;
def Pelist, Exprlist, Chain, Comma;
#def Pelist, Exprlist, 'Chain', Comma;
#def Pelist, Exprlist, undef, Comma;

def Construction, Tuple, Lparen, Exprlist, Rparen;

# In Perl, 'Term' is effectively a reserved name (package 'Term').
def Alternation, LTerm, Literal, Name, Tuple;

#def Nelist, Mchain, LTerm, Whitespace;
def Nelist, Mchain, LTerm, Period;

#def Construction, Expr, Mchain;

# Non-empty list: Program ::+ Expr
#def Nelist, Program, Expr, Semicolon;
def Nelist, Program, Mchain, Semicolon;

print("grammar.pl:");
print("Program='$minilang::Program'\n");
#print("Program='$Program'\n");

$minilang::Exprlist->{element}= $minilang::Mchain;
#$Exprlist->{element}= $Mchain;

# --------------------------------------------------------------------
# EOF
1;
