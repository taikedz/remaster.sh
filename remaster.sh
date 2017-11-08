#!/bin/bash
set -euo pipefail

CLR_GRN="\033[33;1m"
CLR_RED="\033[31;1m"
CLR_DEF="\033[0m"

infoe() {
	echo -e "$CLR_GRN$*$CLR_DEF"
}

printhelp() {
cat <<EOHELP

remaster.sh

Originally by Pat Natali https://github.com/beta0x64/remaster.sh
With contributions by Tai Kedzierski https://github.com/taikedz/remaster.sh

Usage:

    $0 --iniso=old.iso --outiso=new.iso [--entry=ENTRYPOINT]

ENTRYPOINT is a flag at which you can resume a function of the script. The supported entry points are:

mountiso
    Starts the process by mounting the original ISO,
    and proceeds through the rest of the script

customizeiso
    Re-starts the ISO cusotmization step,
    and proceeds through the rest of the script

customizekernel
    Re-starts the post-ISO customization step,
    and proceeds through the rest of the script

buildiso
    Re-builds the ISO from the currrent state.
    Requires that the previous steps to have been run before
    and for ./livecdtemp to not have been removed or broken

EOHELP
}

main() {

	yespat='^(yes|y|YES|Y|aye?|AYE?)$'
	ISOTASK=mountiso

	if [[ -z "$*" ]]; then
	    printhelp
	    exit
	fi

	for term in "$@"; do
	    case "$term" in
		--iniso=*)
		    ORIGINAL_ISO_NAME="${term#--iniso=}"
		    ;;
		--outiso=*)
		    NEW_ISO_NAME="${term#--outiso=}"
		    ;;
		--entry=*)
		    ISOTASK="${term#--entry=}"
		    ;;
		--help)
		    printhelp
		    exit
		    ;;
		*)
		    [[ ! -f "$term" ]] && {
		    	faile "Unknown option $term"
		    	exit 98
		    }
		    ;;
	    esac
	done

	check_iso_names

	prompt_install_prereqs

	case "$ISOTASK" in
		# last to first
		mountiso)
			mountiso;;

		customizeiso)
			customizeiso;;

		customizekernel)
			customizekernel;;

		buildiso)
			buildiso;;
		*)
			faile "Invalid entry point"
			exit 2
			;;
	esac
}

check_iso_names() {
	if [[ -z "$ORIGINAL_ISO_NAME" ]] || [[ -z "$NEW_ISO_NAME" ]]; then
	    printhelp
	    exit 1
	fi
}

is_installed() {
	dpkg --get-selections |awk '{print $1}' |grep -P "^$1$" -q
}

prompt_install_prereqs() {
	if is_installed squashfs-tools && is_installed syslinux ; then
		return
	fi

	read -p "Install pre-requisites? > " resp
	if [[ $resp =~ $yespat ]]; then
	    infoe "Installing/updating squashfs-tools and syslinux"
	    sudo apt-get update && sudo apt-get install squashfs-tools syslinux -y
	fi
}

ensure_tempdir() {
	if [[ "$(basename "$PWD")" == livecdtmp ]]; then
		return
	fi

	mkdir -p ./livecdtmp
	cd ./livecdtmp
}

isoname_in_temp() {
	if [[ -f "../$ORIGINAL_ISO_NAME" ]]; then
	    ORIGINAL_ISO_NAME="../$ORIGINAL_ISO_NAME"
	elif [[ ! -f "$ORIGINAL_ISO_NAME" ]]; then
	    infoe "$ORIGINAL_ISO_NAME cannot be found. Please specify its full path with the --iniso parameter." >&2
	    exit 2
	fi
}

ensure_consistent_environment() {
	# Make a parent directory for our Live USB
	ensure_tempdir
	isoname_in_temp

	infoe "Acquiring root privilege ..."
	sudo su -c ":" || {
		infoe "Failed to run command as root."
		exit 3
	}
}

are_you_happy() {
	local thisstep="$1"; shift

	infoe "You can re-run this step using '$0 --entry=$thisstep --iniso=$ORIGINAL_ISO_NAME --outiso=$NEW_ISO_NAME'"

	read -p "Are you happy with these changes ? > " resp

	if [[ "$resp" =~ $yespat ]]; then
		return 0
	fi

	exit 5
}

mountiso() {
	# Step 1:
	ensure_consistent_environment

	# Step 2:
	# Mount the ISO as a loop filesystem to ./livecdtmp/mnt
	# This will allow us to look at its insides, basically
	mkdir -p ./mnt

	sudo mount -o loop "$ORIGINAL_ISO_NAME" ./mnt

	sudo mkdir extract-cd

	# Copy all the ISO's innards except for filesystem.squashfs to extract-cd/
	sudo rsync --exclude=/casper/filesystem.squashfs -a ./mnt/ ./extract-cd
	
	# Expand the squashed filesystem and put it into ./livecdtmp/edit
	#   so we can update the squashed filesystem with our new values
	#   it needs to boot and install properly
	sudo unsquashfs mnt/casper/filesystem.squashfs
	sudo mv squashfs-root edit

	customizeiso
}

customizeiso() {
	ensure_consistent_environment

	# Step 3:
	# This makes our terminal's "perspective" come from ./livecdtmp/edit/
	sudo mount -o bind /run edit/run || :
	sudo chroot edit mount -t proc none /proc || :
	sudo chroot edit mount -t sysfs none /sys || :
	sudo mount -o bind /dev/pts edit/dev/pts || :

	# Step 4:
	infoe "Now make customizations from the CLI"
	infoe "If you want to replace the desktop wallpaper, use the instructions related to your window manager. You may have to replace the image somewhere under /usr/share"
	infoe "If you need to copy in new files to the ISO, use another terminal to copy to remaster/livecdtmp/extract-cd/ as root"
	infoe "To use apt-get properly, you may have to copy from your /etc/apt/sources.list to this ISO, then run apt-get update and finally resolvconf -u to connect to the internet"
	infoe "When you are done, just type 'exit' to continue the process"
	infoe "You are now in the target ISO's chroot context"

	HOME=/root LC_ALL=C sudo chroot edit

	# Step 5:
	# Back out of the chroot
	infoe "Backing out of the chroot"
	sudo chroot edit umount /proc || :
	sudo chroot edit umount /sys || :
	sudo umount mnt || :
	sudo umount edit/run || :
	sudo umount edit/dev/pts || :

	# =======
	are_you_happy customizeiso
	customizekernel
} # ====================================

customizekernel() {
	ensure_consistent_environment

	infoe "You are now outside of the ISO chroot."
	infoe "If you want to, you can enter kernel commands or other changes from outside of the ISO"
	infoe "If you want to turn off the 'try or install' screen, use these instructions: http://askubuntu.com/a/47613"
	infoe "isolinux.cfg and txt.cfg are in extract-cd/isolinux"
	infoe "When done, type 'exit' to begin the ISO creation process"
	bash

	# =======
	are_you_happy customizekernel
	buildiso
} # ====================================

buildiso() {
	ensure_consistent_environment
	pwd

	# Step 6:
	local manifest="extract-cd/casper/filesystem.manifest"
	local manifest_d="${manifest}-desktop"
	local squashfs="extract-cd/casper/filesystem.squashfs"

	sudo chmod a+w "$manifest"

	infoe "chroot edit dpkg-query -W --showformat='\${Package} \${Version}\n' > '$manifest'" | sudo sh >> ./remaster.log
	sudo cp "$manifest" "$manifest_d"
	sudo sed -i '/ubiquity/d' "$manifest_d"
	sudo sed -i '/casper/d' "$manifest_d"
	sudo rm "$squashfs" || [[ ! -f "$squashfs" ]]
	sudo mksquashfs edit "$squashfs"

	local iso_size="$(sudo du -sx --block-size=1 edit | cut -f1)"

	infoe "printf $iso_size > extract-cd/casper/filesystem.size" | sudo sh >> ./remaster.log
	sudo nano extract-cd/README.diskdefines
	sudo rm extract-cd/md5sum.txt
	infoe "find extract-cd/ -type f -print0 | xargs -0 md5sum | grep -v extract-cd/isolinux/boot.cat | tee extract-cd/md5sum.txt" | sudo sh >> ./remaster.log
	local image_name='Custom ISO'
	sudo mkisofs -D -r -V "$image_name" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "../$NEW_ISO_NAME" extract-cd/
	sudo chmod 775 "../$NEW_ISO_NAME"

	cd ..

	isohybrid "$NEW_ISO_NAME"

	infoe "You can now delete ./livecdtmp (requires root privileges)."
}

main "$@"
