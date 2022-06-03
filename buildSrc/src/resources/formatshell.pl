#!/usr/local/bin/perl
# fmt.script - format scripts in awk, csh, ksh, perl, sh
#
# we do:
# standardize indentation (an indent is one tab by default)
# strip trailing whitespace
# change ${var} to $var where possible
# change ">x" to "> x" for shell scripts
# change "[ ... ]" to "test ..." for Bourne shell scripts
#
# we may do someday, but these are harder:
# convert $VAR to $var unless a setenv or default environment variable
# possibly prepending stuff from template.sh
# "if ... \nthen", for ... in\ndo", "while/until ... \ndo", "fn()\n{"
#
# to have fmt.script reformat itself (a fair test, yes?) try:
#	fmt.script     fmt.script fmt.script.new	# use tabs for indents
#	fmt.script -s4 fmt.script fmt.script.new	# indent is fou

use warnings FATAL => 'all';
use strict;
use File::Compare;

# variable initialization
my $pr		= $0;		# name of this program
$pr		=~ s|.*\/||;	# basename of this program
my $ilen		= 1;		# characters per indent
my $caselevel	= 0;		# case level for sh/ksh scripts
my $type		= '';		# unknown type

# usage message
my $usage		= "usage:
$pr [--tab|--space] [--size=count] [--ksh|--sh] [infile1 [infile2...]]
";

# process command options
use Getopt::Long;
my $tab;
my $space;
my $sh;
my $ksh;
GetOptions(
	"tab"    => \$tab,
	"space"  => \$space,
	"size:i" => \$ilen,
	"sh"     => \$sh,
	"ksh"=>\$ksh
) || die $usage;
my $ichar		= "\t";
if($tab){
	$ichar		= "\t";
}
if($space){
	$ichar		= " ";
}
if($sh){
	$type="sh";
}
if($ksh){
	$type="ksh";
}

if($#ARGV < 0) {
	print "No files to format\n";
	exit;
}
#============================================================================
# regular expression stuff
#
# list of regex to increase next line
my $flow = '^(if|for|foreach|while|until)\s';	# flow control statements
my $caseelem = '^[^\(\)]+\)(\s|$)';	# sh case element (no internal parens!)
my $function = '\(\s*\)(\s*\{\s*)?$';	# sh lists, perl functions, code blocks
my $list = '[\{\(]\s*$';			# list executed, possibly in subshell
# MNS: There is no sense to reformat HEREDOC, especially if you never decrease indentation
#$hereis = '<<\s*(\S+)\s*$';		# hereis documents

# list of regex to decrease this line
my $endflow = '^(done|end|endif|fi)\b';	# fi/done/end/endif
my $endfn = '^\}';				# end of function declaration or block
my $endlist = '^[\}\)]';			# end of list or block execution
my $endcaseelem = '^(;;|breaksw)';		# end of sh/csh case elements

# list of regex to decrease this line *and* increase next line
my $else = '^(\}\s*)?(else|elif|elsif|else\s+if)\b'; 	# else/elsif variants

# list of regex to *postpone* indentation until *next* line
my $postponeinc = '^(then|do)\b';		# sh if/for/while/until ... \nthen/do

# list of useful regex - watch out for oneliners like
#	"for ... ; do ... ; done"
#	"case ... in ; ...) ... ;; ...) ... ;; esac"
#	"...) ... ;;		# part of condensed form case statement
# we could even have something like
#	for ... ; do ... ; done | whatever ...
my $linecaseelem = "$caseelem.*;;";	# handle condensed form case element
my $endinline = ';\s*(done|end|esac|fi)\b'; # inline flow statement end
my $falseincnext = "$linecaseelem|$endinline"; # false alarm

# regex arrays @decthis and @incnext notes:
# 1) $caseelem regex is pushed onto @incnext only while inside a sh/ksh case
# 2) $hereis regex is pushed onto @incnext only for sh/ksh/csh scripts
# 3) $else has to go *before* the other regex in @decthis, because of $endfn
my @decthis = ($else, $endflow, $endfn, $endlist, $endcaseelem);
my @incnext = ($else, $flow, $function, $list);
if ($type =~ /sh$/) {
	# MNS: There is no sense to reformat HEREDOC, especially if you never decrease indentation
	#push(@incnext, $hereis);
}

#============================================================================

# start our work - open files, etc.
my $istr		= $ichar x $ilen; # indent string (typically "    " or "\t")

sub format_from_to {
	my ($input, $output) = @_;
	#print STDOUT "$pr: Formatting $input\n";
	open( INPUT, "$input")		|| die "$pr: Unable to open $input: $!\n";
	open(OUTPUT, ">$output")	|| die "$pr: Unable to create $output: $!\n";

	# Initial indent level
	my $ilevel = 0;
	# Flag to mark that multiline string detected
	my $multiline = 0;

	# I hate inconsistent multiple empty lines in random places
	my $prevempty = 0;

	# process input
	while (my $line = <INPUT>) {

		# initial processing for every line
		my $doincnext = 0;		# increase indent on next line?
		my $dodecthis = 0;		# decrease indent on this line?
		my $dopostponeinc = 0;		# postpone increase indent on this line?
		my $badcaseelem = 0;		# do we have a bad case element?
		my $comment = '';		# assume this line has no inline comment
		chop($line);		# strip newline

		if($multiline == 1) {
			print OUTPUT $line, "\n"; #output line without any change
			#check for the end of multiline string
			if ($line !~ /#/) {
				my @chars = split(//, $line);
				my $nquote = grep(/[\'\"\`]/, @chars);
				if ($nquote == 1) {
					$multiline = 0;
				}
			}
			next;
		}

		$line =~ s/\s+$//;		# strip trailing whitespace
		$line =~ s/^\s+//;		# strip indentation

		if ($line !~ /#/) {
			my @chars = split(//, $line);
			my $nquote = grep (/[\'\"\`]/, @chars);
			if ($nquote == 1) {
				if ($multiline == 0) {
					$multiline = 1;
				}
			}
		}

		# blank lines and comment lines can be passed straight through, with
		# no effect on indentation
		if ($line =~ /^$/) {
			if (!$prevempty) {
				print OUTPUT "\n";
				$prevempty = 1;
			}
			next;
		} else {
			$prevempty = 0;
		}
		if ($line =~ /^#/) {
			print OUTPUT $istr x $ilevel, $line, "\n";
			next;
		}

		# inline comments can be stripped to protect them from other substitutions;
		# the tricky part is deciding what is a comment, since hashmarks can
		# appear inside quotes;
		# we will err on the safe side; meaning we will not strip the comment
		# unless we are pretty sure it is safe
		if ($line =~ s/(\s+#[^'"`]+$)//) {
			$comment = $1;
		}
		# inline substitutions				# discouraged	preferred
		$line =~ s/([^\\])\$\{(\w+)\}(\W|$)/$1\$$2$3/g;      # ${var}        $var
		if ($type =~ /^k?sh$/) {
			# MNS: redirection reformatting disabled because it breaks
			# embedded XML
			# XXX: find a way to ignore > and < in quotes
			#$line =~ s,>([\w\$]),> $1,;		# x>file	x> file
			#$line =~ s,(\w)>([\w\$]),$1 > $2,;		# x> file	x > file
			# 					# [ ... ]	test ...
			$line =~ s/^((if|while)(\s+))?(\[)(.*[^\\"'])(\])/$1test$5/;
		}

		# track case level - use this to see if we should check for case elements
		# there is no point in checking for case elements if we aren't in a
		# ksh/sh script and actually inside a case statement
		if ($type =~ /^k?sh$/) {
			if ($line =~ /^case\b/ && $line !~ /$linecaseelem/) {
				($caselevel == 0) && push(@incnext, $caseelem);
				$caselevel++;
			} elsif ($line =~ /^esac\b/) {
				$caselevel--;
				($caselevel == 0) && pop(@incnext);
			}
		}

		# see if we are going to decrease this line's indentation
		foreach my $regex (@decthis) {
			($line =~ /$regex/) && ($dodecthis=1) && last;
		}
		if ($dodecthis == 1) {
			$ilevel--;
		}

		# handle "command ;;" problems, but make sure we don't trip over
		# condensed form case
		if ($type =~ /^k?sh$/ && $line =~ /.;;/ && $line !~ /$linecaseelem/) {
			$badcaseelem = 1;
			$line =~ s/\s*;;//;
		}

		# see if we are going to postpone increasing this line's indentation
		if ($line =~ /$postponeinc/) {
			$dopostponeinc = 1;
			$ilevel--;
		}

		# print this line (but don't indent blank lines)
		if (! length($line)) {
			print OUTPUT "\n";
		} else {
			print OUTPUT $istr x $ilevel, $line, $comment, "\n";
		}

		# if we found a bad case element print the closing ";;" which we stripped
		if ($badcaseelem) {
			$ilevel--;
			print OUTPUT $istr x $ilevel, ";;\n";
		}

		# we postponed it above, but make sure we do it now
		if ($dopostponeinc == 1) {
			$ilevel++;
		} else {
			# see if we are going to increase the next line's indentation
			foreach my $regex (@incnext) {
				($line =~ /$regex/) && ($doincnext=1) && last;
			}
			if ($doincnext == 1) {
				#XXX: try to disable this block if we ever encounter formatting problems
				if (1) {
					#Looks like $regex is always undefined
					#if ($regex eq $flow) {
					# if we are bourne shell, we can do some advanced checking
					if ($type =~ /^k?sh$/) {
						# for "for" and "case" we can do further checking, but
						# for "if", "elif", "else", and "while" we usually can't
						# prove anything; however there is one small exception
						if ($line =~ /^for/) {
							if ($line !~ /^for\s+\w+($|\s+[;#]|\s+in\s+\S+)/) {
								$doincnext = 0;
							}
						} elsif ($line =~ /^case/) {
							if ($line !~ /^case\s+\S+\s+in\b/) {
								$doincnext = 0;
							}
						} else {
							# flow keywords can be in quoted multi-line text, like:
							# usage="$pr [opts]\nif you like chocolate, honk!"\n
							# this can sometimes be reliably detected (assuming the
							# code actually runs)
							# if the line has no comments and exactly 1 quote char,
							# it is probably like the usage example above
							if ($line !~ /#/) {
								my @chars = split(//, $line);
								my $nquote = grep(/[\'\"\`]/, @chars);
								if ($nquote == 1) {
									$doincnext = 0;
								}
							}
						}
					}
				}
				if ($doincnext == 1 && $line !~ /$falseincnext/) {
					$ilevel++;
				}
			}
		}
		#print STDERR $pr, ": $doincnext/$dodecthis=$ilevel:", $line, "\n";
	}
	close(INPUT);
	close(OUTPUT);
}
for(my $i=0; $i<=$#ARGV; $i++){
	my $input = $ARGV[$i];
	format_from_to( $input, "$input.tmp");
	if (compare($input, "$input.tmp") != 0) {
		use File::Copy "cp";
		cp("$input.tmp",$input) || die "$pr: Cannot copy temporary file $input.tmp over original $input: $!\n";
		print "Reformatted $input\n";
	}
	unlink "$input.tmp" || die "$pr: Cannot delete temporary file $input: $!\n";
}
exit;
