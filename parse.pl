#!/usr/bin/perl -w

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
sub vardescr($$) {
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
# Conditional logging of results
my $log_result;
#$log_result= 1;
sub log_result($$) {
    my ($log, $result)= @ARG;
    assert(defined($log));
    assert(ref($log));
    #assert("HASH" eq ref($log));
    if ($log_result) {
        $log->debug("Type='$result->{_}':");
        $log->debug(varstring('result',$result));
    }
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
    return;
    my @description= map {
        #print("item: $ARG\n");
        vardescr('_', $ARG);
    } @$argl;
    $log->debug("$context: @description");
}

# --------------------------------------------------------------------
my $def_log;
# --------------------------------------------------------------------
sub def($$)
{
    my $log= $def_log;
    my ($name,$val)= @ARG;
    $log->debug(varstring('val',$val));
    eval("\$::$name=\$val;");
    #$::def_val_= $val; eval("\$::$name=\$::def_val_;");
    $val->{name}= $name;
    $log->debug("Defined '$name' as $val.");
}

# --------------------------------------------------------------------
sub eoi($) {
    my ($state)= (@_);
    my $input= hash_get($state, "input"); assert(defined($input));
    if ('' eq ref($input)) { return (length($input)-1 < $state->{pos}); }
    assert("ARRAY" eq ref($input));
    return ($#{@$input} < $state->{pos});
}

# --------------------------------------------------------------------
# Log constructor arguments
sub log_cargs($$) { log_args($_[0], '', $_[1]); }

# --------------------------------------------------------------------
sub match_watch_args($$$) {
    my ($log, $t, $state)= (@_);
    #assert(defined($t));
    #assert('' ne ref($t));
    ##assert("HASH" eq ref($t));
    #assert(exists ($t->{name}));
    my $ctx= hash_get($t, "name");
    assert(defined($ctx));
    log_args($log, $ctx, \@ARG);
    $log->debug("$ctx: state->pos=$state->{pos}");
    $ctx;
}

# --------------------------------------------------------------------
my $terminal_log;
# --------------------------------------------------------------------
sub terminal($)
{
    my $log= $terminal_log;
    log_cargs($log, \@ARG);
    
    my $result= { pattern => $ARG[0], _ => $log->{name}};
    $log->debug(varstring('pattern',$result->{pattern}));
    log_result($log, $result);
    return $result;
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
        if (defined($match))  {
	    $log->debug("$ctx: matched text: '$match'");
	    my $result= {_=>$t, text=>$match};
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
# may be a string or a reference)
sub grammar_object($) {
    #('' eq ref($_[0])) ? eval("\$::$_[0]") : $_[0];
    my ($spec)= (@_);
    assert(defined($spec));
    if ('' eq ref($spec)) {
        my $val= eval("\$::$_[0]");
        (defined($val)) ? $val : $spec;
    }
    else {
        $spec;
    }
}

# --------------------------------------------------------------------
# Returns a reference to an array grammar objects that correspond to
# the given specs (which may be strings or references)
sub grammar_objects($) {
    #log_args($construction_log, "grammar_objects", $ARG[0]);
    # Note that @$ARG[0] is not the same as @{$ARG[0]}
    #my @elements= map { ('' eq ref($_)) ? eval("\$::$_") : $_; } @{$ARG[0]};
    my @elements= map { grammar_object($_); } @{$ARG[0]};
    \@elements;
}

# --------------------------------------------------------------------
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

    #my $result= { _ => $log->{name}, elements => \@ARG };
    #my $result= { _ => $log->{name}, elements => [@ARG] };
    my $result= { _ => $log->{name}, elements => grammar_objects(\@ARG) };
    $log->debug(varstring('elements',$result->{elements}));
    log_result($log, $result);
    return $result;
}

# --------------------------------------------------------------------
my $construction_match_log;
# --------------------------------------------------------------------
sub construction_match($$)
{
    my $log= $construction_match_log;
    my ($t, $state)= @ARG;
    my $ctx= match_watch_args($log, $t, $state);

    my $result= [];
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
	push(@$result, $match);
    } (0 .. $#{@{$t->{elements}}});
    $log->debug("$ctx: matched: '$ctx'");
    $log->debug(varstring('result', $result));
    return ($result);
}

# --------------------------------------------------------------------
my $alternation_log;
# --------------------------------------------------------------------
sub alternation
{
    my $log= $alternation_log;
    log_cargs($log, \@ARG);
    #my $result= { _ => $log->{name}, elements => \@ARG };
    #my $result= { _ => $log->{name}, elements => [@ARG] };
    my $result= { _ => $log->{name}, elements => grammar_objects(\@ARG) };
    $log->debug(varstring('elements',$result->{elements}));
    log_result($log, $result);
    return $result;
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

    # foreach $element in $t->{elements}
    map {
	my $i= $_;
	#$log->debug("$ctx: i=$i");
	my $element= $ {@{$t->{elements}}}[$i];
	#$log->debug(varstring('element', $element));
	$log->debug("$ctx: trying to match element $i=$element->{name}");
	my ($match)= match($element, $state);
	if ($match)  {
	    #$log->debug("$ctx: matched element: " . varstring($i, $element));
            $log->debug("$ctx: matched element $i: $element->{name}");
	    $log->debug("$ctx: matched value: " . varstring('match', $match));
	    return ($match);
	}
        $log->debug("$ctx: element $i not matched: '$element->{name}'");
    } (0 .. $#{@{$t->{elements}}});
    $log->debug("$ctx: not matched: '$ctx'");
    return (undef);
}

# --------------------------------------------------------------------
my $optional_log;
# --------------------------------------------------------------------
sub optional($)
{
    my $log= $optional_log;
    log_cargs($log, \@ARG);
    #my $result= { _ => $log->{name}, element => $ARG[0] };
    my $result= { _ => $log->{name}, element => grammar_object($ARG[0]) };
    $log->debug(varstring('element',$result->{element}));
    log_result($log, $result);
    return $result;
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
	return ($match);
    }
    $log->debug("$ctx: not matched: '$ctx' (resulting in empty string)");
    return ('');
}

# --------------------------------------------------------------------
my $pelist_log;
# --------------------------------------------------------------------
sub pelist($$)
{
    my $log= $pelist_log;
    log_cargs($log, \@ARG);
    #my $result= { _ => $log->{name}, element => $ARG[0], separator => $ARG[1] };
    my $result= {
        _         => $log->{name},
        element   => grammar_object($ARG[0]),
        separator => grammar_object($ARG[1]),
    };
    $log->debug(varstring('element',$result->{element}));
    $log->debug(varstring('separator',$result->{separator}));
    log_result($log, $result);
    return $result;
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
    my $result= {_=>'pelist', elements=>[]};
    while (1) {
	$log->debug("$ctx: trying to match element '$element->{name}'");
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: element not matched: '$element->{name}'");
            return ($result);
        }
	$log->debug("$ctx: matched element '$element->{name}'");
	#push(@$result, $match);
	push(@{$result->{elements}}, $match);

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
sub nelist($$)
{
    my $log= $nelist_log;
    log_cargs($log, \@ARG);
    #my $result= { _ => $log->{name}, element => $ARG[0], separator => $ARG[1] };
    my $result= {
        _         => $log->{name},
        element   => grammar_object($ARG[0]),
        separator => grammar_object($ARG[1]),
    };
    $log->debug(varstring('element',  $result->{element}));
    $log->debug(varstring('separator',$result->{separator}));
    log_result($log, $result);
    return $result;
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
    my $result= {_=>'nelist', elements=>[]};
    while (1) {
	$log->debug("$ctx: trying to match element '$element->{name}'");
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
            $log->debug("$ctx: element not matched: '$element->{name}'");
	    if (0 > $#{@$result}) { return (undef); }
	    else { return ($result); }
	}
	$log->debug("$ctx: matched element '$element->{name}'");
	#push(@$result, $match);
	push(@{$result->{elements}}, $match);

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
sub handle_item
{
    printf("$ARG");
    return;
}

# --------------------------------------------------------------------
my $main_log;

# --------------------------------------------------------------------
sub init {
    #Log::Log4perl->easy_init($INFO);
    Log::Log4perl->easy_init($DEBUG);
    #$logger= get_logger();
    #$logger->info("Running...");
    #if (scalar(@_) > 0) { info(vdump('Args', \@_)); }
    $Data::Dumper::Indent= 1;

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

    $match_log= Logger->new('match');

    $def_log= Logger->new('def');
    $main_log= Logger->new('main');

    require "minilang-grammar.pl";
}

# --------------------------------------------------------------------
sub check_result($$$) {
    my ($result, $expected_typename, $expected_text)= (@_);
    assert(defined($expected_typename));
    assert(defined($expected_text));
    #$main_log->debug(varstring('result', $result));
    my $actual_type= hash_get($result, '_');
    #should(hash_get($actual_type, '_'), 'terminal');
    my $actual_typename= hash_get($actual_type, 'name');
    my $actual_text= hash_get($result, "text");
    should($actual_typename, $expected_typename);
    should($actual_text,     $expected_text);
    $main_log->debug("Okayed: $actual_typename, '$actual_text'");
}

# --------------------------------------------------------------------
$::Name= $::Name;
$::foo= $::foo;
# Suppress 'used only once' warnings
sub test
{
    my $log= $main_log;
    my $state;
    my $result;

    $log->debug("--- Testing terminal_match...");
    $state= { input => 'blah 123  456', pos=>0 };
    $result= terminal_match($::Name, $state);
    $log->debug(varstring('tm Name result', $result));
    $log->debug(varstring('state', $state));
    #should($result->{_}->{_}, 'terminal');
    #should($result->{_}->{name}, 'Name');
    #should($result->{text}, 'blah');
    check_result($result, 'Name', 'blah');

    $result= terminal_match($::Whitespace, $state);
    $log->debug(varstring('tm Whitespace result 1', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Whitespace', ' ');

    $result= terminal_match($::Number, $state);
    $log->debug(varstring('tm Number result 1', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Number', '123');

    $result= terminal_match($::Whitespace, $state);
    $log->debug(varstring('tm Whitespace result 2', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Whitespace', '  ');

    $result= terminal_match($::Number, $state);
    $log->debug(varstring('tm Number result 2', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Number', '456');

    $log->debug("--- Testing alternation_match...");
    $state= { input => 'blah 123', pos=>0 };

    $result= alternation_match($::Token, $state);
    $log->debug(varstring('am Token result 1', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Name', 'blah');

    $result= match($::Whitespace, $state);
    $log->debug(varstring('match Whitespace result 1', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Whitespace', ' ');

    $result= match($::Token, $state);
    $log->debug(varstring('match Token result 2', $result));
    $log->debug(varstring('state', $state));
    check_result($result, 'Number', '123');


    $log->debug("--- Testing tokenization...");
    $state= { input => 'blah "123"  456', pos=>0 };

    $result= match($::Tokenlist, $state);
    $log->debug(varstring('match Tokenlist result 1', $result));
    $log->debug(varstring('state', $state));
    my $result_elements= $result->{elements};
    check_result($$result_elements[0], 'Name', 'blah');
    check_result($$result_elements[1], 'String', '"123"');
    check_result($$result_elements[2], 'Number', '456');

    #$state= { input => 'blah ("123", xyz(456 * 2)); end;', pos=>0 };
    $state= { input => 'blah.("123", xyz.(456.*.2)); end;', pos=>0 };

    $result= match($::Tokenlist, $state);
    $log->debug(varstring('match Tokenlist result 2', $result));
    $log->debug(varstring('state', $state));
    $result_elements= $result->{elements};
    #check_result($$result_elements[0], 'Name', 'blah');
    #check_result($$result_elements[1], 'Period', '.');
    my $i= 0;
    my $expected=
        [[ 'Name',      'blah'],
         [ 'Period',    '.'],
         [ 'Lparen',    '('],
         [ 'String',    '"123"'],
         [ 'Comma',     ','],
         [ 'Name',      'xyz'],
         [ 'Period',    '.'],
         [ 'Lparen',    '('],
         [ 'Number',    456],
         [ 'Period',    '.'],
         [ 'Name',      '*'],
         [ 'Period',    '.'],
         [ 'Number',    2],
         [ 'Rparen',    ')'],
         [ 'Rparen',    ')'],
         [ 'Semicolon', ';'],
         [ 'Name',      'end'],
         [ 'Semicolon', ';'],
         ];
    map {
        my ($e)= $_;
        #$log->debug(varstring('e', $e));
        check_result($$result_elements[$i], $$e[0], $$e[1]);
        ++$i;
    } @$expected;

    my $xml= <<"";
<row>
				<entry>.1 rtpMIBObjects</entry>
				<entry>Objekte der &RTP; MIB</entry>
				<entry></entry>
</row>

    $state= { input => $xml, pos=>0 };

    #$result= match($::Elem, $state);
    #$log->debug(varstring('match Elem result', $result));
    #$log->debug(varstring('state', $state));
    #check_result($result, 'Elem', $state->{input});

    {
    #my $top= "Elem";
    my $top= "Contentlist";
    no strict 'refs';
    $result= match(${"::$top"}, $state);
    $log->debug(varstring('match $top result', $result));
    $log->debug(varstring('state', $state));
    check_result($result, $top, $state->{input});
    }

    # FIXME: Get this test to work
    return;
    $log->debug("--- Testing Program...");
    $log->debug("Program=$::Program.");
    $state= { input => $result, pos=>0 };
    $result= match($::Program, $state);
    $log->debug(varstring('match Program result', $result));
    $log->debug(varstring('state', $state));
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
    def 'foo', {elt=>'bar'};
    $log->debug(varstring('',$::foo));
    #assert($::foo->{elt} eq 'bar');

    (1 == $#ARG) or die($usage);

    my $grammar_filename= shift();
    open(GRAMMAR, "< $grammar_filename")
        or die("Can't open grammar file \`$grammar_filename'.");
    $INPUT_RECORD_SEPARATOR= undef;
    my $grammar= <GRAMMAR>;
    $INPUT_RECORD_SEPARATOR= "";
    close(GRAMMAR);
    #$log->debug("grammar='$grammar'");

    $log->debug("---Evaluating grammar...");
    #eval($grammar);
    #use $grammar_filename;
    require $grammar_filename;
    #$log->debug(varstring('exprlist', $::exprlist));
    $log->debug("Grammar evaluated.");

    # Run self-test
    test();

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
