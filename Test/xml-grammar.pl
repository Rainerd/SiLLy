# --------------------------------------------------------------------
package Parse::SiLLy::Test::XML;

use strict;
use warnings;
#use diagnostics;
#use English;
my $ctx= "xml-grammar.pl";

::import_from("main", "assert");

#BEGIN { $Exporter::Verbose=1 }

# Prefer qualifying all uses of this package's contents

# --------------------------------------------------------------------
# Import components from package 'Parse::SiLLy::Grammar'

sub terminal;
sub optional;
sub lookingat;
sub notlookingat;
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
terminal     Colon,           ':';
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
terminal     DStringContent,  '[^"]*';
terminal     SStringContent,  "[^']*";

#terminal    DStringLiteral,   '"[^"]*"';
#terminal    DStringLiteral,   "\"[^\"]*?:\\\"[^\"]*)*\"";
#terminal    DStringLiteral,   '"[^"]*(?:\"[^"]*)*"';
construction DStringLiteral,  DQuote, DStringContent, DQuote;
construction SStringLiteral,  SQuote, SStringContent, SQuote;
alternation  StringLiteral,   DStringLiteral, SStringLiteral;

terminal     PrefixName,      '\w+';
terminal     PlainAttrName,   '\w+';
terminal     PlainTagName,    '\w+';

# FIXME: Use a negative definition, "everything but ...".
#terminal    Cdata,           '[<]+';
#terminal    Cdata,           '[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]*';
# Use + as a quick fix to ensure progress
terminal     Cdata,           '[-.,\d()\[\]\{\}\w^!$%&/?+*#\':;|@\s]+';

# --------------------------------------------------------------------
# Simple Composites

optional     Owhite,          Whitespace;
#pelist       Owhite,          OneWhitespace, '';

construction Prefix,          PrefixName, Colon;
optional     OPrefix,         Prefix;

construction Attrname,        OPrefix, PlainAttrName;
construction Tagname,         OPrefix, PlainTagName;

construction Attr,            Attrname, Equals, StringLiteral;
#pelist       Attrsi,          Attr, Whitespace;
nelist       Attrsi,          Attr, Whitespace;
construction Attrs,           Whitespace, Attrsi;
optional     Oattrs,          Attrs;

# More elaborate
construction STag,     Langle,        Owhite, Tagname, Oattrs, Owhite, Rangle;
construction EmptyTag, Langle,        Owhite, Tagname, Oattrs, Owhite, Slash, Owhite, Rangle;
construction ETag,     Langle, Slash, Owhite, Tagname,                        Owhite, Rangle;

# Simplified
#construction STag,     Langle,        Tagname, Rangle;
#construction EmptyTag, Langle,        Tagname, Slash, Rangle;
#construction ETag,     Langle, Slash, Tagname,        Rangle;

# Processing Instructions
# Example: <?xml version="1.0" encoding="ISO-8859-1"?>

construction ProcessingInstruction,
    Langle, QuestionMark, Tagname,
    Oattrs, Owhite,
    QuestionMark, Rangle;

# FIXME: Handle -- in the middle of comments
# FIXME: Use perl's negative lookahead
# FIXME: Does not handle '--' in the middle of a comment
#terminal     CommentContent, '(?:[^-]*-)*[^-]+';
# FIXME: Does not handle '-' in the middle of a comment
#terminal     CommentContent, '[^-]*';
construction CommentEndAfterDash,    Dash, Rangle;
construction CommentEnd,             Dash, CommentEndAfterDash;

notlookingat NotCommentEndAfterDash, CommentEndAfterDash;
construction DashInsideComment,      Dash, NotCommentEndAfterDash;
terminal     NonDash,                '[^-]';
alternation  CommentChar,            DashInsideComment, NonDash;
terminal     Epsilon,                '';
pelist       CommentContent,         CommentChar, Epsilon;

# Almost uselessly complicated CommentStart definition, just to test lookingat:
#construction CommentStart,       Langle, ExclamationMark, Dash, Dash,
lookingat    LaWhitespace,       Whitespace;
construction CommentStartSpaced, Langle, ExclamationMark, Dash, Dash, LaWhitespace;
construction CommentStartSimple, Langle, ExclamationMark, Dash, Dash;
alternation  CommentStart,       CommentStartSpaced, CommentStartSimple;

construction Comment,
    #Langle, ExclamationMark, Dash, Dash,
    CommentStart,
    CommentContent,
    CommentEnd;

# --------------------------------------------------------------------
# Nested Composites

# FIXME: Fix handling of "Elem" here:
#alternation  MixedContent, ProcessingInstruction, 'Elem', Cdata;
alternation  MixedContent, ProcessingInstruction, Comment, 'Elem', Cdata;

pelist       Contentlist,  MixedContent, Owhite;
#pelist       Contentlist,  MixedContent, Cdata;

construction SEElem,       STag, Contentlist, ETag;

alternation  Elem,         EmptyTag, SEElem;

# FIXME: Inline this, as it is called only once.
sub elements( $ ) {
    my ($production)= @_;
    #Parse::SiLLy::Grammar::PRODS_ARE_HASHES()
    #? $production->{elements} :
    $production->[Parse::SiLLy::Grammar::PROD_ELEMENTS];
}

{
    # FIXME: Document this:
    # FIXME: Simplify this:
    my $elements= elements($Parse::SiLLy::Test::XML::MixedContent);
    my $Elem    = $Parse::SiLLy::Test::XML::Elem;
    #assert("Elem" eq $elements->[0]);
    #$elements->[0]= $Elem;
    my ($i, $i_elem)= (-1, -1);
    grep { ++$i; if (m/Elem/) { $i_elem= $i; } } @$elements;
    #map { ++$i; if ( ! defined($_)) { $i_elem= $i; } } @$elements;
    assert(-1 != $i_elem); print("$ctx: Found Elem at $i_elem\n");
    $elements->[$i_elem]= $Elem;

    print("$ctx: Test::XML::Elem='$Elem'\n");
}

# --------------------------------------------------------------------
# EOF
1;
