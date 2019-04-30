# Fedora-live-netroot

This package allows to prepare a Fedora or CentOS root filesystem
suitable for booting a diskless system; in the initial approach it
borrowed some concepts from live distributions, thus the name, but it
has successively departed from that. It is mainly oriented to HPC
cluster diskless nodes, but it can be adapted for installing systems
with a different purpose.

It makes (ab)use of the [singularity](https://www.sylabs.io/)
container software for bootstrapping and administering the root
filesystem image. The image can be set up as a directory tree (sandbox
container in singularity jargon) to be served to the diskless client
by nfs or as a squashfs (or possibly other filesystems) image file to
be served as a nbd device or iscsi target (both untested).

By default, the root filesystem image is served in read-only mode,
thus it can be shared among many diskless clients, the filesystem is
made read-write by the client thanks to an in-memory tmpfs
superimposed over the network file system by means of overlayfs kernel
module. The modifications of the root filesystem get thus lost at
every reboot.

It is however possible to serve the image in read-write mode to a
single client.

The image can be quickly tested in a virtual environment with
qemu(-kvm).

## Installation, dependencies and compatibility

For installing the package, simply clone the github source repository
in the desired working directory. It is assumed that all the
operations are done by the `root` user.

Fedora_live_netroot requires the following packages:

 * singularity for building the image
 * qemu, syslinux (syslinux-nonlinux if exists), nfs-utils (and a
   running nfs server) for testing on a virtual machine with nfs
 * nbd, netbsd-iscsi (or iscsi-initiator-utils) for testing transports
   other than nfs.

The system has been tested with CentOS 7, Fedora 28 and Fedora 29 as
diskless client distributions. Three corresponding basic installation
recipes are provided for these distributions. The host system had a
Fedora 24 distro with a custom updated singularity package (v2.5.1),
it should however work on any host distribution capable to bootstrap a
yum/dnf based filesystem with singularity.

## Running

### Quick start on a virtual environment

For a quick start, it is suggested to use the provided `live_netroot`
script and OS recipes `*.def`. The script does the work of installing
the operating system on a local directory, installing a local pxe
bootloader and starting a virtual system with qemu emulating the pxe
network boot process.

Assuming to build a system with the centos7-base recipe, the steps
will be:

 * build the root filesystem tree, this will take long time and
   require an internet connection, remember to remove an existing
   filesystem tree before a rebuild:
 
```
./live_netroot build centos7
```

 * install the syslinux pxe bootloader and the initial OS images for
   network booting by nfs, make the installed image the default for
   booting:

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

now you can login to the guest virtual machine using the root password
specified in the recipe file (`centos7-base.def` in this case) from
the qemu console or from the local host via ssh on port 2222 as
specified in the qemu port redirection option:

```
ssh -p 2222 root@localhost
```

### Customisation of the image build

For more advanced customisation, it is suggested to adjust the
contents of the file `live_netroot_hosts` for setting up a list of
labels referring to configured systems. Every label is associated with
a single installation recipe, but it may be associated with different
root filesystem provisioning method (e.g. nfs and nbd) via the
corresponding `live_netroot` subcommands.

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
 * `EXTRA_QEMU` extra options for qemu

### Customisation of the installed system

If permanent modifications to the image are required after
installation, you can modify directly the filesystem from the host or,
better, chroot into it through singularity, so that, e.g., new
packages can be installed:

```
./live_netroot shell centos7
```

Note that this breaks the reproducibility of the system through the
recipe, but it is probably unavoidable if you need to install a
complete system.

With nfs, it is also possible to modify the read-only root filesystem
from the host (e.g. installing new packages or changing configuration
files) while the system (virtual or real) is running. This should be
however done with care, in particular, when changing files which are
in use by the running system, the modifications may not take effect or
could generate a `stale file handle` error in the client, in the
latter case the command `mount -o remount /` on the diskless client
system usually recovers from the error.


### Deploying on a real environment

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


## Security considerations

The installed diskless system has some security flaws, so run at your
own risk. In particular, the root filesystem is exported through nfs
to a subnet, so users with access to that subnet may obtain read
access to all the system files, including host keys and encrypted
shadow passwords. If this is an issue, you need to take proper
measures.

The root password explicitly set in the example recipes is for testing
purposes only, a safer technique should be used for a real image.

## Internals

The customisations applied to the installed system, with respect to a
basic Fedora or CentOS installation, are all contained in the `base/`
directory tree and applied to the system in the early stages of
package installation:

 * `/usr/lib/dracut/modules.d/90overlay-root/overlay-mount.sh`
   `/usr/lib/dracut/modules.d/90overlay-root/module-setup.sh` from the
   [FAI](https://fai-project.org/) project add a dracut module
   performing overlay mount of a in-memory tmpfs filesystem over the
   read-only root filesystem, enabled by the `rootovl` kernel
   command-line argument
 * `/etc/dracut.conf.d/02livecd.conf` `/etc/sysconfig/mkinitrd` tell
   kernel installation scripts to build an initramfs containing all
   the possible drivers and not only those required by the host system
 * `/usr/lib/systemd/system/rewrite-ifcfg.service` rewrites the ifcfg
   script for the network adapter used to connect to the root fs
   server (created by dracut at boot) in order to subtract it to
   NetworkManager control and avoid disconnections from the server.


