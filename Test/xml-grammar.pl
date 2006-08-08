# --------------------------------------------------------------------
package Parse::SiLLy::Test::XML;

use strict;
#use warnings;
use diagnostics;
#use English;

::import_from("main", "assert");

#BEGIN { $Exporter::Verbose=1 }

# Prefer qualifying all uses of this package's contents

# --------------------------------------------------------------------
# Import components from package 'Parse::SiLLy::Grammar'

sub terminal;
sub optional;
sub construction;
sub alternation;
sub nelist;
sub pelist;

Parse::SiLLy::Grammar::import();

# --------------------------------------------------------------------
# Allow use of barewords

# This does not prevent the 'Unquoted...' warning:
# Prevent it by using uppercase chars in grammar element names. 
no strict 'subs'; # Allow barewords (used to def grammar elements)

# --------------------------------------------------------------------
# Terminals

terminal     Space,           ' ';
terminal     Tab,             '\t';
terminal     Newline,         '\n';
terminal     Cr,              '\r';

terminal     QuestionMark,    '\?';
terminal     ExclamationMark, '\!';
terminal     Dash,            '-';
terminal     Equals,          '=';
terminal     DQuote,          '"';
terminal     SQuote,          "'";

terminal     Langle,          '<';
terminal     Slash,           '/';
terminal     Rangle,          '>';

alternation  OneWhitespace,   Space, Tab, Newline, Cr;

#nelist       Whitespace,      OneWhitespace, '';
terminal     Whitespace,      '[ \t\n\r]+';

# Allow escaped double quotes in string contents
# FIXME: Does XML allow them?
#terminal    DStringContent,   '[^"]*(?:\"[^"]*)*';
terminal     DStringContent,   '[^"]*';
terminal     SStringContent,   "[^']*";

#terminal    DStringLiteral,   '"[^"]*"';
#terminal    DStringLiteral,   "\"[^\"]*?:\\\"[^\"]*)*\"";
#terminal    DStringLiteral,   '"[^"]*(?:\"[^"]*)*"';
construction DStringLiteral,   DQuote, DStringContent, DQuote;
construction SStringLiteral,   SQuote, SStringContent, SQuote;
alternation  StringLiteral,    DStringLiteral, SStringLiteral;

terminal     Attrname,        '[\w]+';
#terminal     Attrname,        '[\w:]+';
terminal     Tagname,         '[\w]+';
#terminal     Tagname,         '[\w:]+';

#terminal    Cdata,           '[<]+';
#terminal    Cdata,           '[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]*';
# Use + as a quick fix to ensure progress
terminal     Cdata,           '[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]+';

# --------------------------------------------------------------------
# Simple Composites

optional    Owhite, Whitespace;
#pelist       Owhite, OneWhitespace, '';

construction Attr,   Attrname, Equals, StringLiteral;
#pelist       Attrsi, Attr, Whitespace;
nelist       Attrsi, Attr, Whitespace;
construction Attrs,  Whitespace, Attrsi;
optional     Oattrs, Attrs;

# More elaborate
construction Ltag, Langle,        Owhite, Tagname, Oattrs, Owhite, Rangle;
construction Etag, Langle,        Owhite, Tagname, Oattrs, Owhite, Slash, Owhite, Rangle;
construction Rtag, Langle, Slash, Owhite, Tagname,                        Owhite, Rangle;

# Simplified
#construction Ltag, Langle,        Tagname, Rangle;
#construction Etag, Langle,        Tagname, Slash, Rangle;
#construction Rtag, Langle, Slash, Tagname,        Rangle;

# Processing Instructions
# Example: <?xml version="1.0" encoding="ISO-8859-1"?>

construction ProcessingInstruction,
    Langle, QuestionMark, Tagname,
    Oattrs, Owhite,
    QuestionMark, Rangle;

# FIXME: Does not handle '--' in the middle of a comment
#terminal     CommentContent, '(?:[^-]*-)*[^-]+';
# FIXME: Does not handle '-' in the middle of a comment
terminal     CommentContent, '[^-]*';
construction Comment,
    Langle, ExclamationMark, Dash, Dash,
    CommentContent,
    Dash, Dash, Rangle;

# --------------------------------------------------------------------
# Nested Composites

# FIXME: Fix handling of "Elem" here:
#alternation  Contentelem, ProcessingInstruction, 'Elem', Cdata;
alternation  Contentelem, ProcessingInstruction, Comment, 'Elem', Cdata;

pelist       Contentlist, Contentelem, Owhite;
#pelist       Contentlist, Contentelem, Cdata;

construction Complexelem, Ltag, Contentlist, Rtag;

#alternation  Elem, Etag, Complexelem;
$Parse::SiLLy::Test::XML::Elem= $Parse::SiLLy::Test::XML::Complexelem;

# FIXME: Document this:
# FIXME: Simplify this:
#assert("Elem" eq $ {$Parse::SiLLy::Test::XML::Contentelem->{elements}}[0]);
#$ {$Parse::SiLLy::Test::XML::Contentelem->{elements}}[0]= $Elem;
my ($i, $i_elem)= (-1, -1);
grep { ++$i; if (m/Elem/) { $i_elem= $i; } }
    @{$Parse::SiLLy::Test::XML::Contentelem->{elements}};
#map { ++$i; if ( ! defined($_)) { $i_elem= $i; } }
#    @{$Parse::SiLLy::Test::XML::Contentelem->{elements}};
assert(-1 != $i_elem); print("Found Elem at $i_elem\n");
$ {$Parse::SiLLy::Test::XML::Contentelem->{elements}}[$i_elem]= $Parse::SiLLy::Test::XML::Elem;

print("xml-grammar.pl:");
print("Elem='$Parse::SiLLy::Test::XML::Elem'\n");

# --------------------------------------------------------------------
# EOF
1;
