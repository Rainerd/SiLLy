#!/usr/bin/perl

# --------------------------------------------------------------------
"Parses, according to the given grammar, the given input. Produces an
appropriately structured hash. ";

# --------------------------------------------------------------------
use strict;
use English;

# --------------------------------------------------------------------
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
    $self->{logger}->debug("$name: constructed.");
    return $self;
}

# --------------------------------------------------------------------
sub info($) {
    my ($self)= shift;
    my $ctx= #ref($self) .
        "$self->{name}";
    #print("$ctx: @_\n");
    $self->{logger}->info("$ctx: @_\n");
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
sub varshow($$) {
 my ($name, $val)= @_;
 Data::Dumper->Dump([$val], [$name]);
}

# --------------------------------------------------------------------
my $print_type;
#$print_type= 1;
sub print_type($$) {
    my ($context, $obj)= @ARG;
    if ($print_type) { printf("$context: (type='$obj->{_}')\n"); }
}

# --------------------------------------------------------------------
my $terminal_log;
# --------------------------------------------------------------------
sub terminal($)
{
    my $log= $terminal_log;
    my $context= 'terminal';
    #printf("$context: " . varshow('ARG',\@ARG) . "\n");
    
    my $result= { element => $ARG[0], _ => $context};
    printf("$context: " . varshow('element',$result->{element}) . "\n");
    #printf("$context: result=$result\n");
    print_type($context, $result);
    return $result;
}

# --------------------------------------------------------------------
my $terminal_match_log;
# --------------------------------------------------------------------
sub terminal_match($$)
{
    my $log= $terminal_match_log;
    my $context= 'terminal_match';
    my ($t, $state)= @ARG;
    #printf("$context: running\n");
    #printf("$context: \@ARG='@ARG'\n");
    printf("$context: " . varshow('ARG',\@ARG) . "\n");
    
    my ($match)= $state->{input} =~ m{($t->{element})};
    if (defined($match))  {
	print("$context: matched text: '$match'\n");
	my $result= {_=>$t, text=>$match};
	return ($result);
    } else {
	print("$context: not matched: '$t->{element}'\n");
	return (undef);
    }
}

# --------------------------------------------------------------------
my $construction_log;
# --------------------------------------------------------------------
sub construction
{
    my $log= $construction_log;
    my $context= 'construction';
    printf("$context: running\n");
    #printf("$context: \@ARG='@ARG'\n");
    printf("$context: " . varshow('ARG',\@ARG) . "\n");
    
    #my $result= { _ => $context, elements => \@ARG };
    my $result= { elements => \@ARG };
    $result->{_}= $context;
    printf("$context: " . varshow('elements',$result->{elements}) . "\n");
    #printf("$context: result=$result\n");
    print_type($context, $result);
    return $result;
}

# --------------------------------------------------------------------
my $construction_match_log;

# --------------------------------------------------------------------
my $alternation_log;
# --------------------------------------------------------------------
sub alternation
{
    my $log= $alternation_log;
    my $context= 'alternation';
    #printf("$context: '@ARG'\n");
    my $result= { _ => $context, elements => \@ARG };
    printf("$context: " . varshow('elements',$result->{elements}) . "\n");
    print_type($context, $result);
    return $result;
}

# --------------------------------------------------------------------
my $alternation_match_log;
# --------------------------------------------------------------------
sub alternation_match($$)
{
    my $log= $alternation_match_log;
    my ($t, $state)= @ARG;
    #$log->debug("$context: \@ARG='@ARG'\n");
    printf("$context: " . varshow('ARG',\@ARG) . "\n");

    # foreach $element in $t->{elements}
    map {
	my $i= $_;
	print("i=$i\n");
	my $element= $ {@{$t->{elements}}}[$i];
	print(varshow('element', $element));
	my ($match)= match($element, $state);
	if ($match)  {
	    print("$context: matched element: " . varshow($i,$element));
	    print("$context: matched text: '$match'\n");
	    return ($match);
	}
    } (0 .. $#{@{$t->{elements}}});
    print("$context: not matched: '$t->{name}'\n");
    return (undef);
}

# --------------------------------------------------------------------
my $optional_log;
# --------------------------------------------------------------------
sub optional($)
{
    my $log= $optional_log;
    my $context= 'optional';
    #printf("$context: '@ARG'\n");
    my $result= { _ => $context, element => $ARG[0] };
    printf("$context: " . varshow('element',$result->{element}) . "\n");
    print_type($context, $result);
    return $result;
}

# --------------------------------------------------------------------
my $optional_match_log;

# --------------------------------------------------------------------
my $pelist_log;
# --------------------------------------------------------------------
sub pelist($$)
{
    my $log= $pelist_log;
    my $context= 'pelist';
    printf("$context: '@ARG'\n");
    my $result= { _ => $context, element => $ARG[0], separator => $ARG[1] };
    printf("$context: " . varshow('element',$result->{element})
           . varshow('separator',$result->{separator}) . "\n");
    print_type($context, $result);
    return $result;
}
# --------------------------------------------------------------------
my $pelist_match_log;

# --------------------------------------------------------------------
my $nelist_log;
# --------------------------------------------------------------------
sub nelist($$)
{
    my $log= $nelist_log;
    my $context= 'nelist';
    printf("$context: " . varshow('ARG',\@ARG) . "\n");
    my $result= { _ => $context, element => $ARG[0], separator => $ARG[1] };
    printf("$context: " . varshow('element',$result->{element})
           . varshow('separator',$result->{separator}) . "\n");
    print_type($context, $result);
    return $result;
}

# --------------------------------------------------------------------
my $nelist_match_log;

# --------------------------------------------------------------------
my $match_log;
# --------------------------------------------------------------------
sub match($$)
{
    my $log= $match_log;
    my $context= 'match';
    my ($t, $state)= @ARG;
    if ('terminal' eq $t->{_}) {
	return (terminal_match($t, $state));
    } elsif ('alternation' eq $t->{_}) {
	return (alternation_match($t, $state));
    } else {
	die("$context: Unsupported type $t->{_}");
    }
}

# --------------------------------------------------------------------
sub handle_item
{
    printf("$ARG\n");
    return;
}

# --------------------------------------------------------------------
my $def_log;
# --------------------------------------------------------------------
sub def($$)
{
    my $log= $def_log;
    my ($name,$val)= @ARG;
    #print(varshow('val',$val) . "\n");
    eval("\$::$name=\$val;");
    #$::def_val_= $val; eval("\$::$name=\$::def_val_;");
    $val->{name}= $name;
    print("defined '$name' as $val.\n\n");
}

# --------------------------------------------------------------------
my $main_log;

# --------------------------------------------------------------------
sub init {
    Log::Log4perl->easy_init($INFO);
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
    my $context= 'main';
    
    # Test 'def'
    def 'foo', {elt=>'bar'};
    print(varshow('',$::foo) . "\n");
    #assert($::foo->{elt} eq 'bar');

    (1 == $#ARG) or die($usage);

    my $grammar_filename= shift();
    open(GRAMMAR, "< $grammar_filename")
        or die("Can't open grammar file \`$grammar_filename'.");
    $INPUT_RECORD_SEPARATOR= undef;
    my $grammar= <GRAMMAR>;
    $INPUT_RECORD_SEPARATOR= "";
    close(GRAMMAR);
    print("grammar='$grammar'\n");

    print("\n---Evaluating grammar...\n");
    #eval($grammar);
    #use $grammar_filename;
    require $grammar_filename;
    print("Evaluated - program=$::program.\n");

    my $state;
    my $result;

    print("\n---Testing terminal_match...\n");
    $state= { input => 'blah 123' };
    $result= terminal_match($::name, $state);
    print("$context: " . varshow('tm name result', $result));
    print("$context: " . varshow('state', $state));
    $result= terminal_match($::number, $state);
    print("$context: " . varshow('tm number result', $result));
    print("$context: " . varshow('state', $state));

    print("\n---Testing alternation_match...\n");
    $state= { input => 'blah 123' };
    $result= alternation_match($::token, $state);
    print("$context: " . varshow('am token result 1', $result));
    print("$context: " . varshow('state', $state));
    $result= alternation_match($::token, $state);
    print("$context: " . varshow('am token result 2', $result));
    print("$context: " . varshow('state', $state));

    print("\n$context: Reading input file...\n");
    my $input= shift();
    open(INPUT, "< $input") or die("Can't open \`$input'.");
    $INPUT_RECORD_SEPARATOR= "---\n";
    while (<INPUT>)
    {
        #print("item=\"$ARG\";\n");
        handle_item($ARG);
    }
    $INPUT_RECORD_SEPARATOR= "";
    close(INPUT);
}

# --------------------------------------------------------------------
main(@ARGV);

# --------------------------------------------------------------------
# EOF
