# --------------------------------------------------------------------
#package main;
package minilang;

use strict;
use warnings;
#use diagnostics;
#use English;

# --------------------------------------------------------------------
# This package does not export anything by default.
# Instead, all uses of this package's contents should be qualified.

#BEGIN { $Exporter::Verbose= 1; }
#use Exporter;
#@::ISA= qw(Exporter);
#%EXPORT_TAGS= ('all' => [qw()]);
#import main qw(Space);
#my $Space;
#*Space= \$::Space;

# --------------------------------------------------------------------
# Allow use of barewords

# Why isn't this allowed?:
#perl -e 'use diagnostics; sub f{print "@_\n"} f x1 a b c d e F G;'

# This is needed to allow bareword arguments to def. Why?
#sub def($$$$$@);

# FIXME: Can we get rid of these (or least write them more compactly)?:

sub terminal;
sub optional;
sub construction;
sub alternation;
sub nelist;
sub pelist;

# This does not prevent the 'Unquoted...' warning:
# Prevent it by using uppercase chars in grammar element names. 
no strict 'subs'; # Allow barewords (used to denote nonterminal grammar elements)

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
# Import components from package 'Parse::SiLLy::Grammar'

#use Parse::SiLLy::Grammar; # qw(def terminal construction alternation optional nelist pelist)
#use Parse::SiLLy::Grammar ':all';

Parse::SiLLy::Grammar::import();

# --------------------------------------------------------------------
# Allow their use without qualifying their names.
#my ($Program, $Exprlist, $Mchain);

#def          Whitespace, terminal('\s+');

terminal     Whitespace, '\s+';
optional     Owhite,     Whitespace;

terminal     Period,     '\.';
terminal     Comma,      ',';
terminal     Semicolon,  ';';

terminal     Lparen,     '\(';
terminal     Rparen,     '\)';
terminal     Lbrack,     '\[';
terminal     Rbrack,     '\]';
terminal     Lbrace,     '\{';
terminal     Rbrace,     '\}';

terminal     String,     '"[^"]*"';
terminal     Number,     '[\d]+(?:.[\d]+)?';
terminal     Name,       '[-\w^!$%&/=?+*#\':<>|@]+';

alternation  Token,      String, Lparen, Number, Comma, Period, Name, Rparen, Semicolon;

pelist       Tokenlist,  Token, Owhite;

# --------------------------------------------------------------------
alternation  Literal,    String, Number;
#alternation  Simple_term, Literal, Name;

# Possibly empty list (set): list ::* e

# Note that Chain has not been defined yet, that is further below.
#my $Chain;
construction WComma,     Owhite, Comma, Owhite;
#pelist       Exprlist,   Expr, WComma;
pelist       Exprlist,   Chain, WComma;
#pelist       Exprlist,   'Chain', WComma;
#pelist       Exprlist,   undef, WComma;

construction Tuple,      Lparen, Exprlist, Rparen;

# In Perl, 'Term' is effectively a reserved name (package 'Term').
alternation  LTerm,      Literal, Name, Tuple;

# Message Chain
#nelist,     Mchain,     LTerm, Whitespace;
nelist       Mchain,     LTerm, Period;

#construction Expr,  Mchain;

construction WSemicolon, Owhite, Semicolon, Owhite;
# Non-empty list: Program ::+ Expr
#nelist       Program,    Expr, Semicolon;
nelist       Program,    Mchain, WSemicolon;

print("minilang-grammar.pl: ");
print("minilang::Program='$minilang::Program'\n");
#print("Program='$Program'\n");

# Establish recursion:
$minilang::Exprlist->[Parse::SiLLy::Grammar::PROD_ELEMENT()]= $minilang::Mchain;

# --------------------------------------------------------------------
# EOF
1;
