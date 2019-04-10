# Fedora-live-netroot

This package allows to setup a Fedora or CentOS root filesystem for a
diskless installation, in the initial approach it borrowed some
concepts from live distributions, thus the name, but it has
successively departed from that. It is mainly oriented to HPC cluster
diskless nodes, but it can be adapted for installing systems with a
different purpose.

It makes (ab)use of the [singularity](https://www.sylabs.io/)
container software for bootstrapping and administering the root
filesystem image. The image can be set up as a directory tree (sandbox
container in singularity jargon) to be served to the diskless client
by nfs or as a squashfs (or possibly other filesystems) image file to
be served as a nbd device or iscsi target (both untested).

By default the root filesystem image is served in read-only mode, thus
it can be shared among many diskless clients, the filesystem is made
read-write by the client by means of an in-memory overlay filesytem,
whose contents gets lost at every reboot.

It is however possible to serve the image in read-write mode to a
single client.

The image can be quickly tested in a virtual environment with
qemu-kvm.

## Dependencies and compatibility

The package requires at least the following dependencies: singularity,
singularity-runtime (if exists), qemu, nfs-utils.

Additional dependencies for testing other transports: nbd,
netbsd-iscsi (or iscsi-initiator-utils).

The system has been tested with CentOS 7, Fedora 28 and Fedora 29 as
diskless client distributions. Three corresponding basic installation
recipes are provided for these distributions. The host system was a
Fedora 24 system with a custom updated singularity package, it should
work on CentOS 7 and later Fedora as well.

## Quick start on a virtual environment

For a quick start, it is suggested to use the provided `live_netroot`
script which does the work of installing the operating system on a
local directory, installing a local pxe bootloader and starting a
virtual system with qemu emulating the pxe network boot process.

The only preliminary operation is to adjust the contents of the file
`live_netroot_hosts` for setting up a list of labels referring to
configured systems. Every label is associated with a single
installation recipe, but it may be associated to different root
filesystem provisioning (e.g. nfs and nbd).

The variables to be defined for each label are:
 * `NETROOT` directory where the root filesystem will be built on the
   local system, it should be different for every label
 * `RECIPE` the singularity recipe file to be used for building the
   root filesystem image
 * `TFTPBOOT` the directory on the local system where the pxe
   bootloader and the kernel and initramfs images will be installed
   for network booting by qemu, it can be the same for different
   images, but only one image will be the one to be booted by default
 * `RW` equal to `Y` if the root filesystem should be mounted
   read-write, without a in-memory overlay, in the booted system
 * `DEBUG` equal to `Y` if debugging should be enabled in the booted
   system, this includes a verbose debugging of the pre-rootfs dracut
   boot process and output of all the log information to a local file
   through a serial console in qemu.

The procdedure, using the `live_netroot` script, assuming to build a
system with the centos7-base recipe, will be:

 * build the root filesystem tree, this will take long time and
   require an internet connection, remember to remove an existing
   filesystem tree before a rebuild:
 
```
./live_netroot build centos7
```

 * install the bootloader and the initial OS images for network
   booting by nfs, make the installed image the default for booting:

```
./live_netroot installnfs centos7
```

 * start the virtual machine simulating network pxe boot using the
   created image as root filesystem, this command also takes care of
   exporting the root filesystem by nfs to the virtual system and
   unexporting it at the end:

```
./live_netroot startnfs centos7
```

now you can login to the machine using the configured root password
(or other users if configured in the recipe) from the qemu console or
from the local host via ssh on port 2222 as specified in the qemu port
redirection option:

```
ssh -p 2222 root@localhost
```

If modifications are needed to the image, you can modify directly the
filesystem from the local host or, better, chroot into it through
singularity, so that, e.g., new packages can be installed:

```
./live_netroot shell centos7
```

Note that this breaks the reproducibility of the system through the
recipe, but it is probably unavoidable if you need to install a
complete system.

## Deploying on a real environment

Once the system works in a satisfactory way in the virtual
environment, the deployment on a real system requires mainly the two
following steps:

 1. set up a real dhcp and tftp server for providing ip address, boot
    loader file, kernel and initramfs image to the diskless clients;
    the directory tree to be exported by tftp can be taken from the
    one created for the virtual environment applying proper
    modifications (mainly concerning the real ip addresses)

 2. set up an export entry in the nfs server (which should already be
    working) for exporting the root filesystem image to the clients;
    unlike the case for the virtual environment, the `insecure` option
    may be omitted for a real case, and the network/mask should be set
    accordingly.


