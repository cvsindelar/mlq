# mlq: module loader-quick
# Please source this script to access the quik module-loading shortcut function '__mlq'
#  as well as the module consistency checker 'mlq_check'
#
# Use 'source mlq.sh --mlq_unload' to remove all traces of these functions
#
# Use the included Easybuild (.eb) file to incorporate mlq into a module;
#  or edit and use the included modulefile (.lua) directly.

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

IFS='' read -r -d '' __mlq_moo <<"EOF"
           (__)
           (@@)
    /##--##-\#)
   / ###  # |  
  *  ||ww--||  
     ^^    ^^  
EOF

###########################################
###########################################
###########################################
# Code to incorporate mlq into a module
###########################################
###########################################
###########################################

# Function to reset modules while keeping the mlq environment intact
function __mlq_reset() {
    # The below variables preserve mlq info if we are in the mlq module;
    #  this is so we can remember them after resetting the module, which
    #  eliminates all __mlq variables
    local tmp_path="${__mlq_path}"
    local tmp_version="${__mlq_version}"
    local tmp_mlq_loaded="${__mlq_loaded}"

    if [[ $# -gt 0 ]] ; then
        # Below, we unload mlq prior to reset/restore/purge; 
        #  this is currently unnecessary since these commands all unload mlq anyway;
        #  just prevents a confusing 'unload' message since it is immediately loaded again.
        # However, if 'module restore' were ever made to work with shortcuts, the mlq 
        #  unloading would probably be needed to prevent quirky behavior on the part of lmod.

        __mlq_orig_module unload ${__mlq_version} >& /dev/null
        module "${@:1}"
    else
        __mlq_orig_module reset >& /dev/null
    fi  
    
    if [[ "${tmp_version}" ]] ; then
        # Keep mlq around; the user can get rid of it by doing 'module reset'
        
        # Note that mlq could be present after a 'module restore', if the
        #  the restored environment includes mlq.
        #  Below, we check for that and make sure to override the restored mlq,
        #   (although unlikely, the restored mlq could be from a different module path and/or
        #    different version than the original)
        if [[ ! `module --redirect -t list | awk '$1 ~ "^mlq[/]"'` ]] ; then
            __mlq_loaded="${tmp_mlq_loaded}"
            module use "${tmp_path}"
            module --redirect load "${tmp_version}" >& /dev/null
            
            # If the reset/restore/purge lost the path to the mlq module, the below line could check for that:
            # if [[ ! `module --redirect --location show ${tmp_version} 2> /dev/null | awk '$0 ~ ".lua$"' ` ]] ; then
        fi
    fi
}

# Function to unload the mlq shortcut if present
function __mlq_shortcut_reset() {
    local mlqs_active
    mlqs_active=(`__mlqs_active`)
    
    # If there is an active shortcut, unload it.
    if [[ "${mlqs_active[@]}" ]]; then
        printf 'Deactivating the shortcut: '
        
        # There shouldn't be more than one, but account for this anyway just in case
        echo "${mlqs_active[@]}" | awk '{for(ind=1; ind<=NF;++ind) {printf("'\'%s\'' ", substr($ind,5,length($ind)-4));} printf("...")}'

        __mlq_orig_module unload "${mlqs_active[@]}"
        # __mlq_orig_module unload "${mlqs_active[@]}" >& /dev/null # > /dev/null 2>&1

        local mlq_path
        for mod in ${mlqs_active[@]} ; do
            # Path may not exist if mlqs_active is out of date (i.e., shortcuts removed by 'module reset')
            mlq_path=`__mlq_orig_module -t --redirect --location show "${mod}" 2>&1`
            if [[ $#{mlq_path} == 1 ]] ; then
                mlq_path="${mlq_path%/*}"
                __mlq_orig_module unuse "${mlq_path}"
            fi
        done
        
        echo ' done.'
    fi
}

function __mlqs_active() {
    ###########################################
    # Prints any active shortcut
    # (there shouldn't be more than one, but handle that case
    #  anyway, to be safe)
    ###########################################

    local __mlqs_active_candidates
    local mod
    local mod_file
    local mlqs_active
    unset mlqs_active
    mlqs_active_candidates=(`__mlq_orig_module -t --redirect list|grep '^mlq[-]'`)
    for mod in ${mlqs_active_candidates[@]} ; do
        mod_file=`__mlq_orig_module --redirect --location show "${mod}"`

        # Screen out 'imposter' modules that start with 'mlq-' but are not shortcuts
        is_qmod=`echo "${mod_file}" | \
                      awk -v qhome="${HOME}"/.mlq/mlq -v qprebuilds="${__mlq_prebuild_dir}" \
                      '{ if(index($1,qhome) == 1 || index($1,qprebuilds) == 1) print(1); }'`
        
        if [[ "${is_qmod}"  ]] ; then
            if [[ ! "${mlqs_active[@]}" ]] ; then
                mlqs_active=("${mod}")
            else
                mlqs_active=("${mlqs_active[@]}" "${mod}")
            fi
        fi
    done
    
    echo ${mlqs_active[@]}
}

function __mlq_active_modules() {
    ###########################################
    # Prints any active module that is not a shortcut
    # (basically the inverse of __mlqs_active)
    ###########################################

    local __mlqs_active_candidates
    local mod
    local mod_file
    local mlqs_active
    modules_active=
    module_candidates=(`__mlq_orig_module -t --redirect list|grep -v '^mlq[/]'`)
    for mod in ${module_candidates[@]} ; do
        # Look for 'imposter' modules that start with 'mlq-' but are not shortcuts
        unset is_qmod
        if [[ `echo $mod | grep '^mlq[-]'` ]] ; then
            mod_file=`__mlq_orig_module --redirect --location show "${mod}"`
            is_qmod=`echo "${mod_file}" | \
                      awk -v qhome="${HOME}"/.mlq/mlq -v qprebuilds="${__mlq_prebuild_dir}" \
                      '{ if(index($1,qhome) == 1 || index($1,qprebuilds) == 1) print(1); }'`
        fi
        
        if [[ ! "${is_qmod}"  ]] ; then
            if [[ ! "${modules_active[@]}" ]] ; then
                modules_active=("${mod}")
            else
                modules_active=("${modules_active[@]}" "${mod}")
            fi
        fi
    done
    
    echo ${modules_active[@]}
}

# Convert a space-separated list of module names into a string that works with lmod collections
function __mlq_collection_name() {
    local mod
    local fullmods
    fullmods=`( for m in "${@:1}" ; do __mlq_get_default_module "$m" ; done )`
    echo ${fullmods[@]} | awk '{gsub("/","-",$0); gsub("[.]","_",$0); gsub("[ ]","___",$0); print $0}'
}

# Get the full module name including the version; if version is missing, fill in
#  the default version if possible.
function __mlq_get_default_module() {
    if [[ $# -ne 1 ]] ; then
        return
    fi

    local mod
    # Below: strip spaces out of our arguments, in case ahem OnDemand gives space-ful ones
    mod=`echo $1`
    # Remove any trailing slash from the module name
    mod="${mod%/}"
    
    # Getting the modulefile location will fill out the default version if needed
    local modfile
    modfile=`(__mlq_orig_module --redirect --location show "${mod}"|awk 'NF == 1') 2> /dev/null`
    
    #  Combine info from the possibly versionless module name together
    #  with the module filename.
    if [[ ${modfile} ]] ; then
        fullmod=$(echo "$modfile" | awk -v modname="${mod}" '
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
        if [[ "${fullmod}" ]] ; then
            echo "${fullmod}"
        else
            echo "${mod}"
        fi
    else
        echo "${mod}"
    fi
}

# Save the original 'module' functions code as __mlq_orig_module
#  and __mlq_orig_ml
# This is for restoring the 'module' functions upon unloading mlq,
#  since we will add hooks to them.
# Note: this can only be done once per load of the mlq module, or 
#  we will destroy the saved original version of the functions!

# If __mlq function is not defined, this is the first time mlq has been loaded.
if [[ ! `type -t __mlq 2> /dev/null` == 'function' ]]; then
  if [[ `declare -f module | grep mlq` ]] ; then
      echo "${__mlq_moo}"
      echo 'ERROR: the mlq environment has become confused!'
      echo 'To restore normal module-loading behavior, you may need to'
      echo 'log out and log in again!'
      return 1
  fi

  eval "$(echo "function __mlq_orig_module()"; declare -f module | tail -n +2)"
  eval "$(echo "function __mlq_orig_ml()"; declare -f ml | tail -n +2)"
fi

# The user can specify --mlq_load to specify we are loading mlq with lmod
#  ('mlq' module), giving the specific version as an argument
# Note, we also test if the __mlq function is defined, because we don't need
#  to load it twice
if [[ "$1" == "--mlq_load" && ! `type -t __mlq 2> /dev/null` == 'function' ]]; then

    # Get rid of all other loaded modules
    # module purge
    
    # echo Loading mlq
    if [[ ! $# != 4 ]] ; then
        echo "${__mlq_moo}"
        echo 'Usage:'
        echo    'source mlq.sh --mlq_load mlq/<version> <path-to-mlq-lua file>'
        return
    fi

    # Make sure the mlq module can be found
    # module is-avail "$2"

    # Get the path to the modulefile
    #  (requires that the modulefile name ends with the right string, mlq/<version>.lua)
    __mlq_path=`echo $2 $3 | awk '{name=$1 ".lua"; if(index($2,name) == length($2) - length(name)+1) print substr($2,1,length($2) - length(name) - 1); }'`

    # Check if the file exists and if the module path was identified correctly
    if [[ ! -f "$3" || ! "${__mlq_path}" ]]; then
        echo "${__mlq_moo}"
        echo 'ERROR: mlq module '"'""$2""'"' not found.'
        echo $3
        echo 'Usage:'
        echo    'source mlq.sh --mlq_load mlq/<version> <path-to-mlq-lua file>'
        return 1
    else
        # Old way:
        # Get the path to the mlq lmod .lua file; this is stored in case
        #  subsequent module resets remove the path from $MODULEPATH
        # __mlq_path=`module --redirect --location show "$2"|awk '{n=sub("/mlq/[^/]+[.]lua$","",$0); if(!n) n=sub("/mlq[.]lua$","",$0); if(n) print}'`

        # New way: path is given by the modulefile
        # Extract the path from the full filename
        # __mlq_path=`echo "$3"|awk '{n=sub("/mlq/[^/]+[.]lua$","",$0); if(!n) n=sub("/mlq[.]lua$","",$0); if(n) print}'`
        if [[ ! ${__mlq_path} ]] ; then
            echo "${__mlq_moo}"
            echo 'ERROR: path to the mlq module cannot be determined!'
            echo '(this should not happen)'
            unset __mlq_path
            return 1
        fi
        __mlq_version="$2"
    fi

    # Add a hook to the 'module' command, so that it unloads mlq and any shortcut
    #  before proceeding. This avoids mixing modules with shortcuts.

    if [[ `declare -f __mlq_orig_module | grep -v __mlq_orig_module | grep mlq` ]] ; then
        echo "${__mlq_moo}"
        echo 'ERROR: the mlq environment has become very, very, very! confused!'
        echo 'To restore normal module-loading behavior, you may need to'
        echo 'log out and log in again!'
        return 1
    fi

    function module() {
        local retVal
        retVal=0
        
        # If doing 'module load', first unload any loaded shortcuts
        # We skip this if the first module argument is an unload request (starts with '-')
        if [[ "$1" == 'load' && $# -gt 1 ]] ; then

            local good_mod_args
            local mod_arg
	    unset good_mod_args
            for mod_arg in "${@:2}" ; do
                # Don't reload the same mlq module on top of itself, as this complicates things
                #  when starting a slurm job, for instance

                mlq_test=( `__mlq_orig_module --redirect --location show "${mod_arg}" 2>&1` )
                if [[ ${#mlq_test[@]} == 1 \
                          && "${__mlq_path}/${__mlq_version}.lua" == "${mlq_test[@]}" ]] ; then
                    echo '[mlq] module '"${__mlq_version}"' is already loaded, skipping...'
                else
                    good_mod_args=( ${good_mod_args[@]} $mod_arg)
                fi
            done

            if [[ "${good_mod_args}" ]] ; then
                # Unload all shortcuts
                __mlq_shortcut_reset

                echo '[mlq] Executing: module load '"${good_mod_args[@]}"
                __mlq_orig_module load "${good_mod_args[@]}"
                retVal=$?
            fi
            return "${retVal}"
        fi

        # Shortcuts do not work when saved in collections. This is because when a collection
        #  is loaded, its path must be in the $MODULEPATH- which it will not be, because __mlq
        #  uses custom paths added to $MODULEPATH, not available otherwise.
        # Even if shortcuts did work with collections it turns out we would need to unload mlq 
        #  before doing a module restore, to ensure that shortcuts in saved collections are
        #  not omitted from the restore!
        # This is because lmod seems not to unload old modules before it begins 
        #  loading the saved ones in the collections. So the old mlq can stay 
        #  loaded past the point when a saved collection shortcut gets loaded.
        #  Then, unloading of the old mlq can occur, which unloads the newly
        #  restored shortcut!!
        # The following code could address the second problem, but not the first:
        # if [[ "$1" == 'restore' || "$1" == 'r' ]] ; then
        #     __mlq_orig_module unload ${__mlq_version} >& /dev/null        
        # fi
        
        if [[ ( "$1" == 'save' || "$1" == 's' ) ]] ; then
            local mlqs_active
            mlqs_active=`__mlqs_active`
            if [[ "${mlqs_active}" ]] ; then
                echo "${__mlq_moo}"
                echo 'Sorry, shortcuts cannot be saved in an lmod collection'
                echo 'To load a shortcut on login, you can put a line in your shell startup file (i.e., .bashrc):'
                echo "${mlqs_active}" | awk '{print "  ml mlq; ml " substr($1,5,length($1)-4)}'
                return 1
            fi
        fi

        # If listing modules, check if ordinary modules and shortcuts are both present (shouldn't be!)
        if [[ ( "$1" == 'list' || "$1" == 'l' ) ]] ; then
            local mlqs_active
            mlqs_active=`__mlqs_active`
            if [[ "${mlqs_active}" ]]; then
                if [[ `__mlq_orig_module --redirect -t list|grep -v StdEnv|grep -v '^mlq[-|/]'` ]] ; then
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo 'WARNING: the mlq environment appears to be corrupted.'
                    echo 'Additional modules are loaded on top of the shortcut' `echo "${mlqs_active}" | awk '{printf("'\'%s\'' ... ", substr($1,5,length($1)-4))}'`
                    echo 'Results may not be predictable; recommend to do '"'"ml reset"'"' before proceeding.'
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                fi
            fi
        fi
        
        # echo '[mlq] Executing: module '"${@:1}"
        __mlq_orig_module "${@:1}"
        retVal="$?"
        return "${retVal}"
    }

    # Add a hook to the 'ml' command to call __mlq
    function ml() {
        local retval
        retval=0
        __mlq "${@:1}"
        retVal="$?"
        return "${retVal}"
    }    
else
    # Specify that mlq is not being loaded as an lmod module
    unset __mlq_version
    unset __mlq_path
fi

###########################################
# YCRC FUDGE: The below variable switches on a 'fudge' for R modules in the YCRC system.
# Synopsis: we relax our strict checking codes to let R/xxxx-bare substitute for R/xxxx
#
# The switch is very low-impact, since it just enables extra
#  error-checking code. Leaving it off will cause certain YCRC module builds to fail
#  unless the user selects --unsafe_build/--unsafe_auto.
#
# In the YCRC setup, R/xxxx modules replace themselves by R/xxxx-bare during module loading.
# This is a necessary workaround so we can bundle extra modules CRAN and Bioconductor
#  in the standard R module, while still using EasyBuild to make R (which we rename R/xxxx-bare).
#  
# An alternative would be to use mlq itself to substitute shortcuts for R/xxxx that include
#  CRAN and Bioconductor. Then you could turn off this switch.
###########################################
export __mlq_ycrc_r_fudge_switch=1

# If requested, remove all traces of mlq during the mlq module unload
if [[ "$1" == "--mlq_unload" ]]; then

    unset __mlq_ycrc_r_fudge_switch
    
    # Unload all shortcuts first
    __mlq_shortcut_reset
    
    # Below, restore original ml and module commands. This script is structured
    #  so that if the __mlq function exists, then __mlq_orig_ml and __mlq_orig_module
    #  also exist
    if [[ `type -t __mlq 2> /dev/null` == 'function' ]] ; then
        if [[ `declare -f __mlq_orig_module | grep -v __mlq_orig_module | grep mlq` ]] ; then
            echo "${__mlq_moo}"
            echo 'ERROR: the mlq environment has become really, really confused!'
            echo 'To restore normal module-loading behavior, you may need to'
            echo 'log out and log in again!'
            return 1
        fi
                
        # Restore the lmod 'ml' and 'module' commands
        # eval "$(echo "ml()"; declare -f __mlq_orig_ml | tail -n +2)"
        eval "$(echo "ml()"; declare -f __mlq_orig_ml | tail -n +2)"
        eval "$(echo "module()"; declare -f __mlq_orig_module | tail -n +2)"
        unset -f __mlq_orig_ml
        unset -f __mlq_orig_module
    fi

    unset -f __mlq
    unset -f __mlq_reset
    unset -f __mlq_shortcut_reset
    unset -f __mlqs_active

    unset __mlq_loaded

    unset __mlq_version
    unset __mlq_path
    unset __mlq_base_dir
    unset __mlq_prebuilds_dir

    unset __mlq_moo
    unset __mlq_welcome
    
    unset -f mlq_check
    unset -f __mlq_parse_module_tree_iter

    unset __mlq_module_version
    unset __mlq_module_file
    unset __mlq_module_callstack
    unset __mlq_expected_versions

    echo '[mlq] Goodbye! To restore fast module loading, do: '"'"ml mlq"'"
    # echo "${__mlq_moo}"

    return
fi

# Location of the script and its default shortcut library
__mlq_base_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
__mlq_prebuilds_dir="${__mlq_base_dir}/mlq_prebuilds"

if [[ ! ${__mlq_loaded} ]] ; then
    ( echo 'Fast module loading is now enabled.' ; \
      echo 'Use '"'"'ml -b <mod>'"'"' or '"'"'ml -b <shortcut_name> <mod1> [<mod2> ...]'"'"' to build new shortcuts' ; \
      echo 'Use '"'"'ml -h'"'"' or '"'"'ml -hf'"'"' for more examples and instructions' ; \
      ) 1>&2
fi

# Keeps track of whether mlq has been loaded before (used for the preceding message only)
__mlq_loaded=1

###########################################
###########################################
###########################################
# The __mlq function
###########################################
###########################################
###########################################

# Enable autocompletion for __mlq the same as 'module':
# t=(`complete -p ml`)
# complete -F "${t[2]}" __mlq
# if [ "$(type -t _ml)" = 'function' ]; then
#     complete -F _ml __mlq
# fi

function __mlq() {

    local mlq_logo
IFS='' read -r -d '' mlq_logo <<"EOF"
            (~~) 
           <(@@) 
  *---##--##-\#) 
      |##  # |_  
   ;_//ww---- \\ 
               ^^
EOF
    
    local mlq_dir
    mlq_dir="${HOME}"/.mlq

    mkdir -p "${mlq_dir}"
    mkdir -p "${__mlq_prebuilds_dir}"

    local n_argin
    n_argin=$#

    local build_modpath
    local mlq_user_orig_modpath
    mlq_user_orig_modpath="${MODULEPATH}"
    build_modpath="${mlq_user_orig_modpath}"

    local shortcut_name
    local custom_name
    local request_type
    local safe_build
    request_type='load'
    unset custom_name
    safe_build=1
    unset shortcut_name
    
    local fall_back
    local rebuild
    local ordered_module_list

    unset fall_back
    unset rebuild
    unset ordered_module_list

    ###########################################
    # Bash command to save file info, including the full contents, size, and date,
    #  for the set of lua modulefiles that defines a shortcut; this is used 
    #  to test if any of them changed, meaning the shortcut should be rebuilt.
    # Bash code is saved in string form to be executed later.
    # When executed, it will require that the list of module files, $ordered_module_list, be set already.
    ###########################################
    local build_lua_record
    # build_lua_record='/bin/ls -lL ${ordered_module_list[@]}; cat ${ordered_module_list[@]}'
    build_lua_record="stat -c '%y'"' ${ordered_module_list[@]}; cat ${ordered_module_list[@]}'
    
    ###########################################
    # Parse the arguments
    # 
    # Note, options to mlq 'ml' are of the form 'ml -h', 'ml -a', etc.
    # This potentially interferes with the lmod 'ml -<mod>' behavior,
    #  which unloads a module.
    #
    # So if the user tries to use 'ml' in this way to unload 
    #  modules named 'h', 'hf', 'hn', 'hml', 'a', 'd', or 'r', this will get overridden by
    #  the corresponding 'mlq' operations. However, these are all non-destructive operations,
    #  and the user can still do the unloading with 'module unload <mod>'.
    ###########################################

    ###########################################
    # --help, --helpful or no arguments: Print help info
    ###########################################
    
    if [[ ( `printf '%s' "$1" | awk '($1 ~ "--h" && "--help" ~ $1) || \
                                     ($1 ~ "--h" && "--helpfull" ~ $1) || \
                                     ($1 ~ "--h" && "--helpnotes" ~ $1) || \
                                     ($1 ~ "--help_m" && "--help_ml" ~ $1) || \
                                     ($1 == "-h" || $1 == "-hf" || $1 == "-hn" || $1 == "-hm") || \
                                     $1 == "show-all-if-ambiguous" '` ) || ( "${n_argin}" -eq 0 )  ]] ; then

        local mlq_welcome
# Welcome message
        IFS='' read -r -d '' mlq_welcome <<"EOF"
mlq: module loader-quick
https://github.com/cvsindelar/mlq

'ml' works the same as before, except that selected modules will now be loaded as fast 'shortcuts'

Note: shortcut modules work only by themselves, not with other modules

To build new shortcuts do, i.e.:
  ml -b SciPy-bundle/2023.02-gfbf-2022b   Builds 'generic' shortcut for SciPy-bundle
  ml -b rel5 RELION/5.0.0-foss-2022b-CUDA-12.0.0 IMOD/4.12.62_RHEL8-64_CUDA12.0 Emacs/28.2-GCCcore-12.2.0
                                          Builds a custom-named 3-module shortcut, 'rel5'

To load modules the ordinary way:          'module load <mod>'
To list existing shortcuts:                'ml -e'
To unload all modules/shortcuts from mlq:  'ml reset'
To exit mlq:                               'ml -mlq', 'module unload mlq', or module reset/purge/restore/r'
EOF

        if [[ ( `printf '%s' "$1" | awk '($1 ~ "--helpf" && "--helpfull" ~ $1) || $1 == "-hf"'` ) ]] ; then
            echo ' Usage: '
            echo '  ml <shortcut name> | <mod1> [<mod2> ..] Activate shortcut if it exists;'
            echo '                                            otherwise load a module'
            echo ''
            echo '  ml [options] sub-command [args ...]     Runs the corresponding '"'"ml"'"' command'
            echo '  module <args ...>                       Runs the '"'"'lmod'"'"' module command'
            echo '                                           (bypasses shortcuts)'
            echo ''
            echo '  ml --build|-b <module> | [<shortcut name> <module1> [<module2> ...]]'
            echo '                                           Build shortcut; If only a module is '
            echo '                                           given, the shortcut will be named'
            echo '                                           after the module'
            echo '                                           These will go in your shortcut library at:'
            echo '                                             '"'""${HOME}/.mlq""'"
            echo '  ml --unsafe_build|-ub <module> | [<shortcut name> <module1> [<module2> ...]]'
            echo '                                           Same as --build but without strict checking'
            echo ''
            echo '  ml --list|-l                            List modulefiles for the loaded'
            echo '                                            shortcut (if any)'
            echo '  ml --exist|-e                           List existing shortcuts'
            echo '  ml --delete|-d <shortcut_name>          Delete shortcut'
            echo '  ml --nuke                               Delete all shortcuts'
            echo ''
            echo '  ml --auto|-a <mod1> [<mod2> ...]        Build & run auto-named shortcut in one step'
            echo '  ml --unsafe_auto|-ua <mod1> [<mod2>...]   Same as --auto but without strict checking'
            echo ''
            echo '  ml --help|-h                            Short help message with examples'
            echo '  ml --helpfull|-hf                       Print this help message'
            echo '  ml --help_ml|-hm                        Print help for '"'"'lmod'"'"' ml'
            echo '  ml --helpnotes|-hn                      Print additional guidance and notes on how mlq works.'
            echo ''
            echo '   If you would like to add your shortcuts to the system-wide '"'"prebuilds"'"' directory then do, i.e.:'
            echo '     cp -R ~/.mlq/<shortcut_dir> '"${__mlq_prebuilds_dir}"
            echo '                   or'
            echo '     cp -R ~/.mlq/* '"${__mlq_prebuilds_dir}"
            echo ''
        elif [[ ( `printf '%s' "$1" | awk '($1 ~ "--helpn" && "--helpnotes" ~ $1) || $1 == "-hn"'` ) ]] ; then
            echo 'Extra notes:'
            echo ''
            echo '  mlq works with lmod module system so you can create and use custom'
            echo '   -built 'shortcut' modules to accelerate the loading of large and'
            echo '   complex module environments.'
            echo ''
            echo '  For large and complex module environments, the lmod module function'
            echo '   may spend most of its loading time doing dependency checks. mlq'
            echo '   works its magic by using a greatly streamlined dependency check'
            echo '   during shortcut loading, relegating costly dependency checks to'
            echo '   the shortcut building step. During shortcut building, a cache is'
            echo '   built containing the original lua code for the specified modules'
            echo '   as well as all the modules these depend on, minus the depends_on'
            echo '   () statements. For shortcut loading, mlq faithfully executes this'
            echo '   code in same order that an ordinary module load would.'
            echo ''
            echo '  Rapid dependency checking during shortcut loading is accomplished'
            echo '   as follows: mlq detects if any of the involved module files changes,'
            echo '   or even if a single modification date changes. If so, then mlq'
            echo '   uses the lmod module command to automatically rebuild the shortcut'
            echo '   (the user is prompted to rebuild the shortcut in the interactive'
            echo '   case); failing that, the shortcut falls back to ordinary module'
            echo '   loading.'
            echo ''
            echo '  mlq is designed to work with 'well-behaved' modules; that is, where'
            echo '   there are no version conflicts between the modules used by a shortcut'
            echo '   Strict checking of the modulefile tree is done to enforce'
            echo '   this***; use the '"'"--unsafe_build"'"' and '"'"--unsafe_auto"'"' options'
            echo '   to disable strict checking. In some cases you may be able to establish '
            echo '   that the reported conflicts are harmless and can be safely ignored.'
            echo ''
            echo '*** Checking is done by screening depends_on() statements in the modulefile lua codes.'
            echo ''
        elif [[ ( `printf '%s' "$1" | awk '($1 ~ "--help_m" && "--help_ml" ~ $1) || $1 == "-hm"'` ) ]] ; then
            __mlq_orig_ml -h
        elif [[ $n_argin -gt 0 ]] ; then
            echo "${mlq_logo}""${mlq_welcome}"
            echo 'Use '"'"'--helpfull'"'"'|'"'"'-hf'"'"' for full instructions.'
            echo 'Use '"'"'--help_ml'"'"'|'"'"'-hm'"'"' for help with '"'"'lmod'"'"' ml'
            echo ''
        fi
        
        ###########################################
        # Show the current shortcut environment if there is anything to show
        #  (if not, the welcome message will have been printed)
        ###########################################
        if [[ "${n_argin}" -eq 0 ]]; then
            
            # __mlq_orig_module --ignore_cache list # |& awk '$0 == "Currently Loaded Modules:" {getline; print}'
            local mlqs_active
            mlqs_active=`__mlqs_active`
            if [[ "${mlqs_active}" ]]; then
                # Print the current shortcut name (take off the leading 'mlq-' from the folder name)
                echo '[mlq] Current shortcut:' `echo "${mlqs_active}" | awk '{print substr($1,5,length($1)-4)}'`
                echo '  Use '"'"'ml reset'"'"' to turn off this shortcut.'
            fi

            # Use lmod's module list but get rid of the trailing empty lines...
            __mlq_orig_ml --redirect |head -n -2
            # ..unless they weren't empty
            __mlq_orig_ml --redirect |tail -2|awk 'NF > 0'
            
            export MODULEPATH="${mlq_user_orig_modpath}"
        fi
        return
        # --help#
    fi

    ###########################################
    # Parse other options
    ###########################################

    ###########################################
    # '--exist' option: list all available shortcuts, including prebuilt ones
    #  as well as custom-made shortcuts
    ###########################################
    if [[ `printf '%s' "$1" | awk '($1 ~ "--e" && "--exist" ~ $1) || $1 == "-e" {print 1}'` ]]; then

        # Find all prebuilt shortcuts that have been disabled (.mlq/*.d; strip off the trailing ".d")
        local disabled
        disabled=`find -L "${mlq_dir}" -name '*.d'| \
                       awk '{sub("^.*[/][.]mlq[/]","",$0); print substr($0,1,length($0)-2)}'`

        # Below, we find all the lua files in $mlq_dir and pull out the module name;
        # Then we list all the prebuilt shortcuts that are not in $disabled ;
        #  (find all lua files in the mlq_prebuilds directory, eliminate the disabled ones,
        #   strip out the module names, and print)

        ( \
         echo 'Existing custom shortcuts:' ; \
         echo '' ; \
         find -L "${mlq_dir}" -name '*.lua' \
                | awk '{sub("^.*[/][.]mlq[/][^/]*[/]mlq[-]","",$0); sub("[.]lua","",$0); print}' ; \
         echo '' ; \
         echo 'System shortcuts:' ; \
         echo '' ; \
            ( \
             find -L "${__mlq_prebuilds_dir}" -name '*.lua' \
                | awk -v disabled="$disabled" \
                      'BEGIN {nd=split(disabled,d)} \
                       { \
                        sub("^.*[/]mlq_prebuilds[/]","",$1); \
                        del=0; \
                        for(ind=1;ind<=nd;++ind) { \
                          if(index($1,d[ind]) == 1) del=1 \
                        } \
                        if(!del) { \
                          sub("[^/]*[/]mlq[-]","",$0); \
                          sub("[.]lua","",$1); \
                          print; \
                        } \
                       }' \
            ) | sort -u ; \
            echo '' ; \
         ) | less -X --quit-if-one-screen

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
                echo ' (note: a backup of your custom shortcuts will be saved to '~/mlq_bak' )'
                
                local confirm
                read -p 'Are you sure? (Y/N): ' confirm
                if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                    __mlq_reset

                    if [[ ! -z "${mlq_dir}" ]] ; then
                        echo ''
                        echo 'Your custom shortcuts have been saved to '~/mlq_bak
                        echo 'Use /bin/cp -r '~/mlq_bak'/<m> '"${mlq_dir}"' to restore one or more of these'
                        echo ''
                        mkdir -p ~/mlq_bak
                        /bin/cp -r "${mlq_dir}"/* ~/mlq_bak
                    fi
                    
                    printf 'Nuking... ' 
                    /bin/rm -r "${mlq_dir}"
                    mkdir -p "${mlq_dir}"
                    
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
            echo "${__mlq_moo}"
            echo 'Arguments after '"'"'--nuke'"'"' not understood!'
            return 1
        fi
        return
    fi
    
    ###########################################
    # '--delete' option: sets up for shortcut deletion, which is done later after
    #  all the relevant names and paths have been found
    ###########################################

    local delete_shortcut
    unset delete_shortcut
    if [[ `printf '%s' "$1" | awk '($1 ~ "--d" && "--delete" ~ $1) || $1 == "-d" {print 1}'` ]] ; then
        if [[ $n_argin -lt 2 ]] ; then
            echo "'"'--delete'"'"' option: please give a shortcut name'
            return
        fi
        # if [[ "${n_argin}" -gt 2 ]] ; then
        #     echo 'Only one shortcut deletion is allowed at a time'
        #     return
        # fi
        shift
        (( n_argin=$n_argin-1 ))
            
        delete_shortcut=1
    fi
    
    ###########################################
    # '--list' option: list dependent modulefiles
    ###########################################
    local mlq_list
    unset mlq_list
    if [[ `printf '%s' "$1" | awk '($1 ~ "--l" && "--list" ~ $1) || $1 == "-l" {print 1}'` ]]; then
        mlq_list=1
        shift
        (( n_argin=$n_argin-1 ))
    fi
    
    ###########################################
    # '--auto' option: build (if needed) & run an automatically named shortcut in one step
    ###########################################
    if [[ `printf '%s' "$1" | \
       awk '($1 ~ "--a" && "--auto" ~ $1) \
            || $1 == "-a" \
            || ($1 ~ "--unsafe_a" && "--unsafe_auto" ~ $1) \
            || $1 == "-ua" \
              {print 1}'` ]] ; then     
        request_type='auto'

        if [[ `printf '%s' "$1" | awk '($1 ~ "--unsafe_a" && "--unsafe_auto" ~ $1) || $1 == "-ua" {print 1}'` ]] ; then
            unset safe_build
        fi
        
        if [[ $n_argin -lt 2 ]] ; then
            echo "'"'--auto|--unsafe_auto'"'"' options: please give a list of module(s)'
            return
        fi
        shift
        (( n_argin=$n_argin-1 ))
    fi

    ###########################################
    # '--build' option: specify a shortcut build
    ###########################################

    if [[ `printf '%s' "$1" | awk '$1 == "--moo" {print 1}'` ]] ; then
	
	cat <<"EOF"
                            ;:                                          
                          .x..                      .                   
                         .x:.:                     ::                   
                          X....                   x...                  
                         .X.......x.:...:.+:.  . ;..;.                  
                         .:.......:..x;XxXXXXX:x...;.                   
                          :+;.........;;..+XXXXX..;.;                   
                       ....;................;XXXX:.                     
            . . ..;X:....:..........::XX+X+.+;xXXX.                     
          ................:.........X+X::XXx:XXXXXX+                    
          .........:..:..X...........:XX;:+.xXXXXXX:                    
           ............x....................x++XXXX.                    
               .X....x......;x......X+;Xx+:..;++xxXX..                  
               .+.x$$$.....xxx....+:XXXXXXX.....$.XXX+;:..              
             .X..$$$$;.....xxx....+XXXXXXXXX.....;......;.              
             .;.$$$x$;....:xx....;XXXXXXXXXXX...........:               
            .+.$$$$+++....;x:....X+XXXXXXXXXXX;+.........               
           .;.$$$$x;X:.....:.....+XXXXXXXXXXXXXx$x... ...   .&+:x       
          ...$$$$x;;X.......x....xXX++x;X;....XX...X.      :+++$+X.&&.  
         ;...$$$+;:..........x...+XX.+$X:.....XX....X.     X+$&+&;+;$+; 
        .:..X$$X+X............x...xXXX;X......X:.....;.     &$+X&X&&;&+;
       .;..;;$...............:xx...xXXXXX............;.    .&Xx&:x;$+;&X
   ..x...:..................;xxxx....XXXXXXX........x;   .X$$$$+X+;;+.. 
...........................+xxxxxx....XXXXXX:X.....X:   .$+;+xX+X$&x;$  
X............:.............+xxxxxxx...............;      X+++xx:$$+;;&  
x.........................:xxxxxxxx .;..;+;.:+.              .X: $$&X+  
....XXXXXXXx..;............xxxxxxx.;..                       :          
XXXXXXXXXXXXX;.............;xxxxxx.....                     .;          
X.X++XXXXXXXXX..............xxxxx;.....+..                  $           
..xX;xXXXXXXXXX.......:......xx+.......;.:                 &X.          
:+.+XXXXXXXXXXXXX:..........................               +;& :        
+:++;+XXXXXXXXXXXXXXX......................                             
X:::+XX+XXXXXXXXXXXXXXX...................+.                            
::::::xXXXXXXXXXXXXXXXX..................:;.                            
::::;::+X:X+XXXXXXXXXXX.................::                              
EOF
	return
    fi
    
    ###########################################
    # '--build' option: specify a shortcut build
    ###########################################

    if [[ `printf '%s' "$1" | awk '($1 ~ "--b" && "--build" ~ $1) || $1 == "-b" || ($1 ~ "--unsafe_b" && "--unsafe_build" ~ $1) || $1 == "-ub" {print 1}'` ]] ; then

        request_type='build'

        if [[ $n_argin -lt 2 ]] ; then
            echo "'"'--build|unsafe_build'"'"' option: please give a module, or <shortcut name> <mod1> [<mod2> ...]'
            return
        fi

        if [[ `printf '%s' "$1" | awk '($1 ~ "--unsafe_b" && "--unsafe_build" ~ $1) || $1 == "-ub" {print 1}'` ]] ; then
            unset safe_build
        fi
        
        # Shift the arguments so we are left with <shortcut name> [mod1 [mod2 ...]]
        shift
        (( n_argin=$n_argin-1 ))
        
        # shortcut_name="$1"
        shortcut_name=`__mlq_get_default_module "$1"`

        local name
        local moo
        
        # Shift the arguments again so we are left with [mod1 [mod2 ...]]
        # If only 2 args given, i.e. '--build <mod>', we don't shift;
        #  shortcut name is the same as the module
        if [[ $n_argin -gt 1 ]] ; then
            shift
            (( n_argin=$n_argin-1 ))
            
            custom_name=1

            # Two extra safety checks
            local ind
            local m         
            for m in "${@:1}" ; do
                
                # If the shortcut name appears as one of the listed modules, it
                #  shall not be taken to be a custom shortcut
                if [[ "${m}" == "${shortcut_name}" ]] ; then
                    unset custom_name
                fi

                # No selfie shortcuts!
                name="$(echo "$m" | awk -F/ '{print $(NF-1)}')"
                if [[ "${name}" == 'mlq' ]] ; then
                    moo=1
                fi
            done
        else
            name="$(echo "$1" | awk -F/ '{print $(NF-1)}')"
            if [[ "${name}" == 'mlq' ]] ; then
                moo=1
            fi
        fi

        if [[ "${moo}" ]] ; then
            echo "${__mlq_moo}"
            echo 'Sorry, mlq cannot build a shortcut of itself!'
            return
        fi
        
    ###########################################
    # All options processed; process the remaining arguments as module names
    ###########################################
    elif [[ $n_argin -gt 1 ]] ; then
        # if multiple modules are given, the shortcut name is the module 
        #  names strung together, but with characters "." and "/" substituted.
        #  This type of module is generated by '--auto'

        shortcut_name=`__mlq_collection_name "${@:1}"`

        custom_name=1
    elif [[ $n_argin -gt 0 ]] ; then
        # shortcut name is the module name, with the default version included if possible
        shortcut_name=`__mlq_get_default_module "$1"`
    fi

    ###########################################
    # Define all the variable names and paths need for loading or building shortcuts/modules
    ###########################################

    local module_spec
    module_spec=("${@:1}")
    # Remove any trailing slash from module specs, preserving their status as strings
    module_spec=("${module_spec[@]%/}")

    # Only do the setup if any sort of loading or building is being done
    if [[ "${module_spec}" ]] ; then
        
        # Make a valid module collection name by getting rid of slashes and periods in $shortcut_name
        local collection_name
        collection_name=`__mlq_collection_name "${shortcut_name}"`

        # Find out if the module includes a version name.
        #  In this case, we need to make a subdirectory
        local dir_t
        local quikmod_top_dir
        dir_t=(`echo "${shortcut_name}" | awk '{sub("/"," ", $0); print}'`)

        if [[ ${#dir_t[@]} -gt 1 ]]; then
            quikmod_top_dir='mlq-'"${dir_t[0]}"
        else
            unset quikmod_top_dir
        fi

        # Define target_dir, which is where the shortcut info will be stored
        local target_dir
        target_dir="${mlq_dir}/${collection_name}"

        # Define extended_target_dir, which also includes the module name if
        #  there is a version subdirectory
        local extended_target_dir
        extended_target_dir="${target_dir}"
        
        if [[ "${quikmod_top_dir}" ]]; then
            extended_target_dir="${extended_target_dir}/${quikmod_top_dir}"
        fi

        # Get the lua filename, based on the full name which is mlq-<shortcut name>
        local quikmod_lua
        local shortcut_name_full

        shortcut_name_full='mlq-'"${shortcut_name}"
        quikmod_lua="$target_dir/${shortcut_name_full}.lua"
        prebuild_lua="${__mlq_prebuilds_dir}/${collection_name}/${shortcut_name_full}.lua"

        # Get the lua filename for loading; this may be either the user one or the prebuilt one
        #  (priority to the user one)
        local load_lua
        local load_dir
        unset load_lua
        unset load_dir
        if [[ -f "${quikmod_lua}" ]] ; then
            load_lua="${quikmod_lua}"
            load_dir="${mlq_dir}"
        elif [[ -f "${prebuild_lua}" ]] ; then
            load_lua="${prebuild_lua}"
            load_dir="${__mlq_prebuilds_dir}"
        fi
    fi
    
    ###########################################
    # List dependent modulefiles
    ###########################################
    if [[ "${mlq_list}" ]] ; then
        local loaded_shortcut
        loaded_shortcut=`__mlqs_active`
        if [[ "${loaded_shortcut}" ]] ; then
            mod_file=`ml --redirect --location show "${loaded_shortcut}"`
            local mod_list
            mod_list=("${mod_file%.*}".mod_list)

            # Below, strip off the leading 'mlq-' from the shortcut name for printing:
            ( echo 'Modulefiles used for the shortcut '`echo "${loaded_shortcut}" | awk '{printf("'\'%s\'' :", substr($1,5,length($1)-4))}'` ; 
              echo '' ; \
              cat "${mod_list}" ; \
            ) \
             | less -X --quit-if-one-screen         
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
            local disable_prebuild
            unset disable_prebuild
            # the existence of an empty directory "${target_dir}.d" is used
            #  to indicate a prebuilt shortcut is 'deleted' (inactivated)
            if [[ -f "${prebuild_lua}" && ! -d "${target_dir}.d" ]] ; then
                disable_prebuild=1
            fi
            
            local for_real
            unset for_real
            [[ -f "${quikmod_lua}" ]] && for_real=1
            [[ -f "${quikmod_lua%.*}.lua_record" ]] && for_real=1
            [[ -f "${quikmod_lua%.*}.spec" ]] && for_real=1

            if [[ "$for_real" || "${disable_prebuild}" ]]; then
                if [[ "$for_real" ]] ; then
                    echo 'This will delete the mlq shortcut '"'"${shortcut_name}"'."
                else
                    echo 'This will disable the prebuilt mlq shortcut '"'"${shortcut_name}"'."
                fi
                local confirm
                read -p 'Are you sure? (Y/N): ' confirm
                if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                    __mlq_reset
                else
                    echo 'Canceled- nothing done.'
                    return
                fi
            fi

            if [[ "$for_real" ]]; then
                # in case target_dir is a link (future-proofing)
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
                fi
                
                echo 'Deleted the shortcut '"'"${shortcut_name}"'"
            fi

            if [[ "${disable_prebuild}" ]] ; then
                if [[ "${for_real}" ]] ; then
                    echo 'Repeat this command to disable the prebuilt shortcut: '"'"${shortcut_name}"'."
                else
                    echo 'Disabled the prebuilt shortcut: '"'"${shortcut_name}"'."
                    mkdir -p "${target_dir}.d"
                fi
            fi

            if [[ ! "$for_real" && ! "${disable_prebuild}" ]] ; then
                if [[ ! -d "${target_dir}.d" ]] ; then
                    echo 'Shortcut '"'"${shortcut_name}"'"' not found. Nothing done.'
                else
                    echo 'Shortcut '"'"${shortcut_name}"'"' is already disabled. Use '"'"'-b'"'"' to re-enable'
                fi
            fi
        fi
        return
    fi
    
    ###########################################
    # If a shortcut already exists, check if it needs to be rebuilt.
    ###########################################

    if [[ -f "${load_lua}" && \
              ("${request_type}" == 'load' || "${request_type}" == 'build' || "${request_type}" == 'auto' ) ]]; then

        # Get previously saved, ordered list of modulefiles:
        ordered_module_list=(`cat "${load_lua%.*}".mod_list`)
        
        if [[ "${request_type}" == 'load' && ! "${ordered_module_list[@]}" ]] ; then
            echo 'The previous shortcut build seems to have failed.'
            ###########################################
            # We shall refuse to build a module unless we have saved info on how it
            #  was built (i.e., <shortcut>.mod_list needs to not be empty)
            ###########################################
            fall_back=1
        else
	    eval ${build_lua_record} | cmp ${load_lua%.*}.lua_record >& /dev/null
	    if [[ "$?" -ne 0 ]] ; then
		###########################################
		# If the module files changed, need to rebuild
		###########################################
		if [[ "${request_type}" == 'load' || "${request_type}" == 'auto' ]] ; then
                    echo 'This shortcut seems to be out of date. Trying to rebuild...'
                    rebuild=1
		    # Unset module_spec to trigger its reloading from the .spec file (below)
		    unset module_spec
		fi
            elif [[ "${request_type}" == 'build' && ! -d "${target_dir}.d" ]] ; then
            # If a build is requested but things look up to date, optionally rebuild.
            #  We also skip this if the user deactivated the prebuilt shortcut; in the case, the
            #  prebuilt shortcut will reactivated in the next section
            
                if [[ ! -f "${quikmod_lua}" ]] ; then 
                    echo 'Prebuilt shortcut '"'"${shortcut_name}"'"' exists already and seems up to date;'
                    # The below line tests if we are in an interactive shell
                    # We would like to keep slurm jobs, etc, from failing if they
                    #  need to be updated
                    if [[ $- == *i* && ! ( -p /dev/stdin ) ]] ; then
                        local confirm
                        read -p 'Are you sure you want to rebuild it? (Y/N): ' confirm
                        if [[ ! ( $confirm == [yY] || $confirm == [yY][eE][sS] ) ]]; then
                            echo 'Canceled- nothing done.'
                            return
                        fi
                        rebuild=1
                    else
                        echo 'Non-interactive shell: nothing done.'
                        return
                    fi
                else
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

    # Special case: prebuilt shortcut exists but has been disabled
    if [[ "${request_type}" == 'build' \
              && ! -f "${quikmod_lua}" && -d "${target_dir}.d" ]] ; then
        echo 'Re-enabled the prebuilt shortcut: '"'"${shortcut_name}"'."
        rmdir "${target_dir}.d"
        return
        
    # Builds are needed if (1) requested by --build ; (2) --auto requested and no shortcut exists;
    #  or (3) a rebuild is needed
    elif [[ "${request_type}" == 'build' \
                || ( "${request_type}" == 'auto' && ! -f "${load_lua}" ) \
                || "${rebuild}" ]]; then

        if [[ "${rebuild}" ]] ; then
            # If a rebuild is needed and the user didn't specify modules, we need to:
            #  - Obtain the original shortcut module list as module_spec; 
            #  - We also restore the modulepath from the shortcut in case a custom path was present
            #    during the original shortcut build (i.e. if the user had previously done 'module use')
            #  - Use the same safety mode
            if [[ ! ${module_spec[@]} ]] ; then
                module_spec=(`cat "${load_lua%.*}".spec`)
                build_modpath=(`cat "${load_lua%.*}".modpath`)
                if [[ -f "${load_lua%.*}".unsafe_build ]] ; then
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    echo 'WARNING: this shortcut was built without safety checks'
                    echo ' ('"'"'--unsafe_build/--unsafe_auto'"'"' options). Rebuilding in the same manner'
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    
                    unset safe_build
                else
                    safe_build=1
                fi
            fi
        fi
                        
        if [[ "${custom_name}" ]] ; then
            printf '%s' 'Building custom-named shortcut for '"'""${shortcut_name}""'"
        else
            printf '%s' 'Building shortcut for '"'""${shortcut_name}""'"
        fi
        
        # Restore the modulepath from the shortcut in case a custom path was present
        #  during the original shortcut build (i.e. if the user had previously done 'module use')
        if [[ "${build_modpath}" ]] ; then
            export MODULEPATH="${build_modpath}"
        fi

        local build_failed
        unset build_failed
        
        # Below, a 'while' statement is used in place of an 'if' statement.
        #  The while statement does not iterate because of the 'break' statement at the end.
        #  Rather, 'while' is used so it can be broken out of, if the shortcut build fails.
        while [[ ! "${build_failed}" ]] ; do
            
            # Check if lmod can find the requested modules:
            # __mlq_orig_module -I is-avail ${module_spec[@]}
            __mlq_orig_module is-avail ${module_spec[@]}

            if [[ ($? != 0) ]]; then
                # The requested module(s) were not available
                echo ''
                echo "Sorry, shortcut '"${shortcut_name}"' cannot be built because one or more of the module(s)"
                echo " cannot be found:"
                echo "   ${module_spec[@]}"
                echo 'This may be because your module search path has changed.'
                echo 'Please adjust the search path with '"'"'module use'"'"' and try again.'

                echo 'Current module path for this shortcut:'
                echo $MODULEPATH
                
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
                fullmod=`__mlq_get_default_module "${mod}"`
                module_spec_full=(${module_spec_full[@]} "${fullmod}")
            done

            echo ' with included modules:'
            echo "${module_spec_full[@]}"
            
            printf 'Purging any loaded modules...'
            __mlq_reset
            
            echo ' done.'

            # Restore the modulepath after the reset
            if [[ "${build_modpath}" ]] ; then
                export MODULEPATH="${build_modpath}"
            fi

            # Strict checking for module loading consistency
            echo 'Strict module consistency check: ' "${module_spec_full[@]}"
            if [[ "${__mlq_ycrc_r_fudge_switch}" ]] ; then
                # YCRC fudge: we let R/xxxx-bare substitute for R/xxxx, because
                #  this should be safe in our setup
                mlq_check --ycrc_r_fudge "${module_spec_full[@]}"
            else
                mlq_check "${module_spec_full[@]}"
            fi
            
            if [[ $? -ne 0 ]]; then
                echo ''
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                if [[ "${safe_build}" ]] ; then
                    echo 'ERROR: Consistency check failed.'
                    echo 'If you really wish to proceed with shortcut building, turn off the safe option with:'
                    echo '  --unsafe_build/--unsafe_auto'
                else
                    echo 'WARNING: Consistency check failed.'
                fi
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo ''
                
                if [[ "${safe_build}" ]] ; then
                    build_failed=1
                    break
                fi
            fi
            
            echo ''     

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
            
            local retVal
            # __mlq_orig_module -I --redirect load ${module_spec_full[@]} >& "${quikmod_lua%.*}".warnings
            __mlq_orig_module --ignore_cache --redirect load ${module_spec_full[@]} >& "${quikmod_lua%.*}".warnings
            retVal="$?"
            
            cat "${quikmod_lua%.*}".warnings

            if [ "${retVal}" -ne 0 ]; then
                ###########################################
                # One more heroic try; R, this is for you!
                ###########################################
		
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo 'WARNING: Module load failed. Retrying modules one at a time...'
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                
                printf '' > "${quikmod_lua%.*}".warnings
                local mod
                local failed_mods
                unset failed_mods
                for mod in ${module_spec_full[@]} ; do
                    echo '[mlq] Executing: module load '"${mod}"
                    __mlq_orig_module --ignore_cache --redirect load "${mod}" >& "${quikmod_lua%.*}".warnings
                    retVal="$?"

                    cat "${quikmod_lua%.*}".warnings
                    
                    if [ "${retVal}" -ne 0 ]; then
                        if [[ ! "${__mlq_ycrc_r_fudge_switch}" ]] ; then
                            failed_mods=( ${failed_mods[@]} "${mod}" )
                        else
                            ###########################################
                            # YCRC fudge: we let R/xxxx-bare substitute for R/xxxx, because
                            #  this should be safe in our setup
                            
                            local name
                            name="$(echo "$mod" | awk -F/ '{print $(NF-1)}')"
                            
                            if [[ ! ${name} == 'R' ]] ; then
                                failed_mods=( ${failed_mods[@]} "${mod}" )
                                echo ''
                            else
                                __mlq_orig_module --ignore_cache --redirect load "${mod}-bare"
                                retVal=$?
                                if [[ ${retVal} ]] ; then
                                    echo '[YCRC fudge] Note: allowing module '"${mod}"'-bare to substitute for '"${mod}"
                                else
                                    failed_mods=( ${failed_mods[@]} "${mod}" )
                                fi
                            fi
                            
                            # YCRC fudge
                            ###########################################
                        fi
                    fi
                done

                # Don't proceed if no modules successfully loaded;
                #  or if we are in safe mode and any modules failed to load
                local failure_exit
                unset failure_exit
                if [[ ( ${#failed_mods} == ${#module_spec_full} ) \
                          || ( ${#failed_mods} -gt 0 && "${safe_build}" ) ]] ; then
                    failure_exit=1
                fi

                if [[ ${#failed_mods} -gt 0 ]] ; then
                    echo ''
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    if [[ "${failure_exit}" ]] ; then
                        echo 'ERROR: could not load the original module(s):'
                    else
                        echo 'WARNING: could not load the original module(s):'
                    fi
                    echo '  '"${failed_mods[@]}"
                    if [[ ! "${failure_exit}" ]] ; then
                        echo 'Safe mode is not requested, so proceeding anyway!'
                    fi
                    echo '###########################################'
                    echo '###########################################'
                    echo '###########################################'
                    
                    if [[ "${failure_exit}" ]] ; then
                        export MODULEPATH="${mlq_user_orig_modpath}"
                        build_failed=1
                        break
                    fi
                fi
                # End of heroic try
                ###########################################
            fi
            
            echo ' done.'
            
            if [[ `awk 'BEGIN {sum=0} tolower($0) ~ "warn" {sum += NF} END {print sum}' "${quikmod_lua%.*}".warnings` -gt 0 ]] ; then
                echo ''
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo 'NOTE: warnings were reported during module loading'
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
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

            # Below: the environment is no longer needed, so reset it.
            # Interestingly, ml --location show <mod> may give different results
            #  depending on whether <mod> is loaded or not; the unloaded case seems to
            #  be preferable (case in point: R modules with two conflicting R module dependencies)
            __mlq_reset

            # However, the build modulepath may still be needed for safety checking
            #  below:
            if [[ "${build_modpath}" ]] ; then
                export MODULEPATH="${build_modpath}"
            fi

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
            # /bin/rm ${collection_file}
            
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

                build_failed=1
                break
            fi      

            # Sanity check: did all the requested modules make it into the 'mod_list' file?
            echo 'Performing extra safety checks'
            
            for mod in ${module_spec_full[@]} ; do
                # modfile_check=`__mlq_orig_module -I --redirect --location show "${mod}"`
                modfile_check=`__mlq_orig_module --redirect --location show "${mod}"`

                # Print a warning if something didn't make it in
                if [[ ! `awk -v mod="${modfile_check}" '$1 == mod {print 1}' "${quikmod_lua%.*}.mod_list"` ]] ; then
                    if [[ ! "${__mlq_ycrc_r_fudge_switch}" ]] ; then
                        if [[ "${safe_build}" ]] ; then
                            build_failed=1
                            break
                        fi
                    else
                        ###########################################
                        # YCRC fudge: we let R/xxxx-bare substitute for R/xxxx, because
                        #  this should be safe in our setup
                        
                        local ycrc_r_fudge_pass
                        unset ycrc_r_fudge_pass
                        local name
                        name="$(echo "$mod" | awk -F/ '{print $(NF-1)}')"
                        
                        if [[ ${name} == 'R' ]] ; then
                            modfile_check=`__mlq_orig_module --redirect --location show "${mod}-bare"`
                            if [[ `awk -v mod="${modfile_check}" '$1 == mod {print 1}' "${quikmod_lua%.*}.mod_list"` ]] ; then
                                echo '[YCRC fudge] Note: allowing module '"${mod}"'-bare to substitute for '"${mod}"
                                ycrc_r_fudge_pass=1
                            fi
                        fi
                        
                        if [[ ! ${ycrc_r_fudge_pass} ]] ; then
                            echo ''
                            echo '###########################################'
                            echo '###########################################'
                            echo '###########################################'
                            echo 'WARNING: the module '"'""${mod}""'"' was not successfully loaded.'
                            echo ' ('"'"'module list'"'"' does not list this module after trying to load all modules).'
                            echo '###########################################'
                            echo '###########################################'
                            echo '###########################################'
                            echo ''

                            if [[ "${safe_build}" ]] ; then
                                build_failed=1
                            fi
                        fi
                    fi
                    
                    # YCRC fudge
                    ###########################################                 
                fi
            done
            if [[ "${build_failed}" ]] ; then
                break
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
            
            echo "${mlq_logo}"
            echo 'Shortcut '"'""${shortcut_name}""'"' is now available.'
            # echo 'mlq '"${shortcut_name}"
            echo ''
            # If building a shortcut for the first time, need to set load_lua and load_dir
            #  for use in the upcoming shortcut loading step
            if [[ "${request_type}" == 'auto' && ! "${load_lua}" ]] ; then
                load_dir="${mlq_dir}"
                load_lua="${quikmod_lua}"
            fi
            
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
        if [[ "${build_failed}" ]] ; then
            if [[ ( "${request_type}" == 'load' || "${request_type}" == 'auto' ) ]] ; then
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'
                echo 'WARNING: Shortcut (re)build has failed, so falling back to ordinary module loading.'
                echo '###########################################'
                echo '###########################################'
                echo '###########################################'

                # Reset all modules to emulate the behavior of shortcut loading
                fall_back=1
                __mlq_reset

                # Restore the modulepath from the shortcut in case a custom path was present
                #  during the original shortcut build (i.e. if the user had previously done 'module use')
                if [[ "${build_modpath}" ]] ; then
                    # export MODULEPATH="${build_modpath}"
		    # Only restore the MODULEPATH but if needed (otherwise, this introduces a ~0.3 sec lag)
		    if [[ `echo "${build_modpath}" $MODULEPATH | awk '$1 != $2 {print 1}'` ]] ; then 
			__mlq_orig_module use "${build_modpath}" 
		    fi		    
                fi
            else
                echo "${__mlq_moo}"
                echo 'ERROR: Shortcut (re)build has failed. Exiting'
                return 1
            fi
        fi          
    fi
    
    ###########################################
    # Do shortcut or module loading
    ###########################################

    if [[ "${request_type}" == 'load' || "${request_type}" == 'auto' ]] ; then
        ###########################################
        # Below are the 3 conditions that need to be satisfied to proceed with shortcut loading:
        #  (1) shortcut file must exist; (2) shortcut building, if it occurred, must have succeeded
        #  (3) the shortcut must not be disabled (disabled = ".d" empty directory present)
        ###########################################
        if [[ "${load_lua}" && ! "${fall_back}" && ! -d "${target_dir}.d" ]] ; then
            local spec
            spec=`awk '{printf("\n"); for(i=1; i <= NF-1; ++i) printf("%s, ", $i); printf($i)}' "${load_lua%.*}".spec`

            printf "%s" "[mlq] Loading shortcut ${shortcut_name} with included modules:"
            printf "${spec}"
            printf '..'
            
            # Don't try to do this trick with other modules around
            __mlq_reset
            echo '.'

	    # Restore the user's MODULEPATH but only if needed (otherwise, this introduces a ~0.3 sec lag)
	    if [[ `echo "${mlq_user_orig_modpath}" $MODULEPATH | awk '$1 != $2 {print 1}'` ]] ; then 
		__mlq_orig_module use "${mlq_user_orig_modpath}" ; 
	    fi	    
	    # Add the shortcut's path to MODULEPATH
            __mlq_orig_module use -a "${load_dir}/${collection_name}"
	    
            __mlq_orig_module load "${shortcut_name_full}"

            if [[ $? == 0 ]] ; then
                echo ''
                echo 'Use '"'"'ml reset'"'"' to turn off this shortcut.'
                echo ''
            else
                echo 'An error occurred loading the shortcut. Falling back to ordinary module loading...'
                module_spec=(`cat "${load_lua%.*}".spec`)
                build_modpath=(`cat "${load_lua%.*}".modpath`)
                fall_back=1
            fi
        fi

        ###########################################
        # Ordinary module functions (anything other than a shortcut):
        #  Use the 'lmod' 'ml' or 'module' commands
        ###########################################
        # Below covers all the cases not covered by the preceding if statement
        #  (Boolean negation of the logical statement)
        # We do not use 'else' here because shortcut loading in the above
        #  clause can fail, which causes $fall_back to be set after the first logical test
        if [[ ! "${load_lua}" || "${fall_back}" || -d "${target_dir}.d" ]] ; then

            # Make sure the user doesn't use 'save' with a shortcut, which won't work
            #  the 'module' function (with 'mlq' hooks) handles this case
            if [[ ( ${module_spec[0]} == 'save' || ${module_spec[0]} == 's' ) ]] ; then
                module ${module_spec[@]}
                return_status=$?
                return $return_status
            fi

            # Reset/restore/purge: use __mlq_reset to keep mlq around
            if [[ ${module_spec[0]} == 'restore' || ${module_spec[0]} == 'r' || \
                      ${module_spec[0]} == 'reset' || \
                      ${module_spec[0]} == 'purge' ]] ; then
                __mlq_reset ${module_spec[@]}
            else
                # Restore the modulepath from the shortcut in case a custom path was present
                #  during the original shortcut build (i.e. if the user had previously done 'module use')
                # This will only happen if an automatic rebuild occurs during a module load and then fails;
                #  the code then falls through to here:
                if [[ "${build_modpath}" ]] ; then
                    export MODULEPATH="${build_modpath}"
                elif [[ "${mlq_user_orig_modpath}" ]] ; then
                    # Restore the original module path prior to exiting
                    export MODULEPATH="${mlq_user_orig_modpath}"
                fi

                # echo 'Executing: '"'"'ml '"${module_spec[@]}""'"
                __mlq_orig_ml ${module_spec[@]}
                return_status=$?
                return $return_status
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

    if [[ "$1" == '-h' || "$1" == '--help' ]] ; then
        echo 'mlq_check: print module loading conflicts with strict consistency checking'
        echo 'Usage: mlq_check | mlq_check <mod1> [<mod2> ...]'
        echo ' No arguments: evaluate the current module environment'
        echo ' With arguments: evaluate listed module environment'
        return
    fi
   
    local return_status
    unset return_status
    
    local mlq_check_args
    unset mlq_check_args
    local ycrc_r_fudge
    unset ycrc_r_fudge
    # If no arguments given, check the current module environment
    if [[ "$#" -gt 0 ]] ; then
        if [[ "$1" == '--ycrc_r_fudge' ]] ; then
            # Ugh
            ycrc_r_fudge='--ycrc_r_fudge'
            shift
        fi
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
    
    __mlq_parse_module_tree_iter $ycrc_r_fudge ${mlq_check_args}
    if [[ $? -ne 0 ]]; then
        return_status=1
    fi
    
    unset __mlq_module_version
    unset __mlq_module_file
    unset __mlq_module_callstack
    unset __mlq_expected_versions

    # Restore the previously loaded modules
    # if [[ "$#" -lt 1 ]] ; then
    #     __mlq_orig_module load ${mlq_check_args}
    # fi

    return $return_status
}

# Fancier logo (as if)
# Font source: https://patorjk.com/software/taag/#p=display&f=Diet%20Cola&t=mlq
# __mlq_diet_cola
#     IFS='' read -r -d '' mlq_diet_cola <<"EOF"
#             (~~)                         
#            <(@@)                  /      
#      /##--##-\#)    .  .-. .-.   / .-.   
#     / |##  # |       )/   )   ) / (   )  
#    *  ||ww--||      '/   /   (_/_.-`-(   
#       ^^    ^^                `-'     `-'
# EOF
    

function __mlq_parse_module_tree_iter() {
    # In the YCRC setup, R versions R/xxx and R/xxx-bare can coexist
    #  as module dependencies (lmod of course will only load one of them
    #  at a time). The below 'fudge' flag allows this to occur
    #  without reporting a conflict!
    local ycrc_r_fudge
    unset ycrc_r_fudge
    if [[ "$1" == '--ycrc_r_fudge' ]] ; then
        # Ugh
        ycrc_r_fudge='--ycrc_r_fudge'
        shift
    fi
    
    local callstack
    local toplevel
    unset callstack
    unset toplevel
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

            # In the YCRC setup, R versions R/xxx and R/xxx-bare coexist although lmod
            #  will only load one of them at a time
            if [[ (  "${ycrc_r_fudge}" == '--ycrc_r_fudge' && "${name}" == 'R' ) \
                      && (    "${version}" == "${__mlq_module_version[$name]}"'-bare' \
                           || "${version}"'-bare' == "${__mlq_module_version[$name]}" ) ]] ; then
                # Ugh
                echo ''
                echo '[YCRC fudge] Skipping R version non-conflict:'
                echo "      R/${version}"
                echo "      R/${__mlq_module_version[$name]}"
            else
                echo ''
                echo 'Conflict: Multiple version dependencies were found for ' "'"${name}"'" ':'
                echo '     '"'"${version}"'"'(Call stack: '${callstack}' )'
                echo '     File: '"${modfile}"
                echo '                vs.'
                echo '     '"'"${__mlq_module_version[$name]}"'"' (Call stack: '${__mlq_module_callstack[$name]}"'"
                echo '     File: '"${__mlq_module_file[$name]}"
                return_status=1
            fi
        fi

        __mlq_module_version[$name]="$version"  # Track version
        __mlq_module_file[$name]="$modfile"  # Track actual modfile name
        __mlq_module_callstack[$name]="$callstack"   # Record whose dependency this is
        __mlq_expected_versions[$fullmod]="$version"     # Record version

        # Parse dependencies
        local modname_list=`awk '$1 ~ "^depends_on[(][\"]" {sub("^depends_on[(][\"]","",$1); sub("[\"][)]$","",$1); print $1}' $modfile`

        local m
        for m in $modname_list; do
            __mlq_parse_module_tree_iter $ycrc_r_fudge --callstack "${callstack}" "$m"
            
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
