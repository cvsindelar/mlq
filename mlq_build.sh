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
    echo 'All oaded modules will be saved into the shortcut file ~/.mlq/mlq_simple/<shortcut_name>.lua'
    return
fi
shortcut_name='mlq-'"$1"

##################
# Get the module build order by making a module collection with
#  the 'module save' function.
##################
collection_name="${shortcut_name##*/}"
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

echo 'Shortcut saved to: '"${HOME}"'/.mlq/mlq_simple/'"${shortcut_name}".lua
echo 'Load with: '
echo 'ml reset; ml use '"${HOME}"'/.mlq/mlq_simple ; ml '"${shortcut_name}"

cd - >& /dev/null
