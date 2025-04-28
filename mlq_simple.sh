# mlsq: Module loader-simple and quick
# Please source this script to access the quik module-loading shortcut function mlsq
#
# Use 'source mlq.sh deactivate' to remove all traces of these functions

###########################################
###########################################
###########################################
# Initial setup
###########################################
###########################################
###########################################

# Check if the current shell is bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script must be sourced from a Bash shell." >&2
  return 1 2>/dev/null || exit 1
fi

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    echo "Please source this script; do not execute it directly."
    exit
fi

###########################################
###########################################
###########################################
# The mlsq function
###########################################
###########################################
###########################################

# Location of the script and its default shortcut library
__mlq_base_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
__mlq_base_simple_dir="${__mlq_base_dir}/mlq_simple"

# Enable autocompletion for mlsq the same as 'module':
# t=(`complete -p ml`)
# complete -F "${t[2]}" mlsq
if [ "$(type -t _ml)" = 'function' ]; then
    complete -F _ml mlsq
fi

function mlsq() {
    local lib1
    local lib2
    lib1="${__mlq_base_simple_dir}"
    lib2="${HOME}"'/.mlq/mlq_simple'
    mkdir -p "${lib1}"
    mkdir -p "${lib2}"

    # Help function
    if [[ "$#" -lt 1 || "$1" == '-h' || "$1" == "--help" ]] ; then
        echo 'mlsq: Module loader-simple and quick'
        echo ''
	echo 'Usage:'
	echo '       mlsq -l                  lists available shortcuts'
	echo '       mlsq <shortcut_name>     loads a shortcut'
	echo ''
	echo 'Use '"'"'source '"${__mlq_base_dir}"'/mlsq_build.sh'"'"' to build shortcuts'
	return
    fi

    # List available shortcuts
    if [[ "$1" == '-l' || "$1" == '--list' ]] ; then
	echo 'Available mlsq shortcuts:'
	for dir in "${lib1}" "${lib2}" ; do
	    if [[ ! -z $( /bin/ls -A "${dir}" ) ]] ; then
		echo ''
		cd "${dir}"
		echo 'In '${PWD}' :'
		# /bin/ls -1 | awk '{print substr($1, 5, length($1) - 8)}' | less --quit-if-one-screen
		cat *.shortcut_name | less --quit-if-one-screen
		cd - >& /dev/null
	    fi
	done
	return
    fi

    # Perform the shortcut loading (or fall back to 'ml')
    
    local shortcut_name
    shortcut_name="mlq-"$1
    # replace forward slashes by '-' so there is no directory in the name
    shortcut_name=`echo "${shortcut_name}"|awk '{gsub("/","-",$0); print $0}'`

    # If a shortcut exists by this name, load it; otherwise, execute 'ml'
    if [[ -f "${HOME}"'/.mlq/mlq_simple/'"${shortcut_name}"'.lua' || \
	      -f "${__mlq_base_simple_dir}"'/'"${shortcut_name}"'.lua' ]] ; then
	# Clear old modules and shortcuts
	ml reset >& /dev/null
	# Add paths to the shortcut modules
	ml use "${HOME}"'/.mlq/mlq_simple:'"${__mlq_base_simple_dir}"

	echo 'Loading shortcut '"'""${shortcut_name}""'"
	ml "${shortcut_name}"
    else
        echo 'Executing: '"'"'ml '"${@:1}""'"
        echo ml "${@:1}"
    fi
}
