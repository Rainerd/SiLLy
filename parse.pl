#!/usr/bin/perl -w
# --------------------------------------------------------------------
=pod

Usage: perl PROGRAM GRAMMAR INPUT > OUTPUT

Example:
    perl -w parse.pl Test/xml-grammar.pl Test/XML/example.xml

Debug:
    PARSE_SILLY_DEBUG=1 perl -w parse.pl Test/xml-grammar.pl Test/XML/example.xml

Profile:
    PARSE_SILLY_ASSERT=0; export PARSE_SILLY_ASSERT
    perl -w -d:DProf parse.pl Test/xml-grammar.pl Test/XML/example.xml;
    dprofpp

Profile:
    PARSE_SILLY_ASSERT=0; export PARSE_SILLY_ASSERT
    perl -w -I../.. -MDevel::Profiler parse.pl Test/xml-grammar.pl \
        Test/XML/example.xml;
    dprofpp

Lint:
    perl -w -MO=Lint parse.pl Test/xml-grammar.pl Test/XML/example.xml

Fastest so far:
    PARSE_SILLY_ASSERT=0 perl parse.pl Test/xml-grammar.pl Test/XML/example.xml

Note that the -w option may cost a percent or two of performance.

Does not work with my Perl: PERL_DEBUG_MSTATS=2

--------------------------------------------------------------------
Copyright (c) 2004-2016 by Rainer Blome

Copying and usage conditions for this document are specified in file
LICENSE.txt.

In short, you may use or copy this document as long as you:

* Keep this copyright and permission notice.

* Use it ,,as is``, at your own risk -- there is NO WARRANTY WHATSOEVER.

* Do not use my name in advertising.

* Allow free distribution of derivatives.


--------------------------------------------------------------------
--------------------------------------------------------------------

Purpose

Parses, according to the given grammar, the given input. Produces an
appropriately structured result (a parse tree alias concrete syntax tree).

Keywords

Parser, recursive descent, backtracking, backup, LL, unlimited
lookahead, memoizing, packrat, linear time, structured grammar rules
parsing expression grammar

Conceptual Grammar Example:

# Terminals
colon ::= ':'
linefeed ::= '\n'
name ::= '\w+'
delimiter ::= '---'
whitespace ::= '\s+'
#owhite ::? whitespace
owhite ::= '\s*'
rest ::= '[\n]*'

# Composites
assignment ::= owhite name owhite colon owhite rest
sectionbody ::* assignment linefeed
section ::= delimiter linefeed sectionbody
file ::* section linefeed


Example Input:

---
a: b
c: 4


Environment Variables

Below, for each variable, the example shows how to change the setting
from the default.

PARSE_SILLY_ASSERT=0 -- Do not check assertions, do not even compute
  the result.  This can significantly speed up the parser (by a factor
  of about two).  However, any remaining bugs may manifest themselves
  much later than when they are encountered.

PARSE_SILLY_MEMOIZE=1 -- Turns on memoization.  This makes this a
  packrat parser.  Currently, with the grammars and examples that I
  used for testing, this option slows the parser down by about 30%.
  Since I guess that the potential advantage of memoization is zero
  for the examples used, this is probably simply the overhead
  introduced by the memoization operations, plus possibly a cache
  penalty.

PARSE_SILLY_DEBUG=1 -- Enable debug messages.  This will slow the
  parser down by a factor of at least ten.

PARSE_SILLY_SHOW_LOCATION=0 -- Disables showing the parse location in
  error messages.


Design

Recursive descent with backup (backtracking of state in case of local mismatch).

Uses a kind of iterator for the input state.

Handles tokenized input (is this still true?).

Packrat behavior (memoizes matches and mismatches for each input position).

The production operators (terminal, construction, alternation etc.)
both construct the grammar element object and define a variable to
hold it.

Alternative: In the implementation of a production instance, on the
"right hand side", production elements can be represented by either
references to the productions themselves, or by names that refer to
the productions.

Features Done

* Automated minilang regression tests

* Separate 'minilang' test from XML test.

* Result print function with compact output format

* Memoize parse results and make use of them (Packrat parsing)

* Actually parse the XML input file's content

* Make it possible to switch off memoization

* Avoid calling debugging code (logging functions, data formatting)
  when debugging is off.

* Avoid checking contracts (assertions etc.) when ASSERT is off.

* Automated XML parsing regression test.

* Compile-time omission of debugging code (default is true).

* Command-line controls for Compile-time options:

  - ASSERT (default is on),

  - DEBUG (default is off),

  - MEMOIZE (default is off).

* If input could not be matched, generates error messages with
  detailed, recursive explanations of which rules did not match and
  why.

* Error messages and explanations show file name, line number and
  column number, in such a way that common development environments
  understand them and can jump to the exact file location (message
  format is "FILE:LINE:COLUMN: TEXT").

* Remembers the furthest mismatch, shows why it did not match, and
  explain how it got there, what the parser was trying to match when
  encountering that mismatch.


Internal Features Done

* Parse the hard-coded example string.

* Replace undef by 'not matched' constant

* Avoid array interpolation during result construction.

* Loggers are implemented as arrays.

* Inline result construction

* Compile-time option for MEMOIZATION.

* Uppercase NOMATCH (formerly nomatch) to get rid of inappropriate warnings.

* Unified implementation of nelist_match and pelist_match.

* Shared implementation of nelist_match and pelist_match.

* Productions are implemented as arrays.

* Parsers (state) are implemented as arrays.

* Automated regression tests for the assert function.

* For purposes of generating explanations, for non-matches,
  stores the reason why a rule did not match.

* Avoids error handling as long as no errors were encountered.


FIXME:

* tuple rule attribute 'elements' is empty

* Catch EOI in all matching functions


Todo: Error Messages

* Search term: parser error recovery


* Detect near matches ("almost matched")

* Annotate grammar with hints

* In case of error, determine what might have helped.

* Suggest remedies.

* Specially handle errors on the first and last elements of composites.
  For example, if only the last element of a composite did not match,
  see if it is easy to see what might be missing, of if there is an
  annotation or hint that suggests a reaction.

* Stop trying if it takes too long.

* Stop trying if no progress is made.


TODO

* Replace the automated commit messages by real ones.

* Group commits of parse.pl with the associated grammar commits.

* Rebase "backup-before-rebase" onto the "old" commit where it fits.

* Get rid of prefix "Parse::SiLLy::" in code as far as makes sense.

* Make the test so easy to understand that it is crystal-clear whether
  the tests yielded the expected results. Currently, one of the XML
  parsing tests apparently prints a result that is too short (ends
  after a left angle bracket).

* Clean up (remove) most of the disabled code.

* Provide  a test for 'lookingat'.

* pos: EOI: Set a flag in the state object, update the flag whenever
  pos changes.

* pos: EOI: Explicitly store the input length in the parser object?
  No, using a flag seems better.


* Memoization: Idea: When memoizing, do not memoize (store) the result
  for every equivalent parsing state alias item (nonterminal plus
  position) separately.  Instead, define item sets as for LR or Earley
  parsers and memoize results for item sets.

* Memoization: Memoize input substrings, too?

* Error messages (see separate section).

* Encoding:

  - Explicitly deal with encoding.

  - Default to UTF-8 encoding.

  - Support grammar annotations (processing instructions)
    that indicate places where the parser can find encoding
    information. For example, use this to interpret Byte Order Marks.
    As another example, use this to interpret the encoding declaration
    in XML declarations ("\<?xml encoding='UTF-8'?\>").

* FIXME: Provide automated regression tests for the test tools (assert
  etc., the validation functions).

* Clean up

  - def3

  - scan

* Memoization: FIXME: Using memoization is currently slower than not doing it

* Memoization: Benchmark without memoization versus with memoization

* Memoization: Find examples for which memoization is faster.

* Memoization: Make it easy to switch off memoization (per parser)

* Memoization: For inputs known to be small, consider stashing in an
  array indexed by position.

* Memoization: Document how it currently works, in particular how the
  stash is keyed.

* Memoization: Consider using arrays indexed by production id.


* Factor out common parts of parsing functions.

* Generate parsing error messages with explanations.

* For purposes of generating explanations, for non-matches,
  store the reason why a rule did not match.


* Benchmark make_result versus inline result construction.

* Do a serious benchmark

* Allow dashes in XML comments

* Add more regression tests

* Packagize (Parse::, Parse::LL:: or Parse::SiLLy?, Grammar, Utils,
  Test, Result, Stash)

* Packagize (Parse::SiLLy::Test::Minilang)

* Packagize productions (Terminal, Construction, etc.)

* Document how to configure logging (search for $DEBUG)

* Result scanner

* Allow using multiple parsers concurrently

* Parameterize result construction (compile-time option):

  - Inline result construction

  - array interpolation versus array reference


=cut

# --------------------------------------------------------------------
#package Parse::SiLLy;

use strict;
use warnings;
#use diagnostics;
use English;

# --------------------------------------------------------------------
my $main_log;

# --------------------------------------------------------------------
my $INC_BASE;
use File::Basename;
#BEGIN { $INC_BASE= dirname($0); }
#BEGIN { $INC_BASE= dirname(dirname(dirname($0))); }
BEGIN { $INC_BASE= "../.."; }

use lib dirname($0)."/lib";
#push(@INC, "$INC_BASE/Log-Log4perl-0.49/blib/lib");
#use lib "${INC_BASE}/Log-Log4perl/blib/lib";

#use Log::Log4perl qw(:easy);
use Data::Dumper;

# --------------------------------------------------------------------
# Imports the given variable to the current package

sub import_from($$) {
    my ($package, $typeglob_name)= (@_);
    #my ($typeglob_name)= (@_);
    my ($calling_package, $filename, $line)= caller();
    eval("\*${calling_package}::$typeglob_name= \*${package}::$typeglob_name");
    undef;
}

# ====================================================================
# Assertions

# Determines whether assertions are done
#sub ASSERT() { 1 }
#sub ASSERT() { 0 }
use constant ASSERT =>
    defined($ENV{PARSE_SILLY_ASSERT}) ? $ENV{PARSE_SILLY_ASSERT} : 1;

# --------------------------------------------------------------------
#use Carp::Assert;
use Carp;

# --------------------------------------------------------------------
# Select here whether you want a stack backtrace with your error message
#my $assert_action= \&croak; # Die without backtrace
my $assert_action= \&confess; # Die with backtrace

# --------------------------------------------------------------------
sub assert($) {
    if (! $_[0]) {
        $Carp::CarpLevel = 1;
        &$assert_action("Assertion failed.\n");
    }
}

# --------------------------------------------------------------------
# Unit test for 'assert'

sub assert_test($)
{
    my ($log)= @_;
    my $ctx= "assert_test";

    my $flag= 1;
    eval('assert(0 == 0); $flag= 0;');
    my $saved_at_value= $@;
    # Check the $@ value before checking the flag,
    # so we can see its contents before dying
    if ("" ne $saved_at_value) {
        $log->debug(varstring('@', $saved_at_value));
        die("$ctx: 'assert(0==0)' failed: \$\@ is not empty,"
            . " but should be empty: '$@'\n");
    }
    if (1 == $flag) {
        die("$ctx: 'assert(0==0); \$flag= 0' failed: flag is now 1,"
            . " but should be 0.\n");
    }

    eval('assert(0 == 1); $flag= 1;');
    $saved_at_value= $@;
    if (1 == $flag) {
        $log->debug(varstring('@', $saved_at_value));
        die("$ctx: 'assert(0==1); \$flag= 1' failed: flag is now 1,"
            . " but should be 0.\n");
    }
    #assert(1 == $flag);
    if ("" eq $saved_at_value) {
        die("$ctx: 'assert(0==1)' failed: \$\@ is empty, but should not.\n");
    }
}

# --------------------------------------------------------------------
sub should($$) {
    if ($_[0] ne $_[1]) {
        &$assert_action("'$_[0]' should be '$_[1]' but is not.\n");
    }
}

# --------------------------------------------------------------------
sub shouldnt($$) {
    if ($_[0] eq $_[1]) {
        &$assert_action("'$_[0]' should not be '$_[1]' but is.\n");
    }
}

# --------------------------------------------------------------------
# Use this for all evals:
sub eval_or_die($) {
    my $evalue= eval($_[0]);
    if ('' ne $@) { die("eval('$_[0]') failed: '$@'\n"); }
    $evalue;
}

# ====================================================================
package Logger;

use strict;
#use diagnostics;
#use English;

::import_from('main', 'assert');
use constant ASSERT => ::ASSERT;

# Logger objects are implemented as arrays.  Use these constants as
# indices to access their fields (array elements):
use constant LOGGER_NAME   => 0;
use constant LOGGER_DEBUG  => 1;

# --------------------------------------------------------------------
# Using the given reference to a prototype or class, and the given
# name, constructs a new Logger object (a blessed array).  Sets the
# debug flag (the field at index LOGGER_DEBUG) to the value of
# `Parse::SiLLy::Grammar::DEBUG()`.

sub new
{
    my $proto= shift;
    my $class= ref($proto) || $proto;
    my $self= [];
    bless($self, $class);

    my $name= shift;

    $$self[LOGGER_NAME]= $name;

    $$self[LOGGER_DEBUG]= Parse::SiLLy::Grammar::DEBUG();
    #print(STDERR "is_debug()=".$self->is_debug()."\n");
    $self->debug("is_debug()=".$self->is_debug()."\n");

    $self->debug("Logger constructed: $name.");

    $self;
}

# --------------------------------------------------------------------
sub name($) {
    $_[0][LOGGER_NAME];
}

# --------------------------------------------------------------------
# FIXME: What is the performance impact of returning the current value?

# @return the value of the debug flag (the field at index
# LOGGER_DEBUG).

#sub is_debug($) { ${@{$_[0]}}[LOGGER_DEBUG]; }
#sub is_debug($) {
#    my $self= $_[0];
#    assert(defined($self)) if ASSERT();
#    assert('' ne ref($self)) if ASSERT();
#    $$self[LOGGER_DEBUG];
#}
sub is_debug($) { $_[0][LOGGER_DEBUG]; }

# --------------------------------------------------------------------
# Sets the value of the debug flag (the field at index LOGGER_DEBUG)
# to 1.

sub set_debug($) {
    my $self= $_[0];
    assert(defined($self)) if ASSERT();
    assert('' ne ref($self)) if ASSERT();
    $self->[LOGGER_DEBUG]= 1;
}

# --------------------------------------------------------------------
# Sets the value of the debug flag (the field at index LOGGER_DEBUG)
# to 0.

sub set_nodebug($) {
    my $self= $_[0];
    assert(defined($self)) if ASSERT();
    assert('' ne ref($self)) if ASSERT();
    $self->[LOGGER_DEBUG]= 0;
}

# --------------------------------------------------------------------
# FIXME: What is the performance impact of the binding to $self?

# --------------------------------------------------------------------
sub info {
    my $self= shift(@_);
    my $ctx= $self->name();
    print(STDERR $ctx,": ",@_,"\n");
}

# --------------------------------------------------------------------
sub error {
    my $self= shift(@_);
    $self->info("*** ERROR ***: ", @_);
}

# --------------------------------------------------------------------
sub debug {
    if ( ! $_[0][LOGGER_DEBUG]) { return; }

    my $self= shift;
    #if ( ! $self->is_debug()) { return; }
    my $ctx= $self->name();
    print(STDERR $ctx,": ",@_,"\n");
}

# ====================================================================
package Parse::SiLLy::Grammar;

use constant PROD_CATEGORY  => 0;
use constant PROD_NAME      => PROD_CATEGORY + 1;
use constant PROD_SHORT_NAME=> PROD_NAME + 1;
use constant PROD_METHOD    => PROD_SHORT_NAME + 1;
use constant PROD_ID        => PROD_METHOD + 1;

use constant PROD_PATTERN   => PROD_ID + 1;
use constant PROD_MATCHER   => PROD_PATTERN + 1;

use constant PROD_ELEMENTS  => PROD_ID + 1;

use constant PROD_ELEMENT   => PROD_ID + 1;
use constant PROD_SEPARATOR => PROD_ELEMENT + 1;

# ====================================================================
package main;

use strict;
#use diagnostics;
use English;
use File::Basename;

# --------------------------------------------------------------------
my $usage="Usage: perl ".basename($0)." GRAMMAR IN > OUT";

# --------------------------------------------------------------------
# CAVEAT: you should resist the temptation to call this 'dump'
# -- Instead of calling this function, Perl will dump core.
sub varstring($$) {
    my ($name, $val)= @_;
    # FIXME: Doesn't Data::Dumper do this already?
    (defined($val) && '' eq $val)
        ? "\$$name = '';"
        : Data::Dumper->Dump([$val], [$name]);
}

# --------------------------------------------------------------------
use constant PROD_NAME      => Parse::SiLLy::Grammar::PROD_NAME;

# --------------------------------------------------------------------
# If the given reference refers to a named object, returns its name.
# Otherwise returns undef.
sub given_name($) {
    my ($val)= @_;
    assert(defined($val)) if ASSERT();
    if ('' ne ref($val)
        #&& "ARRAY" eq ref($val) # Does not work if $val is blessed
        # FIXME: Decouple logging from parsing packages!:
        && scalar(@$val) >= PROD_NAME )
    {
        my $valname= $val->[PROD_NAME];
        if (defined($valname) && '' eq ref($valname)) # name is a string
        {
            return ($valname);
        }
    }
    undef;
}

# --------------------------------------------------------------------
# CAVEAT: you should resist the temptation to call this 'dump'
# -- Instead of calling this function, Perl will dump core.

sub vardescr($$)
{
    my ($name, $val)= @_;
    if ( ! defined($val)) { return ("$name: <UNDEFINED>\n"); }
    my $valname= given_name($val);
    defined($valname) ? "\$$name = ''$valname''\n" : varstring($name, $val);
}

# ====================================================================
package Parse::SiLLy::Result;

use strict;
#use diagnostics;
#use English;

::import_from('main', 'assert');
use constant ASSERT => ::ASSERT;

use constant PROD_CATEGORY  => Parse::SiLLy::Grammar::PROD_CATEGORY;
use constant PROD_NAME      => Parse::SiLLy::Grammar::PROD_NAME;
use constant PROD_ELEMENTS  => Parse::SiLLy::Grammar::PROD_ELEMENTS;

# --------------------------------------------------------------------
use constant RESULT_PROD => 0;
use constant RESULT_MATCH => 1;

# --------------------------------------------------------------------
# FIXME: This is currently unused
sub make_result($$) {
    #return [$_[0] - > {name}, $_[1]];
    my ($t, $match)= (@_);
    assert('ARRAY' eq ref($match)) if ASSERT();
    [$t->[PROD_NAME], $match];
}

# --------------------------------------------------------------------
# FIXME: can we use a scalar value here (not a string)?
# FIXME: Bench these:
use constant NOMATCH => 'NOMATCH';
#use constant NOMATCH => \'NOMATCH';

# --------------------------------------------------------------------
sub matched($) {
    if ($_[0] eq NOMATCH()) { return 0; }
    my ($result)= (@_);
    if ($result->[RESULT_PROD] eq NOMATCH()) { return 0; }
    return 1;
}

# --------------------------------------------------------------------
sub matched_with_assert($)
{
    if (ASSERT() && NOMATCH() ne $_[0]) { assert('ARRAY' eq ref($_[0])); }
    NOMATCH() ne ($_[0]);
}

# --------------------------------------------------------------------
sub matched_test() {
    assert( ! matched(NOMATCH()));
    assert( ! matched([NOMATCH(), "Reason"]));
    assert(matched(["Anything", "Reason"]));
}

# --------------------------------------------------------------------
# Maps production categories to single symbols, for compact output.

my $cats= {
    alternation  => '|',
    construction => '&',
    lookingat    => ':',
    nelist       => '+',
    notlookingat => '!',
    optional     => '?',
    pelist       => '*',
    terminal     => '=',
};

# --------------------------------------------------------------------
# Formats the given result object as a string. To make the output
# easier to read, omits package names in the production names
# (everything up to the last "::").

# Note that while the internal representation of a match result may
# have a reference to an array of matched elements (for example
# [Semicolon [";"]]), this function inlines the matched elements into
# the array that represents the production itself (for example
# [Semicolon ";"]), for brevity.

sub toString($$);
sub toString($$)
{
    #return "DUMMY";
    my ($self, $indent)= @_;
    my $log= $main_log;
    assert(defined($self));
    if ( ! matched($self)) { return 'nomatch'; }
    #'ARRAY' eq ref($self) ||
        #print(STDERR ::varstring("self", $self)
              #.", ref(\$self)=".ref($self)
              #."\n");
    assert('ARRAY' eq ref($self));

    my $typename= $$self[RESULT_PROD];
    assert(defined($typename));
    assert('' eq ref($typename));

    my $type= do { no strict 'refs'; $ {$typename}; };
    # FIXME: Introduce predicate 'is_production'
    assert(defined($type));
    assert('' ne ref($type));
    assert($typename eq $type->[PROD_NAME]);

    my $category= $type->[PROD_CATEGORY];
    #if ($log->is_debug()) {
    #    $log->debug("toString: Category is '",$category,"'.");
    #}

    my $match= $$self[RESULT_MATCH];
    #if ($log->is_debug()) {
    #    $log->debug(::vardescr("toString all: match", $match));
    #}

    $typename=~ s/.*:://o;
    if ($log->is_debug()) {
        $log->debug(
            "toString: Type '",$typename,"' has category '",$category,"'.");
    }

    my $cat= $cats->{$category};

    if ($category eq "terminal") {
        my $val= "$$match[0]"; $val=~ s/'/\\'/o;
        "[".$typename.$cat." '".
            $val.
            "']";
    }
    # Even though an alternation production has multiple alternatives,
    # after it matched there is only one concrete result.
    elsif (grep(/$category/, qw(alternation optional lookingat notlookingat))) {
        if ($log->is_debug()) {
            $log->debug(
                "toString: Category '", $category, "' has only one element.");
        }
        "[".$typename.$cat.
            " ".toString($$match[0], "$indent ")."]";
    }
    else {
        # $category is construction, pelist or nelist.
        if ($log->is_debug()) {
            $log->debug(
                "toString: Category '", $category, "' has multiple elements.");
        }
        "[".$typename.$cat."\n".
            $indent." "
            . join(",\n$indent ", map { toString($_, "$indent "); } @$match)
            #. "$indent]";
            . " ]";
    }
}

# --------------------------------------------------------------------
# Iterates over all elements (matches) in the given parse result
# object, calling the given handler on each one.

sub scan($$);
sub scan($$) {
    my ($self, $handler)= (@_);
    assert(defined($self)) if ASSERT();
    assert(defined($handler)) if ASSERT();
    assert('ARRAY' eq ref($self)) if ASSERT();

    my $typename= $$self[0];
    assert(defined($typename)) if ASSERT();
    assert('' eq ref($typename)) if ASSERT();

    my $type= do { no strict 'refs'; $ {$typename}; };
    assert(defined($type)) if ASSERT();
    assert('' ne ref($type)) if ASSERT();
    assert($typename eq $type->[PROD_NAME]) if ASSERT();

    my $category= $type->[PROD_CATEGORY];

    # FIXME: separate iteration from printing

    if ($category= $Parse::SiLLy::Grammar::terminal) {
        #
        $handler->terminal($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::construction) {
        $handler->construction_begin($self, $typename, $type, $category);
        for (@$self[1..$#$self]) { scan($_, $handler); }
        $handler->construction_end  ($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::alternation) {
        $handler->alternation_begin($self, $typename, $type, $category);
        for (@$self[1..$#$self]) { scan($_, $handler); }
        $handler->alternation_end  ($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::optional) {
        $handler->optional($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::lookingat) {
        $handler->lookingat($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::notlookingat) {
        $handler->notlookingat($self, $typename, $type, $category);
    }
    else {
        my $elements= $self->[PROD_ELEMENTS];
        $handler->print("[$typename '@$elements']");
    }
}

# ====================================================================
package Parse::SiLLy::Grammar;

use strict;
#use diagnostics;
use English;

#use main;
#main::import(qw(assert));
#*assert= \&::assert;
::import_from('main', 'assert');
use constant ASSERT => ::ASSERT;
::import_from('main', 'vardescr');
::import_from('main', 'varstring');

::import_from('Parse::SiLLy::Result', 'matched');
::import_from('Parse::SiLLy::Result', 'NOMATCH');
::import_from('Parse::SiLLy::Result', 'RESULT_MATCH');
::import_from('Parse::SiLLy::Result', 'make_result');

use constant DEBUG =>
    defined($ENV{PARSE_SILLY_DEBUG}) ? $ENV{PARSE_SILLY_DEBUG} : 0;

#BEGIN { $Exporter::Verbose=1 }
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA= qw(Exporter); # Package's ISA
%EXPORT_TAGS= ('all' => [ qw(
    def terminal construction alternation optional lookingat notlookingat nelist pelist
    )]);
@EXPORT_OK= ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT= qw();

sub import {
    #local $Exporter::Verbose= 1;
    # This would try to call Parse::SiLLy::Grammar::export_to_level, which is not defined:
    #export_to_level(1, 'Parse::SiLLy::Grammar', @{ $EXPORT_TAGS{'all'} });

    Parse::SiLLy::Grammar->
        export_to_level(1, 'Parse::SiLLy::Grammar', @{ $EXPORT_TAGS{'all'} });
}

# --------------------------------------------------------------------
use constant MEMOIZE =>
    (defined($ENV{PARSE_SILLY_MEMOIZE}) ? $ENV{PARSE_SILLY_MEMOIZE} : 0);

use constant SHOW_LOCATION =>
    defined($ENV{PARSE_SILLY_SHOW_LOCATION}) ? $ENV{PARSE_SILLY_SHOW_LOCATION} : 1;

# --------------------------------------------------------------------
sub log_args($$$)
{
    my ($log, $context, $argl)= @ARG;
    assert(defined($log));
    assert(defined($context));
    assert($argl);
    #carp(..);
    if ( ! $log->is_debug()) { return; }

    $log->debug("$context: #ARGs=".scalar(@{$argl}));
    #$log->debug("$context: \@ARG=@{$argl}");
    $log->debug("$context: \@ARG='".join("', '", @{$argl})."'");
    #$log->debug("$context: " . varstring('ARG',\@ARG));
    if ('ARRAY' ne ref($argl)) {
        die("$context: log_args: argl argument is not an array reference: "
            . ref($argl) . " $argl\n");
    }
    #return;
    my $i= 0;
    my @description= map {
        ++$i;
        vardescr("ARG[$i]", $ARG);
    } @$argl;
    $log->debug("$context: @description");
}

# --------------------------------------------------------------------
# Log constructor arguments
#sub log_cargs($$) { log_args($_[0], '', $_[1]); }
sub log_cargs($$$) { log_args($ARG[0], $ARG[1], $ARG[2]); }

# --------------------------------------------------------------------
# Returns the grammar object corresponding to the given spec (which
# may be a string or a reference).

sub grammar_object($$)
{
    #('' eq ref($_[0])) ? eval_or_die("\$::$_[0]") : $_[0];
    my ($grammar, $spec)= (@_);
    assert(defined($grammar));
    assert('' eq ref($grammar));
    assert(defined($spec));

    #$grammar_log->debug("Resolving '$spec'...");
    if ('' eq ref($spec)) {
        #my $val= eval("\$::$spec");
        my $val= eval("\$${grammar}::$spec");
        (defined($val)) ? $val : $spec;
    }
    else {
        $spec;
    }
}

# --------------------------------------------------------------------
# Returns a reference to an array of grammar objects that correspond to
# the given array of specs (which may be strings or references).

sub grammar_objects($$)
{
    #log_args($log, "grammar_objects", $ARG[0]);
    # Note that @$ARG[0] is not the same as @{$ARG[0]}
    my $grammar= shift();
    my @elements= map { grammar_object($grammar, $_); } @{$ARG[0]};
    \@elements;
}

# --------------------------------------------------------------------
# Position of end of match, or of start of attempt
use constant LOCATION_POS   => 0;
use constant LOCATION_LINENO => 1 + LOCATION_POS;
use constant LOCATION_LINE_START => 1 + LOCATION_LINENO;
use constant LOCATION_REASON => 1 + LOCATION_LINE_START;

# --------------------------------------------------------------------
sub format_stashed($)
{
    my ($stashed)= @_;
    if ( ! defined($stashed)) { return 'undef'; }
    #assert(defined($stashed)) if ASSERT();
    if (matched($stashed)) {
        if (ASSERT()) {
            assert('' ne ref($stashed));
            assert('ARRAY' eq ref($stashed));
        }
        #: Parse::SiLLy::Result::toString(\@$stashed[1..$#$stashed], " ")
        #: Parse::SiLLy::Result::toString(@{@$stashed}[1..$#$stashed], " ")
        ""
            .(SHOW_LOCATION() ?
              $stashed->[LOCATION_LINENO].":"
              .($stashed->[LOCATION_POS]-$stashed->[LOCATION_LINE_START]+1).": "
              : "")
            ."[$$stashed[LOCATION_POS]]"
            . Parse::SiLLy::Result::toString($$stashed[LOCATION_REASON], " ")
            ;
    }
    else {
        'nomatch';
    }
}

# --------------------------------------------------------------------
sub show_pos_stash_hash($$$)
{
    my ($log, $pos_stash, $pos)= (@_);
    assert(defined($pos_stash));
    assert('HASH' eq ref($pos_stash));
    if ( ! $log->is_debug()) { return; }
    for
        (sort( {$a cmp $b} keys(%$pos_stash)))
    {
        my $spec= $_;
        #$log->debug("Showing pos_stash for $pos.$spec...");
        #my $elt= $spec;

        # FIXME: This leads to an incomplete error message
        # (get assert to add the stack trace to $@ in this case):
        #$elt= "foo";
        # FIXME: Introduce ->name() accessor
        #my $elt_name= $elt->[PROD_NAME];
        my $elt_name= $spec;
        assert(defined($elt_name));
        assert('' eq ref($elt_name));

        #$log->debug("Showing pos_stash for $pos.$elt_name...");
        my $stashed= $pos_stash->{$spec};
        #$log->debug(varstring('stashed', $stashed));
        $log->debug("stash{$pos, $elt_name}=" . format_stashed($stashed));
    }
}

# --------------------------------------------------------------------
my $production_id;
my $productions_by_id;

# --------------------------------------------------------------------
sub show_pos_stash($$$)
{
    my ($log, $pos_stash, $pos)= (@_);
    assert(defined($pos_stash));
    assert('ARRAY' eq ref($pos_stash));
    if ( ! $log->is_debug()) { return; }
    for
        #(sort( {$a <=> $b} keys(%$pos_stash)))
        #(sort( {$a cmp $b} keys(%$pos_stash)))
        (1..$#$pos_stash)
    {
        my $spec= $_;
        my $stashed= $pos_stash->[$spec];
        if ( ! defined($stashed)) { goto SHOW_POS_STASH_MAP_END; }
        #$log->debug("Showing pos_stash for $pos.$spec...");
        #my $elt= $spec;
        my $elt= $$productions_by_id[$spec];

        # FIXME: This leads to an incomplete error message
        # (get assert to add the stack trace to $@ in this case):
        #$elt= "foo";
        # FIXME: Introduce ->name() accessor
        my $elt_name= $elt->[PROD_NAME];
        #my $elt_name= $spec;
        assert(defined($elt_name));
        assert('' eq ref($elt_name));

        #$log->debug("Showing pos_stash for $pos.$elt_name...");
        #my $stashed= $pos_stash->[$spec];
        #$log->debug(varstring('stashed', $stashed));
        $log->debug("stash{$pos, $elt_name}=" . format_stashed($stashed));
      SHOW_POS_STASH_MAP_END:
    }
}

# --------------------------------------------------------------------
sub show_stash($$)
{
    my ($log, $stash)= (@_);
    assert(defined($stash));
    assert('HASH' eq ref($stash));
    if ( ! $log->is_debug()) { return; }
    #$log->debug(vardescr("stash", $stash));
    #$log->debug("Stash:");
    for (sort({$a <=> $b} keys(%$stash)))
    {
        my $pos= $_;
        #$log->debug("Showing stash for pos $pos...");
        show_pos_stash($log, $stash->{$pos}, $pos);
    }
}

# --------------------------------------------------------------------
use constant STATE_INPUT => 0;
#use constant STATE_POS => 1;
use constant STATE_POS => STATE_INPUT + 1;
#use constant STATE_STASH => 2;
# FIXME: Benchmark 'STATE_STASH => 2' vs. 'STATE_STASH => STATE_POS + 1'
use constant STATE_STASH => STATE_POS + 1;
#use constant STATE_POS_STASH => 3;
use constant STATE_POS_STASH => STATE_STASH + 1;
use constant STATE_EXPLAIN    => STATE_POS_STASH + 1;
# Stack of what parser is trying to match.
use constant STATE_TRYING     => 1 + STATE_EXPLAIN;
use constant STATE_FILENAME   => 1 + STATE_TRYING;
use constant STATE_LINENO     => STATE_FILENAME + 1;
use constant STATE_LINE_START => STATE_LINENO + 1;
use constant STATE_FURTHEST   => STATE_LINE_START + 1;
use constant STATE_FURTHEST_REASON => STATE_FURTHEST + 1;

# --------------------------------------------------------------------
# @return the input character index of the given parser state. In
# other words, the value of `pos(input)` (see `perldoc -f pos`), where
# input is the parser input of the given parser state.
sub get_pos($) { pos($_[0]->[STATE_INPUT]); }

# --------------------------------------------------------------------
# Sets the input position of the given parser state to the given
# value. In other words, sets the value of `pos(input)` (see `perldoc
# -f pos`), where input is the parser input of the given parser state,
# to the given value.

sub set_pos($$) {
    pos($_[0]->[STATE_INPUT])= $_[1];

    # FIXME: Move this decision up on the call stack, out of the
    # top-level call to 'match'.
    #if ('' eq ref($_[0]->[STATE_INPUT])) {
    #    pos($_[0]->[STATE_INPUT])= $_[1];
    #} else {
    #    $_[0]->[STATE_POS]= $_[1];
    #}
}

# --------------------------------------------------------------------
sub state_to_location($$) {
    my ($state, $reason) =(@_);
    return [
        get_pos($state),
        $state->[STATE_LINENO],
        $state->[STATE_LINE_START],
        $reason,
        ];
    my $result= [];
    $result->[LOCATION_POS]        = get_pos($state),
    $result->[LOCATION_LINENO]     = $state->[STATE_LINENO];
    $result->[LOCATION_LINE_START] = $state->[STATE_LINE_START];
    $result->[LOCATION_REASON]     = $reason;
    return $result;
}

# --------------------------------------------------------------------

=begin comment

  Resets the given parser's input position to the given position and
  sets the line number counter to the given number.

  Q: Where do we have to actually perform backtracking?

  A: Whenever pos has already been moved (something was matched),
  but the context demands that the match not be used.
  This happens when:

  * A part of a construction was matched, but the next part could not
    be matched.  More generally speaking, where a failure may occur
    after pos has been already moved (but constructions currently are
    the only productions where this is possible).

  * A positive lookahead ('looking at' alias 'and') was matched.  The
    match will be returned, but the input position reset.

  * A negative lookahead ('not looking at' alias 'and not') was not
    matched. In other words, when the match expression of a negative
    lookahead did match. The match is not be returned, and the input
    position is reset.

=end comment

=cut

sub backtrack_to_pos( $$$$ ) {
    my ($state, $pos
        , $lineno
        , $line_start
        )= (@_);
    set_pos($state, $pos);
    $state->[STATE_LINENO]= $lineno;
    $state->[STATE_LINE_START]= $line_start;
    if (MEMOIZE()) {
        $state->[STATE_POS_STASH]=
            stash_get_pos_stash($state->[STATE_STASH], $pos);
    }
}

# --------------------------------------------------------------------
# Resets the given parser's position to zero.

sub Parser_reset( $ ) {
    my ($state)= (@_);
    set_pos($state, 0);
    $state->[STATE_LINENO]= 1;
    $state->[STATE_LINE_START]= 0;
    $state->[STATE_TRYING]= [],
    $state->[STATE_FURTHEST]= 0;
    $state->[STATE_FURTHEST_REASON]= "None";
}

# --------------------------------------------------------------------
# To keep track the current line number, we need to keep track of the
# number of line endings traversed when we change position. Position
# can change in several ways:

# First, position can change when we match a terminal. To determine
# the number of line endings traversed when the parser matches a
# terminal for the first time, we can count the number line endings
# between start and end of the match.

# With memoization, we can avoid having to repeatedly count by
# remembering the number of traversed line endings for each
# combination of position and production.

# Second, position can change when we backtrack. For example, when
# trying to match a construction (a sequence) of two terminals, and
# the first terminal matches and the second one does not, position
# will have changed to the end of the match of the first terminal, but
# we need to move position back to the start of the first match. To
# achieve this, for every attempted match, we need to remember the
# position at its start, and also the line number.

# Third, position can change if we reuse the result of a previous
# match. When we reuse a match, we set the position to the end of the
# match, and need to set the line number accordingly. To achieve this,
# for every stashed match, we need to remember the position at its
# end, and also the corresponding line number.

# FIXME: Packagize, objectify
sub Parser_new($$) {
    my ($filename, $input)= (@_);
    my $state= [];
    $state->[STATE_INPUT]      = $input;
    $state->[STATE_POS]        = 0;
    $state->[STATE_STASH]      = {};
    $state->[STATE_POS_STASH]  = undef;
    $state->[STATE_EXPLAIN]    = 0,
    $state->[STATE_FILENAME]   = $filename,
    Parser_reset($state);
    $state;
}

# --------------------------------------------------------------------
sub location_format( $$ )
{
    my ($state, $location)= (@_);
    return
        (SHOW_LOCATION() ?
         $state->[STATE_FILENAME].":".
         $location->[LOCATION_LINENO].":"
         .($location->[LOCATION_POS]-$location->[LOCATION_LINE_START]+1).": "
         : "")
        #."[".$location->[LOCATION_POS]."]"
        . $location->[LOCATION_REASON]
        ;
}

# --------------------------------------------------------------------
# Using the given parser state, if the current mismatch (input
# position) is further than the previously remembered furthest
# position, stores the current position and the given reason as the
# new furthest position and reason.

sub consider_furthest($$) {
    my ($state, $reason)= (@_);
    my $pos= get_pos($state);
    if ($state->[STATE_FURTHEST] <= $pos
        #&& ! eoi($state->[STATE_INPUT], $pos)
        )
    {
        $state->[STATE_FURTHEST]= $pos;
        $state->[STATE_FURTHEST_REASON]=
            join("\n",
                 map { location_format($state, $_); }
                     @{$state->[STATE_TRYING]}) ."\n".
            $reason;
    }
}

# --------------------------------------------------------------------
# @return a description of the current input position.

sub location( $ ) {
    my ($state)= (@_);
    my $column = get_pos($state) - $state->[STATE_LINE_START] + 1;
    return
        $state->[STATE_FILENAME].":".
        $state->[STATE_LINENO].":".
        $column.":".
        " ";
}

# --------------------------------------------------------------------
sub input_show_state($$) {
    my ($log, $state)= (@_);
    if ( ! $log->is_debug()) { return; }
    $log->debug(varstring('state->pos', get_pos($state)));
}

# --------------------------------------------------------------------
sub match_check_preconditions($$) {
    my ($log, $t)= (@_);
    assert(defined($log)) if ASSERT();
    assert(defined($t)) if ASSERT();
    if ('' eq ref($t)) {
        $log->error("t is not a hash: ".$t);
    }
    assert('' ne ref($t)) if ASSERT();
    if (ASSERT()) {
        assert(scalar(@$t) >= PROD_MATCHER());
    }
}

# --------------------------------------------------------------------
sub match_watch_args($$$) {
    my ($ctx, $log, $state)= (@_);
    assert(defined($ctx)) if ASSERT();
    my $pos= get_pos($state);
    $log->debug("$ctx: state->pos=$pos");
    if (MEMOIZE()) {
        show_pos_stash($log, stash_get_pos_stash($state->[STATE_STASH()], $pos),
                       $pos);
    }
}

# --------------------------------------------------------------------
# Conditional logging of grammar element values (in constructors)
my $log_val;
$log_val= 1;
sub log_val($$) {
    my ($log, $val)= @ARG;
    assert(defined($log)) if ASSERT();
    assert('' ne ref($log)) if ASSERT();
    if ( ! $log->is_debug()) { return; }
    if ($log_val) {
        #assert(defined($val));
        #assert('' ne ref($val));
        $log->debug(varstring('val',$val));
    }
}

# --------------------------------------------------------------------
# Text representation of End Of File.
my $EOI= "<EOI>";

# --------------------------------------------------------------------
sub eoi($$) {
    my ($input, $pos)= (@_);
    assert(defined($input)) if ASSERT();
    if ('' eq ref($input)) { return (length($input)-1 < $pos); }
    assert("ARRAY" eq ref($input)) if ASSERT();
    $#{@$input} < $pos;
}

# --------------------------------------------------------------------
sub nomatch( $$$$ ) {
    my ($ctx, $log, $state, $reason)= (@_);
    $reason=
        (SHOW_LOCATION ? location($state) : "") .
        $ctx." did not match"
        . ": ".$reason;
    if (DEBUG() && $log->is_debug()) { $log->debug($reason); }
    consider_furthest($state, $reason);
    [NOMATCH(), $reason];
}

# --------------------------------------------------------------------
my $def_log;
# --------------------------------------------------------------------
# Defines the given scalar variable in the calling package with the given value
sub def3($$@)
{
    my $log= $def_log;
    #my ($name, $val)= @ARG;
    my ($name, $category, @rest)= @ARG;
    assert(defined($name));
    assert(defined($category));
    assert(0 < scalar(@rest));

    # Define the variable in the calling package
    my ($caller_package, $file, $line)= caller();
    #$name= "::$name";
    $name= "${caller_package}::$name";
    $log->debug("Defining '$name'...");

    # Construct grammar object to bind the variable to
    my $val= &{$category}(@rest);
    $log->debug(varstring('val',$val));

    # FIXME: Factor this out:
    # Bind grammar object to variable
    $ {$name}= $val;
    #bind_var($name, $val);
    #eval("\$$name=\$val;");
    #$::def_val_= $val; eval("\$$name=\$::def_val_;");
    # FIXME: Consider moving this to the grammar object constructors:
    $val->[PROD_NAME]= $name;
    $log->debug("Defined '$name' as $val.");
}

# --------------------------------------------------------------------
my %methods;

use constant terminal_mtch     => \&terminal_match;
use constant alternation_mtch  => \&alternation_match;
use constant construction_mtch => \&construction_match;
use constant optional_mtch     => \&optional_match;
use constant lookingat_mtch    => \&lookingat_match;
use constant notlookingat_mtch => \&notlookingat_match;
use constant nelist_mtch       => \&nelist_match;
use constant pelist_mtch       => \&pelist_match;

# --------------------------------------------------------------------
sub def($$$$$@)
{
    #my $log= $def_log;
    #my $log= shift();
    #log_cargs($log, \@ARG);
    #my ($name, $val)= @ARG;
    my ($log, $category, $name, $val, $caller_package, @ignored)= @ARG;

    assert(defined($val));
    assert('' ne ref($val));
    #$log->debug(varstring('val', $val));

    # Store production type (category) in $val
    assert(defined($category));
    assert('' eq ref($category));
    # Lookup the match method at definition time:
    my $method= $methods{$category};
    assert(defined($method));
    assert('' ne ref($method));
    # FIXME: Move this before previous comment:
    # In front of the type-specific elements make room for
    # the shared elements:
    unshift(@$val, (undef, undef, undef, undef, undef));
    $val->[PROD_CATEGORY]= $category;
    # Store result of symbolic lookup
    $val->[PROD_METHOD] = $method;

    ++$production_id;
    $val->[PROD_ID] = $production_id;
    $productions_by_id->[$production_id]= $val;

    # Determine and store full variable name
    assert(defined($name));
    assert('' eq ref($name));
    #my $fullname= "::$name";
    #my ($caller_package, $file, $line)= caller();
    my $fullname= "${caller_package}::$name";
    $log->debug("Defining '$fullname'...");
    $val->[PROD_NAME]= $fullname;
    $val->[PROD_SHORT_NAME]= $name;

    # Bind grammar object value to variable
    eval("\$$fullname=\$val;");
    log_val($log, $val);
    $log->debug("Defined '$fullname' as $val.");
    $val;
}

# --------------------------------------------------------------------
sub match($$);

# --------------------------------------------------------------------
my $terminal_log;
# --------------------------------------------------------------------
sub terminal#($$)
{
    my $log= $terminal_log;
    #return def($log, 'terminal', $ARG[0], {pattern=>$ARG[1]}, caller());
    my ($name, $pattern)= @ARG;
    log_cargs($log, $name, \@ARG);

    # Here we create an anonymous subroutine that matches $pattern and
    # store a reference to it in $element->{matcher}.

    # The goal here is to let Perl compile the pattern matcher only once,
    # when the terminal is defined (in other words, here, when the
    # subroutine is compiled), and not at every parse.

    # FIXME: Maybe this goal is better achieved by "loading the
    # grammar at compile-time"?  What does this mean?

    #my $matcher= eval("sub { \$_[0] =~ m{^($pattern)}og; }");
    #my $matcher= eval("sub { \$ \$_[0] =~ m{^($pattern)}og; }");
    # FIXME: When pos instead of substrings is used, the ^ here will
    # not work as needed, use \G instead:
    #my $matcher= eval(
    #    "sub { \$_[0]->[STATE_INPUT()]=~ m{^($pattern)}og; \$1; }" );
    # FIXME: perldoc perlre says that using parentheses slows down ALL matchers,
    #  So try to get by without them.
    #  Maybe use substr($input, $before, $pos-$before) instead.
    #my $matcher= eval(
    #    "sub { (\$_[0]->[STATE_INPUT()]=~ m{\\G($pattern)}og) && \$1; }");
    #my $matcher= eval(
    #    'sub { ($_[0]->['.STATE_INPUT().']=~ m{\G('.$pattern.')}og) && $1; }');
    my $matcher=
#         eval('sub { my $bef= pos($_[0]->['.STATE_INPUT().']);'
#              .(ASSERT()?' assert(defined($bef));':'')
#     #         .' if ($_[0]->['.STATE_INPUT().'] !~ m{\G('.$pattern.')}og)'
#              .' if ($_[0]->['.STATE_INPUT().'] !~ m{\G'.$pattern.'}og)'
#              .' { pos($_[0]->['.STATE_INPUT().'])= $bef; undef; }'
#     #         .' else { $1; }'
#              .' else'
#              .' { substr($_[0]->['.STATE_INPUT().'],
#                          $bef, pos($_[0]->['.STATE_INPUT().']) - $bef); }'
#              .'}');
        eval('sub { my $p= \$_[0]->['.STATE_INPUT().'];my $bef= pos($$p);'
             .(ASSERT()?' assert(defined($bef));':'')
             #.' if ($$p =~ m{\G'.$pattern.'}og)'
             #.' { substr($$p, $bef, pos($$p) - $bef); }'
             .' if ($$p =~ m{\G('.$pattern.')}og) { $1; }'
             .' else { pos($$p)= $bef; undef; }'
             .'}');
    #    eval('sub { my $s= \$_[0]->['.STATE_INPUT().'];'
    #         .' my $bef= pos($$s); '.(ASSERT()?'assert(defined($bef)); ':'')
    #         .' if ($$s !~ m{\G'.$pattern.'}og)'
    #         .' { pos($$s)= $bef; undef }'
    #         .' else { substr($$s, $bef, pos($$s) - $bef); }'
    #         .'}');

    def($log, 'terminal', $name, [$pattern, $matcher], caller());
}

# --------------------------------------------------------------------
my $terminal_match_log;

# --------------------------------------------------------------------
# @returns for the given state, the number of line endings between the
# given input position and the current input position.

sub endls_since($$)
{
    my $log= $terminal_match_log;
    my $debug_was_set= Logger::is_debug($log);
    #Logger::set_debug($log);
    my $ctx= "endls_since";
    my ($state, $start_pos)= (@_);
    my $new_pos= get_pos($state);
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: Entered, looking from $start_pos to $new_pos.");
    }
    set_pos($state, $start_pos);

    my $endl= "\n";
    my $endls= 0; # Number of line endings found
    while (get_pos($state) < $new_pos) {
        my $match= $state->[STATE_INPUT]=~ m/$endl/gso;
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: \$match='$match'");
        }
        if ($match)
        {
            if (get_pos($state) <= $new_pos) {
                ++$endls;
                if (DEBUG() && $log->is_debug()) {
                    $log->debug("$ctx: Found line ending $endls before $new_pos.");
                }
                $state->[STATE_LINE_START]= get_pos($state);
            }
            else {
                if (DEBUG() && $log->is_debug()) {
                    $log->debug("$ctx: Found line ending after $new_pos.");
                }
            }
        }
        else {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: No line ending found.");
            }
            last;
        }
    }

    # Restore exact input position - when matching line endings, we
    # might have ended up anywhere at or beyond $new_pos.
    set_pos($state, $new_pos);
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: Returning $endls.");
    }
    if ($debug_was_set) { Logger::set_debug($log); }
    else { Logger::set_nodebug($log); }
    return $endls;
}

# --------------------------------------------------------------------
# Using the given parser state's input and the given end position,
# @return whether the number returned by endls_since($state, $start)
# is equal to the given expected number.
sub endls_since_test_1($$$$)
{
    my ($state, $start, $end, $expected)= (@_);
    set_pos($state, $end);
    my $actual= endls_since($state, $start);
    return ($actual == $expected);
}

# --------------------------------------------------------------------
sub endls_since_test()
{
    my $input= <<'EOT';

ab
c

EOT
    my $state= Parse::SiLLy::Grammar::Parser_new(
        "inline in function endls_since_test", $input);

    assert(endls_since_test_1($state, 0, 0, 0));
    assert(endls_since_test_1($state, 0, 1, 1));
    assert(endls_since_test_1($state, 0, 2, 1));
    assert(endls_since_test_1($state, 0, 3, 1));
    assert(endls_since_test_1($state, 0, 4, 2));
    assert(endls_since_test_1($state, 0, 5, 2));
    assert(endls_since_test_1($state, 0, 6, 3));
    assert(endls_since_test_1($state, 0, 7, 4));
    assert(endls_since_test_1($state, 0, 8, 4));

    assert(endls_since_test_1($state, 1, 0, 0));
    assert(endls_since_test_1($state, 1, 1, 0));
    assert(endls_since_test_1($state, 1, 2, 0));
    assert(endls_since_test_1($state, 1, 3, 0));
    assert(endls_since_test_1($state, 1, 4, 1));
    assert(endls_since_test_1($state, 1, 5, 1));
    assert(endls_since_test_1($state, 1, 6, 2));
    assert(endls_since_test_1($state, 1, 7, 3));
    assert(endls_since_test_1($state, 1, 8, 3));

    assert(endls_since_test_1($state, 4, 0, 0));
    assert(endls_since_test_1($state, 4, 1, 0));
    assert(endls_since_test_1($state, 4, 2, 0));
    assert(endls_since_test_1($state, 4, 3, 0));
    assert(endls_since_test_1($state, 4, 4, 0));
    assert(endls_since_test_1($state, 4, 5, 0));
    assert(endls_since_test_1($state, 4, 6, 1));
    assert(endls_since_test_1($state, 4, 7, 2));
    assert(endls_since_test_1($state, 4, 8, 2));

    assert(endls_since_test_1($state, 6, 0, 0));
    assert(endls_since_test_1($state, 6, 1, 0));
    assert(endls_since_test_1($state, 6, 2, 0));
    assert(endls_since_test_1($state, 6, 3, 0));
    assert(endls_since_test_1($state, 6, 4, 0));
    assert(endls_since_test_1($state, 6, 5, 0));
    assert(endls_since_test_1($state, 6, 6, 0));
    assert(endls_since_test_1($state, 6, 7, 1));
    assert(endls_since_test_1($state, 6, 8, 1));
}

# --------------------------------------------------------------------
sub terminal_match($$)
{
    my $log= $terminal_match_log;
    my ($t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());

    my $input= $state->[STATE_INPUT];
    my $pos= get_pos($state);
    #my ($match)= $state->[STATE_INPUT]=~ m{^$t->[PROD_PATTERN]}g;
    my $match;
    #$log->debug("$ctx: ref(input)=" . ref($state->[STATE_INPUT]) . ".");
    if (eoi($state->[STATE_INPUT], $pos)) {
        return ! $state->[STATE_EXPLAIN] ? NOMATCH() :
            nomatch($ctx, $log, $state, "End Of Input was reached.");
    }
    if ('ARRAY' eq ref($state->[STATE_INPUT])) {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: state->pos=$state->[STATE_POS],"
                        . " input[0]->name=", $ {@$input}[0]->[PROD_NAME]);
        }
        #if ($#{@$input} < $pos) {
        #    return ! $state->[STATE_EXPLAIN] ? NOMATCH() :
        #        nomatch($ctx, $log, $state, "End Of Input was reached.");
        #}
        $match= $ {@$input}[$pos];
        if ($t == $match->[PROD_CATEGORY]) {
            if (DEBUG() && $log->is_debug()) {
                #$log->debug("$ctx: matched token: " . varstring('match', $match));
                $log->debug("$ctx: matched token: $ctx, text:".
                            " '".$match->[RESULT_MATCH()]."'");
            }
            my $result= $match;
            $state->[STATE_POS]= $pos + 1;
            if (DEBUG() && $log->is_debug()) {
                #$log->debug(varstring('state', $state));
                $log->debug("$ctx: state->pos=$state->[STATE_POS]");
            }
            return ($result);
        } else {
            return ! $state->[STATE_EXPLAIN] ? NOMATCH() : nomatch(
                $ctx, $log, $state,
                "as a token it did not match"
                . ": ".$match->[RESULT_MATCH()]
                );
        }
    }
    else # Input is not an array (but a string).
    {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: input at pos $pos ='"
                        . substr($state->[STATE_INPUT], $pos, 80)
                        . "'");
        }
        #if (length($state->[STATE_INPUT])-1 < $pos) {
        #    return ! $state->[STATE_EXPLAIN] ? NOMATCH() :
        #        nomatch($ctx, $log, $state, "End Of Input was reached.");
        #}
        my $pattern= $t->[PROD_PATTERN];
        if (ASSERT()) {
            assert(defined($pattern));
            assert('' eq ref($pattern));
        }

        # FIXME: Can we avoid repeated construction or copying of the
        # same substring?  Looks like memoization does just that.
        # FIXME: Can we avoid substring construction or copying at all?
        #($match)= substr($state->[STATE_INPUT], $pos) =~ m{^($pattern)}g;
        my $matcher= $t->[PROD_MATCHER];
        #($match)= &{$matcher} (substr($state->[STATE_INPUT], $pos));
        #set_pos($state, $pos);

        if (DEBUG() && $log->is_debug()) {
            my $match_pos= get_pos($state);
            $log->debug("$ctx: before attempt: pos=".
                        (defined($match_pos)?$match_pos:"undef"));
        }
        #&{$matcher}($state->[STATE_INPUT]);
        #&$matcher(\$state->[STATE_INPUT]);
        $match= &$matcher($state);
        #$state->[STATE_INPUT]=~ m{^($pattern)}g;
        #$match= $1;
        if (DEBUG() && $log->is_debug()) {
            my $match_pos= get_pos($state);
            $log->debug("$ctx: after attempt: pos=".
                        (defined($match_pos)?$match_pos:"undef"));
        }

        if (defined($match)) {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: end pos=".get_pos($state));
                $log->debug("$ctx: matched text: '".$match."'");
            }

            if ($state->[STATE_EXPLAIN] && SHOW_LOCATION()) {
                $state->[STATE_LINENO] += endls_since($state, $pos);
                #print(STDERR "$ctx: Line number now at $state->[STATE_LINENO]\n");
            }

            #my $result= make_result($t, [$match]);
            my $result= [$t->[PROD_NAME], [$match]];
            # FIXME: Let the matcher do this?:
            #$state->[STATE_POS]= $pos += length($match);
            #assert($state->[STATE_POS] == get_pos($state)) if ASSERT();
            # Move this to match_with_memoize?
            if (MEMOIZE()) {
                $state->[STATE_POS_STASH]=
                    stash_get_pos_stash($state->[STATE_STASH()], $pos);
            }
            if (DEBUG() && $log->is_debug()) {
                #$log->debug(varstring('state', $state));
                $log->debug("$ctx: pos=$pos");
            }
            $result;
        } else {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: pattern not matched: '"
                            . $t->[PROD_PATTERN]."'");
            }
            my $input= $state->[STATE_INPUT];
            #my $pos= pos($input);
            my $pos= get_pos($state);
            my $prod_len= length($t->[PROD_PATTERN]);
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: pos=", defined($pos) ? $pos : "undef");
                $log->debug("$ctx: input: '", $input, "'");
                $log->debug("$ctx: prod_len: '", $prod_len, "'");
            }
            if ( ! defined($pos)) {
                return ! $state->[STATE_EXPLAIN] ? NOMATCH() : nomatch(
                    $ctx, $log, $state,
                    "pos was not defined, input was: ".
                    substr($input, 0,
                           max($prod_len, length($input)) )
                    . "...");
            }
            my $remaining= length($input)-$pos;
            my $inp_from_pos=
                $remaining < $prod_len ?
                substr($input, $pos, $remaining).$EOI :
                substr($input, $pos, $prod_len)."..." ;
            ( ! $state->[STATE_EXPLAIN]) ? NOMATCH() : nomatch(
                $ctx ." (pattern '".$t->[PROD_PATTERN]."')", $log, $state,
                " at: ".$inp_from_pos);
        }
    }
}

# --------------------------------------------------------------------
my $construction_log;

# --------------------------------------------------------------------
sub construction
{
    my $log= $construction_log;
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    assert(0 < scalar(@ARG));

    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'construction', $name,
                 [grammar_objects($caller_package, \@ARG)],
                 caller());
    #$log->debug(varstring('elements',$val->[PROD_ELEMENTS]));
    $val;
}

# --------------------------------------------------------------------
my $construction_match_log;
# --------------------------------------------------------------------
sub construction_match($$)
{
    my $log= $construction_match_log;
    my ($t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: [ Trying to match...");
    }

    my $saved_pos= get_pos($state);
    my $saved_lineno= $state->[STATE_LINENO];
    my $saved_line_start= $state->[STATE_LINE_START];

    # foreach $element in $t's elements
    my $elements= $t->[PROD_ELEMENTS];
    my @result_elements= map
    {
        my $i= $_;
        #if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: i=$i"); }
        my $element= $elements->[$i];
        my $element_name= $element->[PROD_SHORT_NAME];
        if (DEBUG() && $log->is_debug()) {
            #$log->debug(varstring('element', $element));
            $log->debug("$ctx: [ Trying to match element[$i]: $element_name");
        }
        my ($match)= match($element, $state);
        if ( ! matched($match))
        {
            if ( ! $state->[STATE_EXPLAIN]) {
                backtrack_to_pos(
                    $state, $saved_pos, $saved_lineno, $saved_line_start);
                return NOMATCH();
            }
            # Beacuse the attempted entire construction, and the
            # attempted element may be at different locations, we log
            # two lines of explanation.
            my $n= $i+1;
            # Log the attempted element match:
            my $reason=
                (SHOW_LOCATION ? location($state) : "") .
                "element $n ($element_name) did not match:\n".
                $match->[RESULT_MATCH()];
            backtrack_to_pos($state, $saved_pos
                             , $saved_lineno
                             , $saved_line_start
                );
            # After backtracking, log the construction start point:
            my $result= nomatch($ctx, $log, $state, "\n".$reason);
            if (DEBUG() && $log->is_debug()) { $log->debug("\]\]"); }
            return $result;
        }
        if (DEBUG() && $log->is_debug()) {
            #$log->debug("$ctx: Matched element: " . varstring($i,$element)."\]");
            $log->debug("$ctx: Matched element[$i]: $element_name ]");
            #$log->debug("$ctx: element value: " . varstring('match', $match));
        }
        $match;
    }
    (0 .. $#$elements);

    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: matched: '$ctx']");
        #$log->debug(varstring('result_elements', @result_elements));
    }
    #make_result($t, \@result_elements);
    [$t->[PROD_NAME], \@result_elements];
}

# --------------------------------------------------------------------
my $alternation_log;
# --------------------------------------------------------------------
sub alternation
{
    my $log= $alternation_log;
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    #my $val= { _ => $log->{name}, elements => \@ARG };
    #my $val= { _ => $log->{name}, elements => [@ARG] };
    #my $val= { _ => $log->{name}, elements => grammar_objects(\@ARG) };
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'alternation', $name,
                 [grammar_objects($caller_package, \@ARG)],
                 caller());
    $log->debug(varstring('elements', $val->[PROD_ELEMENTS]));
    log_val($log, $val);
    $val;
}

# --------------------------------------------------------------------
my $alternation_match_log;
# --------------------------------------------------------------------
sub alternation_match($$)
{
    my $log= $alternation_match_log;
    #$log->set_debug();
    my ($t, $state)= @ARG;
    # Q: Move argument logging to 'match'?
    # A: No, then we can not control logging locally.
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());

    # The only matching function that potentially consumes 'input' is
    # terminal_match.  Therefore terminal_match is the only place
    # where we must check for EOI (end of input).

    # FIXME: However, it may still be beneficial to check for EOI
    # here?

    my $elements= $t->[PROD_ELEMENTS];
    #$log->debug(varstring('elements', $elements));
    #my $n_elements= $#$elements;
    #$log->debug("n_#=", $n_elements);

    # foreach $element in $elements
    my @reasons= (); # List of reasons, why alternatives did not match
    for (0 .. $#$elements) {
        my $i= $_;
        #if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: i=$i"); }
        my $element= $elements->[$i];
        my $element_name= $element->[PROD_SHORT_NAME];
        if (DEBUG() && $log->is_debug()) {
            #$log->debug(varstring('element', $element));
            $log->debug("$ctx: [ Trying to match element[$i]: $element_name");
        }
        my ($match)= match($element, $state);
        if (matched($match))
        {
            if (DEBUG() && $log->is_debug()) {
                #$log->debug("$ctx: matched element: " . varstring($i, $element)."\]");
                $log->debug("$ctx: Matched element[$i]: $element_name\]");
                #$log->debug("$ctx: matched value: " . varstring('match', $match));
                $log->debug("$ctx: match result: "
                            . Parse::SiLLy::Result::toString($match, " "));
            }
            #return (make_result($t, [$match]));
            return [$t->[PROD_NAME], [$match]];
        }
        if ( ! $state->[STATE_EXPLAIN]) { next; }
        my $n= $i+1;
        my $reason1=
            (SHOW_LOCATION ? location($state) : "") .
            "$ctx alternative $n ($element_name) did not match:\n".
            $match->[RESULT_MATCH()];
        if (DEBUG() && $log->is_debug()) {
            $log->debug($reason1."]");
        }
        push(@reasons, $reason1);
    }

    ! $state->[STATE_EXPLAIN] ? NOMATCH() :
    nomatch($ctx." alternatives", $log, $state,
            ": [\n". join("\n", @reasons) ." ]");
}

# --------------------------------------------------------------------
my $optional_log;
# --------------------------------------------------------------------
sub optional#($)
{
    my $log= $optional_log;
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    #my $val= { _ => $log->{name}, element => $ARG[0] };
    #my $val= { _ => $log->{name}, element => grammar_object($ARG[0]) };
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'optional', $name,
                 [grammar_object($caller_package, $ARG[0])],
                 $caller_package);
    #$log->debug(varstring('element',$val->{element}));
    $val;
}

# --------------------------------------------------------------------
my $optional_match_log;
# --------------------------------------------------------------------
sub optional_match($$)
{
    my $log= $optional_match_log;
    my ($t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());

    my $element= $t->[PROD_ELEMENT];
    my $element_name= $element->[PROD_SHORT_NAME];
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('element', $element));
        $log->debug("$ctx: element=$element_name");
    }

    my ($match)= match($element, $state);
    if (matched($match))
    {
        if (DEBUG() && $log->is_debug()) {
            #$log->debug("$ctx: matched element: " . varstring($i,$element));
            #$log->debug("$ctx: matched " . varstring('value', $match));
            $log->debug("$ctx: matched "
                        . Parse::SiLLy::Result::toString($match, " "));
        }
        #return (make_result($t, [$match]));
        return [$t->[PROD_NAME], [$match]];
    }
    if (DEBUG() && $log->is_debug()) {
        #$log->debug("$ctx: not matched: '$ctx' (resulting in empty string)");
    }
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: not matched: $element_name");
    }
    [$t->[PROD_NAME], [$match]];
}

# --------------------------------------------------------------------
my $lookingat_log;
# --------------------------------------------------------------------
sub lookingat#($)
{
    my $log= $lookingat_log;
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'lookingat', $name,
                 [grammar_object($caller_package, $ARG[0])],
                 $caller_package);
    #$log->debug(varstring('element',$val->{element}));
    $val;
}

# --------------------------------------------------------------------
my $lookingat_match_log;
# --------------------------------------------------------------------
sub lookingat_match($$)
{
    my $log= $lookingat_match_log;
    my ($t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());

    my $element= $t->[PROD_ELEMENT];
    my $element_name= $element->[PROD_SHORT_NAME];
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('element', $element));
        $log->debug("$ctx: element=$element_name");
    }
    my $saved_pos= get_pos($state);
    my $saved_lineno= $state->[STATE_LINENO];
    my $saved_line_start= $state->[STATE_LINE_START];

    my ($match)= match($element, $state);
    if (matched($match))
    {
        if (DEBUG() && $log->is_debug()) {
            #$log->debug("$ctx: matched element: " . varstring($i,$element));
            #$log->debug("$ctx: matched " . varstring('value', $match));
            $log->debug("$ctx: matched "
                        . Parse::SiLLy::Result::toString($match, " "));
        }

        backtrack_to_pos($state, $saved_pos
                         , $saved_lineno
                         , $saved_line_start
            );
        #return (make_result($t, [$match]));
        return [$t->[PROD_NAME], [$match]];
    }
    ! $state->[STATE_EXPLAIN] ? NOMATCH() :
    nomatch($ctx, $log, $state,
            "we are *not* looking at a $element_name:\n".
            $match->[RESULT_MATCH()] );
}

# --------------------------------------------------------------------
my $notlookingat_log;
# --------------------------------------------------------------------
sub notlookingat#($)
{
    my $log= $notlookingat_log;
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'notlookingat', $name,
                 [grammar_object($caller_package, $ARG[0])],
                 $caller_package);
    #$log->debug(varstring('element',$val->{element}));
    $val;
}

# --------------------------------------------------------------------
my $notlookingat_match_log;
# --------------------------------------------------------------------
sub notlookingat_match($$)
{
    my $log= $notlookingat_match_log;
    my ($t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());

    my $element= $t->[PROD_ELEMENT];
    my $element_name= $element->[PROD_SHORT_NAME];
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('element', $element));
        $log->debug("$ctx: element=$element_name");
    }
    my $saved_pos= get_pos($state);
    my $saved_lineno= $state->[STATE_LINENO];
    my $saved_line_start= $state->[STATE_LINE_START];

    my ($match)= match($element, $state);
    if (matched($match))
    {
        if ( ! $state->[STATE_EXPLAIN]) {
            backtrack_to_pos(
                $state, $saved_pos, $saved_lineno, $saved_line_start);
            return NOMATCH();
        }
        my $result= nomatch(
            $ctx, $log, $state,
            "we *are* looking at a $element_name"
            . ": >>".Parse::SiLLy::Result::toString($match, " ")."<<");
        backtrack_to_pos($state, $saved_pos
                         , $saved_lineno
                         , $saved_line_start
            );
        return $result;
    }
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: not matched: $element_name (resulting in a match)");
    }
    [$t->[PROD_NAME], [$match]];
}

# --------------------------------------------------------------------
sub list_new($$$$$$)
{
    my ($log, $category, $name, $element, $separator, $caller_package)= @_;
    log_cargs($log, $name, \@ARG);
    my $val= def($log, $category, $name,
                 [ grammar_object($caller_package, $element),
                   grammar_object($caller_package, $separator) ],
                 $caller_package);
    #$log->debug(varstring('element',  $val->{element}));
    #$log->debug(varstring('separator',$val->{separator}));
    #log_val($log, $val);
    $val;
}

# --------------------------------------------------------------------
sub list_match($$$$)
{
    my ($log, $n_min, $t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_SHORT_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());
    my $element=   $t->[PROD_ELEMENT];
    my $separator= $t->[PROD_SEPARATOR];
    my $element_name=   $element->[PROD_SHORT_NAME];
    my $separator_name= $separator->[PROD_NAME];

    #my $result= make_result($t, []);
    #my $result= [$t->[PROD_NAME], []];
    my $result_elements= [];
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: [ Trying to match list...");
    }
    while (1) {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: [ Trying to match element '$element_name'");
        }
        my ($match)= match($element, $state);
        if ( ! matched($match))
        {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: Element not matched: '$element_name'\]");
            }
            my $n_matched= scalar(@$result_elements);
            if ($n_min > $n_matched) {
                if (DEBUG() && $log->is_debug()) { $log->debug("\]"); }
                return ! $state->[STATE_EXPLAIN] ? NOMATCH() : nomatch(
                    $ctx, $log, $state,
                    "it requires at least $n_min $element_name elements,"
                    . " matched only $n_matched $element_name elements,"
                    . " and the next $element_name did not match"
                    . ":\n"
                    . $match->[RESULT_MATCH()] );
            }
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.\]");
            }
            #return (make_result($t, $result_elements));
            return [$t->[PROD_NAME], $result_elements];
        }
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: Matched element '$element_name']");
        }
        #push(@$result, $match);
        push(@$result_elements, $match);

        if ('' eq $separator) { next; }

        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: [ Trying to match separator '$separator_name'");
        }
        ($match)= match($separator, $state);
        if ( ! matched($match))
        {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: Separator not matched: '$separator_name'\]");
            }
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.\]");
            }
            #return (make_result($t, $result_elements));
            return [$t->[PROD_NAME], $result_elements];
        }
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: Matched separator '$separator_name']");
        }
    }
    die("Must not reach this\n");
}

# --------------------------------------------------------------------
my $pelist_log;
# --------------------------------------------------------------------
sub pelist#($$$)
{
    my ($caller_package, $file, $line)= caller();
    list_new($pelist_log, 'pelist', $_[0], $_[1], $_[2], $caller_package);
}

# --------------------------------------------------------------------
my $pelist_match_log;
# --------------------------------------------------------------------
sub pelist_match($$) { list_match($pelist_match_log, 0, $_[0], $_[1]); }

# --------------------------------------------------------------------
my $nelist_log;
# --------------------------------------------------------------------
sub nelist#($$$)
{
    my ($caller_package, $file, $line)= caller();
    list_new($nelist_log, 'nelist', $_[0], $_[1], $_[2], $caller_package);
}

# --------------------------------------------------------------------
my $nelist_match_log;
# --------------------------------------------------------------------
sub nelist_match($$) { list_match($nelist_match_log, 1, $_[0], $_[1]); }

# --------------------------------------------------------------------
my $match_log;

# This is needed in order to use references as hash keys:
# Q: What performance impact does this cause?
# A: Significant 25% (22 parses per second without Tie::RefHash vs.
#    16 parses per second with Tie::RefHash)
#use Tie::RefHash;

# --------------------------------------------------------------------
sub stash_get_pos_stash_with_assert($$)
{
    # FIXME: Clean up:
    #my ($state, $pos, $t)= @_;
    #my $stash= $state->[STATE_STASH];
    my ($stash, $pos)= @_;
    assert(defined($stash)) if ASSERT();
    assert('' ne ref($stash)) if ASSERT();

    if ( ! exists($stash->{$pos})) {
        #$stash_log->debug("New position $pos, creating pos stash for it...");
        #my $pos_stash= {};
        my $pos_stash= [];
        #tie %$pos_stash, 'Tie::RefHash';
        return ($stash->{$pos}= $pos_stash);
    }
    my $pos_stash= $stash->{$pos};
    assert(defined($pos_stash)) if ASSERT();
    assert('' ne ref($pos_stash)) if ASSERT();
    $pos_stash;
}

# --------------------------------------------------------------------
# @return the position-specific stash (which maps productions to parse
# results), for the given master stash and position.

sub stash_get_pos_stash($$)
{
    my ($stash, $pos)= @_;
    if (ASSERT()) {
        assert(defined($stash));
        assert('' ne ref($stash));
        'HASH' eq ref($stash) || $match_log->info(varstring('stash', $stash));
        assert('HASH' eq ref($stash));
        assert(defined($pos));
    }
    if ( ! exists($stash->{$pos})) {
        #if (DEBUG() && $stash_log->is_debug()) {
        #    $stash_log->debug("New position $pos, creating pos stash for it...");
        #}
        #return ($stash->{$pos}= {});
        return ($stash->{$pos}= []);
    }
    $stash->{$pos};
}

# --------------------------------------------------------------------
sub match_with_memoize($$)
{
    my $log= $match_log;
    #Logger::set_debug($log);
    my ($t, $state)= @ARG;
    if (ASSERT()) {
        assert(defined($t));
        assert('' ne ref($t));

        assert(defined($state));
        assert('' ne ref($state));
    }

    my $pos= get_pos($state);
    if (ASSERT()) {
        assert(defined($pos));
        assert('' eq ref($pos));
    }

    # FIXME: Consider implementing the pos_stashes as arrays.  This
    # may need to map productions to indices, though.  This can be
    # hard when combining grammars.

    #my $pos_stash_key= $t->[PROD_NAME];
    my $pos_stash_key= $t->[PROD_ID];

    my $stash= $state->[STATE_STASH];
    my $pos_stash= stash_get_pos_stash($stash, $pos);
    #my $pos_stash= $stash->{$pos};
    # FIXME: Activate use of STATE_POS_STASH
    #my $pos_stash= $state->[STATE_POS_STASH];
    if ( ! defined($pos_stash)) {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("New position $pos, creating pos stash for it...");
        }
        $state->[STATE_POS_STASH]= $pos_stash= $stash->{$pos}= [];
    }
    my $stashed= $pos_stash->[$pos_stash_key];
    if (defined($stashed))
    {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("Found in stash: ".format_stashed($stashed));
        }
        if (matched($stashed))
        {
            assert('ARRAY' eq ref($stashed)) if ASSERT();
            if (DEBUG() && $log->is_debug()) {
                $log->debug("Pos before jump: ".get_pos($state));
            }
            set_pos($state,             $stashed->[LOCATION_POS]);
            $state->[STATE_LINENO]    = $stashed->[LOCATION_LINENO];
            $state->[STATE_LINE_START]= $stashed->[LOCATION_LINE_START];
            # We have already set STATE_POS_STASH above.

            if (DEBUG() && $log->is_debug()) {
                $log->debug("Pos after jump: ".get_pos($state));
            }
            return ($$stashed[LOCATION_REASON]);
        }
        else {
            return $stashed;
        }
    }

    my $method= $t->[PROD_METHOD];
    my $result= &$method($t, $state);

    if (ASSERT()) {
        assert(matched($result) || get_pos($state) == $pos);
    }

    my $location=
        matched($result)
        ? [
            get_pos($state),
            $state->[STATE_LINENO],
            $state->[STATE_LINE_START],
            $result,
        ]
        : $result;
    if (DEBUG() && $log->is_debug()) {
        $log->debug("Storing result in stash for ${pos}->$pos_stash_key"
                    . ($pos_stash_key ne $t->[PROD_NAME] ? " ($t->[PROD_NAME])" : "")
                    . ": "
                    #. varstring('result', $result)
                    # FIXME: use OO syntax here: $result->toString()
                    . "\$result ="
                    . Parse::SiLLy::Result::toString($result, " ")
                    );
        #$log->debug(varstring("stashed", $location));
    }
    #$pos_stash->{$pos_stash_key}= $location;
    $pos_stash->[$pos_stash_key]= $location;

    # Used this to find out that the $t used above as a hash key
    # was internally (in the hash table) converted to a string.
    #if (DEBUG() && $log->is_debug()) {
    #    for (keys(%$pos_stash)) { $log->debug("key $_ has ref ".ref($_)); }
    #}
    # Used Tie::RefHash to get around that.  Another way might be
    # to use $t's name as the key.
    #for (keys(%$pos_stash)) { assert('HASH' eq ref($_)); }
    # FIXME: is this slow?:
    #for (keys(%$pos_stash)) { ::should('HASH', ref($_)); }

    $result;
}

# --------------------------------------------------------------------
sub match_with_assert($$)
{
    my ($t, $state)= @ARG;
    if (MEMOIZE()) { return match_with_memoize($t, $state); }

    my $method= $t->[PROD_METHOD];
    if (ASSERT()) {
        assert(defined($method));
        assert('' ne ref($method));
    }
    &$method($t, $state);
}

# --------------------------------------------------------------------
#sub match_with_bind($$)
sub match($$)
{
    my ($t, $state)= @ARG;

    if ($state->[STATE_EXPLAIN]) {
        my $location= state_to_location(
            $state, "Trying to match $t->[PROD_SHORT_NAME]");
        push(@{$state->[STATE_TRYING]}, $location);
    }

    if (MEMOIZE()) { return match_with_memoize($t, $state); }
    my $method= $t->[PROD_METHOD];
    my $result= &$method($t, $state);

    if ($state->[STATE_EXPLAIN]) {
        pop(@{$state->[STATE_TRYING]});
    }
    return $result;
}

# --------------------------------------------------------------------
sub match_without_bind($$)
{
    if (MEMOIZE()) { return match_with_memoize($_[0], $_[1]); }
    my $method= $_[0]->[PROD_METHOD];
    &$method($_[0], $_[1]);
}

# --------------------------------------------------------------------
sub match_minimal($$)
{
    my $method= $_[0]->[PROD_METHOD];
    &$method($_[0], $_[1]);
}

# --------------------------------------------------------------------
sub init()
{
    $terminal_log= Logger->new('terminal');
    $terminal_match_log= Logger->new('terminal_match');

    $construction_log= Logger->new('construction');
    $construction_match_log= Logger->new('construction_match');

    $alternation_log= Logger->new('alternation');
    $alternation_match_log= Logger->new('alternation_match');

    $optional_log= Logger->new('optional');
    $optional_match_log= Logger->new('optional_match');

    $lookingat_log= Logger->new('lookingat');
    $lookingat_match_log= Logger->new('lookingat_match');

    $notlookingat_log= Logger->new('notlookingat');
    $notlookingat_match_log= Logger->new('notlookingat_match');

    $nelist_log= Logger->new('nelist');
    $nelist_match_log= Logger->new('nelist_match');

    $pelist_log= Logger->new('pelist');
    $pelist_match_log= Logger->new('pelist_match');

    $def_log= Logger->new('def');
    $match_log= Logger->new('match');

    %methods=
        ('terminal'     => \&terminal_match,
         'alternation'  => \&alternation_match,
         'construction' => \&construction_match,
         'optional'     => \&optional_match,
         'lookingat'    => \&lookingat_match,
         'notlookingat' => \&notlookingat_match,
         'nelist'       => \&nelist_match,
         'pelist'       => \&pelist_match);
    #$match_log->info(varstring('methods', \%methods));

    $production_id= 0;
    $productions_by_id= [];

    endls_since_test();
    Parse::SiLLy::Result::matched_test();
}

# ====================================================================
package main;

use strict;
#use diagnostics;
#use English;

#use constant DEBUG => Parse::SiLLy::Grammar::DEBUG();

use Parse::SiLLy::Compare qw(compareR);

# --------------------------------------------------------------------
sub elements($) {
    #return $ {@{$_[0]}}[1];
    my $result= $_[0];
    my $elements= $$result[1];

    #if (DEBUG() && $log->is_debug()) {
    #    $log->debug(varstring('elements', $elements));
    #}
    assert(defined($elements));
    assert('ARRAY' eq ref($elements));
    $elements;
}

# --------------------------------------------------------------------
# Decorates (qualifies) with the given prefix, for example
# "mygrammar::", the names in the given 'expected' spec (given as name
# and list of elements).

sub decorate( $$ );
sub decorate( $$ ) {
    my ($prefix, $expected)= (@_);
    my $name= $expected->[Parse::SiLLy::Result::RESULT_PROD];
    my @elts= @{$expected}[1..$#{$expected}];
    [$prefix.$name,
     'ARRAY' eq ref($elts[0]) ? [(map { decorate($prefix, $_) } @elts)]
     : \@elts
    ];
}

# --------------------------------------------------------------------
# FIXME: Use this to replace check_result

# Assert that the given actual value matches the given expected value.
sub check_result2( $$$ )
{
    my ($log, $actual, $expected)= (@_);
    my $reason= [''];
    if ( ! compareR($actual, $expected, $reason)) {
        $log->error(
            "Actual value did not match expected value,".
            " because:\n".$reason->[0]);
        $log->info(varstring('actual', $actual));
        $log->info(varstring('expected', $expected));
        confess("Assertion failed");
    }
}

# --------------------------------------------------------------------
sub check_result($$$) {
    my ($result, $expected_typename, $expected_text)= (@_);
    assert(defined($result));
    assert(Parse::SiLLy::Grammar::matched($result));
    assert('ARRAY' eq ref($result));
    assert(2 <= scalar(@$result));
    assert(defined($expected_typename));
    assert(defined($expected_text));
    #$main_log->debug(varstring('result', $result));

    #my $actual_type= $$result[0];
    my $actual_typename= $$result[0];
    should($actual_typename, $expected_typename);

    my $result_elements= elements($result);
    assert(defined($result_elements));
    assert('ARRAY' eq ref($result_elements));

    my $actual_text= $$result_elements[0];
    #should($actual_text,     $expected_text);

    $main_log->debug(varstring("expected_text", $expected_text));
    $main_log->debug(varstring("actual_text", $actual_text));
    check_result2($main_log, $actual_text, $expected_text);

    $main_log->debug("Okayed: $actual_typename, '$actual_text'");
}

# --------------------------------------------------------------------
# Suppress 'used only once' warnings
#$minilang::Name= $minilang::Name;
$::foo= $::foo;

# --------------------------------------------------------------------
# FIXME: Use a unit testing framework, or at least find a better name

sub test1($$$$$)
{
    my ($log, $matcher, $element, $state, $expected)= @_;
    #$log->set_debug();
    my $call= "Parse::SiLLy::Grammar::$matcher(\$$element, \$state)";
    $log->debug("eval('$call')...");
    my $result= eval($call);
    # FIXME: Treat all evals like this?:
    #my $errors= $@;
    #if (defined($@)) { die("eval('$call') failed: '$@'\n"); }
    if ('' ne $@) { die("eval('$call') failed: '$@'\n"); }

    assert(defined($result));
    # FIXME: Check DEBUG calls
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        #$log->debug(varstring("$matcher $element result", $result));
        $log->debug("$matcher $element result = "
                    . Parse::SiLLy::Result::toString($result, " "));
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    check_result($result, $element, $expected);
}

# --------------------------------------------------------------------
sub test_minilang()
{
    my $log= $main_log;
    # FIXME: As far as possible, use `Log4perl.conf` instead.
    #$log->set_debug();
    my $state;
    my $result;

    my $grammar= "Test/minilang-grammar.pl";
    $log->debug("--- Reading '$grammar'...");
    require $grammar;

    $log->debug("--- Testing terminal_match...");
    $state= Parse::SiLLy::Grammar::Parser_new(
        "inline in function test_minilang (Testing terminal_match)",
        'blah 123  456');

    test1($log, "terminal_match", "minilang::Name",       $state, "blah");
    test1($log, "terminal_match", "minilang::Whitespace", $state, " ");
    test1($log, "terminal_match", "minilang::Number",     $state, "123");
    test1($log, "terminal_match", "minilang::Whitespace", $state, "  ");
    test1($log, "terminal_match", "minilang::Number",     $state, "456");

    $log->debug("--- Testing alternation_match...");
    $state= Parse::SiLLy::Grammar::Parser_new(
        "inline in function test_minilang (Testing alternation_match)",
        'blah 123');
    test1($log, "alternation_match", "minilang::Token",
          $state, ["minilang::Name", ["blah"]]);
    test1($log, "match",             "minilang::Whitespace",
          $state, " ");
    test1($log, "match",             "minilang::Token",
          $state, ["minilang::Number", [123]]);

    $log->debug("--- Testing tokenization 1...");
    $state= Parse::SiLLy::Grammar::Parser_new(
        "inline in function test_minilang (Testing tokenization 1)",
        'blah "123"  456');

    $result= Parse::SiLLy::Grammar::match($minilang::Tokenlist, $state);
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        #$log->debug(varstring("match minilang::Tokenlist result 1", $result));
        $log->debug("match minilang::Tokenlist result 1='"
                    . Parse::SiLLy::Result::toString($result, " ")
                    . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    my $expected= ["Tokenlist",
                   ["Token", ["Name", "blah"]],
                   ["Token", ["String", '"123"']],
                   ["Token", ["Number", "456"]],
                   ];
    $expected= decorate("minilang::", $expected);
    #use FreezeThaw;
    #assert(0 == strCmp($result, $expected));
    check_result2($log, $result, $expected);

    my $result_elements= elements($result);
    #check_result($$result_elements[0], "Name", "blah");
    #check_result($$result_elements[1], "String", '"123"');
    #check_result($$result_elements[2], "Number", "456");


    $log->debug("--- Testing tokenization 2...");
    #my $input= 'blah ("123", xyz(456 * 2)); end;';
    my $input= 'blah.("123", xyz.(456.*.2)); end;';
    #           0         1         2         3
    #           0....5....0....5..8.0....5....0.2
    $state= Parse::SiLLy::Grammar::Parser_new(
        "inline in function test_minilang (Testing tokenization 2)",
        $input);

    $result= Parse::SiLLy::Grammar::match($minilang::Tokenlist, $state);
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        #$log->debug(varstring("match minilang::Tokenlist result 2", $result));
        $log->debug("match minilang::Tokenlist result 2='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);

    assert(1 < scalar(@$result));
    $result_elements= elements($result);
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        $log->debug(varstring('result_elements', $result_elements));
    }

    # FIXME: When we always pass an expected result object,
    # check_result needs only two args.

    check_result($$result_elements[0], "minilang::Token",
                 ["minilang::Name", ["blah"]]
                 );
    #check_result($$result_elements[1], 'Period', '.');
    my $i= 0;
    my @token_contents=
        (
         ['Name',      'blah'],
         ['Period',    '.'],
         ['Lparen',    '('],
         ['String',    '"123"'],
         ['Comma',     ','],
         ['Name',      'xyz'],
         ['Period',    '.'],
         ['Lparen',    '('],
         ['Number',    456],
         ['Period',    '.'],
         ['Name',      '*'],
         ['Period',    '.'],
         ['Number',    2],
         ['Rparen',    ')'],
         ['Rparen',    ')'],
         ['Semicolon', ';'],
         ['Name',      'end'],
         ['Semicolon', ';'],
         );
    my @expected_tokens= map {
        #["minilang::Token", ["minilang::$$_[0]", $$_[1]]];
        ["minilang::Token", [ ["minilang::$$_[0]", [ $$_[1] ]] ]];
    } @token_contents;
    my $expected_tokens= \@expected_tokens;
    $expected= ["minilang::Tokenlist", $expected_tokens];
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        $log->debug('expected_tokens formatted as result: '
                    #. Parse::SiLLy::Result::toString($expected_tokens, " ")
                    . Parse::SiLLy::Result::toString($expected, " ")
                    );
        $log->debug(varstring('expected_tokens', $expected_tokens));
    }
    for (@$expected_tokens)
    {
        my ($expected_result)= $_;
        if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
            #$log->debug(varstring('expected_result', $expected_result));
            $log->debug("Checking \$expected_result='"
                        . Parse::SiLLy::Result::toString($expected_result, " ")."'...");
        }
        my $expected_elements= elements($expected_result);
        check_result($$result_elements[$i],
                     $$expected_result[0],
                     $$expected_elements[0]);
        ++$i;
    }
    check_result2($log, $result, $expected);

    $log->debug("--- Testing minilang::Program...");
    $log->debug("minilang::Program=$minilang::Program.");
    # FIXME: Get this (two-stage parsing) to work:
    #$state= Parse::SiLLy::Grammar::Parser_new("tokenized input", $result);
    Parse::SiLLy::Grammar::Parser_reset($state);

    $result= Parse::SiLLy::Grammar::match($minilang::Program, $state);
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        #$log->debug(varstring("match minilang::Program result", $result));
        $log->debug("match minilang::Program result='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);

    $expected=
    ['Program',
     ['Mchain',
      ['LTerm', ['Name', 'blah']],
      ['LTerm', ['Tuple',
        ['Lparen',    '('],
        ['Exprlist',
         ['Mchain',
          ['LTerm', ['Literal', ['String', '"123"']]],
          ],
         ['Mchain',
          ['LTerm', ['Name', 'xyz']],
          ['LTerm', ['Tuple',
            ['Lparen',    '('],
            ['Exprlist',
             ['Mchain',
              ['LTerm', ['Literal', ['Number', 456]]],
              ['LTerm', ['Name', '*']],
              ['LTerm', ['Literal', ['Number', 2]]],
              ]],
            ['Rparen', ')'],
            ]]]],
        ['Rparen', ')'],
        ],
       ], # Term
      ], # Mchain
     ['Mchain',
      ['LTerm', ['Name', 'end']],
      ],
     ];

    $expected= decorate("minilang::", $expected);
    $log->debug(varstring('expected', $expected));
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        $log->debug('expected formatted as result: '
                    . Parse::SiLLy::Result::toString($expected, " ")
            );
    }

    check_result2($log, $result, $expected);
}

# --------------------------------------------------------------------
use constant NOMATCH => Parse::SiLLy::Result::NOMATCH();

# --------------------------------------------------------------------
sub test_xml()
{
    my $log= $main_log;
    my $state;
    my $result;

    my $grammar= "Test/xml-grammar.pl";
    $log->debug("--- Reading '$grammar'...");
    require $grammar;

    my $xml= <<"";
<tr>
 <td>Contents</td>
 <td>Foo Bar</td>
 <td></td>
</tr>

    $state= Parse::SiLLy::Grammar::Parser_new(
        "inline in function test_xml", $xml);

    #$result= Parse::SiLLy::Grammar::match($Parse::SiLLy::Test::XML::Elem,
    #                                      $state);
    #if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
    #    $log->debug(varstring("match XML::Elem result", $result));
    #}
    #Parse::SiLLy::Grammar::input_show_state($log, $state);
    #check_result($result, "Elem", $state->[STATE_INPUT]);

    {
    my $top= eval("\$Parse::SiLLy::Test::XML::Contentlist");
    assert(defined($top));
    $result= Parse::SiLLy::Grammar::match($top, $state);
    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('match $top result', $result));
        $log->debug("match $top result='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);

    no strict 'subs';
    my $expected= [Contentlist,
  [MixedContent, [Elem, [SEElem,
    [STag, [Langle,'<'],            [Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'tr']],[Oattrs,NOMATCH],[Owhite,NOMATCH],[Rangle,'>']],
    [Contentlist,
     [MixedContent, [Cdata,'
 ']],
     [MixedContent, [Elem, [SEElem,
       [STag, [Langle,'<'],            [Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'td']],[Oattrs,NOMATCH],[Owhite,NOMATCH],[Rangle,'>']],
       [Contentlist, [MixedContent, [Cdata,'Contents']]],
       [ETag, [Langle,'<'],[Slash,'/'],[Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'td']],                 [Owhite,NOMATCH],[Rangle,'>']] ]]],
     [MixedContent, [Elem, [SEElem,
       [STag, [Langle,'<'],            [Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'td']],[Oattrs,NOMATCH],[Owhite,NOMATCH],[Rangle,'>']],
       [Contentlist, [MixedContent, [Cdata,'Foo Bar']]],
       [ETag, [Langle,'<'],[Slash,'/'],[Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'td']],                 [Owhite,NOMATCH],[Rangle,'>']] ]]],
     [MixedContent, [Elem, [SEElem,
       [STag, [Langle,'<'],            [Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'td']],[Oattrs,NOMATCH],[Owhite,NOMATCH],[Rangle,'>']],
       [Contentlist,  ],
       [ETag, [Langle,'<'],[Slash,'/'],[Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'td']],                 [Owhite,NOMATCH],[Rangle,'>']] ]]]
     ],
    [ETag, [Langle,'<'],[Slash,'/'],[Owhite,NOMATCH],[Tagname,[OPrefix,NOMATCH],[PlainTagName,'tr']],                 [Owhite,NOMATCH],[Rangle,'>']]
    ]]]];
    use strict 'subs';

    #$log->info(varstring('expected before decorating', $expected));
    $expected= decorate("Parse::SiLLy::Test::XML::", $expected);
    $log->debug(varstring('expected', $expected));
    #$log->info(varstring('expected', $expected));

    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        $log->debug('expected formatted as result: '.
                    Parse::SiLLy::Result::toString($expected, " "));
    }
    my $equal=
        Parse::SiLLy::Result::toString($expected, " ") eq
        Parse::SiLLy::Result::toString($result, " ");
    $log->info("equal?: ", $equal ? "yes": "no");
    # Consider comparing simplified, "undecorated" structures,
    # where the prefix has been removed and match elements are inlined.
    #check_result2($log, $result, $expected);
    $equal;
    }
}

# --------------------------------------------------------------------
# Returns the contents of the INPUT filehandle as a string.
# This should in theory be faster than read_INPUT_join, but is rumored
# to be not (for documents of our size it does not matter anyway).
sub read_INPUT_IRS() {
    my $saved_RS= $INPUT_RECORD_SEPARATOR;
    undef($INPUT_RECORD_SEPARATOR);
    my $data= <INPUT>;
    $INPUT_RECORD_SEPARATOR= $saved_RS;
    #if (DEBUG() && $log->is_debug()) { $log->debug(varstring('data', $data)); }
    $data;
}

# --------------------------------------------------------------------
sub do_one_run($$) {
    my ($state, $top)= @_;
    if (Parse::SiLLy::Grammar::MEMOIZE()) {
        #delete($state->{stash});
        $state->[Parse::SiLLy::Grammar::STATE_STASH()]= {};
    }
    Parse::SiLLy::Grammar::Parser_reset($state);
    no strict 'refs';
    Parse::SiLLy::Grammar::match($ {"$top"}, $state);
}

# --------------------------------------------------------------------
sub do_runs($$$) {
    my ($n, $state, $top)= @_;
    for (my $i= 0; $i<$n; ++$i) { do_one_run($state, $top); }
}

# --------------------------------------------------------------------
# Tests whether `pos()` works how we expect it to work.

sub pos_test($)
{
    my ($log)= @_;

    # Elementary test
{
    my $text= "012abc345";
    my $match;
    assert( ! defined(pos($text)));
    # Who knows, maybe the first pos call changes some state.
    assert( ! defined(pos($text)));
    assert( ! defined($match));

    $text=~ m/\G/go;
    assert(defined(pos($text)));
    assert(0==pos($text));
    $match= $1;
    assert( ! defined($match));

    $text=~ m/\G012/go;
    assert(defined(pos($text)));
    assert(3==pos($text));
    $match= $1;
    assert( ! defined($match));

    $text=~ m/\G(a.c)/go;
    $match= $1;
    if ( ! defined(pos($text))) {
        print(STDERR "match='".(defined($match)?$match:"undef")."'\n");
    }
    assert(defined(pos($text)));
    assert(6==pos($text));
    assert("abc" eq $match);

    $text=~ m/\G(.4)/go;
    $match= $1;
    assert(defined(pos($text)));
    assert(8==pos($text));
    assert("34" eq $match);

    $text=~ m/\G(5)/go;
    $match= $1;
    assert(defined(pos($text)));
    assert(9==pos($text));
    assert("5" eq $match);

    $text=~ m/\G/go;
    $match= $1;
    assert(defined(pos($text)));
    assert(9==pos($text));
    assert( ! defined($match));

    $text=~ m/\G./go;
    $match= $1;
    assert( ! defined(pos($text)));
    assert( ! defined($match));
}

    # Array Element Test
{
    my $text= "01def678";
    my $match;
    assert( ! defined(pos($text)));
    assert( ! defined(pos($text)));
    assert( ! defined($match));
    my $a= [$text];
    assert( ! defined(pos($a->[0])));
    assert( ! defined(pos($a->[0])));

    $a->[0]=~ m/\G01/go;
    assert(defined(pos($a->[0])));
    assert(2==pos($a->[0]));

    $a->[0]=~ m/\G(d.f)/go;
    $match= $1;
    assert(defined(pos($a->[0])));
    assert(5==pos($a->[0]));
    assert("def" eq $match);

    $a->[0]=~ m/\G(.7)/go;
    $match= $1;
    assert(defined(pos($a->[0])));
    assert(7==pos($a->[0]));
    assert("67" eq $match);

    $a->[0]=~ m/\G(..)/go;
    # CAVEAT! $1 is still the value of the previous successful match
    #assert( ! defined($1));
    $match= $1;
    print(STDERR "match='".(defined($match)?$match:"undef")."'\n");
    assert( ! defined(pos($a->[0])));
}

}

# --------------------------------------------------------------------
sub init()
{
    # Turn all warnings into errors
    $SIG{__WARN__}= sub{ confess(@_); };
    # Turn all warnings excepts about deep recursion into errors
    #$SIG{__WARN__} = sub { $_[0] =~ /recursion/ and confess(@_); warn(@_) };

    #Log::Log4perl->easy_init($INFO);
    #Log::Log4perl->easy_init($DEBUG);
    #Log::Log4perl->easy_init(Parse::SiLLy::Grammar::DEBUG() ? $DEBUG : $INFO);
    #$logger->info("Running...");
    #if (scalar(@_) > 0) { info(vdump('Args', \@_)); }
    $Data::Dumper::Indent= 1;

    $main_log= Logger->new('main');
    assert_test($main_log);
    pos_test($main_log);

    Parse::SiLLy::Grammar::init();
}

# --------------------------------------------------------------------
sub main
{
    # Activate this to get a chance to attach a process monitor:
    #sleep(5);
    init();
    my $log= $main_log;

    # If Perl is started with -DL (which needs a Perl built with
    # -DDEBUGGING), this prints memory usage statistics:
    #warn('!');

    # Test 'def'
    #Parse::SiLLy::Grammar::def 'foo', {elt=>'bar'};
    Parse::SiLLy::Grammar::def($log, 'terminal', 'foo', ['bar'], 'main');
    $log->debug(varstring('::foo', $::foo));
    #assert($::foo->{elt} eq 'bar');

    # Run self-tests
    test_minilang();
    test_xml();

    (1 == $#ARG) or die($usage);

    $log->debug("---Reading and Evaluating grammar...");
    my $grammar_filename= shift(@_);

=begin comment

    open(GRAMMAR, "< $grammar_filename")
        or die("Can't open grammar file \`$grammar_filename'.");
    $INPUT_RECORD_SEPARATOR= undef;
    my $grammar= <GRAMMAR>;
    $INPUT_RECORD_SEPARATOR= "";
    close(GRAMMAR);
    #$log->debug("grammar='$grammar'");

=end comment

=cut

    #eval($grammar);
    #use $grammar_filename;
    require $grammar_filename;
    #$log->debug(varstring('exprlist', $::exprlist));
    $log->debug("Grammar evaluated.");

    $log->debug("---Reading input file...");
    my $input= shift(@_);
    open(INPUT, "< $input") or die("Can't open \`$input'.");
    my $input_data= read_INPUT_IRS();
    close(INPUT);

    $log->info("input:\n$input_data");

    {
    my $state= Parse::SiLLy::Grammar::Parser_new($input, $input_data);
    my $top= "Parse::SiLLy::Test::XML::Document";
    my $result;
    #$result= Parse::SiLLy::Grammar::match($::Elem, $state);
    no strict 'refs';
    # FIXME: Make set_debug calls work without DEBUG() being true.
    #$pelist_match_log->set_debug();
    $result= Parse::SiLLy::Grammar::match($ {"$top"}, $state);
    #$pelist_match_log->set_nodebug();
    #$log->info(vardescr("result", $result));
    #$log->set_debug();
    $log->info("first run result:");
    print(STDOUT " ", Parse::SiLLy::Result::toString($result, " "), "\n");
    if ( ! Parse::SiLLy::Result::matched($result)) {
        Parse::SiLLy::Grammar::Parser_reset($state);
        $state->[Parse::SiLLy::Grammar::STATE_EXPLAIN]= 1;
        $result= Parse::SiLLy::Grammar::match($ {"$top"}, $state);
        print(STDERR "Ultimate reason:\n",
              $result->[Parse::SiLLy::Result::RESULT_MATCH()], "\n");
        print(STDERR "Furthest reason:\n",
              $state->[Parse::SiLLy::Grammar::STATE_FURTHEST_REASON()], "\n");
    }
    #$log->set_nodebug();
    #$result= do_one_run($state, $top);
    #$result= do_runs(100, $state, $top);

    use Benchmark;
    # FIXME: Make timethis print to STDERR instead of to STDOUT.
    timethis(1, sub { $result= do_one_run($state, $top); } );
    # First arg -N means repeat for at least N seconds.
    timethis(-2, sub { $result= do_one_run($state, $top); } );

    if (Parse::SiLLy::Grammar::DEBUG() && $log->is_debug()) {
        $log->debug(varstring('match $top result', $result));
        #$log->debug(varstring('state', $state));
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    if (Parse::SiLLy::Grammar::MEMOIZE()) {
        Parse::SiLLy::Grammar::show_stash(
            $log, $state->[Parse::SiLLy::Grammar::STATE_STASH()] );
    }
    }
    #warn('!!!');
    #sleep(5);
}

# --------------------------------------------------------------------
main(@ARGV);

# --------------------------------------------------------------------
# EOF
