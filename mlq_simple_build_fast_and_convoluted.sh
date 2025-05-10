##################
# Makes a fast-loading 'shortcut' module that reproduces
#  the current module environment
##################

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    echo "Please source this script; do not execute it directly."
    exit
fi

if [[ $1 == "--help" || $1 == "-h" || $1 == "show-all-if-ambiguous" || $# -lt 1 || $# -gt 1 ]] ; then
    echo 'Please give one argument: <shortcut_name>'
    echo ''
    echo 'Forward slashes in <shortcut_name> will be substituted by '"'"'-'"'"'.'
    echo ''
    echo 'All loaded modules will be saved into the shortcut file:'
    echo '  ~/.mlq/mlq_simple/mlq-<shortcut_name_no_slashes>.lua'
    return
fi
shortcut_name='mlq-'"$1"
# replace forward slashes by '-' so there is no directory in the name
shortcut_name=`echo "${shortcut_name}"|awk '{gsub("/","-",$0); print $0}'`

##################
# Get the list of module files, in the correct build order: 'ordered_module_list'
##################

# Do this the fast but cumbersome way
__mlsq_fast=1

if [[ ! ${__mlsq_fast} ]] ; then
    ##################
    ##################
    ##################
    # The succinct but slow way to get ordered_module_list
    ##################
    ##################
    ##################
    local m
    ordered_module_list=( $(for m in `ml --redirect -t|grep -v StdEnv` ; do ml --redirect --location show $m ; done) )
else
    ##################
    ##################
    ##################
    # The following 40 lines of code use a collection file to get ordered_module_list;
    #  much faster but cumbersome!
    ##################
    ##################
    ##################
    
    # Make a valid module collection name by getting rid of slashes and periods in $shortcut_name
    collection_name=`echo "${shortcut_name}"|awk '{sub("/","-",$0); gsub("[.]","_",$0); print $0}'`

    # Get the module build order by making a module collection with
    #  the 'module save' function.
    module --redirect --width=1 save "${collection_name}" >& /dev/null

    ##################
    # Account for different naming conventions for module collection files
    #  (there seem to be at least two)
    ##################
    if [[ "${LMOD_SYSTEM_NAME}" ]]; then
	collection_file="${HOME}"/.config/lmod/${collection_name}.${LMOD_SYSTEM_NAME}
    else
	collection_file="${HOME}"/.config/lmod/"${collection_name}"
    fi

    ##################
    # lua script for processing lmod collection files
    # This obtains a list of lua modulefiles, from the saved module collection file,
    #  defining the modules to be used for a shortcut.
    # It also prints the load order number.
    ##################
    process_collection_lua_script='
        for key, subTable in pairs(_ModuleTable_.mT) do 
          if type(subTable) == "table" and subTable.fn then
            print(subTable.loadOrder, subTable.fn) 
          end 
        end '

    # Get list of modulefiles from the saved module collection file;
    # but don't include the standard environment
    # also, be sure to sort the list by the load order.
    ordered_module_list=(`( cat "${collection_file}" ; echo "${process_collection_lua_script}" ) | \
        lua - | sort -n -k 1 | awk '{print $2}' | grep -v 'StdEnv[.]lua$'`)
fi

##################
# Concatenate all the .lua files required by this collection,
#  but strip out the 'depends_on' statements.

# This is predicated on 'module save' having generated a complete, self-consistent
#  list of modules, with a defined build order that we will use when loading.
#  (ordered_module_list is sorted on the build order).

#  Note that most lmod lua files include local declarations of 'root',
#   and lua will error out if more than 500 local declarations are made,
#   even when these are of the same variable. So we also use awk to take care of this,
#   making it so that only the first 'root' declaration keeps the 'local' keyword.
##################

mkdir -p ~/.mlq/mlq_simple
cd ~/.mlq/mlq_simple
printf '' > "${shortcut_name}".lua
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
        >> "${shortcut_name}".lua

# Preserve the original shortcut name for listing purposes (it might have slashes)
echo "$1" > "${shortcut_name}".shortcut_name
echo 'Shortcut saved to: '"${HOME}"'/.mlq/mlq_simple/'"${shortcut_name}".lua
echo 'Load with: '
echo 'mlsq '"$1"
echo '  or manually with:'
echo 'ml reset; ml use '"${HOME}"'/.mlq/mlq_simple ; ml '"${shortcut_name}"

cd - >& /dev/null
