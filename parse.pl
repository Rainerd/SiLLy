#!/usr/bin/perl

# --------------------------------------------------------------------
"Copyright (c) 2004 by Rainer Blome

Copying and usage conditions for this document are specified by
Rainer's Open License, Version 1, in file LICENSE.txt.

In short, you may use or copy this document as long as you:
o Keep this copyright and permission notice.
o Use it ,,as is``, at your own risk -- there is NO WARRANTY WHATSOEVER.
o Do not use my name in advertising.
o Allow free copying of derivatives.
";

# 24.11.04 17:47:32
# --------------------------------------------------------------------
"Parses, according to the given grammar, the given input. Produces an
appropriately structured hash. 


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

";

# --------------------------------------------------------------------
use strict;
use English;

# --------------------------------------------------------------------
#push(@INC, "~/comp/Log-Log4perl-0.49/blib/lib");
#use lib "~/comp/Log-Log4perl-0.49/blib/lib";
use lib "/home1/ffm/blome/comp/Log-Log4perl-0.49/blib/lib";
use Log::Log4perl qw(:easy);
use Data::Dumper;

package Logger;

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
sub info($) {
    my ($self)= shift;
    my $ctx= #ref($self) .
        "$self->{name}";
    #print("$ctx: @_\n");
    $self->{logger}->info("$ctx: @_");
}

# --------------------------------------------------------------------
sub debug($) {
    my ($self)= shift;
    my $ctx= "$self->{name}";
    $self->{logger}->debug("$ctx: @_");
}

# --------------------------------------------------------------------
package main;

my $usage="Usage: perl parse.pl grammar.pl in > out";

# --------------------------------------------------------------------
"Example Grammar:

delimiter ::= '---'
name ::= '\w+'
whitespace ::= '\s+'
#owhite ::? whitespace
owhite ::= '\s*'
colon ::= ':'
linefeed ::= '\n'
#olinefeed ::? linefeed
rest ::= '.*'
#linerest ::= rest olinefeed
assign ::= name owhite colon owhite rest
file ::* assign linefeed

Example Input:
---
a: b
c: 4
";

# --------------------------------------------------------------------
# CAVEAT: you should resist the temptation to call this 'dump'
# -- Instead of calling this function, Perl will dump core.
sub varstring($$) {
    my ($name, $val)= @_;
    Data::Dumper->Dump([$val], [$name]);
}

# --------------------------------------------------------------------
# CAVEAT: you should resist the temptation to call this 'dump'
# -- Instead of calling this function, Perl will dump core.
sub vardescr($$) {
    my ($name, $val)= @_;
    if (ref($val) eq "HASH"
        && exists($val->{name})
        && undef == ref($val->{name}))
    {
        return ("$name: $val->{name}\n");
    }
    varstring($name, $val);
}

# --------------------------------------------------------------------
# Conditional logging of results
my $log_result;
#$log_result= 1;
sub log_result($$) {
    my ($log, $result)= @ARG;
    if ($log_result) {
        $log->debug("Type='$result->{_}':");
        $log->debug(varstring('result',$result));
    }
}

# --------------------------------------------------------------------
sub log_args($$$)
{
    my ($log, $context, $argl)= @ARG;
    #$log->debug("running");
    #$log->debug($context . ': ' . varstring('ARG',\@ARG));
    if ('ARRAY' ne ref($argl)) {
        die("log_args: second argument is not an array reference: "
            . ref($argl) . " $argl\n");
    }
    #return;
    my @description= map {
        #print("item: $ARG\n");
        vardescr('', $ARG);
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
    my ($state)= @_;
    my $input= $state->{input};
    #my $pos= $state->{pos};
    return (undef == ref($input) 
	    ? length($input)-1 < $state->{pos}
	    : $#{@$input} < $state->{pos} );
}

# --------------------------------------------------------------------
my $terminal_log;
# --------------------------------------------------------------------
sub terminal($)
{
    my $log= $terminal_log;
    log_args($log, 'NAME_NOT_YET_SET', \@ARG);
    
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
    log_args($log, $t->{name}, \@ARG);
    
    my $input= $state->{input};
    my $pos= $state->{pos};
    #my ($match)= $input =~ m{^($t->{pattern})}g;
    my $match;
    #$log->debug("$t->{name}: ref(input)=" . ref($input) . ".");
    if (eoi($state)) {
	$log->info("$t->{name}: End Of Input reached");
	return (undef);
    }
    if ('ARRAY' eq ref($input)) {
	$log->debug("$t->{name}: state->pos=$state->{pos}, input[0]->name=", $ {@$input}[0]->{name});
	#if ($#{@$input} < $pos) {
	#    $log->info("$t->{name}: End of input reached");
	#    return (undef);
	#}
	$match= $ {@$input}[$pos];
	if ($t == $match->{_}) {
	    #$log->debug("$t->{name}: matched token: " . varstring('match', $match));
	    $log->debug("$t->{name}: matched token: $t->{name}, text: '$match->{text}'");
	    my $result= $match;
	    $state->{pos}= $pos + 1;
	    #$log->debug(varstring('state', $state));
	    $log->debug("$t->{name}: state->pos=$state->{pos}");
	    return ($result);
	} else {
	    $log->debug("$t->{name}: token not matched: '$t->{name}'");
	    return (undef);
	}
    } else {
	$log->debug("$t->{name}: state->pos=$state->{pos}, substr(input, pos)=", substr($input, $pos));
	#if (length($input)-1 < $pos) {
	#    $log->info("$t->{name}: End Of Input reached");
	#    return (undef);
	#}
	($match)= substr($input, $pos) =~ m{^($t->{pattern})}g;
	if (defined($match))  {
	    $log->debug("$t->{name}: matched text: '$match'");
	    my $result= {_=>$t, text=>$match};
	    $state->{pos}= $pos + length($match);
	    #$log->debug(varstring('state', $state));
	    $log->debug("$t->{name}: state->pos=$state->{pos}");
	    return ($result);
	} else {
	    $log->debug("$t->{name}: pattern not matched: '$t->{pattern}'");
	    return (undef);
	}
    }
}

# --------------------------------------------------------------------
my $construction_log;
# --------------------------------------------------------------------
sub construction
{
    my $log= $construction_log;
    log_args($log, 'NAME_NOT_YET_SET', \@ARG);
    
    my $result= { _ => $log->{name}, elements => \@ARG };
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
    #$log->debug("\@ARG='@ARG'");
    log_args($log, $t->{name}, \@ARG);
    #$log->debug(varstring('ARG',\@ARG));
    #$log->debug("$t->{name}");
    $log->debug("$t->{name}: state->pos=$state->{pos}");
    my $result= [];
    my $saved_pos= $state->{pos};

    # foreach $element in $t->{elements}
    map {
	my $i= $_;
	$log->debug("$t->{name}: i=$i");
	my $element= $ {@{$t->{elements}}}[$i];
	#$log->debug(varstring('element', $element));
	$log->debug("$t->{name}: element=$element->{name}");
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
	    # FIXME: Is this the best place to put backtracking?
	    $state->{pos}= $saved_pos;
	    return (undef);
	}
	#$log->debug("$t->{name}: matched element: " . varstring($i,$element));
	$log->debug("$t->{name}: matched element $i: $element->{name}");
	#$log->debug("$t->{name}: element value: " . varstring('match', $match));
	push(@$result, $match);
    } (0 .. $#{@{$t->{elements}}});
    $log->debug("$t->{name}: matched: '$t->{name}'");
    $log->debug(varstring('result', $result));
    return ($result);
}

# --------------------------------------------------------------------
my $alternation_log;
# --------------------------------------------------------------------
sub alternation
{
    my $log= $alternation_log;
    #$log->debug("\@ARG='@ARG'");
    log_args($log, 'NAME_NOT_YET_SET', \@ARG);
    my $result= { _ => $log->{name}, elements => \@ARG };
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
    #$log->debug("$t->{name}: \@ARG='@ARG'");
    log_args($log, $t->{name}, \@ARG);
    #$log->debug(varstring('ARG',\@ARG));
    #$log->debug("$t->{name}");
    $log->debug("$t->{name}: state->pos=$state->{pos}");
    if (eoi($state)) {
	$log->info("$t->{name}: End Of Input reached");
	return (undef);
    }

    # foreach $element in $t->{elements}
    map {
	my $i= $_;
	$log->debug("$t->{name}: i=$i");
	my $element= $ {@{$t->{elements}}}[$i];
	#$log->debug(varstring('element', $element));
	$log->debug("$t->{name}: element=$element->{name}");
	my ($match)= match($element, $state);
	if ($match)  {
	    #$log->debug("$t->{name}: matched element: " . varstring($i,$element));
	    $log->debug("$t->{name}: matched value: " . varstring('match', $match));
	    return ($match);
	}
    } (0 .. $#{@{$t->{elements}}});
    $log->debug("$t->{name}: not matched: '$t->{name}'");
    return (undef);
}

# --------------------------------------------------------------------
my $optional_log;
# --------------------------------------------------------------------
sub optional($)
{
    my $log= $optional_log;
    #$log->debug("'@ARG'");
    log_args($log, 'NAME_NOT_YET_SET', \@ARG);
    my $result= { _ => $log->{name}, element => $ARG[0] };
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
    #$log->debug("$t->{name}: \@ARG='@ARG'");
    log_args($log, $t->{name}, \@ARG);
    #$log->debug(varstring('ARG',\@ARG));
    #$log->debug("$t->{name}");
    $log->debug("$t->{name}: state->pos=$state->{pos}");
    my $element= $t->{element};
    #$log->debug(varstring('element', $element));
    $log->debug("$t->{name}: element=$element->{name}");

    # FIXME: Add backtracking of state in case of mismatch

    my ($match)= match($element, $state);
    if (defined($match)) {
	#$log->debug("$t->{name}: matched element: " . varstring($i,$element));
	$log->debug("$t->{name}: matched " . varstring('value', $match));
	return ($match);
    }
    $log->debug("$t->{name}: not matched: '$t->{name}' (resulting in empty string)");
    return ('');
}

# --------------------------------------------------------------------
my $pelist_log;
# --------------------------------------------------------------------
sub pelist($$)
{
    my $log= $pelist_log;
    #$log->debug("\@ARG='@ARG'");
    log_args($log, 'NAME_NOT_YET_SET', \@ARG);
    my $result= { _ => $log->{name}, element => $ARG[0], separator => $ARG[1] };
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
    #$log->debug("$t->{name}: \@ARG='@ARG'");
    log_args($log, $t->{name}, \@ARG);
    my $element=   $t->{element};
    my $separator= $t->{separator};
    #$log->debug("$t->{name}");
    $log->debug("$t->{name}: state->pos=$state->{pos}");

    my $result= [];
    while (1) {
	my ($match)= match($element, $state);
	if ( ! defined($match)) { return ($result); }
	push(@$result, $match);
	($match)= match($separator, $state);
	if ( ! defined($match)) { return ($result); }
    }
}

# --------------------------------------------------------------------
my $nelist_log;
# --------------------------------------------------------------------
sub nelist($$)
{
    my $log= $nelist_log;
    #$log->debug(varstring('ARG',\@ARG));
    log_args($log, 'NAME_NOT_YET_SET', \@ARG);
    my $result= { _ => $log->{name}, element => $ARG[0], separator => $ARG[1] };
    $log->debug(varstring('element',$result->{element}));
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
    #$log->debug("$t->{name}: \@ARG='@ARG'");
    log_args($log, $t->{name}, \@ARG);
    #$log->debug(varstring('ARG',\@ARG));
    my $element=   $t->{element};
    my $separator= $t->{separator};
    #$log->debug("$t->{name}");
    $log->debug("$t->{name}: state->pos=$state->{pos}");

    my $result= [];
    while (1) {
	my ($match)= match($element, $state);
	if ( ! defined($match)) {
	    if (0 > $#{@$result}) { return (undef); }
	    else { return ($result); }
	}
	push(@$result, $match);
	($match)= match($separator, $state);
	if ( ! defined($match)) { return ($result); }
    }
}

# --------------------------------------------------------------------
my $match_log;
# --------------------------------------------------------------------
sub match($$)
{
    my $log= $match_log;
    my ($t, $state)= @ARG;
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
    $log->debug("grammar='$grammar'");

    $log->debug("---Evaluating grammar...");
    #eval($grammar);
    #use $grammar_filename;
    require $grammar_filename;
    $log->debug(varstring('exprlist', $::exprlist));
    $log->debug("Evaluated - program=$::program.");

    my $state;
    my $result;

    $log->debug("--- Testing terminal_match...");
    $state= { input => 'blah 123 456', pos=>0 };
    $result= terminal_match($::name, $state);
    $log->debug(varstring('tm name result', $result));
    $log->debug(varstring('state', $state));
    $result= terminal_match($::whitespace, $state);
    $log->debug(varstring('tm whitespace result 1', $result));
    $log->debug(varstring('state', $state));
    $result= terminal_match($::number, $state);
    $log->debug(varstring('tm number result 1', $result));
    $log->debug(varstring('state', $state));
    $result= terminal_match($::whitespace, $state);
    $log->debug(varstring('tm whitespace result 2', $result));
    $log->debug(varstring('state', $state));
    $result= terminal_match($::number, $state);
    $log->debug(varstring('tm number result 2', $result));
    $log->debug(varstring('state', $state));

    $log->debug("--- Testing alternation_match...");
    $state= { input => 'blah 123', pos=>0 };
    $result= alternation_match($::token, $state);
    $log->debug(varstring('am token result 1', $result));
    $log->debug(varstring('state', $state));
    $result= match($::whitespace, $state);
    $log->debug(varstring('match whitespace result 1', $result));
    $log->debug(varstring('state', $state));
    $result= match($::token, $state);
    $log->debug(varstring('match token result 2', $result));
    $log->debug(varstring('state', $state));

    $log->debug("--- Testing tokenization...");
    $state= { input => 'blah "123"  456', pos=>0 };
    $result= match($::tokenlist, $state);
    $log->debug(varstring('match tokenlist result 1', $result));
    $log->debug(varstring('state', $state));
    #$state= { input => 'blah ("123", xyz(456 * 2)); end;', pos=>0 };
    $state= { input => 'blah.("123", xyz.(456.*.2)); end;', pos=>0 };
    $result= match($::tokenlist, $state);
    $log->debug(varstring('match tokenlist result 2', $result));
    $log->debug(varstring('state', $state));

    $log->debug("--- Testing program...");
    $state= { input => $result, pos=>0 };
    $result= match($::program, $state);
    $log->debug(varstring('match program result', $result));
    $log->debug(varstring('state', $state));

    $log->debug("Reading input file...");
    my $input= shift();
    open(INPUT, "< $input") or die("Can't open \`$input'.");
    $INPUT_RECORD_SEPARATOR= "---";
    while (<INPUT>)
    {
        #$log->debug("item=\"$ARG\";");
        handle_item($ARG);
    }
    $INPUT_RECORD_SEPARATOR= "";
    close(INPUT);
}

# --------------------------------------------------------------------
main(@ARGV);

# --------------------------------------------------------------------
# EOF
