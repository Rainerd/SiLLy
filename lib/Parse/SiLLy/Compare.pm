package Parse::SiLLy::Compare;
use strict;

# --------------------------------------------------------------------
use Exporter;
@Parse::SiLLy::Compare::ISA= qw(Exporter);
@Parse::SiLLy::Compare::EXPORT=qw(compare);

use Carp;

# --------------------------------------------------------------------
# @return whether the given LHS matches the given RHS.

# This code started its life as Data::Compare, by Fabien Tassin
# fta@sofaraway.org, kudos for publishing it!

sub compare($$);
sub compare($$)
{
    croak "Usage: compare(x, y)\n" unless $#_ == 1;
    my ($x, $y)= (@_);

    my $refx= ref($x);
    my $refy= ref($y);

    unless ($refx || $refy)	# both are scalars
    {
        (defined($x) && defined($y) && $x eq $y) # both are defined and equal
            || ( ! defined($x) && ! defined($y)); # or none are defined
    }
    elsif ($refx ne $refy) {	# not the same type
	0;
    }
    elsif ($x == $y) {		# exactly the same reference
	1;
    }
    elsif ($refx eq 'SCALAR') {
	compare($$x, $$y);
    }
    elsif ($refx eq 'ARRAY') {
	if ($#$x == $#$y) {	# same length
	    my $i = -1;
	    for (@$x) {
		$i++;
		return 0 unless compare($$x[$i], $$y[$i]);
	    }
	    1;
	}
	else {
	    0;
	}
    }
    elsif ($refx eq 'HASH') {
	return 0 unless scalar keys %$x == scalar keys %$y;
	for (keys %$x) {
	    next unless defined $$x{$_} || defined $$y{$_};
	    return 0 unless defined $$y{$_} && compare($$x{$_}, $$y{$_});
	}
	1;
    }
    elsif ($refx eq 'REF') {
	0;
    }
    elsif ($refx eq 'CODE') {
	1;	     #changed for log4perl, let's just accept coderefs
    }
    elsif ($refx eq 'GLOB') {
	0;
    }
    else {			# a package name (object blessed)
	my ($type) = "$x" =~ m/^$refx=(\S+)\(/o;
	if ($type eq 'HASH') {
	    my %x = %$x;
	    my %y = %$y;
	    compare(\%x, \%y);
	}
	elsif ($type eq 'ARRAY') {
	    my @x = @$x;
	    my @y = @$y;
	    compare(\@x, \@y);
	}
	elsif ($type eq 'SCALAR') {
	    my $x = $$x;
	    my $y = $$y;
	    compare($x, $y);
	}
	elsif ($type eq 'GLOB') {
	    0;
	}
	elsif ($type eq 'CODE') {
	    1;	     #changed for log4perl, let's just accept coderefs
	}
	else {
	    croak "Can't handle $type type.";
	}
    }
}

1;
