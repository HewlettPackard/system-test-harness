#!/usr/bin/env bash
### Generates tools, libraries and tests documentation.
###
### See tools.txt, libraries.txt and tests.txt.
### Strings that contain three # are considered documentation.
###
### Usage:
### generate_summary_doc.sh

export do_traps=false
. $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

cd $bin_dir

verbose=true

while test $# -gt 0
do
	option="$1"
	shift
	case "$option" in
	"--quiet")
		### --quiet
		###     Do not print progress messages, only errors.
		verbose=false
	;;
	esac
done

$verbose && echo "Generating documentation"

$verbose && printf -- "- Generating documentation for tools\n"
tool_doc_file=tools.txt
echo "Following tools are available:" > $tool_doc_file
echo >> $tool_doc_file
echo "Following tools are available:" > harness/$tool_doc_file
echo >> harness/$tool_doc_file
for tool_script in $(ls -1 harness/*.sh *.sh | grep -vP "\btest_" | grep -vP "\blib_" | grep -vE "\bcfg_")
do
	if test -f $tool_script
	then
		if grep -v '#IGNOREDOC' $tool_script | grep -q '###' #IGNOREDOC
		then
			outfile=$tool_doc_file
			if echo $tool_script | grep -q harness/
			then
				outfile=harness/$outfile
			fi
			$verbose && printf -- "-- Tool $tool_script contains documentation\n"
			echo "$(basename $(dirname $tool_script))/$(basename $tool_script) :" >> $outfile
			grep '###' $tool_script | grep -v '#IGNOREDOC' | sed 's/###/   /g' >> $outfile #IGNOREDOC
			echo >> $outfile
		else
			echo "WARNING! Tool $tool_script does not contain documentation" >&2
		fi
	fi
done

$verbose && printf -- "- Generating documentation for libraries\n"
lib_doc_file=libraries.txt
echo "Following libraries are available:" > $lib_doc_file
echo >> $lib_doc_file
echo "Following libraries are available:" > harness/$lib_doc_file
echo >> harness/$lib_doc_file
for lib in cfg_*.sh lib_*.sh harness/cfg_*.sh harness/lib_*.sh
do
	if test -f $lib
	then
		if grep -v '#IGNOREDOC' $lib | grep -q '###' #IGNOREDOC
		then
			outfile=$lib_doc_file
			if echo $lib | grep -q harness/
			then
				outfile=harness/$outfile
			fi
			$verbose && printf -- "-- Library $lib contains documentation\n"
			echo "$(basename $(dirname $lib))/$(basename $lib) :" >> $outfile
			grep -E '###|function' $lib | sed 's/###/   /g' | perl -pe 's/\s*function\s+(.+)\s*{/    Function $1:/g' >> $outfile #IGNOREDOC
			echo >> $outfile
		else
			echo "WARNING! Library $lib does not contain documentation" >&2
		fi
	fi
done

$verbose && printf -- "- Generating documentation for tests\n"
if $verbose
then
	harness/extract_info.sh > tests.txt
else
	harness/extract_info.sh --quiet > tests.txt
fi

if $verbose
then
	echo "Finished"
fi
