#!/usr/bin/env bash
### Portability library.
###

### $arch: H for HP-UX PA-RISC, I - HP-UX Itanium, L - Linux or Cygwin
### on CYGWIN variable IS_CYGWIN is set to true
export IS_CYGWIN=false
case $(uname -m) in
"9000/800")
	arch=H
;;
"ia64")
	arch=I
;;
"x86_64")
	arch=L
;;
*)
	if uname -s | grep -q -i cygwin
	then
		echo "WARNING: Cygwin detected. Results may vary" >&2
		IS_CYGWIN=true
		arch=L
		export CYGWIN=nodosfilewarning
		export JAVA_HOME="$(cygpath -m "$JAVA_HOME")"
		export work_dir="$(cygpath -m "$work_dir")"
		export bin_dir="$(cygpath -m "$bin_dir")"
		export harness_dir="$(cygpath -m "$harness_dir")"
	else
		echo "ERROR: Unsupported OS/platform: $(uname -m)"
		exit 1
	fi
;;
esac

export arch

### $patch: patch command with backup mode enabled
case $arch in
L)
	patch="patch -b"
;;
*)
	patch="patch"
;;
esac

if test "$arch" != "L"
then
	function seq {
		### Print sequence of numbers (for HP-UX).
		### Usage:
		### seq <start> <end>
		local i=$1
		while test $i -le $2
		do
			echo $i
			let i=$i+1
		done
	}
fi

if test -z "${JENKINS_HOME:-}"
then
	ci=false
else
	ci=true
fi

# Don't mess with ! in bash
set +H

# Do not poison environment when calling a function inline with variable set: var=val func
set +o posix
