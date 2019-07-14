remaster.sh
===========

Tool to customize a [*]Ubuntu ISO. You need to use an ISO with a livecd environment - Ubuntu, Xubuntu, Ubuntu MATE, etc. Ubuntu Sevrer ISOs are not supported.



Usage:

    ./remaster.sh --iniso=old.iso --outiso=new.iso [--entry=ENTRYPOINT] [--script=SCRIPT]

SCRIPT is a script that can be passed to the `cusomizeiso` stage. Instead of an interactive shell session, the script itself is run.

ENTRYPOINT is a flag at which you can resume a function of the script. The supported entry points are:

mountiso

* Starts the process by mounting the original ISO,
* and proceeds through the rest of the script

customizeiso
* Re-starts the ISO cusotmization step,
* and proceeds through the rest of the script

customizekernel
* Re-starts the post-ISO customization step,
* and proceeds through the rest of the script

buildiso
* Re-builds the ISO from the currrent state.
* Requires that the previous steps to have been run before, and for `livecdtemp/` to not have been removed or broken



Authors

Originally by Pat Natali <https://github.com/beta0x64/remaster.sh>

This version by Tai Kedzierski <https://github.com/taikedz/remaster.sh>

