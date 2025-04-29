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
ordered_module_list=( $(for m in `ml --redirect -t|grep -v StdEnv` ; do ml --redirect --location show $m ; done) )

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
echo 'mlwq '"$1"
echo '  or manually with:'
echo 'ml reset; ml use '"${HOME}"'/.mlq/mlq_simple ; ml '"${shortcut_name}"

cd - >& /dev/null
