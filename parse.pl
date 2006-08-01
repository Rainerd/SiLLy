#!/usr/bin/perl -w
# --------------------------------------------------------------------
# Usage: perl PROGRAM GRAMMAR INPUT > OUTPUT
# Example: perl parse.pl xml-grammar.pl example.xml
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
appropriately structured hash. 


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

Uses a kind of iterator for the input state.

Handles tokenized input.

Backtracking of state in case of mismatch


FIXME:
o tuple rule attribute 'elements' is empty
o Catch EOS in all matching functions

TODO

o Actually parse the XML input file's content instead of parsing the
  hard-coded example string.
o Separate 'minilang' test from XML test.
o Automate regression tests
o Add more regression tests
o Packagize (Parser, Grammar, Utils, Test, Result)
o Packagize (Terminal, Construction, Alternation, Optional, NEList, PEList)
o Document how to configure logging
o Result print function with compact output format
o Result scanner

=cut

# --------------------------------------------------------------------
use strict;
#use warnings;
use diagnostics;
use English;

# --------------------------------------------------------------------
my $INC_BASE;
use File::Basename;
BEGIN { $INC_BASE= dirname($0); }

#push(@INC, "$INC_BASE/Log-Log4perl-0.49/blib/lib");
use lib "${INC_BASE}/Log-Log4perl/blib/lib";

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
sub hash_get($$) {
    my ($hash, $key)= (@_);
    #local $Carp::CarpLevel; ++$Carp::CarpLevel;
    assert(defined($hash));
    assert('' ne ref($hash));
    #assert("HASH" eq ref($hash)); # false if $hash refers to a blessed object
    #assert(defined($key));
    assert(exists($hash->{$key}));
    $hash->{$key};
}

# ====================================================================
package Logger;
use strict;

# --------------------------------------------------------------------
sub new
{
    my $proto= shift;
    my $class= ref($proto) || $proto;
    my $self= {};
    bless($self, $class);

    my $name= shift;
    $self->{name}= $name;
    $self->{logger}= Log::Log4perl::get_logger($name)
	|| die("$name: Could not get logger.\n");
    #print("$name: Got logger: " . join(', ', keys(%{$self->{logger}})) . "\n");
    $self->{logger}->debug("Logger constructed: $name.");
    return $self;
}

# --------------------------------------------------------------------
sub get_logger($) {
    my ($self)= (@_);
    ::assert(exists($self->{logger}));
    my $log= $self->{logger};
    ::assert(defined($log));
    #print(STDERR "ref(log)=".ref($log)."\n");
    ::assert("Log::Log4perl::Logger" eq ref($log));
    $log;
}

# --------------------------------------------------------------------
sub info($) {
    my ($self)= (@_);
    my $ctx= ::hash_get($self, "name");
    #print("$ctx: @_\n");
    #$self->{logger}->info("$ctx: @_");
    get_logger($self)->info("$ctx: @_");
}

# --------------------------------------------------------------------
sub debug($) {
    my ($self)= shift;
    my $ctx= ::hash_get($self, "name");
    #$self->{logger}->debug("$ctx: @_");
    get_logger($self)->debug("$ctx: @_");
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
# CAVEAT: you should resist the temptation to call this 'dump'
# -- Instead of calling this function, Perl will dump core.

sub vardescr($$)
{
    my ($name, $val)= @_;
    if ( ! defined($val)) { return ("$name: <UNDEFINED>\n"); }
    assert(defined($val));

    # If $val is a named object, print its name instead of its value

=ignore

    if ( ! defined(ref($val))) { return varstring($name, $val); }
    assert(defined(ref($val)));
    #if ("HASH" ne ref($val)) { return varstring($name, $val); }
    #assert("HASH" eq ref($val));
    if ( ! exists($val->{name})) { return varstring($name, $val); }
    assert(exists($val->{name}));
    if ( ! defined($val->{name})) { return varstring($name, $val); }
    assert(defined($val->{name}));
    if (defined(ref($val->{name}))) { return varstring($name, $val); }
    assert( ! defined(ref($val->{name})));

=cut

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
#package Result::PrintHandler;
package Result::PrintHandler::Unused;

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
package main;
# Iterates over all elements (matches) in the given parse result
# object, calling the given handler on each one.

sub Result::scan($$) {
    my ($self, $handler)= (@_);
    assert(defined($self));
    assert(defined($handler));
    assert('ARRAY' eq ref($self));

    my $typename= $$self[0];
    assert(defined($typename));
    assert('' eq ref($typename));

    my $type= do { no strict 'refs'; $ {$typename}; };
    assert(defined($type));
    assert('' ne ref($type));
    assert($typename eq $type->{name});

    my $category= ::hash_get($type, '_');

    # FIXME: separate iteration from printing

    if ($category= $Grammar::terminal) {
        #
        $handler->terminal($self, $typename, $type, $category);
    }
    elsif ($category= $Grammar::construction) {
        $handler->construction_begin($self, $typename, $type, $category);
        map { Result::scan($_, $handler); } @$self[1..$#$self];
        $handler->construction_end  ($self, $typename, $type, $category);
    }
    elsif ($category= $Grammar::alternation) {
        $handler->alternation_begin($self, $typename, $type, $category);
        map { Result::scan($_, $handler); } @$self[1..$#$self];
        $handler->alternation_end  ($self, $typename, $type, $category);
    }
    elsif ($category= $Grammar::optional) {
        $handler->optional($self, $typename, $type, $category);
    }
    else {
        $handler->print("[$typename '@$self->{elements}']");
    }
}

#=cut

# ====================================================================
package Grammar;

use strict;
use diagnostics;
use English;

#use main;
#main::import(qw(assert));
#*assert= \&::assert;
::import_from('main', 'assert');
::import_from('main', 'vardescr');
::import_from('main', 'varstring');

#BEGIN { $Exporter::Verbose=1 }
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA= qw(Exporter); # Package's ISA
%EXPORT_TAGS= ('all' => [qw(def terminal def_terminal construction alternation optional nelist pelist)]);
@EXPORT_OK= ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT= qw();

sub import {
    # This would try to call Grammar::export_to_level, which is not defined:
    #export_to_level(1, 'Grammar', @{ $EXPORT_TAGS{'all'} });

    Grammar->export_to_level(1, 'Grammar', @{ $EXPORT_TAGS{'all'} });
}

# --------------------------------------------------------------------
sub log_args($$$)
{
    my ($log, $context, $argl)= @ARG;
    assert(defined($log));
    assert(defined($context));
    assert($argl);
    #carp(..);
    #$log->debug("$context: \@#ARG=$#{@{$argl}}");
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
        vardescr("$i", $ARG);
    } @$argl;
    $log->debug("$context: @description");
}

# --------------------------------------------------------------------
# Log constructor arguments
#sub log_cargs($$) { log_args($_[0], '', $_[1]); }
sub log_cargs($$$) { log_args($ARG[0], $ARG[1], $ARG[2]); }

# --------------------------------------------------------------------
sub match_watch_args($$$) {
    my ($log, $t, $state)= (@_);
    #assert(defined($t));
    #assert('' ne ref($t));
    ##assert("HASH" eq ref($t));
    #assert(exists ($t->{name}));
    my $ctx= ::hash_get($t, "name");
    assert(defined($ctx));
    log_args($log, $ctx, \@ARG);
    $log->debug("$ctx: state->pos=$state->{pos}");
    $ctx;
}

# --------------------------------------------------------------------
sub make_result($$) {
    my ($t, $match)= (@_);
    #return {_=>$t, result=>$match};
    return [::hash_get($t, "name"), @$match];
}

# --------------------------------------------------------------------
# Conditional logging of grammar element values (in constructors)
my $log_val;
$log_val= 1;
sub log_val($$) {
    my ($log, $val)= @ARG;
    assert(defined($log));
    assert('' ne ref($log));
    #assert("HASH" eq ref($log));
    if ($log_val) {
        #assert(defined($val));
        #assert('' ne ref($val));
        #$log->debug("Type='$val->{_}':");
        $log->debug(varstring('val',$val));
    }
}

# --------------------------------------------------------------------
sub eoi($) {
    my ($state)= (@_);
    my $input= ::hash_get($state, "input"); assert(defined($input));
    if ('' eq ref($input)) { return (length($input)-1 < $state->{pos}); }
    assert("ARRAY" eq ref($input));
    return ($#{@$input} < $state->{pos});
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

    #
    # FIXME: Consider using functions that both create and define a
    # grammar element: def_terminal Foo, '[Ff]oo';
    #

    # Define the variable in the calling package
    my ($caller_package, $file, $line)= caller();
    #$name= "::$name";
    $name= "${caller_package}::$name";
    $log->debug("Defining '$name'...");

    # Construct grammar object to bind the variable to
    my $val= &{$category}(@rest);
    $log->debug(varstring('val',$val));

    # Bind grammar object to variable
    eval("\$$name=\$val;");
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
my $terminal_log;
# --------------------------------------------------------------------
=ignore

package Grammar::Unused;

sub terminal#($)
{
    my $log= $terminal_log;
    log_cargs($log, \@ARG);
    
    my $val= { pattern => $ARG[0], _ => $log->{name}};
    $log->debug(varstring('pattern',$val->{pattern}));
    log_val($log, $val);
    return $val;
}

package Grammar;

=cut

# --------------------------------------------------------------------
#sub def_terminal($$)
sub terminal#($$)
{
    my $log= $terminal_log;
    #log_cargs($log, \@ARG);
    #return def($log, 'terminal', $ARG[0], {pattern=>$ARG[1]}, caller());
    my ($name, $pattern)= @ARG;
    log_cargs($log, $name, \@ARG);
    return def($log, 'terminal', $name, {pattern=>$pattern}, caller());
=ignore

    #my $log= $def_log;
    log_cargs($log, \@ARG);
    my ($name, $pattern)= (@ARG);
    assert(defined($name));
    assert('' eq ref($name));
    assert(defined($pattern));
    assert('' eq ref($pattern));

    # Determine full variable name
    #my $fullname= "::$name";
    my ($caller_package, $file, $line)= caller();
    my $fullname= "${caller_package}::$name";
    $log->debug("Defining '$fullname'...");

    # Construct grammar object to bind the variable to
    #my $val= &{$category}(@rest);
    #my $val= { pattern => $pattern, _ => $log->{name}};
    my $val= { '_'=>$log->{name}, name=>$fullname, pattern=>$pattern };
    #$log->debug(varstring('val', $val));
    $log->debug(varstring('pattern', $val->{pattern}));

    # Bind grammar object to variable
    eval("\$$fullname=\$val;");
    #$::def_val_= $val; eval("\$$fullname=\$::def_val_;");
    # FIXME: Consider moving this to the grammar object constructors:
    #$val->{name}= $name;
    #$val->{name}= $fullname;
    $log->debug("Defined '$fullname' as $val.");

    log_val($log, $val);
    return $val;

=cut

}

# --------------------------------------------------------------------
my $terminal_match_log;
# --------------------------------------------------------------------
sub terminal_match($$)
{
    my $log= $terminal_match_log;
    my ($t, $state)= @ARG;
    my $ctx= match_watch_args($log, $t, $state);
    
    my $input= $state->{input};
    my $pos= $state->{pos};
    #my ($match)= $input =~ m{^($t->{pattern})}g;
    my $match;
    #$log->debug("$ctx: ref(input)=" . ref($input) . ".");
    if (eoi($state)) {
	$log->info("$ctx: End Of Input reached");
	return (undef);
    }
    if ('ARRAY' eq ref($input)) {
	$log->debug("$ctx: state->pos=$state->{pos}, input[0]->name=", $ {@$input}[0]->{name});
	#if ($#{@$input} < $pos) {
	#    $log->info("$ctx: End of input reached");
	#    return (undef);
	#}
	$match= $ {@$input}[$pos];
	if ($t == $match->{_}) {
	    #$log->debug("$ctx: matched token: " . varstring('match', $match));
	    $log->debug("$ctx: matched token: $ctx, text: '$match->{text}'");
	    my $result= $match;
	    $state->{pos}= $pos + 1;
	    #$log->debug(varstring('state', $state));
	    $log->debug("$ctx: state->pos=$state->{pos}");
	    return ($result);
	} else {
	    $log->debug("$ctx: token not matched: '$ctx'");
	    return (undef);
	}
    } else {
	$log->debug("$ctx: state->pos=$state->{pos}, substr(input, pos)=", substr($input, $pos));
	#if (length($input)-1 < $pos) {
	#    $log->info("$ctx: End Of Input reached");
	#    return (undef);
	#}
        my $pattern= $t->{pattern};
        assert(defined($pattern));
        assert('' eq ref($pattern));
	($match)= substr($input, $pos) =~ m{^($t->{pattern})}g;
        if (defined($match)) {
	    $log->debug("$ctx: matched text: '$match'");
            #my $result= {_=>$t, text=>$match};
	    my $result= make_result($t, [$match]);
	    $state->{pos}= $pos + length($match);
	    #$log->debug(varstring('state', $state));
	    $log->debug("$ctx: state->pos=$state->{pos}");
	    return ($result);
	} else {
	    $log->debug("$ctx: pattern not matched: '$t->{pattern}'");
	    return (undef);
	}
    }
}

# --------------------------------------------------------------------
my $construction_log;

# --------------------------------------------------------------------
# Returns the grammar object corresponding to the given spec (which
# may be a string or a reference).

sub grammar_object($$)
{
    #('' eq ref($_[0])) ? eval("\$::$_[0]") : $_[0];
    my ($grammar, $spec)= (@_);
    assert(defined($grammar));
    assert('' eq ref($grammar));
    assert(defined($spec));

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
    #log_args($construction_log, "grammar_objects", $ARG[0]);
    # Note that @$ARG[0] is not the same as @{$ARG[0]}
    #my @elements= map { ('' eq ref($_)) ? eval("\$::$_") : $_; } @{$ARG[0]};
    my $grammar= shift();
    my @elements= map { grammar_object($grammar, $_); } @{$ARG[0]};
    \@elements;
}

# --------------------------------------------------------------------
=ignore

sub construction
{
    my $log= $construction_log;
    log_cargs($log, \@ARG);
    # These are not allowed (elements of @ARG are read-only)
    #map { if ('' eq ref($_)) { $_= eval("\$::$_"); } } @ARG;
    #for (@ARG) { if ('' eq ref($_)) { $_= eval("\$::$_"); } }
    #for (my $i= $#ARG; $i > 0; --$i) {
    #    if ('' eq ref($ARG[$i])) {
    #        $ARG[$i]=     # This gives the error
    #            eval("\$::$ARG[$i]");
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
    my $log= $construction_log;
    #my $log= $def_log;
    #log_cargs($log, \@ARG);
    #my ($name, $pattern)= (@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    assert(defined($name));
    assert('' eq ref($name));
    assert(0 < scalar(@ARG));

    #assert(defined($pattern));
    #assert('' eq ref($pattern));

    # Determine full variable name
    #my $fullname= "::$name";
    my ($caller_package, $file, $line)= caller();
    my $fullname= "${caller_package}::$name";
    $log->debug("Defining '$fullname'...");

    # Construct grammar object to bind the variable to
    #my $val= &{$category}(@rest);
    #my $val= { _ => $log->{name}, elements => \@ARG };
    #my $val= { _ => $log->{name}, elements => [@ARG] };
    #my $val= { _ => $log->{name}, elements => grammar_objects(\@ARG) };
    my $val= { _ => $log->{name}, name=>$fullname,
               elements => grammar_objects($caller_package, \@ARG) };
    #$log->debug(varstring('val', $val));
    $log->debug(varstring('elements',$val->{elements}));

    # Bind grammar object to variable
    eval("\$$fullname=\$val;");
    #$::def_val_= $val; eval("\$$fullname=\$::def_val_;");
    # FIXME: Consider moving this to the grammar object constructors:
    #$val->{name}= $name;
    #$val->{name}= $fullname;
    $log->debug("Defined '$fullname' as $val.");

    log_val($log, $val);
    return $val;
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
	#$log->debug("$ctx: i=$i");
	my $element= $ {@{$t->{elements}}}[$i];
	#$log->debug(varstring('element', $element));
	$log->debug("$ctx: trying to match element $i=$element->{name}");
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: element $i not matched: $element->{name} (giving up on '$ctx')");
	    # FIXME: Is this the best place to put backtracking?
	    $state->{pos}= $saved_pos;
	    return (undef);
	}
	#$log->debug("$ctx: matched element: " . varstring($i,$element));
	$log->debug("$ctx: matched element $i: $element->{name}");
	#$log->debug("$ctx: element value: " . varstring('match', $match));
	push(@$result_elements, $match);
    } (0 .. $#{@{$t->{elements}}});
    $log->debug("$ctx: matched: '$ctx'");
    $log->debug(varstring('result_elements', $result_elements));
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
    # FIXME: Q: Move argument logging to 'match'?
    # A: No, then we can not control logging locally.
    my $ctx= match_watch_args($log, $t, $state);

    if (eoi($state)) {
	$log->info("$ctx: End Of Input reached");
	return (undef);
    }

    my $elements= $t->{elements};
    # foreach $element in $elements
    map {
	my $i= $_;
	#$log->debug("$ctx: i=$i");
        # FIXME: shouldn't this be '$elements[$i]'?:
	#my $element= $$elements[$i];
	my $element= $ {@$elements}[$i];
	#$log->debug(varstring('element', $element));
	$log->debug("$ctx: trying to match element $i=$element->{name}");
	my ($match)= match($element, $state);
	if ($match)  {
	    #$log->debug("$ctx: matched element: " . varstring($i, $element));
            $log->debug("$ctx: matched element $i: $element->{name}");
	    $log->debug("$ctx: matched value: " . varstring('match', $match));
	    #return ($match);
	    return (make_result($t, [$match]));
	}
        $log->debug("$ctx: element $i not matched: '$element->{name}'");
    } (0 .. $#{@$elements});
    $log->debug("$ctx: not matched: '$ctx'");
    return (undef);
}

# --------------------------------------------------------------------
my $optional_log;
# --------------------------------------------------------------------
sub optional#($)
{
    my $log= $optional_log;
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
    #log_val($log, $val);
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
    #$log->debug(varstring('element', $element));
    $log->debug("$ctx: element=$element->{name}");

    # FIXME: Add backtracking of state in case of mismatch

    my ($match)= match($element, $state);
    if (defined($match)) {
	#$log->debug("$ctx: matched element: " . varstring($i,$element));
	$log->debug("$ctx: matched " . varstring('value', $match));
	return (make_result($t, [$match]));
    }
    $log->debug("$ctx: not matched: '$ctx' (resulting in empty string)");
    return ('');
}

# --------------------------------------------------------------------
my $pelist_log;
# --------------------------------------------------------------------
sub pelist#($$)
{
    my $log= $pelist_log;
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    #my $val= { _ => $log->{name}, element => $ARG[0], separator => $ARG[1] };
    #my $val= {
    #    _         => $log->{name},
    #    element   => grammar_object($ARG[0]),
    #    separator => grammar_object($ARG[1]),
    #};
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'pelist', $name,
                 { element   => grammar_object($caller_package, $ARG[0]),
                   separator => grammar_object($caller_package, $ARG[1]) },
                 $caller_package);
    $log->debug(varstring('element',$val->{element}));
    $log->debug(varstring('separator',$val->{separator}));
    log_val($log, $val);
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
    my $result= make_result($t, []);
    #my $result_elements= [];
    while (1) {
	$log->debug("$ctx: trying to match element '$element->{name}'");
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: element not matched: '$element->{name}'");
            return ($result);
        }
	$log->debug("$ctx: matched element '$element->{name}'");
	push(@$result, $match);
	#push(@{$result->{elements}}, $match);

        if ('' eq $separator) { next; }

	$log->debug("$ctx: trying to match separator '$separator->{name}'");
	($match)= match($separator, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: separator not matched: '$separator->{name}'");
            return ($result);
        }
	$log->debug("$ctx: matched separator '$separator->{name}'");
    }
}

# --------------------------------------------------------------------
my $nelist_log;
# --------------------------------------------------------------------
sub nelist#($$)
{
    my $log= $nelist_log;
    #log_cargs($log, \@ARG);
    my $name= shift();
    log_cargs($log, $name, \@ARG);
    #my $val= { _ => $log->{name}, element => $ARG[0], separator => $ARG[1] };
    #my $val= {
    #    _         => $log->{name},
    #    element   => grammar_object($ARG[0]),
    #    separator => grammar_object($ARG[1]),
    #};
    my ($caller_package, $file, $line)= caller();
    my $val= def($log, 'pelist', $name,
                 { element   => grammar_object($caller_package, $ARG[0]),
                   separator => grammar_object($caller_package, $ARG[1]) },
                 $caller_package);
    $log->debug(varstring('element',  $val->{element}));
    $log->debug(varstring('separator',$val->{separator}));
    log_val($log, $val);
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
    while (1) {
	$log->debug("$ctx: trying to match element '$element->{name}'");
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: element not matched: '$element->{name}'");
	    if (0 == scalar(@$result_elements)) { return (undef); }
	    else { return (make_result($t, $result_elements)); }
	}
	$log->debug("$ctx: matched element '$element->{name}'");
	#push(@$result, $match);
	push(@$result_elements, $match);

        if ('' eq $separator) { next; }

	$log->debug("$ctx: trying to match separator '$separator->{name}'");
	($match)= match($separator, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: separator not matched: '$separator->{name}'");
            return (make_result($t, $result_elements));
        }
	$log->debug("$ctx: matched separator '$separator->{name}'");
    }
    die("Must not reach this\n");
}

# --------------------------------------------------------------------
my $match_log;
# --------------------------------------------------------------------
sub match($$)
{
    my $log= $match_log;
    my ($t, $state)= @ARG;
    assert(defined($t));
    assert('' ne ref($t));

    if ('terminal' eq $t->{_}) { 
	return (terminal_match($t, $state));
    } elsif ('alternation' eq $t->{_}) {
	return (alternation_match($t, $state));
    } elsif ('construction' eq $t->{_}) {
	return (construction_match($t, $state));
    } elsif ('optional' eq $t->{_}) {
	return (optional_match($t, $state));
    } elsif ('nelist' eq $t->{_}) {
	return (nelist_match($t, $state));
    } elsif ('pelist' eq $t->{_}) {
	return (pelist_match($t, $state));
    } else {
	die("$log->{name}: Unsupported type " . varstring('t->_', $t->{_}));
    }
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
    #Log::Log4perl->easy_init($INFO);
    Log::Log4perl->easy_init($DEBUG);
    #$logger= get_logger();
    #$logger->info("Running...");
    #if (scalar(@_) > 0) { info(vdump('Args', \@_)); }
    $Data::Dumper::Indent= 1;

    Grammar::init();

    $main_log= Logger->new('main');
}

# --------------------------------------------------------------------
sub check_result($$$) {
    my ($result, $expected_typename, $expected_text)= (@_);
    assert(defined($expected_typename));
    assert(defined($expected_text));
    #$main_log->debug(varstring('result', $result));

    # FIXME:
    #return;

    #my $actual_type= ::hash_get($result, '_');
    #my $actual_type= $$result[0];
    #my $actual_typename= ::hash_get($actual_type, 'name');
    my $actual_typename= $$result[0];
    should($actual_typename, $expected_typename);

    #my $actual_text= ::hash_get($result, "text");
    my $actual_text= $$result[1];
    should($actual_text,     $expected_text);

    $main_log->debug("Okayed: $actual_typename, '$actual_text'");
}

# --------------------------------------------------------------------
# Suppress 'used only once' warnings
$minilang::Name= $minilang::Name;
$::foo= $::foo;

# --------------------------------------------------------------------
sub input_show_state($$) {
    my ($log, $state)= (@_);
    $log->debug(varstring('state->pos', $state->{pos}));
}

# --------------------------------------------------------------------
sub test_minilang()
{
    my $log= $main_log;
    my $state;
    my $result;

    
    $log->debug("--- Reading minilang-grammar...");
    require "minilang-grammar.pl";

    $log->debug("--- Testing terminal_match...");
    $state= { input => 'blah 123  456', pos=>0 };
    $result= Grammar::terminal_match($minilang::Name, $state);
    $log->debug(varstring('terminal_match Name result', $result));
    input_show_state($log, $state);
    #should($result->{_}->{_}, 'terminal');
    #should($result->{_}->{name}, 'Name');
    #should($result->{text}, 'blah');
    check_result($result, 'Name', 'blah');

    # FIXME: Use a common test case function for these:

    $result= Grammar::terminal_match($minilang::Whitespace, $state);
    $log->debug(varstring('terminal_match minilang::Whitespace result 1', $result));
    input_show_state($log, $state);
    check_result($result, 'Whitespace', ' ');

    $result= Grammar::terminal_match($minilang::Number, $state);
    $log->debug(varstring('terminal_match minilang::Number result 1', $result));
    input_show_state($log, $state);
    check_result($result, 'Number', '123');

    $result= Grammar::terminal_match($minilang::Whitespace, $state);
    $log->debug(varstring('terminal_match minilang::Whitespace result 2', $result));
    input_show_state($log, $state);
    check_result($result, 'Whitespace', '  ');

    $result= Grammar::terminal_match($minilang::Number, $state);
    $log->debug(varstring('terminal_match minilang::Number result 2', $result));
    input_show_state($log, $state);
    check_result($result, 'Number', '456');

    $log->debug("--- Testing alternation_match...");
    $state= { input => 'blah 123', pos=>0 };

    $result= Grammar::alternation_match($minilang::Token, $state);
    $log->debug(varstring('alternation_match minilang::Token result 1', $result));
    input_show_state($log, $state);
    check_result($result, 'Token', ['Name', 'blah']);
    #check_result($result, 'Name', 'blah');

    $result= Grammar::match($minilang::Whitespace, $state);
    $log->debug(varstring('match minilang::Whitespace result 1', $result));
    input_show_state($log, $state);
    check_result($result, 'Whitespace', ' ');

    $result= Grammar::match($minilang::Token, $state);
    $log->debug(varstring('match minilang::Token result 2', $result));
    input_show_state($log, $state);
    #check_result($result, 'Number', '123');
    check_result($result, 'Token', ['Number', '123']);


    $log->debug("--- Testing tokenization 1...");
    $state= { input => 'blah "123"  456', pos=>0 };

    $result= Grammar::match($minilang::Tokenlist, $state);
    $log->debug(varstring('match minilang::Tokenlist result 1', $result));
    input_show_state($log, $state);
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
    my $result_elements= \@$result[1..$#{@$result}];
    #check_result($$result_elements[0], 'Name', 'blah');
    #check_result($$result_elements[1], 'String', '"123"');
    #check_result($$result_elements[2], 'Number', '456');


    $log->debug("--- Testing tokenization 2...");
    #$state= { input => 'blah ("123", xyz(456 * 2)); end;', pos=>0 };
    $state= { input => 'blah.("123", xyz.(456.*.2)); end;', pos=>0 };

    $result= Grammar::match($minilang::Tokenlist, $state);
    $log->debug(varstring('match minilang::Tokenlist result 2', $result));
    input_show_state($log, $state);
    # FIXME: Use an access function here: $result->elements();
    #$result_elements= $result->{elements};
    assert(1 < scalar(@$result));
    #$result_elements= {@$result}[0..($#$result-1)];
    my @result_elements= @$result[1, -1];
    $result_elements= \@result_elements;

    check_result($$result_elements[0], 'Name', 'blah');
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
    my $expected_tokens= map { ['Token', $_] } @token_contents;
    $expected= ['Tokenlist', $expected_tokens];
    map {
        my ($e)= $_;
        $log->debug(varstring('e', $e));
        check_result($$result_elements[$i],
                     $$e[0],
                     $$e[1]);
        ++$i;
    } @$expected;
    Sump::Validate::Compare($expected, $result);

    # FIXME: Get this test to work
    return;
    $log->debug("--- Testing Program...");
    $log->debug("Program=$minilang::Program.");
    $state= { input => $result, pos=>0 };
    $result= match($minilang::Program, $state);
    $log->debug(varstring('match minilang::Program result', $result));
    input_show_state($log, $state);
}

# --------------------------------------------------------------------
sub test_xml()
{
    my $log= $main_log;
    my $state;
    my $result;

    require "xml-grammar.pl";
    my $xml= <<"";
<row>
				<entry>.1 rtpMIBObjects</entry>
				<entry>Objekte der &RTP; MIB</entry>
				<entry></entry>
</row>

    $state= { input => $xml, pos=>0 };

    #$result= match($Grammar::XML::Elem, $state);
    #$log->debug(varstring('match XML::Elem result', $result));
    #input_show_state($log, $state);
    #check_result($result, 'Elem', $state->{input});

    {
    #my $top= "Elem";
    my $top= "Contentlist";
    no strict 'refs';
    $result= match(${"Grammar::XML::$top"}, $state);
    $log->debug(varstring('match XML::$top result', $result));
    input_show_state($log, $state);
    check_result($result, $top, $state->{input});
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
    #$log->debug(varstring('data', $data));
    $data;
}

# --------------------------------------------------------------------
sub read_data_old {
    $INPUT_RECORD_SEPARATOR= "---";
    while (<INPUT>)
    {
        #$log->debug("item=\"$ARG\";");
        handle_item($ARG);
    }
    $INPUT_RECORD_SEPARATOR= "";
}

# --------------------------------------------------------------------
sub main
{
    init();
    my $log= $main_log;
    
    # Test 'def'
    #Grammar::def 'foo', {elt=>'bar'};
    Grammar::def($log, '<category>', 'foo', {elt=>'bar'}, 'main');
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
    my $top= "Contentlist";
    no strict 'refs';
    #my $result= match($::Elem, $state);
    my $result= match(${"::$top"}, $state);
    $log->debug(varstring('match Elem result', $result));
    $log->debug(varstring('state', $state));
    }
}

# --------------------------------------------------------------------
main(@ARGV);

# --------------------------------------------------------------------
# EOF
