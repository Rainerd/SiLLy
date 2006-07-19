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

# --------------------------------------------------------------------
# Terminals

def Whitespace, terminal('\s+');

def Equals, terminal('=');

def Langle, terminal('<');
def Slash,  terminal('/');
def Rangle, terminal('>');

def Value, terminal('"[^"]*"');
# Used for testing only:
#def Number, terminal('[\d]+(?:.[\d]+)?');
def Attrname,  terminal('[-\w^!$%&/?+*#\':|@]+');
def Tagname,  terminal('[-\w^!$%&/?+*#\':|@]+');
def Cdata, terminal('[-\w^!$%&/?+*#\':|@\s]*');

# --------------------------------------------------------------------
# Simple Composites

def Owhite, optional($Whitespace);

def Attr, construction($Attrname, $Equals, $Value);
def Attrsi, pelist($Attr, $Whitespace);
def Attrs, construction($Whitespace, $Attrsi);
def Oattrs, optional($Attrs);

def Ltag, construction($Langle,         $Owhite, $Tagname, $Oattrs, $Owhite, $Rangle);
def Etag, construction($Langle,         $Owhite, $Tagname, $Oattrs, $Owhite, $Slash, $Owhite, $Rangle);
def Rtag, construction($Langle, $Slash, $Owhite, $Tagname,                           $Owhite, $Rangle);

# --------------------------------------------------------------------
# Nested Composites

#my $Elem;

def Contentelem, alternation('Elem', $Cdata);
def Contentlist, pelist($Contentelem, $Owhite);
def Complexelem, construction($Ltag, $Contentlist, $Rtag);
def Elem, alternation($Etag, $Complexelem);
$Contentelem->{first}= $Elem;

print("xml-grammar.pl:");
print("Elem='$Elem'\n");

# --------------------------------------------------------------------
# EOF
1;
