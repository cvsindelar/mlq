#!/bin/bash

#SBATCH -c 32 --mem 32G

# Check if the current shell is bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script must be run with a Bash shell." >&2
  return 1 2>/dev/null || exit 1
fi

if [[ "$0" != "${BASH_SOURCE}" ]]; then
    echo "Please execute this script directly; do not source it"
    return
fi

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

module reset
ml mlq

shortcut_list=`ml -e | grep -v 'System[ ]shortcuts[:]' | grep -v 'Existing[ ]custom[ ]shortcuts[:]'`

module reset
module load parallel

(for m in $shortcut_list ; do echo $m ; done)| parallel -j $SLURM_CPUS_ON_NODE 'module reset; ml mlq; echo ml {} ; ml {}'

parallel_status=$?

echo Exit status':' $parallel_status

if [[ $parallel_status -ne 0 ]] ; then
    echo 'WARNING: update is incomplete: '$parallel_status' failures'
    exit
fi

ml mlq
echo 'Transferring the updated shortcuts to '"'""${__mlq_prebuilds_dir}""'"
/bin/cp -rf $HOME/.mlq/* "${__mlq_prebuilds_dir}"
/bin/rm -r $HOME/.mlq
echo 'Restoring your '"'""${HOME}/.mlq""'"' library from '"'""${save_dir}""'"
mv $save_dir $HOME/.mlq
