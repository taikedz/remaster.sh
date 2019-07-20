#!/usr/bin/env bash

# A simple script with which to test a built ISO
# Simply run `./test-iso.sh ISOFILE` to start a KVM machine booting from the ISO

MEM_MB=4096

hasbin() {
    which "$1" &>/dev/null
}

die() {
    echo "FAIL - $*" >&2
    exit 1
}

run-iso() {
    #qemu-system-x86_64 -cdrom "$1" -m "$MEM_MB"
    kvm -m "$MEM_MB" -cdrom "$1" -boot d
}

main() {
    if ! hasbin kvm ; then
        die "You must install the 'kvm' package to test using Kernel-based Virtual Machines."
    fi

    if [[ ! "$1" =~ .+\.iso$ ]]; then
        die "Provide a file ending in *.iso"
    fi

    run-iso "$1"
}

main "$@"
