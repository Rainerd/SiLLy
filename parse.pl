#!/usr/bin/perl -w
# --------------------------------------------------------------------
# Usage: perl PROGRAM GRAMMAR INPUT > OUTPUT
# Example: perl          parse.pl Test/xml-grammar.pl Test/XML/example.xml
# Profile: perl -w -d:DProf parse.pl Test/xml-grammar.pl Test/XML/example.xml; dprofpp
# Lint: perl -w -MO=Lint,-context parse.pl Test/xml-grammar.pl Test/XML/example.xml

# --------------------------------------------------------------------
=ignore

Copyright (c) 2004-2006 by Rainer Blome

Copying and usage conditions for this document are specified by
Rainer's Open License, Version 1, in file LICENSE.txt.

In short, you may use or copy this document as long as you:
o Keep this copyright and permission notice.
o Use it ,,as is``, at your own risk -- there is NO WARRANTY WHATSOEVER.
o Do not use my name in advertising.
o Allow free copying of derivatives.


Purpose

Parses, according to the given grammar, the given input. Produces an
appropriately structured hash (an abstract syntax tree).

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

o FIXME: Provide automated regression tests for the test tools (assert
  etc., the validation functions).
o Avoid array interpolation during result construction.
o Inline result construction
o FIXME: Using memoization is currently slower than not doing it
o Benchmark without memoization versus with memoization
o Share implementation of nelist_match and pelist_match. 
o Implement state as an array
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
o Make it easy to switch off memoization (per parser)

Done
o Automate regression tests
o Separate 'minilang' test from XML test.
o Parse the hard-coded example string.
o Replace undef by 'not matched' constant
o Result print function with compact output format
o Memoize parse results and make use of them (Packrat parsing)
o Actually parse the XML input file's content
o Make it possible to switch off memoization
o Implement the logger as an array
o Avoid calling debugging code (logging functions, data formatting) when debugging is off.
o Avoid checking contracts (assertions etc.) when ASSERT is off.
o Unify implementation of nelist_match and pelist_match. 

=cut

# --------------------------------------------------------------------
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
sub ASSERT() { 1 }
#sub ASSERT() { 0 }

# --------------------------------------------------------------------
#use Carp::Assert;
use Carp;

# --------------------------------------------------------------------
sub assert($) { if (! $_[0]) { croak("Assertion failed.\n"); } }

# --------------------------------------------------------------------
sub should($$) {
    if ($_[0] ne $_[1]) { croak("'$_[0]' should be '$_[1]' but is not.\n"); }
}

# --------------------------------------------------------------------
#sub shouldn't($$)
sub shouldnt($$) { # Fix editor's parenthesis matching: }' sub {
    if ($_[0] eq $_[1]) { croak("'$_[0]' should not be '$_[1]' but is.\n"); }
}

# --------------------------------------------------------------------
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
    $$self[0]= $name;

    #$self->{logger}= Log::Log4perl::get_logger($name)
    $$self[2]= Log::Log4perl::get_logger($name)
	|| die("$name: Could not get logger.\n");
    #print("$name: Got logger: " . join(', ', keys(%{$self->{logger}})) . "\n");

    #$self->{debugging}= $self->{logger}->is_debug();
    #$$self[1]= $ {@$self}[2]->is_debug();
    #$$self[1]= ($$self[2])->is_debug();
    $$self[1]= $self->get_logger()->is_debug();
    #print("is_debug()=".$self->is_debug()."\n");
    $self->debug("is_debug()=".$self->is_debug()."\n");
    #print("get_logger()->is_debug()=".$self->get_logger()->is_debug()."\n");
    #print("get_logger()->level()=".$self->get_logger()->level()."\n");

    #$self->{logger}->debug("Logger constructed: $name.");
    #($$self[2])->debug("Logger constructed: $name.");
    $self->debug("Logger constructed: $name.");

    return $self;
}

# --------------------------------------------------------------------
sub name($) {
    # FIXME: Switch to this after testing:
    return $ { @{ $_[0]}}[0];

    my ($self)= @_;
    assert(defined($self)) if ASSERT();
    assert('' ne ref($self)) if ASSERT();
    #assert('Logger' eq ref($self)) if ASSERT();
    assert(0 < scalar(@$self)) if ASSERT();
    my $name= $$self[0];
    assert(defined($name)) if ASSERT();
    assert('' eq ref($name)) if ASSERT();
}

# --------------------------------------------------------------------
# FIXME: What is the performance impact of returning the current value?

#sub is_debug($) { $_[0]->{logger}->is_debug(); }
#sub is_debug($) { $_[0]->get_logger()->is_debug(); }
#sub is_debug($) { $_[0]->{debugging}; }
#sub is_debug($) { ${@{$_[0]}}[1]; }

sub is_debug($) {
    return $ {@ {$_[0]}}[1];

    my $self= $_[0];
    assert(defined($self)) if ASSERT();
    assert('' ne ref($self)) if ASSERT();
    $$self[1];
}

# --------------------------------------------------------------------
# FIXME: What is the performance impact of the assertions?
# FIXME: What is the performance impact of the binding to $self?

sub get_logger($) {
    #return $ {@ {$_[0]}}[2];

    my ($self)= (@_);
    #::assert(exists($self->{logger})) if ASSERT();
    ::assert(2 <= $#$self) if ASSERT();
    #my $log= $self->{logger};
    my $log= $$self[2];
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
    #($$self[2])->info("$ctx: @_");
    get_logger($self)->info("$ctx: @_");
}

# --------------------------------------------------------------------
sub debug($) {
    if ( ! $ {@{$_[0]}}[1]) { return; }
    my ($self)= shift;
    #if ( ! $self->is_debug()) { return; }
    #if ( ! $self->get_logger()->is_debug()) { return; }
    #my $ctx= $$self[0];
    my $ctx= $self->name();
    # FIXME: Why don't I use this line?:
    #$self->{logger}->debug("$ctx: @_");
    #($$self[2])->debug("$ctx: @_");
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
# If the given reference refers to a named object, returns its name.
# Otherwise returns undef.
sub given_name($) {
    my ($val)= @_;
    assert(defined($val)) if ASSERT();
    if (
        #"HASH" eq ref($val) # Does not work if $val is blessed
        '' ne ref($val)
        && exists($val->{name}))
    {
        my $valname= $val->{name};
        if (defined($valname) && '' eq ref($valname)) # name is a string
        {
            return ($valname);
        }
    }
    return undef;
}

# --------------------------------------------------------------------
# CAVEAT: you should resist the temptation to call this 'dump'
# -- Instead of calling this function, Perl will dump core.

sub vardescr($$)
{
    my ($name, $val)= @_;
    if ( ! defined($val)) { return ("$name: <UNDEFINED>\n"); }
    my $valname= given_name($val);
    return (defined($valname) ? "\$$name = ''$valname''\n" : varstring($name, $val));

    assert(defined($val));

    # If $val is a named object, print its name instead of its value
    if (
        #"HASH" eq ref($val) # Does not work if $val is blessed
        '' ne ref($val)
        && exists($val->{name})) {
        my $valname= $val->{name};
        if (defined($valname) && '' eq ref($valname)) # name is a string
        {
            return ("$name: $valname\n");
        }
    }
    varstring($name, $val);
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
    return $self;
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
sub make_result($$) {
    my ($t, $match)= (@_);
    #return {_=>$t, result=>$match};
    #return [::hash_get($t, "name"), @$match];
    return [$t->{name}, @$match];
    #return [$t->{name}, $match];
}

# --------------------------------------------------------------------
#sub nomatch() { undef; }
#sub matched($) { defined($_[0]); }

#my $nomatch= ['nomatch'];
#my $nomatch= 'nomatch';
#sub nomatch() { $nomatch }
#use constant nomatch => 'nomatch';
sub nomatch() { 'nomatch' }
#my $nomatch= nomatch();
sub matched($) { nomatch() ne ($_[0]); }

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
    assert(defined($type));
    assert('' ne ref($type));
    assert($typename eq $type->{name});

    my $category= ::hash_get($type, '_');
    #print("categ=$category\n");

    if ($category eq "terminal") {
        "[$typename '".quotemeta($$self[1])."']";
    }
    elsif ($category eq "alternation") {
        "[$typename ".toString($$self[1], "$indent ")."]";
    }
    elsif ($category eq "optional") {
        "[$typename ".toString($$self[1], "$indent ")."]";
    }
    else #($category eq "construction")
    {
        "[$typename\n$indent "
            . join(",\n$indent ", map { toString($_, "$indent "); } @$self[1..$#$self])
            . "$indent]";
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
    assert($typename eq $type->{name}) if ASSERT();

    my $category= ::hash_get($type, '_');

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
        $handler->print("[$typename '@$self->{elements}']");
    }
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
::import_from('Parse::SiLLy::Result', 'nomatch');
::import_from('Parse::SiLLy::Result', 'make_result');

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
sub format_stashed($)
{
    my $stashed= @_;
    assert(defined($stashed));
    ( ! matched($stashed)) ? 'nomatch'
        #: Parse::SiLLy::Result::toString(\@$stashed[1..$#$stashed], " ")
        #: Parse::SiLLy::Result::toString(@{@$stashed}[1..$#$stashed], " ")
        : "[$$stashed[0]]".Parse::SiLLy::Result::toString($$stashed[1], " ")
        ;
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
        my $elt= $spec;

        # FIXME: This leads to an incomplete error message
        # (get assert to add the stack trace to $@ in this case):
        #$elt= "foo";
        #my $elt_name= ::hash_get($elt, 'name');
        my $elt_name= $elt->{'name'};
        assert(defined($elt_name));
        assert('' eq ref($elt_name));

        #$log->debug("Showing pos_stash for $pos.$elt_name...");
        my $stashed= $pos_stash->{$spec};
        assert(defined($stashed));
        $log->debug(
                    #matched($stashed)
                    #? varstring("$pos.$elt_name", $stashed)
                    #: "$pos.$elt_name = nomatch"
                    "stash{$pos, $elt_name}="
                    #. format_stashed($pos_stash->{$spec})
                    . ( ! matched($stashed) ? 'nomatch'
                        : "[$$stashed[0]]"
                          .Parse::SiLLy::Result::toString($$stashed[1], " ")
                        )
                    );
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
sub input_show_state($$) {
    my ($log, $state)= (@_);
    if ( ! $log->is_debug()) { return; }
    $log->debug(varstring('state->pos', $state->{pos}));
}

# --------------------------------------------------------------------
sub match_watch_args($$$) {
    my ($log, $t, $state)= (@_);
    assert(defined($log)) if ASSERT();

    #my $ctx= ::hash_get($t, "name");
    assert(defined($t)) if ASSERT();
    assert('' ne ref($t)) if ASSERT();
    #assert("HASH" eq ref($t)) if ASSERT();
    assert(exists($t->{name})) if ASSERT();
    my $ctx= $t->{name};
    assert(defined($ctx)) if ASSERT();
    if ( ! $log->is_debug()) { return $ctx; }

    $log->debug("$ctx: state->pos=$state->{pos}");
    # FIXME: Use a faster method to access the parser state (array)
    if (exists($state->{stash})) {
        my $pos= $state->{pos};
        show_pos_stash($log, $state->{stash}->{$pos}, $pos);
    }
    $ctx;
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
    return ($#{@$input} < $pos);
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
    $val->{name}= $name;
    $log->debug("Defined '$name' as $val.");
}

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

    assert(defined($category));
    assert('' eq ref($category));
    $val->{_}= $category;

    # Determine full variable name
    assert(defined($name));
    assert('' eq ref($name));
    #my $fullname= "::$name";
    #my ($caller_package, $file, $line)= caller();
    my $fullname= "${caller_package}::$name";
    $log->debug("Defining '$fullname'...");
    $val->{name}= $fullname;

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
    #log_cargs($log, \@ARG);
    #return def($log, 'terminal', $ARG[0], {pattern=>$ARG[1]}, caller());
    my ($name, $pattern)= @ARG;
    log_cargs($log, $name, \@ARG);

    # Here we create an anonymous subroutine that matches $pattern and
    # store a reference to it in $element->{matcher}.

    # The goal here is to let Perl compile the pattern matcher only once,
    # when the terminal is defined (in other words, here, when the
    # subroutine is compiled), and not at every parse.
    my $matcher= eval("sub { \$_[0] =~ m{^($pattern)}og; }");

    return def($log, 'terminal', $name,
               { pattern => $pattern, matcher => $matcher },
               caller());
}

# --------------------------------------------------------------------
my $terminal_match_log;
# --------------------------------------------------------------------
sub terminal_match($$)
{
    my $log= $terminal_match_log;
    my ($t, $state)= @ARG;

    # FIXME: Separate concerns of checking preconditions, determining
    # the context and argument logging.
    my $ctx= match_watch_args($log, $t, $state);
    
    my $input= $state->{input};
    my $pos= $state->{pos};
    #my ($match)= $input =~ m{^($t->{pattern})}g;
    my $match;
    #$log->debug("$ctx: ref(input)=" . ref($input) . ".");
    if (eoi($input, $pos)) {
	if ($log->is_debug()) { $log->debug("$ctx: End Of Input reached"); }
	return (nomatch());
    }
    if ('ARRAY' eq ref($input)) {
	if ($log->is_debug()) {
            $log->debug("$ctx: state->pos=$state->{pos},"
                        . " input[0]->name=", $ {@$input}[0]->{name});
        }
	#if ($#{@$input} < $pos) {
	#    if ($log->is_debug()) { $log->debug("$ctx: End of input reached");}
	#    return (nomatch());
	#}
	$match= $ {@$input}[$pos];
	if ($t == $match->{_}) {
            if ($log->is_debug()) {
                #$log->debug("$ctx: matched token: " . varstring('match', $match));
                $log->debug("$ctx: matched token: $ctx, text: '$match->{text}'");
            }
	    my $result= $match;
	    $state->{pos}= $pos + 1;
            if ($log->is_debug()) {
                #$log->debug(varstring('state', $state));
                $log->debug("$ctx: state->pos=$state->{pos}");
            }
	    return ($result);
	} else {
            if ($log->is_debug()) {
                $log->debug("$ctx: token not matched: '$ctx'");
            }
	    return (nomatch());
	}
    } else {
        if ($log->is_debug()) {
            $log->debug("$ctx: state->pos=$state->{pos},"
                        . " substr(input, pos)='"
                        . quotemeta(substr($input, $pos))."'");
        }
	#if (length($input)-1 < $pos) {
	#    if ($log->is_debug()) {$log->debug("$ctx: End Of Input reached");}
	#    return (nomatch());
	#}
        my $pattern= $t->{pattern};
        assert(defined($pattern)) if ASSERT();
        assert('' eq ref($pattern)) if ASSERT();

	#($match)= substr($input, $pos) =~ m{^($t->{pattern})}g;
        #my $matcher= $t->{matcher};
	($match)= &{$t->{matcher}}(substr($input, $pos));

        if (defined($match)) {
            if ($log->is_debug()) {
                $log->debug("$ctx: matched text: '".quotemeta($match)."'");
            }
            #my $result= {_=>$t, text=>$match};
	    my $result= make_result($t, [$match]);
	    $state->{pos}= $pos + length($match);
	    if ($log->is_debug()) {
                #$log->debug(varstring('state', $state));
                $log->debug("$ctx: state->pos=$state->{pos}");
            }
	    return ($result);
	} else {
	    if ($log->is_debug()) {
                $log->debug("$ctx: pattern not matched: '"
                            . quotemeta($t->{pattern})."'");
            }
	    return (nomatch());
	}
    }
}

# --------------------------------------------------------------------
my $construction_log;

# --------------------------------------------------------------------
=ignore

sub construction
{
    my $log= $construction_log;
    log_cargs($log, \@ARG);
    # These are not allowed (elements of @ARG are read-only)
    #map { if ('' eq ref($_)) { $_= grammar_object($_); } } @ARG;
    #for (@ARG) { if ('' eq ref($_)) { $_= grammar_object($_); } }
    #for (my $i= $#ARG; $i > 0; --$i) {
    #    if ('' eq ref($ARG[$i])) {
    #        $ARG[$i]=     # This assignment gives the error
    #            grammar_object($ARG[$i]);
    #    }
    #}

    #my $val= { _ => $log->{name}, elements => \@ARG };
    #my $val= { _ => $log->{name}, elements => [@ARG] };
    my $val= { _ => $log->{name}, elements => grammar_objects(\@ARG) };
    $log->debug(varstring('elements',$val->{elements}));
    log_val($log, $val);
    return $val;
}

=cut

# --------------------------------------------------------------------
sub construction
{
    # FIXME: Clean up
    my $log= $construction_log;
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    assert(0 < scalar(@ARG));

    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'construction', $name,
                 { elements => grammar_objects($caller_package, \@ARG) },
                 caller());
    #$log->debug(varstring('elements',$val->{elements}));
    $val;
}

# --------------------------------------------------------------------
my $construction_match_log;
# --------------------------------------------------------------------
sub construction_match($$)
{
    my $log= $construction_match_log;
    my ($t, $state)= @ARG;
    my $ctx= match_watch_args($log, $t, $state);

    my $result_elements= [];
    my $saved_pos= $state->{pos};

    # foreach $element in $t->{elements}
    map {
	my $i= $_;
	#if ($log->is_debug()) { $log->debug("$ctx: i=$i"); }
	my $element= $ {@{$t->{elements}}}[$i];
        if ($log->is_debug()) {
            #$log->debug(varstring('element', $element));
            $log->debug("$ctx: [ Trying to match element[$i]=$element->{name}");
        }
	my ($match)= match($element, $state);
	#if ( ! matched($match))
	if (nomatch() eq $match)
        {
            if ($log->is_debug()) {
                $log->debug("$ctx: ] element[$i] not matched: $element->{name}"
                            . " (giving up on '$ctx')");
            }

	    # Q: Why is this currently the only place where
	    # backtracking must be performed? A: Because this is the
	    # only place where a failure may occur after pos has been
	    # already moved.

	    $state->{pos}= $saved_pos;
	    return (nomatch());
	}
        if ($log->is_debug()) {
            #$log->debug("$ctx: ] Matched element: " . varstring($i,$element));
            $log->debug("$ctx: ] Matched element[$i]: $element->{name}");
            #$log->debug("$ctx: element value: " . varstring('match', $match));
        }
	push(@$result_elements, $match);
    } (0 .. $#{@{$t->{elements}}});

    if ($log->is_debug()) {
        $log->debug("$ctx: matched: '$ctx'");
        #$log->debug(varstring('result_elements', $result_elements));
    }
    #return ($result_elements);
    #return ({_=>$ctx, elements=>$result_elements});
    return (make_result($t, $result_elements));
}

# --------------------------------------------------------------------
my $alternation_log;
# --------------------------------------------------------------------
sub alternation
{
    my $log= $alternation_log;
    # FIXME: Clean up
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    #my $val= { _ => $log->{name}, elements => \@ARG };
    #my $val= { _ => $log->{name}, elements => [@ARG] };
    #my $val= { _ => $log->{name}, elements => grammar_objects(\@ARG) };
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'alternation', $name,
                 { elements => grammar_objects($caller_package, \@ARG) },
                 caller());
    $log->debug(varstring('elements',$val->{elements}));
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
    my $ctx= match_watch_args($log, $t, $state);

    # FIXME: Do we need to check for EOI here?
    # FIXME: Is it beneficial to check for EOI here?
    if (eoi($state->{input}, $state->{pos})) {
        if ($log->is_debug()) { $log->debug("$ctx: End Of Input reached"); }
	return (nomatch());
    }

    my $elements= $t->{elements};
    # foreach $element in $elements
    map {
	my $i= $_;
	#if ($log->is_debug()) { $log->debug("$ctx: i=$i"); }
        # FIXME: shouldn't this be '$elements[$i]'?:
	#my $element= $$elements[$i];
	my $element= $ {@$elements}[$i];
        if ($log->is_debug()) {
            #$log->debug(varstring('element', $element));
            $log->debug("$ctx: [ Trying to match element[$i]=$element->{name}");
        }
	my ($match)= match($element, $state);
	#if (matched($match))
	if (nomatch() ne $match)
        {
            if ($log->is_debug()) {
                #$log->debug("$ctx: matched element: " . varstring($i, $element));
                $log->debug("$ctx: ] Matched element[$i]: $element->{name}");
                #$log->debug("$ctx: matched value: " . varstring('match', $match));
                $log->debug("$ctx: match result: "
                            . Parse::SiLLy::Result::toString($match, " "));
            }
	    #return ($match);
	    return (make_result($t, [$match]));
	}
        if ($log->is_debug()) {
            $log->debug("$ctx: ] element[$i] not matched: '$element->{name}'");
        }
    } (0 .. $#{@$elements});

    if ($log->is_debug()) { $log->debug("$ctx: not matched: '$ctx'"); }
    return (nomatch());
}

# --------------------------------------------------------------------
my $optional_log;
# --------------------------------------------------------------------
sub optional#($)
{
    my $log= $optional_log;
    # FIXME: Clean up
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    #my $val= { _ => $log->{name}, element => $ARG[0] };
    #my $val= { _ => $log->{name}, element => grammar_object($ARG[0]) };
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'optional', $name,
                 { element => grammar_object($caller_package, $ARG[0]) },
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
    my $ctx= match_watch_args($log, $t, $state);

    my $element= $t->{element};
    if ($log->is_debug()) {
        #$log->debug(varstring('element', $element));
        $log->debug("$ctx: element=$element->{name}");
    }

    # FIXME: Add backtracking of state in case of mismatch

    my ($match)= match($element, $state);
    #if (matched($match))
    if (nomatch() ne $match)
    {
        if ($log->is_debug()) {
            #$log->debug("$ctx: matched element: " . varstring($i,$element));
            #$log->debug("$ctx: matched " . varstring('value', $match));
            $log->debug("$ctx: matched "
                        . Parse::SiLLy::Result::toString($match, " "));
        }
	return (make_result($t, [$match]));
    }
    if ($log->is_debug()) {
        #$log->debug("$ctx: not matched: '$ctx' (resulting in empty string)");
    }
    #return ('');
    if ($log->is_debug()) { $log->debug("$ctx: not matched: '$ctx'"); }
    return (make_result($t, [$match]));
}

# --------------------------------------------------------------------
my $pelist_log;
# --------------------------------------------------------------------
sub pelist#($$)
{
    my $log= $pelist_log;
    # FIXME: Clean up
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'pelist', $name,
                 { element   => grammar_object($caller_package, $ARG[0]),
                   separator => grammar_object($caller_package, $ARG[1]) },
                 $caller_package);
    #$log->debug(varstring('element',$val->{element}));
    #$log->debug(varstring('separator',$val->{separator}));
    #log_val($log, $val);
    return $val;
}

# --------------------------------------------------------------------
my $pelist_match_log;
# --------------------------------------------------------------------
sub pelist_match($$)
{
    my $log= $pelist_match_log;
    my ($t, $state)= @ARG;
    my $ctx= match_watch_args($log, $t, $state);
    my $element=   $t->{element};
    my $separator= $t->{separator};

    #my $result= [];
    #my $result= {_=>$ctx, elements=>[]};
    #my $result= make_result($t, []);
    my $result_elements= [];
    if ($log->is_debug()) {
        $log->debug("$ctx: [ Trying to match list...");
    }
    while (1) {
        if ($log->is_debug()) {
            $log->debug("$ctx: [ Trying to match element '$element->{name}'");
        }
	my ($match)= match($element, $state);
	#if ( ! matched($match))
	if (nomatch() eq $match)
        {
            if ($log->is_debug()) {
                $log->debug("$ctx: ] Element not matched: '$element->{name}'");
            }
            if ($log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.]");
            }
            #return ($result);
            return (make_result($t, $result_elements));
        }
        if ($log->is_debug()) {
            $log->debug("$ctx: ] Matched element '$element->{name}'");
        }
	#push(@$result, $match);
	push(@$result_elements, $match);

        if ('' eq $separator) { next; }

        if ($log->is_debug()) {
            $log->debug("$ctx: [ Trying to match separator '$separator->{name}'");
        }
	($match)= match($separator, $state);
	#if ( ! matched($match))
	if (nomatch() eq $match)
        {
            if ($log->is_debug()) {
                $log->debug("$ctx: ] Separator not matched: '$separator->{name}'");
            }
            if ($log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.]");
            }
            #return ($result);
            return (make_result($t, $result_elements));
        }
        if ($log->is_debug()) {
            $log->debug("$ctx: ] Matched separator '$separator->{name}'");
        }
    }
    die("Must not reach this\n");
}

# --------------------------------------------------------------------
my $nelist_log;
# --------------------------------------------------------------------
sub nelist#($$)
{
    my $log= $nelist_log;
    # FIXME: Clean up
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'pelist', $name,
                 { element   => grammar_object($caller_package, $ARG[0]),
                   separator => grammar_object($caller_package, $ARG[1]) },
                 $caller_package);
    #$log->debug(varstring('element',  $val->{element}));
    #$log->debug(varstring('separator',$val->{separator}));
    #log_val($log, $val);
    return $val;
}

# --------------------------------------------------------------------
my $nelist_match_log;
# --------------------------------------------------------------------
sub nelist_match($$)
{
    my $log= $nelist_match_log;
    my ($t, $state)= @ARG;
    my $ctx= match_watch_args($log, $t, $state);
    my $element=   $t->{element};
    my $separator= $t->{separator};

    #my $result= [];
    #my $result= {_=>$ctx, elements=>[]};
    #my $result= make_result($t, []);
    my $result_elements= [];
    if ($log->is_debug()) {
        $log->debug("$ctx: [ Trying to match list...");
    }
    while (1) {
        if ($log->is_debug()) {
            $log->debug("$ctx: [ Trying to match element '$element->{name}'");
        }
	my ($match)= match($element, $state);
	#if ( ! matched($match))
	if (nomatch() eq $match)
        {
            if ($log->is_debug()) {
                $log->debug("$ctx: ] Element not matched: '$element->{name}'");
            }
	    if (0 == scalar(@$result_elements)) {
                if ($log->is_debug()) { $log->debug("$ctx: ...not matched.]");}
                return (nomatch());
            }
            if ($log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.]");
            }
            #return ($result);
            return (make_result($t, $result_elements));
        }
        if ($log->is_debug()) {
            $log->debug("$ctx: ] Matched element '$element->{name}'");
        }
	#push(@$result, $match);
	push(@$result_elements, $match);

        if ('' eq $separator) { next; }

        if ($log->is_debug()) {
            $log->debug("$ctx: [ Trying to match separator '$separator->{name}'");
        }
	($match)= match($separator, $state);
	#if ( ! matched($match))
	if (nomatch() eq $match)
        {
            if ($log->is_debug()) {
                $log->debug("$ctx: ] Separator not matched: '$separator->{name}'");
            }
            if ($log->is_debug()) {
                $log->debug("$ctx: ...matched ".scalar(@$result_elements)
                            . " elements.]");
            }
            #return ($result);
            return (make_result($t, $result_elements));
        }
        if ($log->is_debug()) {
            $log->debug("$ctx: ] Matched separator '$separator->{name}'");
        }
    }
    die("Must not reach this\n");
}

# --------------------------------------------------------------------
my $match_log;

# This is needed in order to use references as hash keys:
# FIXME: What performance impact does this cause?
# A: Significant (22 vs. 16 parses per second)
#use Tie::RefHash;

# --------------------------------------------------------------------
sub stash_get_pos_stash($$)
{
    # FIXME: Clean up:
    #my ($state, $pos, $t)= @_;
    #my $stash= $state->{stash};
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
my %methods=
    ('terminal' => \&terminal_match,
     'alternation' => \&alternation_match,
     'construction' => \&construction_match,
     'optional' => \&optional_match,
     'nelist' => \&nelist_match,
     'pelist' => \&pelist_match);

# --------------------------------------------------------------------
sub match($$)
{
    my $log= $match_log;
    my ($t, $state)= @ARG;
    # FIXME: Allow defining these asserts away (35 vs. 41 /sec):
    assert(defined($t)) if ASSERT();
    assert('' ne ref($t)) if ASSERT();

    assert(defined($state)) if ASSERT();
    assert('' ne ref($state)) if ASSERT();

    assert(exists($state->{pos})) if ASSERT();
    my $pos= $state->{pos};
    assert(defined($pos)) if ASSERT();
    assert('' eq ref($pos)) if ASSERT();

    # FIXME: This should be done by a constructor:
    if ( ! exists($state->{stash})) {
        # If these are disabled, memoization is not done:
        # FIXME: Using memoization is currently slower than not doing it
        #if ($log->is_debug()) { $log->debug("Initializing stash..."); }
        #$state->{stash}= {};
    }

    my $pos_stash;

    # FIXME: Consider implementing the pos_stashes as arrays (need to
    # map grammar elements to indices, though).

    #my $pos_stash_key= $t;
    my $pos_stash_key= $t->{name};
    if (exists($state->{stash})) {
        $pos_stash= stash_get_pos_stash($state->{stash}, $pos);
        if (exists($pos_stash->{$pos_stash_key}))
        {
            my $stashed= $pos_stash->{$pos_stash_key};
            assert(defined($stashed));
            if ($log->is_debug()) {
                $log->debug("Found in stash: "
                            #. format_stashed($stashed)
                            .
                            (matched($stashed)
                             ? "[$$stashed[0]]"
                             .Parse::SiLLy::Result::toString($$stashed[1], " ")
                             : 'nomatch'
                             )
                            );
            }
            #if (matched($stashed))
            if (nomatch() ne $stashed)
            {
                assert('ARRAY' eq ref($stashed)) if ASSERT();
                $state->{pos}= $$stashed[0];
                return ($$stashed[1]);
            }
            else {
                return (nomatch());
            }
        }
    }

    my $result;
    # FIXME: Speed this up (use a method?)
    # Hmm, using a method hash here has no noticeable effect on performance.
    if (0) {
        my $method= $methods{$t->{_}}
        ||	die("$log->{name}: Unsupported type " . varstring('t->_', $t->{_}));
        $result= &$method($t, $state);
    }
    else {

    my $c= $t->{_}; # category
    if    ('terminal'     eq $c) { $result=     terminal_match($t, $state); }
    elsif ('alternation'  eq $c) { $result=  alternation_match($t, $state); }
    elsif ('construction' eq $c) { $result= construction_match($t, $state); }
    elsif ('optional'     eq $c) { $result=     optional_match($t, $state); }
    elsif ('nelist'       eq $c) { $result=       nelist_match($t, $state); }
    elsif ('pelist'       eq $c) { $result=       pelist_match($t, $state); }
    else {
	die("$log->{name}: Unsupported type " . varstring('t->_', $c));
    }
}

    #assert(matched($result) || $state->{pos} == $pos) if ASSERT();
    assert((nomatch() ne $result) || $state->{pos} == $pos) if ASSERT();

    if (exists($state->{stash})) {
        #my $stashed= matched($result) ? [$state->{pos}, $result] : nomatch();
        my $stashed= (nomatch() ne $result) ? [$state->{pos}, $result] : nomatch();
        if ($log->is_debug()) {
            $log->debug("Storing result in stash for ${pos} ->{$pos_stash_key} ($t->{name}): "
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
        #if ($log->is_debug()) {
        #    map { $log->debug("key $_ has ref ".ref($_)); } keys(%$pos_stash);
        #}
        # Used Tie::RefHash to get around that.  Another way might be
        # to use $t's name as the key.
        #map { assert('HASH' eq ref($_)); } keys(%$pos_stash);
        # FIXME: is this slow?:
        #map { ::should('HASH', ref($_)); } keys(%$pos_stash);
    }
    $result;
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
    return;
}

# --------------------------------------------------------------------
my $main_log;

# --------------------------------------------------------------------
sub init()
{
    Log::Log4perl->easy_init($INFO);
    #Log::Log4perl->easy_init($DEBUG);
    #$logger= get_logger();
    #$logger->info("Running...");
    #if (scalar(@_) > 0) { info(vdump('Args', \@_)); }
    $Data::Dumper::Indent= 1;

    Parse::SiLLy::Grammar::init();

    $main_log= Logger->new('main');
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

    #my $actual_text= ::hash_get($result, "text");
    my $actual_text= $$result[1];
    #should($actual_text,     $expected_text);

    # FIXME: ACTIVATE!
    #assert(Sump::Validate::Compare($actual_text,     $expected_text));

    $main_log->debug("Okayed: $actual_typename, '$actual_text'");
}

# --------------------------------------------------------------------
# Suppress 'used only once' warnings
$minilang::Name= $minilang::Name;
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
    if ($log->is_debug()) {
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
    $state= { input => 'blah 123  456', pos=>0 };
    test1($log, "terminal_match", "minilang::Name",       $state, "blah");
    test1($log, "terminal_match", "minilang::Whitespace", $state, " ");
    test1($log, "terminal_match", "minilang::Number",     $state, "123");
    test1($log, "terminal_match", "minilang::Whitespace", $state, "  ");
    test1($log, "terminal_match", "minilang::Number",     $state, "456");

    $log->debug("--- Testing alternation_match...");
    $state= { input => 'blah 123', pos=>0 };
    test1($log, "alternation_match", "minilang::Token",
          $state, ['minilang::Token', ['minilang::Name', 'blah']]);
    test1($log, "match",             "minilang::Whitespace",
          $state, " ");
    test1($log, "match",             "minilang::Token",
          $state, ['minilang::Token', ['minilang::Number', '123']]);

    $log->debug("--- Testing tokenization 1...");
    $state= { input => 'blah "123"  456', pos=>0 };

    $result= Parse::SiLLy::Grammar::match($minilang::Tokenlist, $state);
    if ($log->is_debug()) {
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
    my $expected= ['minilang::Tokenlist',
                   ['minilang::Token', ['minilang::Name', 'blah']],
                   ['minilang::Token', ['minilang::String', '"123"']],
                   ['minilang::Token', ['minilang::Number', '456']],
                   ];
    #use FreezeThaw;
    #assert(0 == strCmp($result, $expected));
    use lib "../SVStream/lib"; # SVStream::Utils
    use lib ".."; # Sump::Validate
    use Sump::Validate;
    assert(Sump::Validate::Compare($result, $expected));
    #Sump::Validate($result, $expected);

    #my $result_elements= $result->{elements};
    # FIXME: Make this a function:
    # FIXME: Implicit scalar context for array in block:
    my $result_elements= \@$result[1..$#{@$result}];
    #check_result($$result_elements[0], 'Name', 'blah');
    #check_result($$result_elements[1], 'String', '"123"');
    #check_result($$result_elements[2], 'Number', '456');


    $log->debug("--- Testing tokenization 2...");
    #$state= { input => 'blah ("123", xyz(456 * 2)); end;', pos=>0 };
    $state= { input => 'blah.("123", xyz.(456.*.2)); end;', pos=>0 };
    #                   0....5....0....5..8..0

    $result= Parse::SiLLy::Grammar::match($minilang::Tokenlist, $state);
    if ($log->is_debug()) {
        #$log->debug(varstring('match minilang::Tokenlist result 2', $result));
        $log->debug("match minilang::Tokenlist result 2='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);

    # FIXME: Use an access function here: $result->elements();
    #$result_elements= $result->{elements};
    assert(1 < scalar(@$result));
    #$result_elements= {@$result}[0..($#$result-1)];
    #my @result_elements= @$result[1, -1];
    # FIXME: Implicit scalar context for array in block
    my @result_elements= @{@$result}[1..$#$result];
    if ($log->is_debug()) {
        $log->debug(varstring('@result_elements', \@result_elements));
    }

    $result_elements= \@result_elements;
    #$result_elements= \@{@$result}[1..$#$result];
    if ($log->is_debug()) {
        $log->debug(varstring('result_elements', $result_elements));
    }

    # FIXME: When we always pass an expected result object,
    # check_result needs only two args.

    check_result($$result_elements[0], 'minilang::Token',
                 ['minilang::Token', ['minilang::Name', 'blah']]);
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
        ["minilang::Token", ["minilang::$$_[0]", $$_[1]]];
    } @token_contents;
    my $expected_tokens= \@expected_tokens;
    if ($log->is_debug()) {
        $log->debug(varstring('expected_tokens', $expected_tokens));
    }
    #$expected= ['Tokenlist', $expected_tokens];
    map {
        my ($e)= $_;
        if ($log->is_debug()) {
            #$log->debug(varstring('e', $e));
            $log->debug("$e='".Parse::SiLLy::Result::toString($e, " ")."'");
        }
        check_result($$result_elements[$i],
                     $$e[0],
                     $$e[1]);
        ++$i;
    }
    #@$expected;
    @$expected_tokens;
    Sump::Validate::Compare($expected, $result);

    $log->debug("--- Testing Program...");
    $log->debug("Program=$minilang::Program.");
    # FIXME: Get this (two-stage parsing) to work:
    #$state= { input => $result, pos=>0 };
    $state->{pos}= 0;

    # FIXME: Get this test to work
    $result= Parse::SiLLy::Grammar::match($minilang::Program, $state);
    if ($log->is_debug()) {
        #$log->debug(varstring('match minilang::Program result', $result));
        $log->debug("match minilang::Program result='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
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

    Sump::Validate::Compare($expected, $result);
}

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

    $state= { input => $xml, pos=>0 };

    #$result= Parse::SiLLy::Grammar::match($Parse::SiLLy::Test::XML::Elem,
    #                                      $state);
    #if ($log->is_debug()) {
    #    $log->debug(varstring('match XML::Elem result', $result));
    #}
    #Parse::SiLLy::Grammar::input_show_state($log, $state);
    #check_result($result, 'Elem', $state->{input});

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
    if ($log->is_debug()) {
        #$log->debug(varstring('match $top result', $result));
        $log->debug("match $top result='"
                    . Parse::SiLLy::Result::toString($result, " ") . "'");
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    check_result($result, $top_name, $state->{input});
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
    #if ($log->is_debug()) { $log->debug(varstring('data', $data)); }
    $data;
}

# --------------------------------------------------------------------
sub read_data_old {
    $INPUT_RECORD_SEPARATOR= "---";
    while (<INPUT>)
    {
        #if ($log->is_debug()) { $log->debug("item=\"$ARG\";"); }
        handle_item($ARG);
    }
    $INPUT_RECORD_SEPARATOR= "";
}

# --------------------------------------------------------------------
sub do_one_run($$) {
    my ($state, $top)= @_;
    if (exists($state->{stash})) {
        delete($state->{stash});
    }
    $state->{pos}= 0;
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
    Parse::SiLLy::Grammar::def($log, '<category>', 'foo', {elt=>'bar'},
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
    my $state= { input => $input_data, pos=>0 };
    my $top= "Parse::SiLLy::Test::XML::Contentlist";
    my $result;
    #$result= Parse::SiLLy::Grammar::match($::Elem, $state);
    no strict 'refs';
    # FIXME: Why does the first run fail?
    $result= Parse::SiLLy::Grammar::match($ {"$top"}, $state);
    #$result= do_one_run($state, $top);
    #$result= do_runs(100, $state, $top);

    sleep(1);
    use Benchmark;
    #timethis(1, sub { $result= Parse::SiLLy::Grammar::match($ {"$top"}, $state); } );
    #timethis(1, sub { $result= do_one_run($state, $top); } );
    timethis(1, sub { $result= do_one_run($state, $top); } );
    # First arg -N means repeat for at least N seconds.
    timethis(-2, sub { $result= do_one_run($state, $top); } );

    if ($log->is_debug()) {
        $log->debug(varstring('match $top result', $result));
        #$log->debug(varstring('state', $state));
    }
    Parse::SiLLy::Grammar::input_show_state($log, $state);
    if (exists($state->{stash})) {
        Parse::SiLLy::Grammar::show_stash($log, $state->{stash});
    }
    print(Parse::SiLLy::Result::toString($result, " ")."\n");
    }
}

# --------------------------------------------------------------------
main(@ARGV);

# --------------------------------------------------------------------
# EOF
