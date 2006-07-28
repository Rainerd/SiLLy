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
sub def($$@);
sub def_terminal($$);
sub def_optional($$);
sub def_construction($@);
sub def_alternation($@);
sub def_nelist($$$);
sub def_pelist($$$);

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

def_terminal Whitespace, '\s+';
def_optional Owhite, Whitespace;

def_terminal Period, '\.';
def_terminal Comma, ',';
def_terminal Semicolon, ';';

def_terminal Lparen, '\(';
def_terminal Rparen, '\)';
def_terminal Lbrack, '\[';
def_terminal Rbrack, '\]';
def_terminal Lbrace, '\{';
def_terminal Rbrace, '\}';

def_terminal String, '"[^"]*"';
def_terminal Number, '[\d]+(?:.[\d]+)?';
def_terminal Name, '[-\w^!$%&/=?+*#\':<>|@]+';

def_alternation Token, String, Lparen, Number, Comma, Period, Name, Rparen, Semicolon;

def_pelist Tokenlist, Token, Owhite;

# --------------------------------------------------------------------
def_alternation Literal, String, Number;
#def_alternation Simple_term, Literal, Name;

# Possibly empty list (set): list ::+ e

# Note that Chain has not been defined yet, that is further below.
#my $Chain;
#def_pelist Exprlist, Expr, Comma;
def_pelist Exprlist, Chain, Comma;
#def_pelist Exprlist, 'Chain', Comma;
#def_pelist Exprlist, undef, Comma;

def_construction Tuple, Lparen, Exprlist, Rparen;

# In Perl, 'Term' is effectively a reserved name (package 'Term').
def_alternation LTerm, Literal, Name, Tuple;

#def_nelist Mchain, LTerm, Whitespace;
def_nelist Mchain, LTerm, Period;

#def_construction Expr, Mchain;

# Non-empty list: Program ::+ Expr
#def_nelist Program, Expr, Semicolon;
def_nelist Program, Mchain, Semicolon;

print("grammar.pl:");
print("Program='$minilang::Program'\n");
#print("Program='$Program'\n");

$minilang::Exprlist->{element}= $minilang::Mchain;
#$Exprlist->{element}= $Mchain;

# --------------------------------------------------------------------
# EOF
1;
