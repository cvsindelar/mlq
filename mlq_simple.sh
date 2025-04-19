__mlq_base_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
__mlq_base_simple_dir="${__mlq_base_dir}/mlq_simple"

mlq() {
    lib1="${__mlq_base_simple_dir}"
    lib2="${HOME}"'/.mlq/mlq_simple'
    mkdir -p "${lib1}"
    mkdir -p "${lib2}"

    # Help function
    if [[ "$#" -lt 1 || "$1" == '-h' || "$1" == "--help" ]] ; then
	echo 'Usage: mlq <list>|<shortcut_name>'
	echo 'Use '"'"'source '"${__mlq_base_dir}"'/mlq_build.sh'"'"' to build shortcuts'
	return
    fi

    # List available shortcuts
    if [[ "$1" == '-l' || "$1" == '--list' ]] ; then
	echo 'Available mlq shortcuts:'
	for dir in "${lib1}" "${lib2}" ; do
	    if [[ ! -z $( /bin/ls -A "${dir}" ) ]] ; then
		echo ''
		cd "${dir}"
		echo 'In '${PWD}' :'
		/bin/ls -1 | awk '{print substr($1, 5, length($1) - 8)}' | less --quit-if-one-screen
		cd - >& /dev/null
	    fi
	done
	return
    fi
    
    # Load shortcut
    ml reset
    ml use "${__mlq_base_simple_dir}"':'"${HOME}"'/.mlq/mlq_simple'
    ml "mlq-"$1
}
