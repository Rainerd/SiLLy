#!/usr/bin/perl -w
# --------------------------------------------------------------------
=ignore

Usage: perl PROGRAM GRAMMAR INPUT > OUTPUT

Example: perl -w parse.pl Test/xml-grammar.pl Test/XML/example.xml
Debug:   PARSE_SILLY_DEBUG=1 perl -w parse.pl Test/xml-grammar.pl Test/XML/example.xml
Profile: PARSE_SILLY_ASSERT=0 perl -w -d:DProf parse.pl Test/xml-grammar.pl Test/XML/example.xml; dprofpp
Profile: PARSE_SILLY_ASSERT=0 perl -w -I../.. -MDevel::Profiler parse.pl Test/xml-grammar.pl Test/XML/example.xml; dprofpp
Lint:    perl -w -MO=Lint,-context parse.pl Test/xml-grammar.pl Test/XML/example.xml
Fastest so far: PARSE_SILLY_ASSERT=0 perl parse.pl Test/xml-grammar.pl Test/XML/example.xml

Note that the -w option may cost a percent or two of performance.

--------------------------------------------------------------------
Copyright (c) 2004-2006 by Rainer Blome

Copying and usage conditions for this document are specified by
Rainer's Open License, Version 1, in file LICENSE.txt.

In short, you may use or copy this document as long as you:
o Keep this copyright and permission notice.
o Use it ,,as is``, at your own risk -- there is NO WARRANTY WHATSOEVER.
o Do not use my name in advertising.
o Allow free copying of derivatives.


--------------------------------------------------------------------
--------------------------------------------------------------------
Purpose

Parses, according to the given grammar, the given input. Produces an
appropriately structured result (a parse tree alias concrete syntax tree).

Keywords

Parser, recursive descent, backtracking, backup, LL, unlimited
lookahead, memoizing, packrat, linear time, structured grammar rules


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

PARSE_SILLY_ASSERT=0 -- Do not check assertions, do not even compute
  the result.  This can significantly speed up the parser (by a factor
  of about two).  However, any remaining bugs may manifest themselves
  much later than when they are encountered.

PARSE_SILLY_MEMOIZE=1 -- Turns on memoization.  This makes this a
  packrat parser.  Currently, with the grammars and examples that I
  used for testing, this option slows the parser down by about 30%.

PARSE_SILLY_DEBUG=1 -- Enable debug messages.  This will slow the
  parser down by a factor of at least ten.

PARSE_SILLY_PRODS_ARE_HASHES=0 -- Implement productions as arrays
  instead of hashes.


Design

Recursive descent with backup (backtracking of state in case of local mismatch).

Uses a kind of iterator for the input state.

Handles tokenized input (is this still true?).

Packrat behavior (memoizes matches and mismatches for each input position).

The production operators (terminal, construction, alternation etc.)
both construct the grammar element object and define a variable to
hold it.


FIXME:
o tuple rule attribute 'elements' is empty
o Catch EOS in all matching functions

TODO

o Memoization: Idea: When memoizing, do not memoize (store) the result
  for every equivalent parsing state alias item (nonterminal plus
  position) separately.  Instead, define item sets as for LR or Earley
  parsers and memoize results for item sets.
o Memoization: Memoize input substrings, too?

o FIXME: Provide automated regression tests for the test tools (assert
  etc., the validation functions).
o Clean up
  - def3
  - scan
o Memoization: FIXME: Using memoization is currently slower than not doing it
o Memoization: Benchmark without memoization versus with memoization
o Memoization: Find examples for which memoization is faster.
o Memoization: Make it easy to switch off memoization (per parser)
o Factor out common parts of parsing functions.
o Do a serious benchmark
o Allow dashes in XML comments
o Add more regression tests
o Packagize (Parse::, Parse::LL:: or Parse::SiLLy?, Grammar, Utils, Test, Result, Stash)
o Packagize (Parse::SiLLy::Test::Minilang)
o Packagize (Terminal, Construction, Alternation, Optional, NEList, PEList)
o Document how to configure logging (search for $DEBUG)
o Result scanner
o Allow using multiple parsers concurrently
o Parameterize result construction (compile-time option):
  - Inline result construction
  - array interpolation versus array reference

Features Done
o Automated minilang regression tests
o Separate 'minilang' test from XML test.
o Result print function with compact output format
o Memoize parse results and make use of them (Packrat parsing)
o Actually parse the XML input file's content
o Make it possible to switch off memoization
o Avoid calling debugging code (logging functions, data formatting) when debugging is off.
o Avoid checking contracts (assertions etc.) when ASSERT is off.
o Automated XML parsing regression test.
o Compile-time omission of debugging code (default is true).
o Command-line controls for Compile-time options:
  o ASSERT (default is on),
  o DEBUG (default is off),
  o MEMOIZE (default is off).

Internal Features Done
o Parse the hard-coded example string.
o Replace undef by 'not matched' constant
o Avoid array interpolation during result construction.
o Loggers are implemented as arrays.
o Inline result construction
o Compile-time option for MEMOIZATION.
o Uppercase NOMATCH (formerly nomatch) to get rid of inappropriate warnings.
o Unified implementation of nelist_match and pelist_match.
o Shared implementation of nelist_match and pelist_match. 
o Productions are implemented as arrays.
o Parsers (state) are implemented as arrays.
o Automated regression tests for the assert function.

=cut

# --------------------------------------------------------------------
#package Parse::SiLLy;

use strict;
#use warnings;
use diagnostics;
use English;

# --------------------------------------------------------------------
my $INC_BASE;
use File::Basename;
#BEGIN { $INC_BASE= dirname($0); }
#BEGIN { $INC_BASE= dirname(dirname(dirname($0))); }
BEGIN { $INC_BASE= "../.."; }

#push(@INC, "$INC_BASE/Log-Log4perl-0.49/blib/lib");
use lib "${INC_BASE}/Log-Log4perl/blib/lib";
use lib "${INC_BASE}";
use lib "${INC_BASE}/SVStream/lib";

use Log::Log4perl qw(:easy);
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
sub assert($) { if (! $_[0]) { &$assert_action("Assertion failed.\n"); } }

# --------------------------------------------------------------------
# Unit test for 'assert'

sub assert_test($)
{
    my ($log)= @_;
    my $ctx= "assert_test";

    my $flag= 1;
    eval('assert(0 == 0); $flag= 0;');
    my $saved_at_value= $@;
    $log->debug(varstring('@', $saved_at_value));
    if (1 == $flag) {
        die("$ctx: 'assert(0==0); \$flag= 0' failed: flag is now 1,"
            . " but should be 0.\n");
    }
    if ("" ne $saved_at_value) {
        die("$ctx: 'assert(0==0)' failed: \$\@ is not empty,"
            . " but should be empty: '$@'\n");
    }

    eval('assert(0 == 1); $flag= 1;');
    $saved_at_value= $@;
    $log->debug(varstring('@', $saved_at_value));
    if (1 == $flag) {
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
    if ($_[0] ne $_[1]) { &$assert_action("'$_[0]' should be '$_[1]' but is not.\n"); }
}

# --------------------------------------------------------------------
#sub shouldn't($$)
sub shouldnt($$) { # Fix editor's parenthesis matching: }' sub {
    if ($_[0] eq $_[1]) { &$assert_action("'$_[0]' should not be '$_[1]' but is.\n"); }
}

# --------------------------------------------------------------------
# Use this for all evals:
sub eval_or_die($) {
    my $evalue= eval($_[0]);
    if ('' ne $@) { die("eval('$_[0]') failed: '$@'\n"); }
    $evalue;
}

# --------------------------------------------------------------------
sub hash_get($$) {
    my ($hash, $key)= (@_);
    #local $Carp::CarpLevel; ++$Carp::CarpLevel;
    assert(defined($hash)) if ASSERT();
    assert('' ne ref($hash)) if ASSERT();
    #assert("HASH" eq ref($hash)) if ASSERT(); # false if $hash refers to a blessed object
    #assert(defined($key)) if ASSERT();
    assert(exists($hash->{$key})) if ASSERT();
    $hash->{$key};
}

# ====================================================================
package Logger;

use strict;
use diagnostics;
#use English;

::import_from('main', 'assert');
::import_from('main', 'ASSERT');

# Logger objects are implemented as arrays.  Use these constants as
# indices to access their fields (array elements):
use constant LOGGER_NAME   => 0;
use constant LOGGER_DEBUG  => 1;
use constant LOGGER_LOGGER => 2;

# --------------------------------------------------------------------
sub new
{
    my $proto= shift;
    my $class= ref($proto) || $proto;
    #my $self= {};
    my $self= [];
    bless($self, $class);

    my $name= shift;

    #$self->{name}= $name;
    $$self[LOGGER_NAME]= $name;

    #$self->{logger}= Log::Log4perl::get_logger($name)
    $$self[LOGGER_LOGGER]= Log::Log4perl::get_logger($name)
	|| die("$name: Could not get logger.\n");
    #print("$name: Got logger: " . join(', ', keys(%{$self->{logger}})) . "\n");

    #$self->{debugging}= $self->{logger}->is_debug();
    #$$self[LOGGER_DEBUG]= $ {@$self}[LOGGER_LOGGER]->is_debug();
    #$$self[LOGGER_DEBUG]=   ($$self[LOGGER_LOGGER])->is_debug();
    $$self[LOGGER_DEBUG]= $self->get_logger()->is_debug();
    #print("is_debug()=".$self->is_debug()."\n");
    $self->debug("is_debug()=".$self->is_debug()."\n");

    #print("get_logger()->is_debug()=".$self->get_logger()->is_debug()."\n");
    #print("get_logger()->level()=".$self->get_logger()->level()."\n");

    #$self->{logger}->debug("Logger constructed: $name.");
    #($$self[LOGGER_LOGGER])->debug("Logger constructed: $name.");
    $self->debug("Logger constructed: $name.");

    $self;
}

# --------------------------------------------------------------------
sub name($) {
    $ { @{ $_[0]}}[LOGGER_NAME];
}

sub name_explicit($) {
    my ($self)= @_;
    assert(defined($self)) if ASSERT();
    assert('' ne ref($self)) if ASSERT();
    #assert('Logger' eq ref($self)) if ASSERT();
    assert(0 < scalar(@$self)) if ASSERT();
    my $name= $$self[LOGGER_NAME];
    assert(defined($name)) if ASSERT();
    assert('' eq ref($name)) if ASSERT();
}

# --------------------------------------------------------------------
# FIXME: What is the performance impact of returning the current value?

#sub is_debug($) { $_[0]->{logger}->is_debug(); }
#sub is_debug($) { $_[0]->get_logger()->is_debug(); }
#sub is_debug($) { $_[0]->{debugging}; }
#sub is_debug($) { ${@{$_[0]}}[LOGGER_DEBUG]; }
#sub is_debug($) {
#    my $self= $_[0];
#    assert(defined($self)) if ASSERT();
#    assert('' ne ref($self)) if ASSERT();
#    $$self[LOGGER_DEBUG];
#}

sub is_debug($) { $ {@ {$_[0]}}[LOGGER_DEBUG]; }

# --------------------------------------------------------------------
# FIXME: What is the performance impact of the assertions?
# FIXME: What is the performance impact of the binding to $self?

sub get_logger($) {
    #return $ {@ {$_[0]}}[LOGGER_LOGGER];

    my ($self)= (@_);
    #::assert(exists($self->{logger})) if ASSERT();
    ::assert(2 <= $#$self) if ASSERT();
    #my $log= $self->{logger};
    my $log= $$self[LOGGER_LOGGER];
    ::assert(defined($log)) if ASSERT();
    #print(STDERR "ref(log)=".ref($log)."\n");
    ::assert("Log::Log4perl::Logger" eq ref($log)) if ASSERT();
    $log;
}

# --------------------------------------------------------------------
sub info($) {
    my ($self)= (@_);
    my $ctx= $self->name();
    #print("$ctx: @_\n");
    #$self->{logger}->info("$ctx: @_");
    #($$self[LOGGER_LOGGER])->info("$ctx: @_");
    get_logger($self)->info("$ctx: @_");
}

# --------------------------------------------------------------------
sub debug($) {
    # If ! $self->{debugging} return:
    if ( ! $ {@{$_[0]}}[LOGGER_DEBUG]) { return; }

    my ($self)= shift;
    #if ( ! $self->is_debug()) { return; }
    #if ( ! $self->get_logger()->is_debug()) { return; }
    #my $ctx= $$self[LOGGER_NAME];
    my $ctx= $self->name();
    # FIXME: Why don't I use this line?:
    #$self->{logger}->debug("$ctx: @_");
    #($$self[LOGGER_LOGGER])->debug("$ctx: @_");
    #get_logger($self)->debug("$ctx: @_");
    $self->get_logger()->debug("$ctx: @_");
}

# ====================================================================
package main;

use strict;
use diagnostics;
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
use constant PROD_CATEGORY => 0;
use constant PROD_NAME     => 1;
use constant PROD_METHOD   => 2;
use constant PROD_PATTERN  => 3;
use constant PROD_MATCHER  => 4;

# --------------------------------------------------------------------
# If the given reference refers to a named object, returns its name.
# Otherwise returns undef.
sub given_name($) {
    my ($val)= @_;
    assert(defined($val)) if ASSERT();
    if ('' ne ref($val)
        #&& "ARRAY" eq ref($val) # Does not work if $val is blessed
        # FIXME: Decouple logging from parsing packages!:
        && scalar(@$val) >= PROD_NAME() )
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

# --------------------------------------------------------------------
#package Parse::SiLLy::Result::PrintHandler;
package Parse::SiLLy::Result::PrintHandler::Unused;

use strict;
use diagnostics;
#use English;

sub new($$) {
    my ($class, $log)= (@_);
    my $self= { log=>$log };
    $self;
}
sub terminal($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    $self->{log}->info("[$typename '$result->{text}']");
}
sub alternation_begin($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    # FIXME: Do not print newline at the end
    $self->{log}->info("[$typename");
}
sub alternation_end($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    $self->{log}->info("]");
}
sub construction_begin($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    $self->{log}->info("[$typename");
}
sub construction_end($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    $self->{log}->info("]");
}
# FIXME: make this an alias of construction_begin
sub pelist_begin($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    $self->{log}->info("[$typename");
}
sub pelist_end($$$$$) {
    my ($self, $result, $typename, $type, $category)= (@_);
    $self->{log}->info("]");
}

# --------------------------------------------------------------------
package Parse::SiLLy::Result;

use strict;
use diagnostics;
#use English;

::import_from('main', 'assert');
::import_from('main', 'ASSERT');

# --------------------------------------------------------------------
# FIXME: Define these only once:
use constant PROD_CATEGORY  => 0;
use constant PROD_NAME      => 1;
use constant PROD_METHOD    => 2;
use constant PROD_ELEMENTS  => 3;

# --------------------------------------------------------------------
use constant RESULT_PROD => 0;
use constant RESULT_MATCH => 1;

# --------------------------------------------------------------------
sub make_result($$) {
    #return [$_[0] - > {name}, $_[1]];
    my ($t, $match)= (@_);
    assert('ARRAY' eq ref($match)) if ASSERT();
    #[$t->[PROD_NAME], @$match];
    [$t->[PROD_NAME], $match];
}

# --------------------------------------------------------------------
# FIXME: can we use a scalar value here (not a string)?
# FIXME: Bench these:
use constant NOMATCH => 'NOMATCH';
#use constant NOMATCH => \'NOMATCH';

# --------------------------------------------------------------------
sub matched      ($) { NOMATCH() ne $_[0]; }

# --------------------------------------------------------------------
sub matched_with_assert($)
{
    if (ASSERT() && NOMATCH() ne $_[0]) { assert('ARRAY' eq ref($_[0])); }
    NOMATCH() ne ($_[0]);
}

# --------------------------------------------------------------------
sub matched_test() {
    assert( ! matched(NOMATCH()));
}

# --------------------------------------------------------------------
# Formats the given result object as a string

sub toString($$);
sub toString($$)
{
    #return "DUMMY";
    my ($self, $indent)= @_;
    assert(defined($self));
    if ( ! matched($self)) { return $indent.'nomatch'; }
    #'ARRAY' eq ref($self) ||
        #print(::varstring("self", $self)
              #.", ref(\$self)=".ref($self)
              #."\n");
    assert('ARRAY' eq ref($self));

    my $typename= $$self[0];
    assert(defined($typename));
    assert('' eq ref($typename));

    my $type= do { no strict 'refs'; $ {$typename}; };
    #print("tn=$typename\n");
    # FIXME: Introduce predicate 'is_production'
    assert(defined($type));
    assert('' ne ref($type));
    assert($typename eq $type->[PROD_NAME]);

    my $category= $type->[PROD_CATEGORY];
    #print("categ=$category\n");

    my $match= $$self[1];
    if ($category eq "terminal") {
        "[$typename '".quotemeta($$match[0])."']";
    }
    elsif ($category eq "alternation") {
        "[$typename ".toString($$match[0], "$indent ")."]";
    }
    elsif ($category eq "optional") {
        "[$typename ".toString($$match[0], "$indent ")."]";
    }
    else {
        "[$typename\n$indent "
            #. join(",\n$indent ", map { toString($_, "$indent "); } @$self[1..$#$self])
            . join(",\n$indent ", map { toString($_, "$indent "); } @$match)
            #. "$indent]";
            . " ]";
    }
}

# --------------------------------------------------------------------
# Iterates over all elements (matches) in the given parse result
# object, calling the given handler on each one.

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
        map { scan($_, $handler); } @$self[1..$#$self];
        $handler->construction_end  ($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::alternation) {
        $handler->alternation_begin($self, $typename, $type, $category);
        map { scan($_, $handler); } @$self[1..$#$self];
        $handler->alternation_end  ($self, $typename, $type, $category);
    }
    elsif ($category= $Parse::SiLLy::Grammar::optional) {
        $handler->optional($self, $typename, $type, $category);
    }
    else {
        my $elements= $self->[PROD_ELEMENTS];
        $handler->print("[$typename '@$elements']");
    }
}

# ====================================================================
package Parse::SiLLy::Terminal;
use strict; use diagnostics;

sub new($) {
    my $proto= shift;
    my $class= ref($proto) || $proto;
    #my $self= {};
    my $self= [];
    bless($self, $class);
    $self;
}

# ====================================================================
package Parse::SiLLy::Grammar;

use strict;
use diagnostics;
use English;

#use main;
#main::import(qw(assert));
#*assert= \&::assert;
::import_from('main', 'assert');
::import_from('main', 'ASSERT');
::import_from('main', 'vardescr');
::import_from('main', 'varstring');

::import_from('Parse::SiLLy::Result', 'matched');
::import_from('Parse::SiLLy::Result', 'NOMATCH');
::import_from('Parse::SiLLy::Result', 'make_result');

use constant DEBUG =>
    defined($ENV{PARSE_SILLY_DEBUG}) ? $ENV{PARSE_SILLY_DEBUG} : 0;

#BEGIN { $Exporter::Verbose=1 }
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA= qw(Exporter); # Package's ISA
%EXPORT_TAGS= ('all' => [qw(def terminal construction alternation optional nelist pelist)]);
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

# --------------------------------------------------------------------
use constant PROD_CATEGORY  => 0;
use constant PROD_NAME      => 1;
use constant PROD_METHOD    => 2;

use constant PROD_PATTERN   => 3;
use constant PROD_MATCHER   => 4;

use constant PROD_ELEMENTS  => 3;

use constant PROD_ELEMENT   => 3;
use constant PROD_SEPARATOR => 4;

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
        #print("item: $ARG\n");
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
use constant STASHED_END   => 0;
use constant STASHED_MATCH => 1;

# --------------------------------------------------------------------
sub format_stashed($)
{
    my ($stashed)= @_;
    assert(defined($stashed)) if ASSERT();
    if (matched($stashed)) {
        if (ASSERT()) {
            assert('' ne ref($stashed));
            assert('ARRAY' eq ref($stashed));
        }
        #: Parse::SiLLy::Result::toString(\@$stashed[1..$#$stashed], " ")
        #: Parse::SiLLy::Result::toString(@{@$stashed}[1..$#$stashed], " ")
        "[$$stashed[STASHED_END]]"
            . Parse::SiLLy::Result::toString($$stashed[STASHED_MATCH], " ")
            ;
    }
    else {
        #print(STDERR "not matched\n");
        'nomatch';
    }
}

# --------------------------------------------------------------------
sub show_pos_stash($$$)
{
    my ($log, $pos_stash, $pos)= (@_);
    assert(defined($pos_stash));
    assert('HASH' eq ref($pos_stash));
    if ( ! $log->is_debug()) { return; }
    map {
        my $spec= $_;
        #$log->debug("Showing pos_stash for $pos.$spec...");
        #my $elt= $spec;

        # FIXME: This leads to an incomplete error message
        # (get assert to add the stack trace to $@ in this case):
        #$elt= "foo";
        # FIXME: Introduce ->name() accessor
        #my $elt_name= ::hash_get($elt, 'name');
        #my $elt_name= $elt->[PROD_NAME];
        my $elt_name= $spec;
        assert(defined($elt_name));
        assert('' eq ref($elt_name));

        #$log->debug("Showing pos_stash for $pos.$elt_name...");
        my $stashed= $pos_stash->{$spec};
        #$log->debug(varstring('stashed', $stashed));
        $log->debug("stash{$pos, $elt_name}=" . format_stashed($stashed));
    } sort({$a <=> $b} keys(%$pos_stash));
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
    map {
        my $pos= $_;
        #$log->debug("Showing stash for pos $pos...");
        show_pos_stash($log, $stash->{$pos}, $pos);
    } sort({$a <=> $b} keys(%$stash));
}

# --------------------------------------------------------------------
use constant STATE_INPUT => 0;
use constant STATE_POS => 1;
use constant STATE_STASH => 2;
use constant STATE_POS_STASH => 3;

# --------------------------------------------------------------------
# FIXME: Packagize, objectify
sub Parser_new($) {
    my ($input)= @_;
    [$input, 0, {}, undef]; # input, pos, stash, pos_stash
}

# --------------------------------------------------------------------
sub input_show_state($$) {
    my ($log, $state)= (@_);
    if ( ! $log->is_debug()) { return; }
    $log->debug(varstring('state->pos', $state->[STATE_POS]));
}

# --------------------------------------------------------------------
sub match_check_preconditions($$) {
    my ($log, $t)= (@_);
    assert(defined($log)) if ASSERT();
    assert(defined($t)) if ASSERT();
    assert('' ne ref($t)) if ASSERT();
    #assert("HASH" eq ref($t)) if ASSERT();
    #assert(exists($t->{name})) if ASSERT();
    if (ASSERT()) {
        assert(scalar(@$t) >= PROD_MATCHER());
    }
}

# --------------------------------------------------------------------
sub match_watch_args($$$) {
    my ($ctx, $log, $state)= (@_);
    assert(defined($ctx)) if ASSERT();
    my $pos= $state->[STATE_POS];
    $log->debug("$ctx: state->pos=$pos");
    # FIXME: Use a faster method to access the parser state (array)
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
    #assert("HASH" eq ref($log));
    if ($log_val) {
        #assert(defined($val));
        #assert('' ne ref($val));
        #$log->debug("Type='$val->{_}':");
        $log->debug(varstring('val',$val));
    }
}

# --------------------------------------------------------------------
sub eoi($$) {
    my ($input, $pos)= (@_);
    assert(defined($input)) if ASSERT();
    if ('' eq ref($input)) { return (length($input)-1 < $pos); }
    assert("ARRAY" eq ref($input)) if ASSERT();
    $#{@$input} < $pos;
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

    # Set this production's category
    assert(defined($category));
    assert('' eq ref($category));
    my $method= $methods{$category};
    assert(defined($method));
    assert('' ne ref($method));

    $val->[PROD_CATEGORY]= $category;
    $val->[PROD_METHOD] = $method;

    # Determine full variable name
    assert(defined($name));
    assert('' eq ref($name));
    #my $fullname= "::$name";
    #my ($caller_package, $file, $line)= caller();
    my $fullname= "${caller_package}::$name";
    $log->debug("Defining '$fullname'...");
    $val->[PROD_NAME]= $fullname;

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
    my $matcher= eval("sub { \$_[0] =~ m{^($pattern)}og; }");

    def($log, 'terminal', $name,
        [ undef, undef, undef, $pattern, $matcher ],
        caller());
}

# --------------------------------------------------------------------
my $terminal_match_log;
# --------------------------------------------------------------------
sub terminal_match($$)
{
    my $log= $terminal_match_log;
    my ($t, $state)= @ARG;
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());;
    
    my $input= $state->[STATE_INPUT];
    my $pos= $state->[STATE_POS];
    #my ($match)= $input =~ m{^$t->[PROD_PATTERN]}g;
    my $match;
    #$log->debug("$ctx: ref(input)=" . ref($input) . ".");
    if (eoi($input, $pos)) {
	if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: End Of Input reached"); }
	return (NOMATCH());
    }
    if ('ARRAY' eq ref($input)) {
	if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: state->pos=$state->[STATE_POS],"
                        . " input[0]->name=", $ {@$input}[0]->[PROD_NAME]);
        }
	#if ($#{@$input} < $pos) {
	#    if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: End of input reached");}
	#    return (NOMATCH());
	#}
	$match= $ {@$input}[$pos];
	if ($t == $match->[PROD_CATEGORY]) {
            if (DEBUG() && $log->is_debug()) {
                #$log->debug("$ctx: matched token: " . varstring('match', $match));
                $log->debug("$ctx: matched token: $ctx, text: '$match->[RESULT_MATCH()]'");
            }
	    my $result= $match;
	    $state->[STATE_POS]= $pos + 1;
            if (DEBUG() && $log->is_debug()) {
                #$log->debug(varstring('state', $state));
                $log->debug("$ctx: state->pos=$state->[STATE_POS]");
            }
	    return ($result);
	} else {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: token not matched: '$ctx'");
            }
	    return (NOMATCH());
	}
    } else {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: state->pos=$state->[STATE_POS],"
                        . " substr(input, pos)='"
                        . quotemeta(substr($input, $pos))."'");
        }
	#if (length($input)-1 < $pos) {
	#    if (DEBUG() && $log->is_debug()) {$log->debug("$ctx: End Of Input reached");}
	#    return (NOMATCH());
	#}
        my $pattern= $t->[PROD_PATTERN];
        if (ASSERT()) {
            assert(defined($pattern));
            assert('' eq ref($pattern));
        }

        # FIXME: Can we avoid repeated construction or copying of the
        # same substring?  Looks like momoization does just that.
        # FIXME: Can we avoid substring construction or copying at all?
	#($match)= substr($input, $pos) =~ m{^($pattern)}g;
        my $matcher= $t->[PROD_MATCHER];
	($match)= &{$matcher} (substr($input, $pos));

        if (defined($match)) {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: matched text: '".quotemeta($match)."'");
            }
            #my $result= {_=>$t, text=>$match};
	    #my $result= make_result($t, [$match]);
	    my $result= [$t->[PROD_NAME], [$match]];
	    $state->[STATE_POS]= $pos += length($match);
            # Move this to match_with_memoize?
            if (MEMOIZE()) {
                $state->[STATE_POS_STASH]=
                    stash_get_pos_stash($state->[STATE_STASH()], $pos);
            }
	    if (DEBUG() && $log->is_debug()) {
                #$log->debug(varstring('state', $state));
                $log->debug("$ctx: state->pos=$state->[STATE_POS]");
            }
	    $result;
	} else {
	    if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: pattern not matched: '"
                            . quotemeta($t->[PROD_PATTERN])."'");
            }
	    NOMATCH();
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
                 [ undef, undef, undef, grammar_objects($caller_package, \@ARG)],
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
    my $ctx= $t->[PROD_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());;
    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: [ Trying to match...");
        #$log->debug(varstring('result_elements', $result_elements));
    }

    my $result_elements= [];
    my $saved_pos= $state->[STATE_POS];

    # foreach $element in $t's elements
    map {
	my $i= $_;
	#if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: i=$i"); }
	my $element= $ {@{$t->[PROD_ELEMENTS]}}[$i];
        my $element_name= $element->[PROD_NAME];
        if (DEBUG() && $log->is_debug()) {
            #$log->debug(varstring('element', $element));
            $log->debug("$ctx: [ Trying to match element[$i]: $element_name");
        }
	my ($match)= match($element, $state);
	#if ( ! matched($match))
	if (NOMATCH() eq $match)
        {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: element[$i] not matched: $element_name"
                            . " (giving up on '$ctx')\]\]");
            }

	    # Q: Why is this currently the only place where
	    # backtracking must be performed? A: Because this is the
	    # only place where a failure may occur after pos has been
	    # already moved.

	    $state->[STATE_POS]= $saved_pos;
            if (MEMOIZE()) {
                $state->[STATE_POS_STASH]= stash_get_pos_stash($state->[STATE_STASH], $saved_pos);
            }
	    return (NOMATCH());
	}
        if (DEBUG() && $log->is_debug()) {
            #$log->debug("$ctx: Matched element: " . varstring($i,$element)."\]");
            $log->debug("$ctx: Matched element[$i]: $element_name ]");
            #$log->debug("$ctx: element value: " . varstring('match', $match));
        }
	push(@$result_elements, $match);
    } (0 .. $#{@{$t->[PROD_ELEMENTS]}});

    if (DEBUG() && $log->is_debug()) {
        $log->debug("$ctx: matched: '$ctx']");
        #$log->debug(varstring('result_elements', $result_elements));
    }
    #$result_elements;
    #{_=>$ctx, elements=>$result_elements};
    #make_result($t, $result_elements);
    [$t->[PROD_NAME], $result_elements];
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
                 [ undef, undef, undef, grammar_objects($caller_package, \@ARG)],
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
    my ($t, $state)= @ARG;
    # Q: Move argument logging to 'match'?
    # A: No, then we can not control logging locally.
    match_check_preconditions($log, $t) if ASSERT();
    my $ctx= $t->[PROD_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());;

    # The only matching function that potentially consumes 'input' is
    # terminal_match.  Therefore terminal_match is the only place
    # where we must check for EOI (end of input).

    # FIXME: However, it may still be beneficial to check for EOI
    # here?

    my $elements= $t->[PROD_ELEMENTS];
    # foreach $element in $elements
    map {
	my $i= $_;
	#if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: i=$i"); }
        # FIXME: shouldn't this be '$elements[$i]'?:
	#my $element= $$elements[$i];
	my $element= $ {@$elements}[$i];
        my $element_name= $element->[PROD_NAME];
        if (DEBUG() && $log->is_debug()) {
            #$log->debug(varstring('element', $element));
            $log->debug("$ctx: [ Trying to match element[$i]: $element_name");
        }
	my ($match)= match($element, $state);
	#if (matched($match))
	if (NOMATCH() ne $match)
        {
            if (DEBUG() && $log->is_debug()) {
                #$log->debug("$ctx: matched element: " . varstring($i, $element)."\]");
                $log->debug("$ctx: Matched element[$i]: $element_name\]");
                #$log->debug("$ctx: matched value: " . varstring('match', $match));
                $log->debug("$ctx: match result: "
                            . Parse::SiLLy::Result::toString($match, " "));
            }
	    #return ($match);
	    #return (make_result($t, [$match]));
	    return [$t->[PROD_NAME], [$match]];
	}
        if (DEBUG() && $log->is_debug()) {
            $log->debug("$ctx: element[$i] not matched: '$element_name']");
        }
    } (0 .. $#{@$elements});

    if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: not matched: '$ctx'"); }
    NOMATCH();
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
                 # FIXME: Either pass category and name in the array
                 # argument, or pass a shorter array:
                 [ undef, undef, undef, grammar_object($caller_package, $ARG[0])],
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
    my $ctx= $t->[PROD_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());;

    my $element= $t->[PROD_ELEMENT];
    my $element_name= $element->[PROD_NAME];
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('element', $element));
        $log->debug("$ctx: element=$element_name");
    }

    my ($match)= match($element, $state);
    #if (matched($match))
    if (NOMATCH() ne $match)
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
    if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: not matched: '$ctx'"); }
    #'';
    [$t->[PROD_NAME], [$match]];
}

# --------------------------------------------------------------------
sub list_new($$$$$$)
{
    my ($log, $category, $name, $element, $separator, $caller_package)= @_;
    log_cargs($log, $name, \@ARG);
    my $val= def($log, $category, $name,
                 [ undef, undef, undef,
                   grammar_object($caller_package, $element),
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
    my $ctx= $t->[PROD_NAME];
    match_watch_args($ctx, $log, $state) if (DEBUG() && $log->is_debug());;
    my $element=   $t->[PROD_ELEMENT];
    my $separator= $t->[PROD_SEPARATOR];
    my $element_name=   $element->[PROD_NAME];
    my $separator_name= $separator->[PROD_NAME];

    #my $result= [];
    #my $result= {_=>$ctx, elements=>[]};
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
	#if ( ! matched($match))
	if (NOMATCH() eq $match)
        {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: Element not matched: '$element_name'\]");
            }
	    if ($n_min > scalar(@$result_elements)) {
                if (DEBUG() && $log->is_debug()) { $log->debug("$ctx: ...not matched.\]");}
                return (NOMATCH());
            }
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.\]");
            }
            #return ($result);
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
	#if ( ! matched($match))
	if (NOMATCH() eq $match)
        {
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: Separator not matched: '$separator_name'\]");
            }
            if (DEBUG() && $log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.\]");
            }
            #return ($result);
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
        my $pos_stash= {};
        #tie %$pos_stash, 'Tie::RefHash';
        return ($stash->{$pos}= $pos_stash);
    }
    my $pos_stash= $stash->{$pos};
    assert(defined($pos_stash)) if ASSERT();
    assert('' ne ref($pos_stash)) if ASSERT();
    $pos_stash;
}

# --------------------------------------------------------------------
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
        return ($stash->{$pos}= {});
    }
    $stash->{$pos};
}

# --------------------------------------------------------------------
sub match_with_memoize($$)
{
    my $log= $match_log;
    my ($t, $state)= @ARG;
    if (ASSERT()) {
        assert(defined($t));
        assert('' ne ref($t));

        assert(defined($state));
        assert('' ne ref($state));

        #assert(exists($state->[STATE_POS]));
    }

    my $pos= $state->[STATE_POS];
    if (ASSERT()) {
        assert(defined($pos));
        assert('' eq ref($pos));
    }

    # FIXME: Consider implementing the pos_stashes as arrays.  This
    # may need to map productions to indices, though.  This can be
    # hard when combining grammars.

    my $pos_stash_key= $t->[PROD_NAME];

    my $stash= $state->[STATE_STASH];
    my $pos_stash= stash_get_pos_stash($stash, $pos);
    #my $pos_stash= $stash->{$pos};
    # FIXME: Activate:
    #my $pos_stash= $state->[STATE_POS_STASH];
    if ( ! defined($pos_stash)) {
        if (DEBUG() && $log->is_debug()) {
            $log->debug("New position $pos, creating pos stash for it...");
        }
        $state->[STATE_POS_STASH]= $pos_stash= $stash->{$pos}= {};
    }
    if (exists($pos_stash->{$pos_stash_key}))
    {
        my $stashed= $pos_stash->{$pos_stash_key};
        assert(defined($stashed)) if ASSERT();
        if (DEBUG() && $log->is_debug()) {
            $log->debug("Found in stash: ".format_stashed($stashed));
        }
        if (NOMATCH() ne $stashed)
        {
            assert('ARRAY' eq ref($stashed)) if ASSERT();
            $state->[STATE_POS]= $$stashed[STASHED_END];
            return ($$stashed[STASHED_MATCH]);
        }
        else {
            return (NOMATCH());
        }
    }

    my $method= $t->[PROD_METHOD];
    my $result= &$method($t, $state);

    if (ASSERT()) {
        #assert(matched($result) || $state->[STATE_POS] == $pos);
        assert((NOMATCH() ne $result) || $state->[STATE_POS] == $pos);
    }

    #my $stashed= matched($result) ? [$state->[STATE_POS], $result] : NOMATCH();
    my $stashed= (NOMATCH() ne $result) ? [$state->[STATE_POS], $result] : NOMATCH();
    if (DEBUG() && $log->is_debug()) {
        $log->debug("Storing result in stash for ${pos}->{$pos_stash_key}"
                    . ($pos_stash_key ne $t->[PROD_NAME] ? " ($t->[PROD_NAME])" : "")
                    . ": "
                    #. varstring('result', $result)
                    # FIXME: use OO syntax here: $result->toString()
                    . "\$result ="
                    . Parse::SiLLy::Result::toString($result, " ")
                    );
        #$log->debug(varstring("stashed", $stashed));
    }
    $pos_stash->{$pos_stash_key}= $stashed;

    # Used this to find out that the $t used above as a hash key
    # was internally (in the hash table) converted to a string.
    #if (DEBUG() && $log->is_debug()) {
    #    map { $log->debug("key $_ has ref ".ref($_)); } keys(%$pos_stash);
    #}
    # Used Tie::RefHash to get around that.  Another way might be
    # to use $t's name as the key.
    #map { assert('HASH' eq ref($_)); } keys(%$pos_stash);
    # FIXME: is this slow?:
    #map { ::should('HASH', ref($_)); } keys(%$pos_stash);

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
    if (MEMOIZE()) { return match_with_memoize($t, $state); }
    my $method= $t->[PROD_METHOD];
    &$method($t, $state);
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
         'nelist'       => \&nelist_match,
         'pelist'       => \&pelist_match);
    #$match_log->info(varstring('methods', \%methods));

    Parse::SiLLy::Result::matched_test();
}

# ====================================================================
package main;

use strict;
use diagnostics;
#use English;

# --------------------------------------------------------------------
sub handle_item
{
    printf("$ARG");
}

# --------------------------------------------------------------------
my $main_log;

# --------------------------------------------------------------------
sub init()
{
    #Log::Log4perl->easy_init($INFO);
    #Log::Log4perl->easy_init($DEBUG);
    Log::Log4perl->easy_init(Parse::SiLLy::Grammar::DEBUG() ? $DEBUG : $INFO);
    #$logger= get_logger();
    #$logger->info("Running...");
    #if (scalar(@_) > 0) { info(vdump('Args', \@_)); }
    $Data::Dumper::Indent= 1;

    $main_log= Logger->new('main');
    assert_test($main_log);

    Parse::SiLLy::Grammar::init();
}

# --------------------------------------------------------------------
sub elements($) {
    #return $ {@{$_[0]}}[1];
    my $result= $_[0];
    my $elements= $$result[1];

    # Various other attempts:
    #my $elements= $ {@$result}[1];
    #my $elements= \@{@$result}[1..$#$result];
    # FIXME: Implicit scalar context for array in block:
    #my $elements= \@$result[1..$#{@$result}];

    #my @elements= @$result[1, -1];
    #my @elements= @{@$result}[1..$#$result];
    #if (DEBUG() && $log->is_debug()) {
    #    $log->debug(varstring('@elements', \@elements));
    #}
    #my $elements= \@elements;

    #if (DEBUG() && $log->is_debug()) {
    #    $log->debug(varstring('elements', $elements));
    #}
    assert(defined($elements));
    assert('ARRAY' eq ref($elements));
    $elements;
}

# --------------------------------------------------------------------
sub check_result($$$) {
    my ($result, $expected_typename, $expected_text)= (@_);
    assert(defined($result));
    #assert(Parse::SiLLy::Grammar::matched($result));
    assert('ARRAY' eq ref($result));
    #print(varstring('result', $result)."\n");
    #print('$result='.Parse::SiLLy::Result::toString($result)."\n");
    assert(2 <= scalar(@$result));
    assert(defined($expected_typename));
    assert(defined($expected_text));
    #$main_log->debug(varstring('result', $result));

    #my $actual_type= ::hash_get($result, '_');
    #my $actual_type= $$result[0];
    #my $actual_typename= ::hash_get($actual_type, 'name');
    my $actual_typename= $$result[0];
    should($actual_typename, $expected_typename);

    my $result_elements= elements($result);
    assert(defined($result_elements));
    assert('ARRAY' eq ref($result_elements));

    #my $actual_text= ::hash_get($result, "text");
    #my $actual_text= $$result[1];
    #my $actual_text= @{ $$result[1]}[0];
    my $actual_text= $$result_elements[0];
    #should($actual_text,     $expected_text);

    $main_log->debug(varstring("expected_text", $expected_text));
    $main_log->debug(varstring("actual_text", $actual_text));
    assert(Sump::Validate::Compare($actual_text,     $expected_text));

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
    my $call= "Parse::SiLLy::Grammar::$matcher(\$$element, \$state)";
    $log->debug("eval('$call')...");
    my $result= eval($call);
    # FIXME: Treat all evals like this?:
    #my $errors= $@;
    #if (defined($@)) { die("eval('$call') failed: '$@'\n"); }
    if ('' ne $@) { die("eval('$call') failed: '$@'\n"); }

    assert(defined($result));
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring("$matcher $element result", $result));
        $log->debug("$matcher $element result = "
                    . Parse::SiLLy::Result::toString($result, " "));
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    #should($result->{_}->{_}, $matcher);
    #should($result->{_}->{name}, $element);
    #should($result->{text}, $expected);
    check_result($result, $element, $expected);
}

# --------------------------------------------------------------------
sub test_minilang()
{
    my $log= $main_log;
    my $state;
    my $result;

    my $grammar= "Test/minilang-grammar.pl";
    $log->debug("--- Reading '$grammar'...");
    require $grammar;

    $log->debug("--- Testing terminal_match...");
    $state= Parse::SiLLy::Grammar::Parser_new('blah 123  456');

    test1($log, "terminal_match", "minilang::Name",       $state, "blah");
    test1($log, "terminal_match", "minilang::Whitespace", $state, " ");
    test1($log, "terminal_match", "minilang::Number",     $state, "123");
    test1($log, "terminal_match", "minilang::Whitespace", $state, "  ");
    test1($log, "terminal_match", "minilang::Number",     $state, "456");

    $log->debug("--- Testing alternation_match...");
    $state= Parse::SiLLy::Grammar::Parser_new('blah 123');
    test1($log, "alternation_match", "minilang::Token",
          $state, ['minilang::Name', ['blah']]);
    test1($log, "match",             "minilang::Whitespace",
          $state, " ");
    test1($log, "match",             "minilang::Token",
          $state, ['minilang::Number', [123]]);

    $log->debug("--- Testing tokenization 1...");
    $state= Parse::SiLLy::Grammar::Parser_new('blah "123"  456');

    $result= Parse::SiLLy::Grammar::match($minilang::Tokenlist, $state);
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('match minilang::Tokenlist result 1', $result));
        $log->debug("match minilang::Tokenlist result 1='"
                    . Parse::SiLLy::Result::toString($result, " ")
                    . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    #my $expected= ['Tokenlist',
    #               ['Token', ['Name', 'blah']],
    #               ['Token', ['String', '"123"']],
    #               ['Token', ['Number', '456']],
    #               ];
    #my $expected= ['minilang::Tokenlist',
    #               ['minilang::Token', ['minilang::Name', 'blah']],
    #               ['minilang::Token', ['minilang::String', '"123"']],
    #               ['minilang::Token', ['minilang::Number', '456']],
    #               ];
    my $expected= ['minilang::Tokenlist', [
                   ['minilang::Token', [ ['minilang::Name',   ['blah' ]] ]],
                   ['minilang::Token', [ ['minilang::String', ['"123"']] ]],
                   ['minilang::Token', [ ['minilang::Number', ['456'  ]] ]],
                   ] ];
    #use FreezeThaw;
    #assert(0 == strCmp($result, $expected));
    use lib "../SVStream/lib"; # SVStream::Utils
    use lib ".."; # Sump::Validate
    use Sump::Validate;
    assert(Sump::Validate::Compare($result, $expected));
    #Sump::Validate($result, $expected);

    my $result_elements= elements($result);
    #check_result($$result_elements[0], 'Name', 'blah');
    #check_result($$result_elements[1], 'String', '"123"');
    #check_result($$result_elements[2], 'Number', '456');


    $log->debug("--- Testing tokenization 2...");
    #$state= Parse::SiLLy::Grammar::Parser_new('blah ("123", xyz(456 * 2)); end;');
    $state= Parse::SiLLy::Grammar::Parser_new('blah.("123", xyz.(456.*.2)); end;');
    #                   0         1         2         3
    #                   0....5....0....5..8.0....5....0.2

    $result= Parse::SiLLy::Grammar::match($minilang::Tokenlist, $state);
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('match minilang::Tokenlist result 2', $result));
        $log->debug("match minilang::Tokenlist result 2='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);

    assert(1 < scalar(@$result));
    $result_elements= elements($result);
    if (DEBUG() && $log->is_debug()) {
        $log->debug(varstring('result_elements', $result_elements));
    }

    # FIXME: When we always pass an expected result object,
    # check_result needs only two args.

    check_result($$result_elements[0], 'minilang::Token',
                 ['minilang::Name', ['blah']]
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
    $expected= ['minilang::Tokenlist', $expected_tokens];
    if (DEBUG() && $log->is_debug()) {
        $log->debug('expected_tokens formatted as result: '
                    #. Parse::SiLLy::Result::toString($expected_tokens, " ")
                    . Parse::SiLLy::Result::toString($expected, " ")
                    );
        $log->debug(varstring('expected_tokens', $expected_tokens));
    }
    map {
        my ($expected_result)= $_;
        if (DEBUG() && $log->is_debug()) {
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
    #@$expected;
    @$expected_tokens;
    Sump::Validate::Compare($expected, $result);

    $log->debug("--- Testing Program...");
    $log->debug("Program=$minilang::Program.");
    # FIXME: Get this (two-stage parsing) to work:
    #$state= Parse::SiLLy::Grammar::Parser_new($result);
    $state->[Parse::SiLLy::Grammar::STATE_POS()]= 0;

    # FIXME: Get this test to work
    $result= Parse::SiLLy::Grammar::match($minilang::Program, $state);
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('match minilang::Program result', $result));
        $log->debug("match minilang::Program result='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
=ignore

    $expected=
    ['minilang::Program',
     ['minilang::Mchain',
      ['minilang::LTerm', ['minilang::Name', 'blah']],
      ['minilang::Period',    '.'],
      ['minilang::LTerm',
       ['minilang::Tuple',
        ['minilang::Lparen',    '('],
        ['minilang::Exprlist',
         ['minilang::Mchain',
          ['minilang::LTerm',
           ['minilang::Literal', ['minilang::String', '"123"']]],
          ],
         ['minilang::Comma',     ','],
         ['minilang::Mchain',
          ['minilang::LTerm', ['minilang::Name', 'xyz']],
          ['minilang::Period',    '.'],
          ['minilang::LTerm',
           ['minilang::Tuple',
            ['minilang::Lparen',    '('],
            ['minilang::Exprlist',
             ['minilang::Mchain',
              ['minilang::LTerm',
               ['minilang::Literal', ['minilang::Number', 456]]],
              ['minilang::Period',    '.'],
              ['minilang::LTerm', ['minilang::Name', '*']],
              ['minilang::Period',    '.'],
              ['minilang::LTerm',
               ['minilang::Literal', ['minilang::Number', 2]]],
              ]],
            ['minilang::Rparen', ')'],
            ]]]],
        ['minilang::Rparen', ')'],
        ],
       ], # Term
      ], # Mchain
     ['minilang::Semicolon', ';'],
     ['minilang::Mchain',
      ['minilang::LTerm', ['minilang::Name', 'end']],
      ],
     ['minilang::Semicolon', ';'],
     ];

=cut

    $expected=
    ['Program',
     ['Mchain',
      ['LTerm', ['Name', 'blah']],
      ['Period',    '.'],
      ['LTerm', ['Tuple',
        ['Lparen',    '('],
        ['Exprlist',
         ['Mchain',
          ['LTerm', ['Literal', ['String', '"123"']]],
          ],
         ['Comma',     ','],
         ['Mchain',
          ['LTerm', ['Name', 'xyz']],
          ['Period',    '.'],
          ['LTerm', ['Tuple',
            ['Lparen',    '('],
            ['Exprlist',
             ['Mchain',
              ['LTerm', ['Literal', ['Number', 456]]],
              ['Period',    '.'],
              ['LTerm', ['Name', '*']],
              ['Period',    '.'],
              ['LTerm', ['Literal', ['Number', 2]]],
              ]],
            ['Rparen', ')'],
            ]]]],
        ['Rparen', ')'],
        ],
       ], # Term
      ], # Mchain
     ['Semicolon', ';'],
     ['Mchain',
      ['LTerm', ['Name', 'end']],
      ],
     ['Semicolon', ';'],
     ];
    my $f;
    $f= sub {
        my ($name, @elts)= (@_);
        ["minilang::$name",
         ('' eq ref($elts[0]) ? \@elts : [(map { &{$f}(@$_)} @elts)]),
         ];
    };
    $expected= &$f(@$expected);

    Sump::Validate::Compare($expected, $result);
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

    $state= Parse::SiLLy::Grammar::Parser_new($xml);

    #$result= Parse::SiLLy::Grammar::match($Parse::SiLLy::Test::XML::Elem,
    #                                      $state);
    #if (DEBUG() && $log->is_debug()) {
    #    $log->debug(varstring('match XML::Elem result', $result));
    #}
    #Parse::SiLLy::Grammar::input_show_state($log, $state);
    #check_result($result, 'Elem', $state->[STATE_INPUT]);

    {
    #my $top= "Parse::SiLLy::Test::XML::Elem";
    #my $top= "Parse::SiLLy::Test::XML::Contentlist";
    my $top_name= "Parse::SiLLy::Test::XML::Contentlist";
    # FIXME: Why does this not work?:
    #no strict 'refs';
    #my $top= ${$top_name}; assert(defined($top));
    #$result= Parse::SiLLy::Grammar::match($top, $state);
    # Avoid warning 'Used only once':
    my $top= $Parse::SiLLy::Test::XML::Contentlist
           = $Parse::SiLLy::Test::XML::Contentlist;
    $result= Parse::SiLLy::Grammar::match($top, $state);
    if (DEBUG() && $log->is_debug()) {
        #$log->debug(varstring('match $top result', $result));
        $log->debug("match $top result='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);

    # FIXME: Unify this with the code in test_minilang:
    # Decorates (qualifies) the names in the given 'expected' spec
    my $f;
    $f= sub {
        my ($name, @elts)= (@_);
        ["Parse::SiLLy::Test::XML::$name",
         (
          'ARRAY' eq ref($elts[0]) ? [(map { &$f(@$_)} @elts)]
          #: '' eq ref($elts[0]) ? \@elts
          #: 'STRING' eq ref($elts[0]) ? \@elts
          #'ERROR'
          : \@elts
          )
         ];
    };
    no strict 'subs';
    my $expected=
  [Contentelem, [Complexelem,
    [Ltag, [Langle, '<'], [Owhite, NOMATCH], [Tagname, 'tr'], [Oattrs, NOMATCH], [Owhite, NOMATCH], [Rangle, '>']],
    [Contentlist,
     [Contentelem, [Cdata, '
 ']],
     [Contentelem, [Complexelem,
       [Ltag, [Langle, '<'], [Owhite, NOMATCH], [Tagname, 'td'], [Oattrs, NOMATCH], [Owhite, NOMATCH], [Rangle, '>']],
       [Contentlist, [Contentelem, [Cdata, 'Contents']]],
       [Rtag, [Langle, '<'], [Slash, '/'], [Owhite, NOMATCH], [Tagname, 'td'], [Owhite, NOMATCH], [Rangle, '>']] ]],
     [Contentelem, [Complexelem,
       [Ltag, [Langle, '<'], [Owhite, NOMATCH], [Tagname, 'td'], [Oattrs, NOMATCH], [Owhite, NOMATCH], [Rangle, '>']],
       [Contentlist, [Contentelem, [Cdata, 'Foo Bar']]],
       [Rtag, [Langle, '<'], [Slash, '/'], [Owhite, NOMATCH], [Tagname, 'td'], [Owhite, NOMATCH], [Rangle, '>']] ]],
     [Contentelem, [Complexelem,
       [Ltag, [Langle, '<'], [Owhite, NOMATCH], [Tagname, 'td'], [Oattrs, NOMATCH], [Owhite, NOMATCH], [Rangle, '>']],
       [Contentlist,  ],
       [Rtag, [Langle, '<'], [Slash, '/'], [Owhite, NOMATCH], [Tagname, 'td'], [Owhite, NOMATCH], [Rangle, '>']] ]]
     ],
    [Rtag, [Langle, '<'], [Slash, '/'], [Owhite, NOMATCH], [Tagname, 'tr'], [Owhite, NOMATCH], [Rangle, '>']]
    ]];
    use strict 'subs';

    #$log->info(varstring('expected before decorating', $expected));
    $expected= &$f(@$expected);
    $log->debug(varstring('expected', $expected));
    #$log->info(varstring('expected', $expected));
    $log->debug('expected formatted as result: '.Parse::SiLLy::Result::toString($expected, " "));
    check_result($result, $top_name, $expected);
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
sub read_data_old {
    $INPUT_RECORD_SEPARATOR= "---";
    while (<INPUT>)
    {
        #if (DEBUG() && $log->is_debug()) { $log->debug("item=\"$ARG\";"); }
        handle_item($ARG);
    }
    $INPUT_RECORD_SEPARATOR= "";
}

# --------------------------------------------------------------------
sub do_one_run($$) {
    my ($state, $top)= @_;
    if (Parse::SiLLy::Grammar::MEMOIZE()) {
        #delete($state->{stash});
        $state->[Parse::SiLLy::Grammar::STATE_STASH()]= {};
    }
    $state->[Parse::SiLLy::Grammar::STATE_POS()]= 0;
    no strict 'refs';
    Parse::SiLLy::Grammar::match($ {"$top"}, $state);
}

# --------------------------------------------------------------------
sub do_runs($$$) {
    my ($n, $state, $top)= @_;
    for (my $i= 0; $i<$n; ++$i) { do_one_run($state, $top); }
}

# --------------------------------------------------------------------
sub main
{
    init();
    my $log= $main_log;
    
    # Test 'def'
    #Parse::SiLLy::Grammar::def 'foo', {elt=>'bar'};
    Parse::SiLLy::Grammar::def($log, 'terminal', 'foo',
                               ['dummy1', 'dummy2', 'bar'],
                               'main');
    $log->debug(varstring('::foo', $::foo));
    #assert($::foo->{elt} eq 'bar');

    # Run self-tests
    test_minilang();
    test_xml();

    (1 == $#ARG) or die($usage);

    $log->debug("---Reading and Evaluating grammar...");
    my $grammar_filename= shift();
=ignore

    open(GRAMMAR, "< $grammar_filename")
        or die("Can't open grammar file \`$grammar_filename'.");
    $INPUT_RECORD_SEPARATOR= undef;
    my $grammar= <GRAMMAR>;
    $INPUT_RECORD_SEPARATOR= "";
    close(GRAMMAR);
    #$log->debug("grammar='$grammar'");

=cut

    #eval($grammar);
    #use $grammar_filename;
    require $grammar_filename;
    #$log->debug(varstring('exprlist', $::exprlist));
    $log->debug("Grammar evaluated.");

    $log->debug("---Reading input file...");
    my $input= shift();
    open(INPUT, "< $input") or die("Can't open \`$input'.");
    #read_data_old();
    my $input_data= read_INPUT_IRS();
    close(INPUT);

    $log->debug("input:\n$input_data");
    
    {
    my $state= Parse::SiLLy::Grammar::Parser_new($input_data);
    my $top= "Parse::SiLLy::Test::XML::Contentlist";
    my $result;
    #$result= Parse::SiLLy::Grammar::match($::Elem, $state);
    no strict 'refs';
    # FIXME: Why does the first run fail?
    $result= Parse::SiLLy::Grammar::match($ {"$top"}, $state);
    #$result= do_one_run($state, $top);
    #$result= do_runs(100, $state, $top);

    #sleep(1);
    use Benchmark;
    #timethis(1, sub { $result= Parse::SiLLy::Grammar::match($ {"$top"}, $state); } );
    #timethis(1, sub { $result= do_one_run($state, $top); } );
    timethis(1, sub { $result= do_one_run($state, $top); } );
    # First arg -N means repeat for at least N seconds.
    timethis(-2, sub { $result= do_one_run($state, $top); } );

    if (DEBUG() && $log->is_debug()) {
        $log->debug(varstring('match $top result', $result));
        #$log->debug(varstring('state', $state));
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    if (Parse::SiLLy::Grammar::MEMOIZE()) {
        Parse::SiLLy::Grammar::show_stash(
            $log, $state->[Parse::SiLLy::Grammar::STATE_STASH()] );
    }
    #print(Parse::SiLLy::Result::toString($result, " ")."\n");
    }
}

# --------------------------------------------------------------------
main(@ARGV);

# --------------------------------------------------------------------
# EOF
