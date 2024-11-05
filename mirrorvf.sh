#!/bin/bash

# Title: mirrorvf.sh  
# Celine Wu/ De Montardy Simon

# Function to display help message
help(){
    echo "how to use it: miroir.sh [-s source_machine] [-m mirror_machine] source_dir mirror_dir"
    echo
    echo "Updates a mirror copy of a source directory. locally or far away"
    echo
    echo "Options:"
    echo "  -s source_machine   is going to Fetch the source from source_machine (local by default)."
    echo "  -m mirror_machine   is going to Update the mirror on mirror_machine (local by default)."
    echo
    echo "Both -s and -m options are mutually exclusive."
    echo
    echo "Arguments:"
    echo "  source_dir : Source directory path."
    echo "  mirror_dir  : Mirror directory path."
    echo
    echo "If no -s or -m option is provided, it performs a local copy."
    echo "When only one machine is specified, mirror_dir is assumed to be the same as source_dir."
    echo "If ~/.miroirrc exists, it will be used to exclude files from synchronization."
    exit 1
}

# Check if the user is root and deny the execution of the script
if [ "$(id -u)" -eq 0 ]; then
    echo "You are root, you should not run this script as root due to security reasons."
    exit 1
fi

# Parse options
while getopts ":s:m:h" opt; do
    case $opt in
        s)
            source_machine="$OPTARG"
            ;;
        m)
            mirror_machine="$OPTARG"
            ;;
        h)
            help
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            help
            ;;
    esac
done

# Shift off the parsed options and optional --
shift $((OPTIND-1))

# Extract source_dir and mirror_dir from the arguments as a variable
source_dir="$1"
mirror_dir="$2"

# Check if source_dir and mirror_dir are provided. 
if [ -z "$source_dir" ] || [ -z "$mirror_dir" ]; then
    echo "Both source_dir and mirror_dir are required arguments."
    help
fi

# Check if ~/.miroirrc exists and create exclude flag if it does to exclude it. 
exclude_flag=""
if [ -f "$HOME/.miroirrc" ]; then
    exclude_flag="--exclude-from=$HOME/.miroirrc"
fi

# Check if source and mirror are local or remote
if [ -n "$source_machine" ] && [ -n "$mirror_machine" ]; then
    echo "Both source and mirror machines cannot be specified together."
    help
elif [ -n "$source_machine" ]; then
    # Fetch source from source_machine
    ssh "$source_machine" test -d "$source_dir" || { echo "Source directory does not exist or SSH connection to $source_machine failed."; exit 1; }
    mirror_machine="$source_machine"
elif [ -n "$mirror_machine" ]; then
    # Update mirror on mirror_machine
    ssh "$mirror_machine" test -d "$mirror_dir" || { echo "Mirror directory does not exist or SSH connection to $mirror_machine failed."; exit 1; }
    source_machine="$mirror_machine"
fi

# Check if source and mirror directories are on the same partition
if [ "$(df -P "$source_dir" | awk 'NR==2 {print $1}')" == "$(df -P "$mirror_dir" | awk 'NR==2 {print $1}')" ]; then
    echo "Warning: Source and mirror directories are on the same partition."
    read -p "Are you sure you want to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if source and mirror directories are the same
if [ "$source_dir" = "$mirror_dir" ]; then
    echo "Source and mirror directories cannot be the same."
    exit 1
fi

# Perform the synchronization using rsync
rsync -avz -e ssh $exclude_flag "$source_machine:$source_dir/" "$mirror_machine:$mirror_dir/"
