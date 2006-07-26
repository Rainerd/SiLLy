# --------------------------------------------------------------------
use strict;
#use warnings;
use diagnostics;
use English;

# This does not prevent the 'Unquoted...' warning:
# Prevent it by using uppercase chars in grammar element names. 
no strict 'subs'; # Allow barewords (used to def grammar elements)

no strict 'vars'; # Allow omitting '::'.

package main;

# Barewords denote strings 
#sub test_bareword { print(STDERR "_[0]='$_[0]' ref='".ref($_[0])."'\n"); }
#test_bareword(Bearword);

#use Exporter;
#@::ISA= qw(Exporter);
#import main qw(Space);
#my $Space;
#*Space= \$::Space;

# --------------------------------------------------------------------
# Terminals

def Space,   terminal(" ");
def Tab,     terminal("\t");
def Newline, terminal("\n");
def Cr,      terminal("\r");

def OneWhitespace, alternation($Space, $Tab, $Newline, $Cr);
#def OneWhitespace, alternation($Space, Tab, $Newline, $Cr);

def Whitespace, nelist($OneWhitespace, '');

def QuestionMark, terminal('\?');
def ExclamationMark, terminal('\!');
def Dash, terminal('-');
def Equals, terminal('=');
def DQuote, terminal('"');

def Langle, terminal('<');
def Slash,  terminal('/');
def Rangle, terminal('>');

#def StringContent, terminal('[^"]*(?:\\\"[^"]*)*');
def StringContent, terminal('[^"]');
#def StringContent, alternation('[^"]');
#def Value, terminal('"[^"]*"');
#def Value, terminal('"[^"]*(?:\\\"[^"]*)*"');
def StringLiteral, construction($DQuote, $StringContent, $DQuote);

def Attrname,  terminal('\w+');
def Tagname,  terminal('\w+');
#def Cdata, terminal('[<]+');
#def Cdata, terminal('[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]*');
# Use + as a quick fix to ensure progress
def Cdata, terminal('[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]+');

# --------------------------------------------------------------------
# Simple Composites

#def Owhite, optional($Whitespace);
def Owhite, pelist($OneWhitespace, '');

def Attr, construction($Attrname, $Equals, $Value);
def Attrsi, pelist($Attr, $Whitespace);
def Attrs, construction($Whitespace, $Attrsi);
def Oattrs, optional($Attrs);

# More elaborate
def Ltag, construction($Langle,         $Owhite, $Tagname, $Oattrs, $Owhite, $Rangle);
def Etag, construction($Langle,         $Owhite, $Tagname, $Oattrs, $Owhite, $Slash, $Owhite, $Rangle);
def Rtag, construction($Langle, $Slash, $Owhite, $Tagname,                           $Owhite, $Rangle);

# Simplified
#def Ltag, construction($Langle,         $Tagname, $Rangle);
#def Etag, construction($Langle,         $Tagname, $Slash, $Rangle);
#def Rtag, construction($Langle, $Slash, $Tagname,         $Rangle);

# Processing Instructions
# Example: <?xml version="1.0" encoding="ISO-8859-1"?>

def ProcessingInstruction,
    construction($Langle, $QuestionMark, $Tagname,
                 $Owhite, $Oattrs, $Owhite,
                 $QuestionMark, $Rangle);

def CommentContent, terminal("(?:[^-]*-)*[^-]+-->");
def Comment,
    construction($Langle, $ExclamationMark, $Dash, $Dash,
                 $CommentContent,
                 $Dash, $Dash, $Exclamationmark, $Rangle);

# --------------------------------------------------------------------
# Nested Composites

def Contentelem, alternation($ProcessingInstruction, 'Elem', $Cdata);
#def Contentelem, alternation($ProcessingInstruction, $Comment, 'Elem', $Cdata);
def Contentlist, pelist($Contentelem, $Owhite);
def Complexelem, construction($Ltag, $Contentlist, $Rtag);
#def Elem, alternation($Etag, $Complexelem);
$Elem= $Complexelem;

#assert("Elem" eq $ {$Contentelem->{elements}}[0]);
#$ {$Contentelem->{elements}}[0]= $Elem;
my ($i, $i_elem)= (-1, -1);
grep { ++$i; if (m/Elem/) { $i_elem= $i; } } @{$Contentelem->{elements}};
assert(-1 != $i_elem); #print("Found Elem at $i_elem\n");
$ {$Contentelem->{elements}}[$i_elem]= $Elem;

print("xml-grammar.pl:");
print("Elem='$Elem'\n");

# --------------------------------------------------------------------
# EOF
1;
