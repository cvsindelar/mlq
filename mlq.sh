# mlq: Module loader-quick
# Please source this script to access the quik module-loading shortcut function 'mlq'
#  as well as the module consistency checker 'mlq_check'
#
# Use 'source mlq.sh --mlq_unload' to remove all traces of these functions

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
# Code to incorporate mlq into a module
###########################################
###########################################
###########################################

# The user can specify --mlq_load to specify we are loading mlq with lmod
#  ('mlq' module), giving the specific version as an argument
if [[ "$1" == "--mlq_load" ]]; then
    # echo Loading mlq
    if [[ ! $# != 3 ]] ; then
        echo 'Usage:'
        echo    'source mlq.sh --mlq_load mlq/<version>'
        return
    fi

    # Make sure the mlq module can be found
    module is-avail "$2"
    
    if [[ ($? != 0) ]]; then
        echo 'ERROR: mlq module '"'""$2""'"' not found.'
        echo 'Usage:'
        echo    'source mlq.sh --mlq_load mlq/<version>'
        return
    else
	# Get the path to the mlq lmod .lua file; this is stored in case
	#  subsequent module resets remove the path from $MODULEPATH
        __mlq_path=`module --redirect --location show "$2"|awk '{n=sub("/mlq/[^/]+[.]lua$","",$0); if(!n) n=sub("/mlq[.]lua$","",$0); if(n) print}'`
        if [[ ! ${__mlq_path} ]] ; then
            echo 'ERROR: path to the mlq module cannot be determined!'
            echo '(this should not happen)'

            unset __mlq_path
            return
        fi
        __mlq_version="$2"
    fi
    # Unsetting __mlqs_active makes sure it will be refreshed when mlq is called
    #  for the first time
    unset __mlqs_active
else
    # Specify that mlq is not being loaded as an lmod module
    unset __mlq_version
    unset __mlq_path
fi

# Add a hook to the 'module' command, so that it unloads mlq and any shortcut
#  before proceeding. This avoids mixing modules with shortcuts.

#  Note: we test __mlq_activated to make sure we don't try to do this a second
#  time, which would destroy the saved original versions of 'ml' and 'module' functions!
if [[ "${__mlq_version}" && ! "${__mlq_activated}" ]] ; then
    # Save the original 'module' function code as __mlq_orig_module
    # Note we don't need to add a hook to 'ml', because it calls 'module'
    eval "$(echo "__mlq_orig_module()"; declare -f module | tail -n +2)"

    function module() {
	echo 'Unloading the mlq shortcut environment'
	__mlq_orig_module reset
	module "${@:1}"
    }
fi

# If requested, remove all traces of mlq during the mlq module unload
if [[ "$1" == "--mlq_unload" ]]; then
    # echo Unloading mlq
    if [[ "${__mlq_activated}" ]] ; then
        unset __mlq_activated

        # Restore the lmod 'ml' and 'module' commands
        # eval "$(echo "ml()"; declare -f __mlq_orig_ml | tail -n +2)"
        eval "$(echo "module()"; declare -f __mlq_orig_module | tail -n +2)"
        unset -f __mlq_orig_ml
        unset -f __mlq_orig_module
    fi
    
    unset -f mlq
    unset -f __mlq_reset
    unset -f __mlq_shortcut_reset

    unset __mlq_version
    unset __mlq_path
    unset __mlq_base_dir
    unset __mlq_prebuilds_dir
    
    unset -f mlq_check
    unset -f __mlq_parse_module_tree_iter

    unset __mlqs_active
    unset __mlq_module_version
    unset __mlq_module_file
    unset __mlq_module_callstack
    unset __mlq_expected_versions

    return
fi

__mlq_activated=1

# Location of the script and its default shortcut library
__mlq_base_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
__mlq_prebuilds_dir="${__mlq_base_dir}/mlq_prebuilds"

###########################################
###########################################
###########################################
# Initialization step: pre-loading of generic module shortcuts:
#  this generates a set of symbolic links in the user's .mlq directory, pointing
#  to (read-only) pre-generated shortcut files located in the same directory
#  as the mlq.sh script (in 'mlq_prebuilds').
#
# If one of these linked shortcuts is (or later becomes) out of date, mlq will 
#  automatically detect this, knock out the symbolic link, and build an updated 
#  shortcut within the user .mlq directory. This circumvents the problem of users
#  not having permissions to update a central shortcut repository, and
#  accompanying problems of multi-user conflicts, etc.
###########################################
###########################################
###########################################

# Only do this step if there are no shortcuts in the mlq_prebuilds directory
if [ -z "$( /bin/ls -A ${HOME}/.mlq/mlq )" ] ; then
    # Source: https://patorjk.com/software/taag/#p=display&f=Diet%20Cola&t=mlq

    # Welcome message
    IFS='' read -r -d '' __mlq_logo <<"EOF"
                .      
               /       
 .  .-. .-.   / .-.    
  )/   )   ) / (   )   
 '/   /   (_/_.-`-(    
           `-'     `-' 
EOF
    echo "${__mlq_logo}"
    unset __mlq_logo

    echo 'Welcome to mlq!'
    echo ''

    if [[ $n_argin -lt 1 ]]; then
        echo 'Use this function for quick module loading with the lmod system'
        echo ''
        echo 'Use '"'"'mlq --help'"'"' for examples and instructions'
        echo ''
    fi

    # Add prebuilt shortcuts if available
    if [ ! -z "$( /bin/ls -A ${__mlq_prebuilds_dir} )" ] ; then
        printf 'Setting up pre-built mlq shortcuts...'
        
        mkdir -p "${HOME}"/.mlq/mlq
        # Link all shortcuts in the mlq_prebuilds directory to ~/.mlq/mlq
        if [ -z "$( /bin/ls -A ${HOME}/.mlq/mlq )" ] ; then
            # The fast way, if the ${HOME}/.mlq/mlq directory is empty
            /bin/ln -s "${__mlq_prebuilds_dir}"/* "${HOME}"/.mlq/mlq
        else
            # The slow way, needed when .mlq/mlq is not empty:
            /bin/ls -1 ${__mlq_prebuilds_dir} | xargs -I '{}' sh -c "if [[ ! -e ${HOME}/.mlq/mlq/{} ]] ; then /bin/ln -s "${__mlq_prebuilds_dir}"/{} ${HOME}/.mlq/mlq/ ; printf '.' ; fi"
        fi
        
        echo ' done.'
        echo ''
        echo 'Use '"'"'mlq --avail'"'"' to list all available shortcuts'
        echo ''
    fi
fi

###########################################
###########################################
###########################################
# Ancillary functions
###########################################
###########################################
###########################################

function __mlq_reset() {
    # The below variables preserve mlq info if we are in the mlq module;
    #  this is so we can remember them after resetting the module, which
    #  eliminates all __mlq variables
    local tmp_path="${__mlq_path}"
    local tmp_version="${__mlq_version}"
    
    __mlq_orig_module reset >& /dev/null
    
    if [[ "${tmp_version}" ]] ; then
	# Keep mlq around; the user can get rid of it by doing 'mlq reset'
        module use "${tmp_path}"
        module load "${tmp_version}"
    fi
}

function __mlq_shortcut_reset() {
    # If a shortcut is active, unload it.
    if [[ "${__mlqs_active[@]}" && "${__mlqs_active}" != 'none' ]]; then
        printf 'Deactivating the shortcut: '
        
        # There shouldn't be more than one, but account for this anyway just in case
        echo "${__mlqs_active[@]}" | awk '{for(ind=1; ind<=NF;++ind) {printf("'\'%s\'' ", substr($ind,5,length($ind)-4));} printf("...")}'

        __mlq_orig_module unload ${__mlqs_active[@]} #  > /dev/null 2>&1
        
        local mlq_path
        for mod in ${__mlqs_active[@]} ; do
	    mlq_path=`__mlq_orig_module -t --redirect --location show "${mod}"`
	    mlq_path="${mlq_path%/*}"
	    __mlq_orig_module unuse "${mlq_path}"
        done
        echo ' done.'
    fi
}

###########################################
###########################################
###########################################
# The mlq function
###########################################
###########################################
###########################################

# Enable autocompletion for mlq the same as 'module':
# t=(`complete -p ml`)
# complete -F "${t[2]}" mlq
if [ "$(type -t _ml)" = 'function' ]; then
    complete -F _ml mlq
fi

mkdir -p "${__mlq_prebuilds_dir}"

function mlq() {
    local mlq_dir
    local mlq_custom_dir
    mlq_dir="${HOME}"/.mlq/mlq
    mlq_custom_dir="${HOME}"/.mlq/mlq_custom

    mkdir -p "${mlq_dir}"
    mkdir -p "${mlq_custom_dir}"

    local n_argin
    n_argin=$#

    local mlq_user_orig_modpath
    mlq_user_orig_modpath="${MODULEPATH}"
        
    ###########################################
    # Set __mlqs_active to any active shortcut
    # (there shouldn't be more than one, but handle that case
    #  anyway, to be safe)
    ###########################################

    if [[ ! ${__mlqs_active} ]] ; then
	local __mlqs_active_candidates
	local mod
	local mod_file
	
	mlqs_active_candidates=(`__mlq_orig_module -t --redirect list|grep '^mlq[-]'`)
	for mod in ${mlqs_active_candidates[@]} ; do
            mod_file=`__mlq_orig_module --redirect --location show "${mod}"`

            # Screen out 'imposter' modules that start with 'mlq-' but are not shortcuts
            is_qmod=`echo "${mod_file}" | \
                      awk -v qhome="${HOME}"/.mlq/mlq \
                      '{ if(substr($1,1,length(qhome)) == qhome) print(1); }'`
            
            if [[ "${is_qmod}"  ]] ; then
		if [[ ! "${__mlqs_active}" ]] ; then
                    __mlqs_active=("${mod}")
		else
                    __mlqs_active=("${__mlqs_active}" "${mod}")
		fi
            fi
	done
    fi
    
    if [[ ! "${__mlqs_active}" ]] ; then
        __mlqs_active='none'
    fi

    ###########################################
    # Parse the arguments
    ###########################################

    ###########################################
    # --help, --helpful or no arguments: Print help info
    ###########################################
    
    if [[ ( `printf '%s' "$1" | awk '($1 ~ "--h" && "--help" ~ $1) || \
                                     ($1 ~ "--h" && "--helpfull" ~ $1) || \
                                     ($1 ~ "--h" && "--helpnotes" ~ $1) || \
                                     ($1 == "-h" || $1 == "-hf" || $1 == "-hn") || \
                                     $1 == "show-all-if-ambiguous" '` ) || ( "${n_argin}" -eq 0 )  ]] ; then
        # Welcome message
        if [ -z "$( /bin/ls -A ${HOME}/.mlq/mlq )" ] ; then
            # Source: https://patorjk.com/software/taag/#p=display&f=Diet%20Cola&t=mlq
            local __mlq_logo
            IFS='' read -r -d '' __mlq_logo <<"EOF"
                .      
               /       
 .  .-. .-.   / .-.    
  )/   )   ) / (   )   
 '/   /   (_/_.-`-(    
           `-'     `-' 
EOF
            echo "${__mlq_logo}"

            echo 'Welcome to mlq!'
            echo ''
            
            if [[ $n_argin -lt 1 ]]; then
                echo 'Use this function for quick module loading with the lmod system'
                echo ''
                echo 'Use '"'"'mlq --help'"'"' for examples and instructions'
                echo ''
            fi
            
            # If prebuilt shortcuts available, let the user know
            if [ ! -z "$( /bin/ls -A ${__mlq_prebuilds_dir} )" ] ; then
                echo 'Use '"'"'mlq --prebuild'"'"' to install curated, pre-built shortcuts'
                echo '   These will go in your shortcut library at: '"'""${HOME}/.mlq/mlq""'"
                echo ''
            fi            
        fi

        local help
        help=
        if [[ $n_argin -eq 1 ]]; then

            help=1
            
            echo 'mlq: Module loader-quick'
            echo ''
            
            if [[ ( `printf '%s' "$1" | awk '($1 ~ "--helpf" && "--helpfull" ~ $1) || $1 == "-hf"'` ) ]] ; then
                echo ' Usage: '
                echo '  mlq <shortcut name> | <module>           Activate shortcut if it exists;'
                echo '                                            otherwise load a module'
                echo ''
                echo '  mlq [options] sub-command [args ...]     Runs the corresponding '"'"ml"'"' command'
                echo '  mlq <module 1> <module 2> [...]          Ordinary multiple module loading'
                echo ''
                echo '  mlq --build|-b <module> | [<shortcut name> <module1> [<module2> ...]]'
                echo '                                           Build shortcut; If only a module is '
                echo '                                           given, the shortcut will be named'
                echo '                                           after the module'
                echo '                                           These will go in your shortcut library at:'
                echo '                                             '"'""${HOME}/.mlq/mlq""'"
                echo '  mlq --unsafe_build|-ub <module> | [<shortcut name> <module1> [<module2> ...]]'
                echo '                                           Same as --build but without'
                echo '                                           strict checking'
                echo ''
                echo '  mlq --list|-l                            List modulefiles for the loaded'
                echo '                                            shortcut (if any)'
                echo '  mlq --avail|-a                           List all available shortcuts'
                echo '                                            (including generic ones)'
                echo '  mlq --delete|-d <shortcut_name>          Delete shortcut'
                echo '  mlq --reset|-r|reset                     Same as '"'"'module reset'"'"
                echo '  mlq --nuke                               Delete all shortcuts'
                echo '  mlq --prebuild [<dir>]                   Install links to pre-built shortcuts'
                echo '                                            If not specified, <dir> defaults to '
                echo '                                            pre-built system shortcuts in:'
                echo '                                            '"${__mlq_prebuilds_dir}"
                echo '  mlq --help|-h                            Short help message with examples'
                echo '  mlq --helpfull|-hf                       Print this help message'
                echo '  mlq --helpnotes|-hn                      Print extra notes on mlq'
                echo ''
                echo 'Use '"'"'--helpnotes'"'"'|'"'"'-hn'"'"' for additional guidance and notes on how mlq works.'
            elif [[ ( `printf '%s' "$1" | awk '($1 ~ "--helpn" && "--helpnotes" ~ $1) || $1 == "-hn"'` ) ]] ; then
                echo 'Extra notes:'
                echo ''
                echo '   mlq works with lmod module system so you can create and use custom-built'
                echo '    '"'"shortcut"'"' modules to accelerate the loading of large and complex'
                echo '    module environments'
                echo ''
                echo '   Shortcut (mlq) modules are intended to be used by themselves, without'
                echo '    other modules. When you load a shortcut with mlq, a '"'"module reset"'"' is'
                echo '    automatically performed before loading the shortcut, removing any previously'
                echo '    loaded modules. Likewise, if you use mlq to load an ordinary module on top'
                echo '    of a shortcut, the shortcut is automatically deactivated'
                echo ''
                echo '   Any command that works with '"'"ml"'"' should also work with '"'"'mlq'"'"
                echo '    (any call not to do with mlq shortcuts gets passed straight through to '"'"'ml'"'"')'
                echo ''
                echo '   A shortcut module works by caching the code for one or more modules'
                echo '    and all the modules they depend on. It faithfully executes the same code'
                echo '    as the original modules, in the same order. Strict checking is done to ensure'
                echo '    that if any of the involved module files changes, or even if a single modification'
                echo '    date changes, then the shortcut falls back to ordinary module loading;'
                echo '    the user is prompted to rebuild the shortcut'
                echo ''
                echo '   mlq is designed to work with '"'"'well-behaved'"'"' modules;'
                echo '    that is, where there are no version conflicts between the modules'
                echo '    that a shortcut depends on. Strict checking of the modulefile tree '
                echo '    is done to enforce this***.'
                echo '    In some cases a conflict may be detected that can be safely ignored. '
                echo '    If you are able to confidently establish that reported conflicts can'
                echo '    be ignored, '"'"'--unsafe_build'"'" '    can be used, which bypasses these safety checks.'
                echo '   *** Checking is done by screening '"'"'depends_on()'"'"' statements in the'
                echo '      modulefile lua codes.'
                echo ''
                echo '   If you would like to add shortcuts to your own '"'"prebuilds"'"' directory then do, i.e.:'
                echo '     cp -R -L ~/.mlq/mlq/<shortcut_dir> <your_new_prebuilds_dir>/'
                echo '                   or'
                echo '     cp -R -L ~/.mlq/mlq/* <your_new_prebuilds_dir>/'
                echo ''
            else
                echo ' Usage:'
                echo '  mlq [ arguments for ml... ]'
                echo '              or'
                echo '  mlq [ shortcut arguments... ]'
                echo ''
                echo ' HANDY TIPS:'
                echo '  - tab autocompletion works for '"'"mlq"'"' exactly the same as '"'"ml"'"
                echo ''
                echo '  - mlq shortcuts are modules, but work by themselves, not with other modules'
                echo ''
                echo ' TLDR examples:'
                echo '  mlq                                      Lists any loaded shortcut;'
                echo '                                            or, lists available custom-named shortcuts'
                echo '  mlq -b SciPy-bundle/2023.02-gfbf-2022b   Builds '"'"'generic'"'"' shortcut for SciPy-bundle'
                echo '  mlq SciPy-bundle/2023.02-gfbf-2022b      Loads the above shortcut'
                echo '  mlq -r                                   Deactivates the shortcut'
                echo '  mlq -d SciPy-bundle/2023.02-gfbf-2022b   Deletes the above shortcut'
                echo '  mlq SciPy-bundle/2023.02-gfbf-2022b      If no shortcut exists, then do '
                echo '                                            '"'"'ml SciPy-bundle/2023.02-gfbf-2022b'"'"
                echo ''
                echo '  mlq -b rel5 RELION/5.0.0-foss-2022b-CUDA-12.0.0 IMOD/4.12.62_RHEL8-64_CUDA12.0 Emacs/28.2-GCCcore-12.2.0'
                echo '                                           Builds a custom-named 3-module shortcut, '"'"'rel5'"'"
                echo ''
                echo '  mlq list ; mlq purge; # etc              Runs the corresponding '"'"ml"'"' commands, i.e.:'
                echo '                                            ml list ; ml purge # etc'
                echo ''
                echo '  function rel5() { mlq rel5 ; }           Bash function definition can be '
                echo '                                           pasted into your .bashrc'            
                echo ''
                echo 'Use '"'"'--helpfull'"'"'|'"'"'-hf'"'"' for full instructions.'
            fi
        fi
        
        ###########################################
        # Show the current shortcut environment if there is anything to show
        #  (if not, the welcome message will have been printed)
        ###########################################
        if [[ "${n_argin}" -eq 0 && ! -z "$( /bin/ls -A ${HOME}/.mlq/mlq )" ]]; then
                
            # __mlq_orig_module --ignore_cache list # |& awk '$0 == "Currently Loaded Modules:" {getline; print}'
            
            if [[ "${__mlqs_active[@]}" && "${__mlqs_active}" != 'none' ]]; then
                # Check if ordinary modules are also present (shouldn't be!)
                if [[ `__mlq_orig_module --redirect -t list|grep -v StdEnv|grep -v '^mlq[-|/]'` ]] ; then
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo 'WARNING: additional modules are loaded on top of the shortcut' `echo "${__mlqs_active[@]}" | awk '{printf("'\'%s\'' ... ", substr($1,5,length($1)-4))}'`
                    echo ' (type '"'"'module list'"'"' to confirm)'
                    echo 'Results may not be predictable; recommend to do '"'"mlq reset"'"' before proceeding.'
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo ''
                fi

                # Print the current shortcut name (take off the leading 'mlq-' from the folder name)
                echo 'Current shortcut:' `echo "${__mlqs_active[@]}" | awk '{print substr($1,5,length($1)-4)}'`
                echo ''
                echo 'Use '"'"'mlq -r'"'"' (or '"'"'mlq reset'"'"' / '"'"'mlq purge'"'"') to turn off this shortcut.'
                echo ''
            else
                echo 'No module shortcut is currently active.'
                echo ''
                echo 'Custom-named module shortcuts:'

                # Temporarily change the module path so we can list the named shortcuts;
                #  note that the only purpose for $mlq_custom_dir is for keeping track of the
                #  custom shortcuts; it is not used for, i.e., loading modules
                export MODULEPATH="${mlq_custom_dir}"

                # List all the modulefiles; note we NEVER use the cache, since we don't need it and
                #  it occasionally gets corrupted.
                # We use awk to strip out the last part of the module printout, since it doesn't apply.
                __mlq_orig_module --redirect --nx --ignore_cache avail | awk 'BEGIN {no_print=1} $0 == "If the avail list is too long consider trying:" {no_print=1} !no_print {print} $0 ~ "mlq_custom" {no_print=0}'

                echo 'Use '"'"'mlq --avail'"'"' to list all available shortcuts'
                echo '   (may include generic/prebuilt ones)'
                echo ''
                echo 'Use '"'"'mlq --help'"'"' for examples and instructions'
                echo ''
            fi

            export MODULEPATH="${mlq_user_orig_modpath}"
        fi
        return
        # --help#
    fi

    ###########################################
    # Parse other options
    ###########################################

    ###########################################
    # '--prebuild' option: list dependent modulefiles
    ###########################################
    if [[ `printf '%s' "$1" | awk '($1 ~ "--p" && "--prebuild" ~ $1) {print 1}'` ]]; then
        local prebuild_dir
        if [[ "$#" == 2 ]] ; then
            prebuild_dir="$2"
        elif [[ "$#" -gt 2 ]] ; then
            echo 'Only one directory can be specified with the '"'"'--prebuild'"'"'.'
            return
        else
            prebuild_dir=${__mlq_prebuilds_dir}
        fi
            
        if [ ! -z "$( /bin/ls -A ${prebuild_dir} )" ] ; then
            
            printf 'Setting up pre-built mlq shortcuts...'

            # Link all shortcuts in the mlq_prebuilds directory to ~/.mlq/mlq
            if [ -z "$( /bin/ls -A ${HOME}/.mlq/mlq )" ] ; then
                # The fast way, if the ${HOME}/.mlq/mlq directory is empty
                /bin/ln -s "${prebuild_dir}"/* "${HOME}"/.mlq/mlq
            else
                # The slow way, needed when .mlq/mlq is not empty:
                /bin/ls -1 ${prebuild_dir} | xargs -I '{}' sh -c "if [[ ! -e ${HOME}/.mlq/mlq/{} ]] ; then /bin/ln -s "${prebuild_dir}"/{} ${HOME}/.mlq/mlq/ ; printf '.' ; fi"
            fi
            
            echo ' done.'
        else
            echo 'Sorry, no pre-built shortcuts are available in '"'""${prebuild_dir}""'"
        fi
        return
    fi
    
    ###########################################
    # '--list' option: list dependent modulefiles
    ###########################################
    local mlq_list
    mlq_list=
    if [[ `printf '%s' "$1" | awk '($1 ~ "--l" && "--list" ~ $1) || $1 == "-l" {print 1}'` ]]; then
        mlq_list=1
    fi
    
    ###########################################
    # '--avail' option: list all available shortcuts, including generic ones
    #  as well as custom-named shortcuts
    ###########################################
    if [[ `printf '%s' "$1" | awk '($1 ~ "--a" && "--avail" ~ $1) || $1 == "-a" {print 1}'` ]]; then
        echo 'All available module shortcuts:'

        export MODULEPATH="${mlq_custom_dir}"

        # Below, we print all the lua files in .mlq.mlq (including the custom-named ones, so redundant
        #  with the next printout)

        ( find -L "${HOME}"/.mlq/mlq -name '*.lua'| \
              awk '{sub("^.*[.mlq][/]mlq[/][^/]*[/]mlq[-]","",$0); sub("[.]lua","",$0); print}' ; ) \
            | less -X --quit-if-one-screen
        
        echo '' ;
        echo 'Custom-named module shortcuts:' ;
        __mlq_orig_module --redirect --nx --ignore_cache avail | awk 'BEGIN {no_print=1} $0 == "If the avail list is too long consider trying:" {no_print=1} !no_print {print} $0 ~ "mlq_custom" {no_print=0}'

        export MODULEPATH="${mlq_user_orig_modpath}"
        
        return
    fi

    ###########################################
    # '--reset' option: turn off shortcuts with 'module reset'
    ###########################################
    if [[ `printf '%s' "$1" | awk '($1 ~ "--r" && "--reset" ~ $1) || $1 == "-r" {print 1}'` ]]; then
        if [[ $n_argin -gt 1 ]] ; then
            echo 'ERROR: no arguments accepted after '"'"'reset|--reset|-r'"'"' option.'
            return
        fi
        local mlq_activated_list
        mlq_activated_list=$(echo ${MODULEPATH} | \
                                 awk -v h=${HOME} \
                                     '{ \
                        n=split($0,mods,":"); \
                        for(ind=1; ind<=n; ++ind) \
                          if(substr(mods[ind],1,length(h)) == h) \
                            print(mods[ind]); \
                        }')
        # echo module unuse ${mlq_activated_list}
        # module unuse ${mlq_activated_list}
        __mlq_reset
        return
    fi
    
    ###########################################
    # '--nuke' option: Delete all shortcuts/
    # ( '-p /dev/stdin' detects if we are in a pipeline subsheel)
    ###########################################
    
    if [[ "$1" == '--nuke' ]] ; then
        if [[ $n_argin -eq 1 ]] ; then
            
            # Don't allow this in pipeline subshells
            if [[ ! -p /dev/stdin ]] ; then
                echo 'You have invoked '"'"mlq"'"' --nuke'
                echo 'This will delete all '"'"mlq'"'' shortcuts.'
                local confirm
                read -p 'Are you sure? (Y/N): ' confirm
                if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                    __mlq_reset

                    printf 'Nuking... ' 
                    /bin/rm -r "${HOME}"/.mlq/mlq
                    /bin/rm -r "${HOME}"/.mlq/mlq_custom
                    mkdir -p "${mlq_dir}"
                    mkdir -p "${mlq_custom_dir}"
                    
                    echo 'done.'
                else
                    echo 'The nuclear option is canceled.'
                fi
            else
                echo 'The nuclear option --nuke is not allowed in a pipeline subshell like:'
                echo '   echo Y | mlq --nuke'
                echo 'If you would like to automatically proceed with this option, do:'
                echo '   mlq --nuke <<< Y'
                return
            fi
            return
        else
            echo 'Arguments after '"'"'--nuke'"'"' not understood!'
            return 1
        fi
    fi
    
    ###########################################
    # '--delete' option: sets up for shortcut deletion, which is done later after
    #  all the relevant names and paths have been found
    ###########################################

    local delete_shortcut
    delete_shortcut=
    if [[ `printf '%s' "$1" | awk '($1 ~ "--d" && "--delete" ~ $1) || $1 == "-d" {print 1}'` ]] ; then
        if [[ $n_argin -lt 2 ]] ; then
            echo "'"'--delete'"'"' option: please give a shortcut name'
            return
        fi
        if [[ "${n_argin}" -gt 2 ]] ; then
            echo 'Only one shortcut deletion is allowed at a time'
            return
        fi
        shift
        n_argin=1
            
        delete_shortcut=1
    fi
    
    local need_to_build
    local fall_back
    local rebuild

    need_to_build=
    fall_back=
    rebuild=

    ###########################################
    # '--build' option: specify a shortcut build
    ###########################################
    local shortcut_name
    local custom_name
    local request_type
    local safe_build
    request_type='load'
    custom_name=
    safe_build=1
    shortcut_name=

    if [[ `printf '%s' "$1" | awk '($1 ~ "--b" && "--build" ~ $1) || $1 == "-b" || ($1 ~ "--ub" && "--unsafe_build" ~ $1) || $1 == "-ub" {print 1}'` ]] ; then
        # build shortcut
        request_type='build'
        need_to_build=1

        if [[ $n_argin -lt 2 ]] ; then
            echo "'"'--build'"'"' option: please give at least one module'
            return
        fi

        if [[ `printf '%s' "$1" | awk '($1 ~ "--ub" && "--unsafe_build" ~ $1) || $1 == "-ub" {print 1}'` ]] ; then
            safe_build=
        fi
        
        # Shift the arguments so we are left with <shortcut name> [mod1 [mod2 ...]]
        shift
        shortcut_name="$1"

        # Shift the arguments again so we are left with [mod1 [mod2 ...]]
        # If only 2 args given, i.e. '--build <mod>', we don't shift;
        #  shortcut name is the same as the module
        if [[ $n_argin -gt 2 ]] ; then
            shift
            custom_name=1

            # If the shortcut name appears as one of the listed modules, it
            #  shall not be taken to be a custom shortcut
            local ind
            local m
            for m in "${@:1}" ; do
                if [[ "${m}" == "${shortcut_name}" ]] ; then
                    custom_name=
                fi
            done
        fi
    elif [[ $n_argin -gt 1 ]] ; then
        # if multiple modules given without '--build', the shortcut name is the module 
        #  names strung together. This case is not currently relevant, since the user must 
        #  explicitly specify shortcut names when there is more than one module.

        shortcut_name=`echo "${@:1}"|awk '{sub("/","-",$0); gsub("[.]","_",$0); gsub(" ","___",$0); print $0}'`
        custom_name=1
    else
        # shortcut name is the same as the module name
        shortcut_name="$1"
    fi

    ###########################################
    # Define all the needed variable names and paths
    ###########################################
    
    local module_spec
    module_spec=("${@:1}")
    
    # Make a valid module collection name by getting rid of slashes and periods in $shortcut_name
    local collection_name
    collection_name=`echo "${shortcut_name}"|awk '{sub("/","-",$0); gsub("[.]","_",$0); print $0}'`

    # Find out if the module includes a version name.
    #  In this case, we need a make subdirectory
    local dir_t
    local quikmod_top_dir
    dir_t=(`echo "${shortcut_name}" | awk '{sub("/"," ", $0); print}'`)

    if [[ ${#dir_t[@]} -gt 1 ]]; then
        quikmod_top_dir='mlq-'"${dir_t[0]}"
        custom_top_dir="${dir_t[0]}"
    else
        quikmod_top_dir=
        custom_top_dir=
    fi

    # Define target_dir, which is where the shortcut info will be stored
    local target_dir
    target_dir="${mlq_dir}/${collection_name}"

    local lua_custom_placeholder
    # Get the filename for links inside mlq_custom_dir; these
    #  are only used to keep track of custom-named shortcuts
    lua_custom_placeholder="$mlq_custom_dir/${shortcut_name}.lua"

    # Define extended_target_dir, which also includes the module name if
    #  there is a version subdirectory
    local extended_target_dir
    local extended_custom_target_dir
    extended_target_dir="${target_dir}"
    extended_custom_target_dir=
    
    if [[ "${quikmod_top_dir}" ]]; then
        extended_target_dir="${extended_target_dir}/${quikmod_top_dir}"
        extended_custom_target_dir="${mlq_custom_dir}"/"${extended_custom_target_dir}/${custom_top_dir}"
    fi

    # Get the lua filename, based on the full name which is mlq-<shortcut name>
    local quikmod_lua
    local shortcut_name_full

    shortcut_name_full='mlq-'"${shortcut_name}"
    quikmod_lua="$target_dir/${shortcut_name_full}.lua"

    ###########################################
    # List dependent modulefiles
    ###########################################
    if [[ "${mlq_list}" ]] ; then
        if [[ "${__mlqs_active[@]}" && "${__mlqs_active}" != 'none' ]] ; then
            local mod_list
            shortcut_name=`echo "${__mlqs_active[@]}" | awk '{print substr($1,5,length($1)-4)}'`
            collection_name=`echo "${shortcut_name}"|awk '{sub("/","-",$0); gsub("[.]","_",$0); print $0}'`
            
            # If for whatever reason there were multiple mod_list files (should never happen),
            #  we make sure the existence check would still work:
            mod_list=(`find "${mlq_dir}"/"${collection_name}"/ -name '*.mod_list'`)

            if [[ "${mod_list[-1]}" ]] ; then
                echo 'Modulefiles used for shortcut '"${shortcut_name}" ':'
		local m
		for m in ${mod_list[@]} ; do
		    echo "From ${m}" ':'
                    echo ''
                    cat "${m}"
		    echo ''
		done
            fi
        fi
        return
    fi

    ###########################################
    # Delete a shortcut:
    ###########################################
    if [[ "${delete_shortcut}" ]] ; then

        # The below line tests if we are in a pipeline subshell.
        #  Deletions are not allowed in this case because the 'module reset'
        #  does not transfer back to the calling shell.
        if [[ -p /dev/stdin ]] ; then
            echo 'Shortcut deletions are not allowed in a pipeline subshell like:'
            echo '   echo Y | mlq -d <shortcut>'
            echo 'If you would like to automatically proceed with a deletion, do:'
            echo '   mlq -d <shortcut> <<< Y'
            return
        else
            local for_real
            for_real=
            [[ -f "${quikmod_lua}" ]] && for_real=1
            [[ -f "${quikmod_lua%.*}.lua_record" ]] && for_real=1
            [[ -f "${quikmod_lua%.*}.spec" ]] && for_real=1
            
            if [[ "$for_real" ]]; then
                echo 'This will delete the mlq shortcut '"'"${shortcut_name}"'."
                
                local confirm
                read -p 'Are you sure? (Y/N): ' confirm
                if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                    
                    __mlq_reset

                    # target_dir could be a link to a prebuilt shortcut
                    if [[ -h "${target_dir}" ]] ; then
                        /bin/rm "${target_dir}"
                    else
                        /bin/rm "${quikmod_lua}"
                        [[ -f "${quikmod_lua%.*}".warnings ]] && /bin/rm "${quikmod_lua%.*}".warnings
                        /bin/rm "${quikmod_lua%.*}".lua_record
                        /bin/rm "${quikmod_lua%.*}".mod_list
                        /bin/rm "${quikmod_lua%.*}".modpath
                        /bin/rm "${quikmod_lua%.*}".spec
                        [[ -f "${quikmod_lua%.*}".unsafe_build ]] && /bin/rm "${quikmod_lua%.*}".unsafe_build
                        if [[ "${quikmod_top_dir}" ]]; then
                            rmdir "${extended_target_dir}"
                        fi
                        rmdir "${target_dir}" 
                    
                        [[ -f "${lua_custom_placeholder}" ]]        && /bin/rm "${lua_custom_placeholder}"
                        [[ -d "${extended_custom_target_dir}" ]] && rmdir "${extended_custom_target_dir}"
                    fi
                    
                    echo 'Deleted the shortcut '"'"${shortcut_name}"'"
                    return
                else
                    echo 'Deletion is canceled. Doing nothing.'
                    return
                fi
            else
                echo 'Shortcut '"'"${shortcut_name}"'"' not found. Doing nothing.'
                return
            fi
        fi
    fi
    
    ###########################################
    # Bash command to save file info, including the full contents, size, and date,
    #  for the set of lua modulefiles that defines a shortcut; this is used 
    #  to test if any of them changed, meaning the shortcut should be rebuilt.
    # It requires that the list of module files, $ordered_module_list, be set already.
    ###########################################
    local build_lua_record
    local ordered_module_list
    build_lua_record='/bin/ls -lL ${ordered_module_list[@]}; cat ${ordered_module_list[@]}'
    
    ordered_module_list=
    build_modpath=

    ###########################################
    # If loading a shortcut, check if it needs to be rebuilt.
    ###########################################
    if [[ "${request_type}" == 'load' && -f "${quikmod_lua}" ]]; then

        # Get previously saved, ordered list of modulefiles:
        ordered_module_list=(`cat "${quikmod_lua%.*}".mod_list`)
        
        ###########################################
        # If the previously saved list is empty, need to rebuild
        ###########################################
        if [[ ! "${ordered_module_list[@]}" ]] ; then
            echo 'The previous mlq build seems to have failed.'

            # We cannot rebuild a module if the previous build attempt failed, so
            #  fall back to ordinary module load
            fall_back=1
        else
            ###########################################
            # If the module files changed, need to rebuild
            ###########################################
            if [ "$(eval ${build_lua_record} | cmp ${quikmod_lua%.*}.lua_record)" ] ; then
                echo 'The module environment seems to have changed.'
            
                if [[ "${request_type}" == 'load' ]] ; then
                    # If the user requested a load but the shortcut is out of date, try to rebuild the shortcut.
                    # To do this, we first need to:
                    #  - Obtain the original shortcut module list as module_spec; 
                    #  - We also restore the modulepath from the shortcut in case a custom path was present
                    #    during the original shortcut build (i.e. if the user had previously done 'module use')
                    if [[ "${request_type}" == 'load' ]] ; then
                        module_spec=(`cat "${quikmod_lua%.*}".spec`)
                        build_modpath=(`cat "${quikmod_lua%.*}".modpath`)
                        rebuild=1
                        
                        # echo 'Falling back to ordinary module loads'
                        # echo 'To rebuild, please use:'
                        # if [[ "${shortcut_name}" == "${module_spec[@]}" ]] ; then
                        #     echo 'mlq -b '"${module_spec[@]}"
                        # else
                        #     echo 'mlq -b '"${shortcut_name}"' '"${module_spec[@]}"
                        # fi
                        # fall_back=1
                    fi
                fi
            else
                if [[ "${request_type}" == 'build' ]] ; then
                    ###########################################
                    # If nothing changed, blow off the user's request
                    #  (they can always manually delete)
                    ###########################################
                    echo 'Shortcut '"'"${shortcut_name}"'"' exists already and seems to be up to date; nothing done'
                    return
                fi
            fi
        fi
    fi

    ###########################################
    # Build the shortcut, if needed
    ###########################################
    if [[ ( "${request_type}" == 'build' && "${need_to_build}" ) || "${rebuild}" ]]; then

        if [[ "${custom_name}" ]] ; then
            printf '%s' 'Building custom-named shortcut for '"'""${shortcut_name}""'"
        else
            printf '%s' 'Building shortcut for '"'""${shortcut_name}""'"
        fi

        echo ' with included modules:'
        echo "${module_spec[@]}"
        
        # Restore the modulepath from the shortcut in case a custom path was present
        #  during the original shortcut build (i.e. if the user had previously done 'module use')
        if [[ "${build_modpath}" ]] ; then
            export MODULEPATH="${build_modpath}"
        fi

        local build_failed
        build_failed=
        
        if [[ -f "${quikmod_lua}" ]] ; then
            echo 'The shortcut '"'"${shortcut_name}'"'' exists already.'

            # The below line tests if we are in an interactive shell
            # We would like to keep slurm jobs, etc, from failing if they
            #  need to be updated
            if [[ $- == *i* && ! ( -p /dev/stdin ) ]] ; then
                local confirm
                read -p 'Are you sure you want to rebuild it? (Y/N): ' confirm
                if [[ ! ( $confirm == [yY] || $confirm == [yY][eE][sS] ) ]]; then
                    # return
                    build_failed=1
                fi
            else
                echo 'Non-interactive shell: automatically proceeding'
            fi
        fi

        # Below, a 'while' statement is used in place of an 'if' statement.
        #  The while statement does not iterate because of the 'break' statement at the end.
        #  Rather, 'while' is used so it can be broken out of, if the shortcut build fails.
        while [[ ! "${build_failed}" ]] ; do
            
            # Check if lmod can find the requested modules:
            # __mlq_orig_module -I is-avail ${module_spec[@]}
            __mlq_orig_module is-avail ${module_spec[@]}

            if [[ ($? != 0) ]]; then
                # The requested module(s) were not available
                echo "Sorry, shortcut '"${shortcut_name}"' cannot be built because one or more of the module(s)"
                echo " cannot be found:"
                echo "   ${module_spec[@]}"
                echo 'This may be because your module search path has changed.'
                echo 'Please adjust the search path with '"'"'module use'"'"' and try again.'

                echo 'Current module path for this shortcut:'
                echo $MODULEPATH
                
                # return 1
                build_failed=1
                break
            fi

            # echo Getting full module names and versions

            # Get the full module names
            local mod
            local modfile_check
            local fullmod
            
            local module_spec_full
            module_spec_full=       
            for mod in ${module_spec[@]} ; do
                # modfile_check=`__mlq_orig_module -I --redirect --location show "${mod}"`
                modfile_check=`__mlq_orig_module --redirect --location show "${mod}"`

                # Get the full module name including the version
                #  To do this, we combine info from the possibly versionless module name together
                #  with the module filename.
                fullmod=$(echo "$modfile_check" | awk -v modname="$mod" '
                         function escape_regex(s,    i, c, out, specials) {
                             specials = "\\.^$*+?()[]{}|";
                             out = "";
                             for (i = 1; i <= length(s); i++) {
                                 c = substr(s, i, 1);
                                 if (index(specials, c)) {
                                                                      out = out "\\" c;
                                 } else {
                                     out = out c;
                                 }
                             }
                             return out;
                         }
                         BEGIN {
                             escaped_modname = escape_regex(modname);
                             pattern = escaped_modname "([^/]*|/[^/]+)\\.lua$";
                         }
                         {
                             if (match($0, pattern)) {
                                 print substr($0, RSTART, RLENGTH-4);
                             }
                         }')

                module_spec_full=(${module_spec_full[@]} "${fullmod}")
            done

            printf 'Purging any loaded modules...'
            __mlq_reset
            
            echo ' done.'

            # If rebuilding, use the 'unsafe' way if that was how it was done originally
            if [[ "${rebuild}" ]] ; then
                if [[ -f "${quikmod_lua%.*}".unsafe_build ]] ; then
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo 'WARNING: this shortcut was built with the '"'"'--unsafe_build'"'"' option. Rebuilding in the same manner'
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    
                    safe_build=
                else
                    safe_build=1
                fi
            fi
                        
            # Strict checking for module loading consistency
            if [[ "${safe_build}" ]] ; then
                # for mod in ${module_spec_full[@]} ; do

                echo 'Strict module consistency check: ' "${module_spec_full[@]}"
                mlq_check "${module_spec_full[@]}"
                
                if [[ $? -ne 0 ]]; then
                    echo ''
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo ''
                    echo 'ERROR: Consistency check failed.'
                    echo 'If you would really like to build this shortcut, try the '"'"'--unsafe_build'"'"' option.'
                    echo ''
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo ''
                    
                    # return 1
                    build_failed=1
                    break
                fi
                
                echo ''     
            fi

            # Make the needed directories;
            #  Here we make it so that the target_dir can be a symbolic link to
            #  a pre-generated, read-only shortcut set up elsewhere.
            # Then, if the shortcut needs to be rebuilt, we remove the symbolic link
            #  and replace with an updated shortcut.
            # Get rid of these directories if they are actually links:
            [[ -h "${target_dir}" ]] && /bin/rm "${target_dir}"
            [[ -h "${extended_target_dir}" ]] && /bin/rm "${extended_target_dir}"
            
            mkdir -p "${target_dir}"
            mkdir -p "${extended_target_dir}"

            # Load the modules
            printf '%s' 'Loading module(s): '
            echo "${module_spec_full[@]}" ' ...'
            
            # __mlq_orig_module -I --redirect load ${module_spec_full[@]} >& "${quikmod_lua%.*}".warnings
            __mlq_orig_module --ignore_cache --redirect load ${module_spec_full[@]} >& "${quikmod_lua%.*}".warnings
            
            local retVal
            retVal=$?

            if [ "${retVal}" -ne 0 ]; then
                echo ''
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo ''
                echo 'ERROR: could not load the original module(s). The offending command:'
                echo '   ml '"${module_spec[@]}"
                echo ''
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                
                export MODULEPATH="${mlq_user_orig_modpath}"

                # return 1
                build_failed=1
                break
            fi
            echo ' done.'

            if [[ "${safe_build}" ]] ; then
                if [ `awk 'BEGIN {sum=0} tolower($0) ~ "warn" {sum += NF} END {print sum}' "${quikmod_lua%.*}".warnings` -gt 0 ] ; then
                    echo ''
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo ''
                    echo 'ERROR: could not load the original module(s) cleanly.'
                    echo 'The following warnings were reported:'
                    echo ''
                    cat "${quikmod_lua%.*}".warnings
                    echo ''
                    echo 'If you would really like to build this shortcut, try the '"'"'--unsafe_build'"'"' option.'
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'

                    # return 1
                    build_failed=1
                    break
                fi
            fi

            # Specify the location for module collection files.
            # We use LMOD_USE_DOT_CONFIG_ONLY to make sure
            #  the collection is saved in the traditional place, ~/.lmod.d
            #  (modules are still also saved in the 'new' default 
            #  location, ~/.config/lmod
            local orig_lmod_use_dot_config_only
            orig_lmod_use_dot_config_only="${LMOD_USE_DOT_CONFIG_ONLY}"
            export LMOD_USE_DOT_CONFIG_ONLY=no
            
            ###########################################
            ###########################################
            ###########################################
            # The actual shortcut building code:
            ###########################################
            ###########################################
            ###########################################

            echo 'Establishing the build order'
            
            ##################
            # Get the list of module files, in the correct build order: 'ordered_module_list'
            # Note: the succinct but slow way to do this is:
            # ordered_module_list=( $(for m in `ml --redirect -t|grep -v StdEnv` ; do ml --redirect --location show $m ; done) )
            ##################

            # Get the module build order by making a module collection with
            #  the 'module save' function.
            # Here we turn off caching to eliminate any possible glitches;
            #  also, we use --width=1 so lmod doesn't print out things in
            #  in multi-column format, which depends on the user's window width!
            __mlq_orig_module --redirect --ignore_cache --width=1 save "${collection_name}" >& /dev/null

            # lua script for processing lmod collection files
            # This obtains a list of lua modulefiles, from the saved module collection file,
            #  defining the modules to be used for a shortcut.
            # It also prints the load order number.
            process_collection_lua_script='
              for key, subTable in pairs(_ModuleTable_.mT) do 
                if type(subTable) == "table" and subTable.fn then
                  print(subTable.loadOrder, subTable.fn) 
                end 
              end '

            # Account for different naming conventions for module collection files
            #  (there seem to be at least two)
            local collection_file
            if [[ "${LMOD_SYSTEM_NAME}" ]]; then
                collection_file="${HOME}"/.config/lmod/${collection_name}.${LMOD_SYSTEM_NAME}
            else
                collection_file="${HOME}"/.config/lmod/"${collection_name}"
            fi

            # Get list of modulefiles from the saved module collection file;
            # but don't include the standard environment
            # also, be sure to sort the list by the load order.
            
            ( cat "${collection_file}" ; echo "${process_collection_lua_script}" ) | \
                lua - | sort -n -k 1 | awk '{print $2}' | \
		grep -v 'StdEnv[.]lua$' | awk '$0 !~ "/mlq/[^/]+[.]lua$"' | awk '$0 !~ "/mlq[.]lua$"' \
					       > "${quikmod_lua%.*}".mod_list
	    
            ordered_module_list=(`cat "${quikmod_lua%.*}.mod_list"`)
            if [[ ! "${ordered_module_list[@]}" ]] ; then
                echo ''
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo 'ERROR: module load of '"'"${module_spec[@]}"'"' seems to have failed!'
                echo '  Nothing done.'
                echo '  The offending command:'
                echo "      ml ${module_spec[@]}"
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'

                export MODULEPATH="${mlq_user_orig_modpath}"

                # return 1
                build_failed=1
                break
            fi      

            # Safety check: did all the requested modules make it into the 'mod_list' file?
            # If not, the module load order is unrecoverable unless the last requested one is the one that's missing.
            # Note: The below safety check should be redundant with the above strict consistency checks
            if [[ "${safe_build}" ]] ; then
                echo 'Performing extra safety checks'
                
                #  The below, funky 'for' statement performs the safety check for all
                #  but the last requested module, which is handled immediately afterwards.
                for mod in ${module_spec[@]::${#module_spec[@]}-1} ; do         
                    # modfile_check=`__mlq_orig_module -I --redirect --location show "${mod}"`
                    modfile_check=`__mlq_orig_module --redirect --location show "${mod}"`

                    if [[ ! `awk -v mod="${modfile_check}" '$1 == mod {print 1}' "${quikmod_lua%.*}.mod_list"` ]] ; then
                        echo ''
                        echo '###########################################'
                        echo '###########################################'
                        echo '###########################################'
                        echo 'ERROR: the command '"'"'module load '"${mod}""'"' partially failed.'
                        echo ' '"'"'module list'"'"' does not list this module afterwards.'
                        echo ' The correct module load order therefore cannot be determined.'
                        echo ''
                        echo ' To confirm, do: '"'"'module reset; module load '"${mod}"'; module list'"'"
                        echo ''
                        echo ' Please compare with the shortcut module listing '"'""${quikmod_lua%.*}.mod_list""'" '.'
                        echo ''
                        echo ' Also check the original modulefile '"'""${modfile_check}""'" '.'
                        echo ' Maybe it is an inappropriately named symbolic link?'
                        echo ''
                        echo 'If you would really like to build this shortcut, try the '"'"'--unsafe_build'"'"' option.'
                        echo ''
                        echo 'Exiting...'
                        echo '###########################################'
                        echo '###########################################'
                        echo '###########################################'
                        echo ''

                        export MODULEPATH="${mlq_user_orig_modpath}"
                        
                        # return 1
                        build_failed=1
                        break
                    fi
                done
            fi

            # Check if the last requested file made it into the 'mod_list' file.
            # If not, issue a warning and add it to the end of the file. We can
            #  do this since it should always be executed at the very end.

            # modfile_check=`__mlq_orig_module -I --redirect --location show "${module_spec[-1]}"`
            modfile_check=`__mlq_orig_module --redirect --location show "${module_spec[-1]}"`

            if [ ! $( echo "${modfile_check}" "${ordered_module_list[-1]}" | awk '{ if($1 == $2) {print 1} else {print 0}}' ) -ne 0 ] ; then

                echo ''
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo 'WARNING: the command '"'"'module load '"${module_spec[-1]}""'"' partially failed.'
                echo ' '"'"'module list'"'"' does not include this module at the end.'
                echo ''
                echo ' To confirm, do: '"'"'module reset; module load '"${mod}"'; module list'"'"
                echo ''
                echo ' Attempting to repair by including original modulefile:'
                echo '   '"'""${modfile_check}""'"
                echo ' at the end of the shortcut modulefile.'
                echo ''
                echo ' Note, the module and/or the derived shortcut may not unload cleanly.'
                echo ''
                echo ' Please compare with the shortcut module listing '"'""${quikmod_lua%.*}.mod_list""'"'.'
                echo ''
                echo ' Also check the original modulefile '"'""${modfile_check}""'"'.'
                echo ' Maybe it is an inappropriately named symbolic link?'
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo ''
                echo "${modfile_check}" >> "${quikmod_lua%.*}.mod_list"
            fi

            # Record the shortcut environment for consistency checks, rebuilding ,etc.
            if [[ ! "${safe_build}" ]] ; then
                touch "${quikmod_lua%.*}".unsafe_build
            else
                [[ -f "${quikmod_lua%.*}".unsafe_build ]] && /bin/rm "${quikmod_lua%.*}".unsafe_build
            fi
            
            ordered_module_list=(`cat "${quikmod_lua%.*}.mod_list"`)
            eval "$build_lua_record" > "${quikmod_lua%.*}".lua_record
            echo "${MODULEPATH}" > "${quikmod_lua%.*}".modpath
            
            # Use a temporary file so we can make the creation of the new lua file atomic (below)
            printf "" > "${quikmod_lua}"_temp

            # Concatenate all the .lua files required by this collection,
            #  but strip out the 'depends_on' statements.
            
            # This is predicated on 'module save' having generated a complete, self-consistent
            #  list of modules, with a defined build order that we will use when loading.
            #  (ordered_module_list is sorted on the build order).

            #  Note that most lmod lua files include local declarations of 'root',
            #   and lua will error out if more than 500 local declarations are made,
            #   even when these are of the same variable. So we also use awk to take care of this,
            #   making it so that only the first 'root' declaration keeps the 'local' keyword.

            ordered_module_list=(`cat "${quikmod_lua%.*}.mod_list"`)
            local m
            (for m in ${ordered_module_list[@]} ; do grep -v 'depends_on' "${m}" ; done) | \
                awk \
                    '{ \
                   if($0 ~ "^local[ ]root[ ][=]") { \
                     n+=1; \
                     if(n > 1) \
                       sub("^local[ ]root[ ][=]", "root ="); \
                   } \
                   print; \
                 }' \
                    >> "${quikmod_lua}"_temp

            ###########################################
            ###########################################
            ###########################################
            # End of shortcut building code
            ###########################################
            ###########################################
            ###########################################
            
            # Make the creation of the new lua file atomic
            /bin/mv "${quikmod_lua}"_temp "${quikmod_lua}"

            # Restore the original module collection file location
            export LMOD_USE_DOT_CONFIG_ONLY="${orig_lmod_use_dot_config_only}"
            
            printf '' > "${quikmod_lua%.*}".spec
            for mod in ${module_spec_full[@]} ; do
                echo ${mod} >> "${quikmod_lua%.*}".spec
            done
            
            # If a shortcut name has been given or else defined by --autoname
            #  add this to the custom shortcut list for when '--help' is used
            
            if [[ "${custom_name}" ]] ; then
                [[ "${extended_custom_target_dir}" ]] && mkdir -p "${extended_custom_target_dir}"
                touch "${lua_custom_placeholder}"
            fi
            
            __mlq_reset

            echo ''
            echo 'Shortcut '"'""${shortcut_name}""'"' is now available. To use, type:'
            echo 'mlq '"${shortcut_name}"
            echo ''

            # Below, we break out of while statement;
            #  we never iterate, we just use it as an 'if' statement
            #  that can be broken out of
            break
        done
        # while [[ ! "${build_failed}" ]] ; do

        # Restore the original module path prior to exiting
        export MODULEPATH="${mlq_user_orig_modpath}"

        # If a rebuild was attempted after the user requested to load the shortcut,
        #  but the rebuild failed, we fall back to ordinary module loading.
        if [[ "${build_failed}" && "${request_type}" == 'load' ]] ; then
            echo 'WARNING: Shortcut has failed, so falling back to ordinary module loading.'
            
            # Reset all modules to emulate the behavior of shortcut loading
            fall_back=1
            __mlq_reset

            # Restore the modulepath from the shortcut in case a custom path was present
            #  during the original shortcut build (i.e. if the user had previously done 'module use')
            if [[ "${build_modpath}" ]] ; then
                export MODULEPATH="${build_modpath}"
            fi
        fi          
    fi
    # if [[ ( "${request_type}" == 'build' && "${need_to_build}" ) || "${rebuild}" ]]; then
    
    ###########################################
    # Load the shortcut (or perform 'ml' command)
    # If there is no shortcut, fall back to the lmod 'ml' command
    ###########################################

    if [[ "${request_type}" == 'load' ]] ; then
        ###########################################
        # Ordinary module functions
        ###########################################
        if [[ -f "${quikmod_lua}" && ! "${fall_back}" ]] ; then
            ###########################################
            # Load the shortcut
            ###########################################
            local spec
            spec=`awk '{printf("\n"); for(i=1; i <= NF-1; ++i) printf("%s, ", $i); printf($i)}' "${quikmod_lua%.*}".spec`

            printf "%s" "Loading shortcut ${shortcut_name} with included modules:"
            printf "${spec}"
            printf '..'
            
            # Don't try to do this trick with other modules around
            __mlq_reset
            echo '.'

            __mlq_orig_module use -a "${mlq_dir}/${collection_name}"
            __mlq_orig_module load "${shortcut_name_full}"

	    if [[ $? == 0 ]] ; then
		__mlqs_active="${shortcut_name_full}"
		echo 'Use '"'"'mlq -r'"'"' (or '"'"'module reset'"'"' / '"'"'module purge'"'"') to turn off this shortcut.'
	    else
		echo 'An error occurred loading the shortcut. Falling back to ordinary module loading...'
		fall_back=1
	    fi
	fi
	
        if [[ ! -f "${quikmod_lua}" || "${fall_back}" ]] ; then

	    # 'list' and 'reset' are handled specially because they invoked by
	    #  'module' rather than 'module load'
	    if [[ "${module_spec[0]}" == 'list' || "${module_spec[0]}" == 'reset' || \
		      "${module_spec[0]}" == 'purge' ]] ; then
		__mlq_orig_module ${module_spec[@]}
	    else
		# Don't allow shortcuts if the user is trying to do ordinary module functions
		__mlq_shortcut_reset

		echo 'Executing: '"'"'ml '"${module_spec[@]}""'"
		__mlq_orig_module use "${__mlq_path}"
		__mlq_orig_module load ${module_spec[@]}
	    fi
	fi
    fi
}

###########################################
# Function __mlq_parse_module_tree_iter
# Strict checking for module loading consistency:
#  is the same version of each required module
#  always used?
# Do this by recursively parsing the Lua module file tree
###########################################

# Enable autocompletion for mlq_check the same as 'module':
# t=(`complete -p ml`)
# complete -F "${t[2]}" mlq
if [ "$(type -t _ml)" = 'function' ]; then
    complete -F _ml mlq_check
fi

function mlq_check() {

    local return_status
    return_status=
    
    local mlq_check_args
    mlq_check_args=
    # If no arguments given, check the current module environment
    if [[ "$#" -gt 0 ]] ; then
        mlq_check_args="${@:1}"
    else
        mlq_check_args=`__mlq_orig_module --redirect -t list`
        # Reset the module environment to speed up the checking
        # __mlq_reset
    fi

    unset __mlq_module_version
    unset __mlq_module_file
    unset __mlq_module_callstack
    unset __mlq_expected_versions
    declare -Ag __mlq_module_file
    declare -Ag __mlq_module_version
    declare -Ag __mlq_module_callstack
    declare -Ag __mlq_expected_versions
    
    __mlq_parse_module_tree_iter ${mlq_check_args}
    if [[ $? -ne 0 ]]; then
        return_status=1
    fi
    
    unset __mlq_module_version
    unset __mlq_module_file
    unset __mlq_module_callstack
    unset __mlq_expected_versions

    # Restore the previously loaded modules
    if [[ "$#" -lt 1 ]] ; then
        __mlq_orig_module load ${mlq_check_args}
    fi
    return $return_status
}

function __mlq_parse_module_tree_iter() {
    local callstack
    local toplevel
    callstack=
    toplevel=
    if [[ "$1" == '--callstack' ]] ; then
        shift
        callstack=$1
        shift
    else
        toplevel=1
    fi

    local return_status
    return_status=0
    
    # Loop through all the input arguments;
    #  By using "${@:1}" instead of $* we can correctly handle special characters in the arguments
    for fullmod in "${@:1}" ; do
        # Avoid re-parsing the same module
        if [[ "${__mlq_expected_versions[$fullmod]}" ]]; then
            continue
        fi
        
        if [[ "${toplevel}" ]] ; then
            printf 'Parsing: '"'""${fullmod}""'"' ...'
            callstack="${fullmod}"
        else
            printf '.'
            callstack="${callstack}":"${fullmod}"
        fi

        # Extract module name and version
        local name="$(echo "$fullmod" | awk -F/ '{print $(NF-1)}')"
        local version="$(echo "$fullmod" | awk -F/ 'NF > 1 {print $NF}')"

        # module --location fails with an ugly error if the module is not found
        # the following would check for that, but makes the algorithm very slow
        # __mlq_orig_module -I is-avail ${fullmod}
        # if [[ ($? != 0) ]]; then
        #     echo 'ERROR: module not found: ' "${fullmod}"
        #     return 1
        # fi

        # Get the modulefile
        local modfile=$(__mlq_orig_module --redirect --location show "$fullmod")

        # Check if module --location failed (module not found)
        if [[ ! "${modfile}" ]] ; then
            echo 'ERROR: module not found: ' "${fullmod}"
            echo 'Call stack: '"${callstack}"
            # return immediately; cannot proceed without a modulefile
            return 1
        fi
        
        # Check if the version has already been encountered for this module

        # if [[ "${__mlq_module_version[$name]}" && "${__mlq_module_version[$name]}" != "$version" ]]; then
        if [[ "${__mlq_module_version[$name]}" && "${__mlq_module_file[$name]}" != "$modfile" ]] ; then
            echo ''
            echo 'Conflict: Multiple version dependencies were found for ' "'"${name}"'" ':'
            echo '     '"'"${version}"'"'(Call stack: '${callstack}' )'
            echo '     File: '"${modfile}"
            echo '                vs.'
            echo '     '"'"${__mlq_module_version[$name]}"'"' (Call stack: '${__mlq_module_callstack[$name]}"'"
            echo '     File: '"${__mlq_module_file[$name]}"
            return_status=1
        fi

        __mlq_module_version[$name]="$version"  # Track version
        __mlq_module_file[$name]="$modfile"  # Track actual modfile name
        __mlq_module_callstack[$name]="$callstack"   # Record whose dependency this is
        __mlq_expected_versions[$fullmod]="$version"     # Record version

        # Parse dependencies
        local modname_list=`awk '$1 ~ "^depends_on[(][\"]" {sub("^depends_on[(][\"]","",$1); sub("[\"][)]$","",$1); print $1}' $modfile`

        local m
        for m in $modname_list; do
            __mlq_parse_module_tree_iter --callstack "${callstack}" "$m"
            
            if [[ $? -ne 0 ]]; then
                # echo "while loading: ${fullmod}"
                return_status=1
            fi
        done

        if [[ "${toplevel}" ]] ; then
            echo ' done.'
        fi
    done

    return $return_status
}
