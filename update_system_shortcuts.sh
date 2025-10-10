#!/bin/bash

#SBATCH -c 32 --mem 10G

# Check if the current shell is bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script must be run with a Bash shell." >&2
  return 1 2>/dev/null || exit 1
fi

if [[ "$0" != "${BASH_SOURCE}" ]]; then
    echo "Please execute this script directly; do not source it"
    return
fi

if [[ $1 == "--help" || $1 == "-h" || $1 == "show-all-if-ambiguous" || $# -gt 1 ]] ; then
    echo 'Usage:'
    echo ' update_system_shortcuts.sh [optional:n_cpus]'
    echo '   or'
    echo ' sbatch -c <n_cpus> [--mem <memG>, i.e. 10G> ...] update_system_shortcuts.sh'
    exit
fi

if [[ $# == 1 ]] ; then
    mlq_update_cpus=$1
elif [[ "${SLURM_CPUS_ON_NODE}" ]] ; then
    mlq_update_cpus=$SLURM_CPUS_ON_NODE
else
    mlq_update_cpus=1
fi

echo 'Using '${mlq_update_cpus}' CPUs'

save_dir=$HOME/mlq_save
if [[ -d "$save_dir" ]]; then
    echo 'Your last shortcut update was apparently incomplete. Continuing...'
else
    echo 'Temporarily moving your existing '"'""${HOME}/.mlq""'"' library to '"'""${save_dir}""'"
    mv $HOME/.mlq $save_dir
    if [[ $? -ne 0 || ! -d $save_dir ]] ; then
	echo 'Error backing up '"'""${HOME}/.mlq""'"' ; exiting'
	return 1
    fi
fi

# Clean up any leftover temporary folders if the last attempt was interrupted
[[ -d $HOME/mlq_prebuilds_update ]] && /bin/rm -r $HOME/mlq_prebuilds_update
[[ -d $HOME/mlq_prebuilds_failed ]] && /bin/rm -r $HOME/mlq_prebuilds_failed
[[ -d "${__mlq_prebuilds_dir}.d" ]] && /bin/rm -r "${__mlq_prebuilds_dir}.d"
[[ -d "${__mlq_prebuilds_dir}.u" ]] && /bin/rm -r "${__mlq_prebuilds_dir}.u"

module reset >& /dev/null
ml mlq >& /dev/null

shortcut_list=(`ml -e | grep -v 'System[ ]shortcuts[:]' | grep -v 'Existing[ ]custom[ ]shortcuts[:]'`)

module reset >& /dev/null
module load parallel

# unset shortcut_list_short
# shortcut_list_short=(${shortcut_list[0]} ${shortcut_list[1]})

if [[ -d {HOME}/mlq_prebuilds_failed ]] ; then
    rmdir ${HOME}/mlq_prebuilds_failed
fi

# echo The list: ${shortcut_list_short[@]}

# (for m in ${shortcut_list_short[@]} ; do echo $m ; done) | \

(for m in ${shortcut_list[@]} ; do echo $m ; done) | \
    parallel -j $mlq_update_cpus \
	     'echo "######################################" ; \
	      echo checking {}; \
	      echo "######################################" ; \
              module reset >& /dev/null; \
              ml mlq >& /dev/null; \
	      mod_name_full=`__mlq_collection_name {}` ; \
              ml {}; \
              if [[ $? -ne 0 ]] ; then \
                echo "Update attempt failed: ${mod_name_full}"
                mkdir -p ${HOME}/mlq_prebuilds_failed ; \
                /bin/mv ~/.mlq/"${mod_name_full}" ${HOME}/mlq_prebuilds_failed ; \
              else \
	        if [[ -d ~/.mlq/"${mod_name_full}" ]] ; then \
                  echo "Updating: ${mod_name_full}"
                  mkdir -p ${HOME}/mlq_prebuilds_update ; \
                  /bin/mv ~/.mlq/"${mod_name_full}" ${HOME}/mlq_prebuilds_update; \
                else \
                  echo "No update needed: ${mod_name_full}"
		fi \
              fi ; \
	      echo ""'

parallel_status=$?

echo Exit status':' $parallel_status

if [[ $parallel_status -ne 0 ]] ; then
    echo 'WARNING: Unexpected shortcut update failures ('$parallel_status')'
fi

if [[ -d ${HOME}/mlq_prebuilds_failed ]] ; then
    echo 'WARNING: shortcut update is incomplete. The following rebuilds failed:'
    d_tmp=$PWD
    for m in ${HOME}/mlq_prebuilds_failed/* ; do
	cd $m
	failed_mod=(`ls -1 */*.lua`)
	echo "${failed_mod}" | awk '{print substr($1,5,length($1)-8)}'
	cd "${d_tmp}"
    done
    echo ''
fi

ml mlq >& /dev/null

# if [[ $(ls -A $HOME/mlq/_prebuilds_update) ]] ; then
if [[ -d $HOME/mlq_prebuilds_update ]] ; then
    echo 'Transferring updated shortcuts to '"'""${__mlq_prebuilds_dir}""'"
    mkdir -p "${__mlq_prebuilds_dir}.d"
    mkdir -p "${__mlq_prebuilds_dir}.u"
    for m in $HOME/mlq_prebuilds_update/* ; do
	m_name=${m##*/}
	# Move new shortcut dir to the new filesystem first, as this can be slow
	/bin/mv "${m}" "${__mlq_prebuilds_dir}.u"

	# Swap in the new shortcut quickly
	/bin/mv "${__mlq_prebuilds_dir}/${m_name}" "${__mlq_prebuilds_dir}.d"
	/bin/mv "${__mlq_prebuilds_dir}.u/${m_name}" "${__mlq_prebuilds_dir}/${m_name}"

	# Delete the old shortcut
	/bin/rm -r "${__mlq_prebuilds_dir}.d/${m_name}"
    done
    rmdir "${__mlq_prebuilds_dir}.d"
    rmdir "${__mlq_prebuilds_dir}.u"
fi

/bin/rm -r $HOME/.mlq
echo 'Restoring your '"'""${HOME}/.mlq""'"' library from '"'""${save_dir}""'"
/bin/mv $save_dir $HOME/.mlq
