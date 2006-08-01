# --------------------------------------------------------------------
package Grammar::XML;

use strict;
#use warnings;
use diagnostics;
#use English;

::import_from("main", "assert");

#BEGIN { $Exporter::Verbose=1 }

# Prefer qualifying all uses of this package's contents

# --------------------------------------------------------------------
# Import components from package 'Grammar'

Grammar::import();

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

terminal     Langle,          '<';
terminal     Slash,           '/';
terminal     Rangle,          '>';

alternation  OneWhitespace,   Space, Tab, Newline, Cr;

nelist       Whitespace,      OneWhitespace, '';

# Allow escaped double quotes in string contents
# FIXME: Does XML allow them?
#terminal    StringContent,   '[^"]*(?:\"[^"]*)*';
terminal     StringContent,   '[^"]';

#terminal    StringLiteral,   '"[^"]*"';
#terminal    StringLiteral,   "\"[^\"]*?:\\\"[^\"]*)*\"";
#terminal    StringLiteral,   '"[^"]*(?:\"[^"]*)*"';
construction StringLiteral,   DQuote, StringContent, DQuote;

terminal     Attrname,        '\w+';
terminal     Tagname,         '\w+';
#terminal    Cdata,           '[<]+';
#terminal    Cdata,           '[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]*';
# Use + as a quick fix to ensure progress
terminal     Cdata,           '[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]+';

# --------------------------------------------------------------------
# Simple Composites

#optional    Owhite, Whitespace;
pelist       Owhite, OneWhitespace, '';

construction Attr,   Attrname, Equals, Value;
pelist       Attrsi, Attr, Whitespace;
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
    Owhite, Oattrs, Owhite,
    QuestionMark, Rangle;

terminal     CommentContent, '(?:[^-]*-)*[^-]+-->';
construction Comment,
    Langle, ExclamationMark, Dash, Dash,
    CommentContent,
    Dash, Dash, Exclamationmark, Rangle;

# --------------------------------------------------------------------
# Nested Composites

# FIXME: Fix handling of "Elem" here:
alternation  Contentelem, ProcessingInstruction, 'Elem', Cdata;
#alternation  Contentelem, ProcessingInstruction, Comment, 'Elem', Cdata;
pelist       Contentlist, Contentelem, Owhite;
construction Complexelem, Ltag, Contentlist, Rtag;
#alternation  Elem, Etag, Complexelem;
$Grammar::XML::Elem= $Grammar::XML::Complexelem;

#assert("Elem" eq $ {$Grammar::XML::Contentelem->{elements}}[0]);
#$ {$Grammar::XML::Contentelem->{elements}}[0]= $Elem;
my ($i, $i_elem)= (-1, -1);
grep { ++$i; if (m/Elem/) { $i_elem= $i; } }
    @{$Grammar::XML::Contentelem->{elements}};
#map { ++$i; if ( ! defined($_)) { $i_elem= $i; } }
#    @{$Grammar::XML::Contentelem->{elements}};
assert(-1 != $i_elem); #print("Found Elem at $i_elem\n");
$ {$Grammar::XML::Contentelem->{elements}}[$i_elem]= $Grammar::XML::Elem;

print("xml-grammar.pl:");
print("Elem='$Grammar::XML::Elem'\n");

# --------------------------------------------------------------------
# EOF
1;
