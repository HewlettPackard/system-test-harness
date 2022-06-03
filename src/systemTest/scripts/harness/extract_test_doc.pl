our $tr = $ENV{'report_mode'} eq 'tr';
our $ts = $ENV{'report_mode'} eq 'ts';
our $html = $ts || $tr;
our $script_name;
our $body_started = 0;
our $ignore_tables = 0;
our $head_printed = 0;
our $current_case= '';
our $current_phase = '';
our $steps_in_current_phase = 0;
our $has_goal = 0;
our $has_type = 0;
our $failed = 0;

sub put_header_if_needed {
	our $script_name;
	our $head_printed;
	if(!$head_printed && !$ignore_tables){
		$head_printed=1;
		print "<h3>$script_name</h3>\n";
		print "<table border='1'><tr><th>Manual / automatic</th><th>$script_name</th></tr>\n";
	}
}

sub put_body_start_if_needed {
	our $body_started;
	our $ignore_tables;
	our $failed;
	if(!$body_started && !$ignore_tables){
		$body_started=1;
		if($tr){
			if($ENV{'is_supported'} eq 'false'){
				print "<tr><td>Test result</td><td>Functionality not supported</td></tr>\n";
			}else{
				if($failed){
					print "<tr><td>Test result</td><td>Failed</td></tr>\n";
				}else{
					print "<tr><td>Test result</td><td>Passed</td></tr>\n";
				}
			}
		}else{
			print "<tr><td>Description (phases)</td><td><ol>\n";
		}
	}
}

sub put_end_if_needed {
	our $body_started;
	our $ignore_tables;
	if($body_started && !$ignore_tables){
		$body_started=0;
		if($tr){
			print "</table>\n";
		}else{
			print "</ol></td></tr></table>\n";
		}
	}
}

sub replace_line_with_doc {
	our $script_name;
	our $body_started;
	our $ignore_tables;
	our $failed;
	if( $_ =~ m/test_case_begin/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if( $current_case ){
			die "ERROR: Case $current_case was not finished but starting case $_ in $script_name\n";
		}
		$current_case = $_;
		$current_phase = '';
		$steps_in_current_phase = 0;
		$has_type = 0;
		$has_goal = 0;
		$failed = 0;
		if($html) {
			$_ =~ s/&/&amp;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			print "<h3>$_</h3>\n";
			print "<table border='1'><tr><th>Manual / automatic</th><th>$script_name</th></tr>\n";
			print "<tr><td>Title</td><td>$_</td></tr>\n";
		} else {
			print "\tTEST CASE: $_";
		}
		$body_started=0;
		$head_printed=1;
	}
	if( $_ =~ m/test_case_goal/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if( ! $current_case ){
			die "ERROR: Case was not started but documenting its goal in $script_name\n";
		}
		if( $has_goal ){
			die "ERROR: Goal for case $current_case was already set\n";
		}
		$has_goal = 1;
		if( $has_type ){
			die "ERROR: Wrong goal/type order for case $current_case. Should first set goal then specify type\n";
		}
		if($html) {
			$_ =~ s/&/&amp;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			put_header_if_needed();
			print "<tr><td>Goal</td><td>$_</td></tr>\n";
		} else {
			print "\t\tGOAL:   $_";
		}
		$body_started=0;
	}
	if( $_ =~ m/test_case_type/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if( ! $current_case ){
			die "ERROR: Case was not started but documenting its type in $script_name\n";
		}
		if( ! $has_goal ){
			die "ERROR: Wrong goal/type order for case $current_case. Should first set goal then specify type\n";
		}
		if( $has_type ){
			die "ERROR: Setting type twise for case $current_case in $script_name\n";
		}
		$has_type = 1;
		if($html) {
			$_ =~ s/&/&amp;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			put_header_if_needed();
			print "<tr><td>Type</td><td>$_</td></tr>\n";
		} else {
			print "\t\tTYPE:   $_";
		}
		$body_started=0;
	}
	if( $_ =~ m/test_case_fails/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if( ! $current_case ){
			die "ERROR: Case was not started but documenting its type in $script_name\n";
		}
		if( ! $has_goal ){
			die "ERROR: Wrong goal/type order for case $current_case. Should first set goal then specify type\n";
		}
		if(! $has_type ){
			die "ERROR: Type should be specified for case $current_case\n";
		}
		$failed = 1;
		if($tr){
			if($html) {
				$_ =~ s/&/&amp;/g;
				$_ =~ s/</&lt;/g;
				$_ =~ s/>/&gt;/g;
				put_header_if_needed();
				print "<tr><td>Comment</td><td>$_</td></tr>\n";
			} else {
				print "\t\tCOMMENT:   $_";
			}
		}
		$body_started=0;
	}
	if( $_ =~ m/annotate_check/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if($script_name ne 'donotrecurse'){
			if( ! $current_case ){
				die "ERROR: No test case name was specified before describing check in $script_name\n";
			}
			if( ! $has_goal ){
				die "ERROR: No goal was set for case $current_case in $script_name\n";
			}
			if( ! $has_type ){
				die "ERROR: No type was set for case $current_case in $script_name\n";
			}
			$steps_in_current_phase++;
		}
		if($html) {
			$_ =~ s/&/&amp;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			put_header_if_needed();
			put_body_start_if_needed();
			if($ts){
				print "<li>Check: $_</li>\n";
			}
		} else {
			print "\t\tCHECK:  $_";
		}
	}
	if( $_ =~ m/annotate_action/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if($script_name ne 'donotrecurse'){
			if( ! $current_case ){
				die "ERROR: No test case name was specified before describing action in $script_name\n";
			}
			if( ! $has_goal ){
				die "ERROR: No goal was set for case $current_case in $script_name\n";
			}
			if( ! $has_type ){
				die "ERROR: No type was set for case $current_case in $script_name\n";
			}
			$steps_in_current_phase++;
		}
		if($html) {
			$_ =~ s/&/&amp;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			put_header_if_needed();
			put_body_start_if_needed();
			if($ts){
				print "<li>Action: $_</li>\n";
			}
		} else {
			print "\t\tACTION: $_";
		}
	}
	if( $_ =~ m/^phase\s+/ ) {
		$_ =~ s/.*?['"](.*)['"].*/$1/;
		if( ! $current_case ){
			die "ERROR: Case was not started but documenting phase $_ in $script_name\n";
		}
		if( ! $has_goal ){
			die "ERROR: No goal was set for case $current_case in $script_name\n";
		}
		if( ! $has_type ){
			die "ERROR: No type was set for case $current_case in $script_name\n";
		}
		if( ! $steps_in_current_phase && $current_phase ){
			die "ERROR: Phase $current_phase in case $current_case contains no steps in $script_name\n";
		}
		$steps_in_current_phase = 0;
		$current_phase = $_;
		if($html) {
			$_ =~ s/&/&amp;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			put_header_if_needed();
			put_body_start_if_needed();
			if($ts){
				print "</ol><p><b>Phase: $_</b></p><ol>\n";
			}
		} else {
			print "\t\tPHASE:  $_";
		}
	}
	if( $_ =~ m/test_case_end/ ) {
		if( ! $current_case ){
			die "ERROR: Case was not started but trying to finish it in $script_name\n";
		}
		if( ! $steps_in_current_phase && $current_phase ){
			die "ERROR: Phase $current_phase in case $current_case contains no steps in $script_name\n";
		}
		$steps_in_current_phase = 0;
		$current_phase = '';
		$current_case = '';
		if($html) {
			put_end_if_needed();
			$body_started=0;
		}
	}
}

sub replace_line_with_function_doc {
	if( $#ARGV<0 || $ARGV[0] ne "donotrecurse"){
		foreach my $cached_func (@cached_funcs) {
			if( $_ =~ m/^(\s*|.*\$\(|(\s*\w+=\$\w+\s+)+)$cached_func\b/ ) {
				$steps_in_current_phase++;
				if(!$tr){
					$_ =~ s/.*?\b($cached_func).*/$1/;
					open(cache_file, "$ENV{'doc_cache_dir'}/$_") || die "Cannot read cached definition of function $_";
					while (read(cache_file, $buffer, 16384)) {
						print $buffer;
					}
					close(cache_file);
				} else {
				}
				next;
			}
		}
	}
}

sub replace_line_with_groovy_doc {
	# printf "DEBUG starting replace_line_with_groovy_doc in $script_name for line $_\n";
	if( $#ARGV<0 || $ARGV[0] ne "donotrecurse"){
		if($_ =~ m/^[^#]*\brun_simulator\b.*/){
			local $groovy_script;
			if($_ =~ m/run_simulator\s+([\w\d\._-]+)\.groovy/) {
				$groovy_script = $_;
				$groovy_script =~ s/.*run_simulator\s+([\w\d\._-]+).*/$1/;
				# printf "DEBUG determined groovy name from parameter as $groovy_script for line $_\n";
			}else{
				$groovy_script = $script_name;
				$groovy_script =~ s/(.+)\.sh/$1.groovy/;
				# printf "DEBUG determined groovy name from sh script name as $groovy_script for line $_\n";
			}
			open(cache_file, "$ENV{'doc_cache_dir'}/$groovy_script") || die "Cannot read cached definition of groovy script $groovy_script for inclusion in $script_name for line:\n$_";
			while (read(cache_file, $buffer, 16384)) {
				$steps_in_current_phase++;
				print $buffer;
			}
			close(cache_file);
		}
	}
}

$script_name=$ARGV[0];
opendir(DIR, $ENV{'doc_cache_dir'}) or die $!;
our @cached_funcs = grep { /^\w/ && -f "$ENV{'doc_cache_dir'}/$_" } readdir(DIR);
closedir(DIR);
if($script_name eq 'donotrecurse'){
	$ignore_tables=1;
}
while(<STDIN>){
	local $line = $_;
	replace_line_with_doc();
	$_ = $line;
	replace_line_with_function_doc();
	$_ = $line;
	replace_line_with_groovy_doc();
}
if($html) {
	put_end_if_needed();
}
