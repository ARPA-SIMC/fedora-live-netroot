#!/bin/bash


usage() {

    cat <<EOF
Usage: $0 <command> <label>
where <command> is one of:

 build
  build the root filesystem image

 installnfs
  install the bootloader and the initial images for network booting by
  nfs, make the installed image the default for booting

 startnfs
  start the virtual machine simulating network pxe boot using the
  created image as root filesystem

 shell
  chroot into the root filesystem image container for administration

<label> must be defined in the configuration file live_netroot_hosts
and associated to a specific host configuration.
EOF
    exit 1
}

setuptftp() {
    # copy pxelinux bootloader binary
    if [ ! -f "$TFTPBOOT/pxelinux.0" -o ! -f "$TFTPBOOT/ldlinux.c32" ]; then
	echo "Setting up pxelinux"
	mkdir -p $TFTPBOOT/pxelinux.cfg
	if [ -f /usr/share/syslinux/pxelinux.0 ]; then
	    cp /usr/share/syslinux/pxelinux.0 $TFTPBOOT
	    cp /usr/share/syslinux/ldlinux.c32 $TFTPBOOT
	elif [ -f /usr/lib/syslinux/pxelinux.0 ]; then
	    cp /usr/lib/syslinux/pxelinux.0 $TFTPBOOT
	    cp /usr/lib/syslinux/ldlinux.c32 $TFTPBOOT
	else
	    echo "Could not add pxelinux.0 to $TFTPBOOT subdirectory"
	    return 1
	fi
    fi
}

copykernel() {
    # cleanup boot direcyory
    rm -f $NETROOT/boot/*rescue*
    kernels=($(ls -rt $NETROOT/boot/vmlinuz-*))
    initrds=($(ls -rt $NETROOT/boot/initramfs-*.img))

    if [ ${#kernels[*]} -gt 0 -a ${#initrds[*]} -gt 0 ]; then
	# copy last kernel and initramfs
	cp -p ${kernels[-1]} $TFTPBOOT/vmlinuz_$label
	cp -p ${initrds[-1]} $TFTPBOOT/initrd_$label.img
    else
	echo "No kernel or initramfs found in $NETROOT/boot"
	return 1
    fi
}

addpxelinuxentry() {
    pxelabel=$1
    if [ "$DEBUG" = "Y" ]; then
	cmdline="$cmdline rd.debug console=ttyS0,38400"
    fi
    if [ ! -f "$tftpconf" ]; then # create new file
	cat > $tftpconf <<EOF
DEFAULT pxeboot_$pxelabel
TIMEOUT 20
PROMPT 0
LABEL pxeboot_$pxelabel
        KERNEL vmlinuz_$label
        APPEND initrd=initrd_$label.img $cmdline
EOF
    else # update existing file
	# remove existing section and make the new section default
	sed -i -e "s/^DEFAULT .*$/DEFAULT pxeboot_$pxelabel/g" \
	    -e "/^LABEL pxeboot_$pxelabel/,/^ *APPEND/d" $tftpconf
	# add the new section
	cat >> $tftpconf <<EOF
LABEL pxeboot_$pxelabel
        KERNEL vmlinuz_$label
        APPEND initrd=initrd_$label.img $cmdline
EOF
    fi
}

createsquashfsimg () {
    mksquashfs $NETROOT $1 -noappend
}

startvm() {
    # start vm with pxe boot on network, redirect ssh, output serial
    # console to file
    qemu-kvm -m 2048 -net nic \
	     -net user,tftp=$TFTPBOOT,bootfile=/pxelinux.0,hostfwd=tcp:127.0.0.1:2222-:22 \
	     -serial file:serial.out $EXTRA_QEMU
}

set -e
set -u

if [ "$#" -ne "2" ]; then
    usage
fi
command=$1
shift
label=$1
shift
. ./live_netroot_hosts

#set -x

case $command in
    build)
	singularity build --sandbox $NETROOT $RECIPE
	# this has to be done here after singularity %post
	rm -f $NETROOT/etc/mtab
	ln -s ../proc/self/mounts $NETROOT/etc/mtab
	;;
    shell)
	singularity shell -w $NETROOT
	;;
    installnfs)
	# setup tftp pxe bootloader
	setuptftp
	tftpconf=$TFTPBOOT/pxelinux.cfg/default
	if [ "$RW" = "Y" ]; then
	    cmdline="audit=0 root=10.0.2.2:$NETROOT:rw,nolock,nfsvers=3 rootfstype=nfs rd.luks=0 rd.md=0 rd.dm=0"
	else
	    cmdline="audit=0 rootovl root=10.0.2.2:$NETROOT:ro,nolock,nfsvers=3 rootfstype=nfs rd.luks=0 rd.md=0 rd.dm=0"
	fi
	# copy kernel and initramfs images and configure bootloader
	if copykernel; then
	    addpxelinuxentry ${label}_nfs
	fi
	;;
    startnfs)
	if [ "$RW" = "Y" ]; then
	    rwflag=rw
	else
	    rwflag=ro
	fi
	# export nfs root to localhost
	exportfs -o $rwflag,no_root_squash,async,no_subtree_check,insecure 127.0.0.1:$NETROOT
	startvm
	# unexport nfs root filesystem
	exportfs -u 127.0.0.1:$NETROOT
	;;
    installnbd)
	# setup tftp pxe bootloader
	setuptftp
	tftpconf=$TFTPBOOT/pxelinux.cfg/default
	if [ "$RW" = "Y" ]; then
	    ro=false
	    echo "rw image not yet supported on nbd"
	    exit 1
	else
	    cmdline="audit=0 rootovl root=nbd:10.0.2.2:10809:squashfs:ro rootfstype=squashfs rd.luks=0 rd.md=0 rd.dm=0"
	    ro=true
	fi
	# copy kernel and initramfs images and configure bootloader
	if copykernel; then
	    addpxelinuxentry ${label}_nbd
	fi
	# create rootfs image
	createsquashfsimg $NETROOT.img
	# create nbd configuration for serving rootfs image
	cat <<EOF > nbd.conf
[generic]
  port = 10809
[$label]
  exportname = $NETROOT.img
  readonly = $ro
  multifile = false
  copyonwrite = false
EOF
	;;
    startnbd)
	# serve rootfs image by nbd
	nbd-server -C nbd.conf -d &
	startvm
	# stop nbd server
	kill %1
	;;
    installiscsi)
	echo "iscsi not working yet"
	exit 1
	# setup tftp pxe bootloader
	setuptftp
	tftpconf=$TFTPBOOT/pxelinux.cfg/default
	if [ "$RW" = "Y" ]; then
	    rwflag=rw
	    echo "rw image not yet supported on iscsi"
	    exit 1
	else
	    cmdline="audit=0 rootovl root=???:10.0.2.2:squashfs:ro rootfstype=squashfs rd.luks=0 rd.md=0 rd.dm=0"
	    rwflag=ro
	fi
	# copy kernel and initramfs images and configure bootloader
	if copykernel; then
	    addpxelinuxentry ${label}_nbd
	fi
	# create rootfs image
	createsquashfsimg $NETROOT.img

	# create iscsi target configuration for serving rootfs image with netbsd-iscsi
	cat <<EOF > exports
extent0 $NETROOT.img 0 size
target0 $rwflag extent0 127.0.0.1/8
EOF
       	;;
    startiscsi)
	echo "iscsi not working yet"
	exit 1
	# serve rootfs image by iscsi
	iscsi-target -f ./targets -D &
	startvm
	# stop iscsi server
	kill %1
	;;
    *)
	echo "Command $command not valid"
	usage
	;;
esac

