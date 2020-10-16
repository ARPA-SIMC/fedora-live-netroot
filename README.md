# Fedora-live-netroot

This package allows to prepare a Fedora or CentOS root filesystem
suitable for booting a diskless system; in the initial approach it
borrowed some concepts from live distributions, thus the name, but it
has successively departed from that. It is mainly oriented to HPC
cluster diskless nodes, but it can be adapted for installing systems
with a different purpose.

It makes (ab)use of the [singularity](https://www.sylabs.io/)
container software for bootstrapping and administering the root
filesystem image.

By default, the root filesystem image is served in read-only mode,
thus it can be shared among many diskless clients, the filesystem is
made read-write by the client thanks to an in-memory tmpfs
superimposed over the network file system by means of overlayfs kernel
module. The modifications of the root filesystem get thus lost at
every reboot. It is however possible to serve the image in read-write
mode to a single client.

The image can be quickly tested in a virtual environment with
qemu(-kvm).

## Installation, dependencies and compatibility

For installing the package, simply clone the github source tree
repository in the desired working directory. It is assumed that all
the operations are done by the `root` user.

Fedora-live-netroot requires the following packages:

 * singularity for building the image
 * qemu, syslinux (syslinux-nonlinux if exists), nfs-utils (and a
   running nfs server) for testing on a virtual machine with nfs
 * nbd, netbsd-iscsi (or iscsi-initiator-utils) for testing transports
   other than nfs.

The system has been tested with CentOS 7, CentOS 8 and Fedora 32 (plus
older Fedora) as diskless client distributions. Three corresponding
basic installation recipes are provided for these distributions. The
tested host systems are CentOS 7 and Fedora 24-32 distros with
singularity v3+. CentOS 7 is not capable to bootstrap newer Fedora
versions due to rpm database incompatibility.

For the unlucky users living behind an http proxy, the correct
environment variable for proxifying the basic system installation is:

``` export http_proxy=http://<user>:<passwd>@<host>:<port>/ ```

If other network installation operations, besides `yum`/`dnf`, are
performed in the installation recipe, other environment variable
definitions may be required in order for the proxy to work.

## Running

### Quick start on a virtual environment

For a quick start, it is suggested to use the script `live_netroot`
and the singularity recipes `*.def` included in the source tree. The
script does the work of installing the operating system on a local
directory, installing a local pxe bootloader and starting a virtual
system with qemu emulating the pxe network boot process.

Assuming to build a system with the centos7-base recipe, the steps
will be:

 * build the guest diskless root filesystem tree, this will take long
   time and require an internet connection, remember to remove an
   existing filesystem tree before a rebuild:
 
```
./live_netroot build centos7
```

 * install the syslinux pxe bootloader, kernel and initramfs image for
   network booting by nfs in the host system, make the installed image
   the default for booting:

```
./live_netroot installnfs centos7
```

 * start the virtual machine simulating network pxe boot using the
   created image as root filesystem, this command also takes care of
   exporting the root filesystem by nfs to the virtual system and
   unexporting it at the end (the nfs server must have already been
   started at this moment, e.g. with `systemctl start
   nfs-server.service`):

```
./live_netroot startnfs centos7
```

now you can log onto the guest virtual machine using the root password
specified in the recipe file (`centos7-base.def` in this case) from
the qemu console or from the local host via ssh on port 2222 as
specified in the qemu port redirection option in `live_netroot`
script:

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
   read-write, without an in-memory overlay, in the guest system
 * `DEBUG` equal to `Y` if debugging should be enabled in the guest
   system, this includes a verbose debugging of the pre-rootfs dracut
   boot process and output of all the log information to a local file
   through a serial console in qemu
 * `EXTRA_CMDLINE` extra kernel command-line arguments
 * `EXTRA_QEMU` extra options for qemu.

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
however done with care since, when changing files which are in use by
the running system, the modifications may not take effect or could
generate a `stale file handle` error on the client; in the latter case
the command `mount -o remount /` on the diskless client system usually
recovers from the error.

### Further per-host custom configurations

If the same base image is used for booting different hosts, requiring
different configurations that cannot easily be applied through kernel
command-line or dhcp arguments, e.g. setting a static network
configuration on a different network interface, it is possible to
populate the read-only root filesystem image with a set of file trees
that can replace the files in the base read-only image before
pivot-root, depending on kernel command-line arguments.

This is done in the following way:

1. in the base root fs create a directory `etc/rootovl/<config-name>`
   and populate it with the files that need to be added or modified,
   starting from the root of the filesystem, so, for changing
   `/etc/sysconfig/network-scripts/ifcfg-ens20f0` you need to create
   the file
   `etc/rootovl/<config-name>/etc/sysconfig/network-scripts/ifcfg-ens20f0`
   in the root tree

2. start the diskless system adding the `rootovlcfg=<config-name>`
   kernel command-line argument (this can be done with the
   `EXTRA_CMDLINE` environment variable in the qemu test environment).

If everything works, the root filesystem at pivot-root time will
contain the requested modifications, which will reside in the memory
overlay, while diskless systems started without `rootovlcfg` argument
will see the unmodified root filesystem. Any number of different
configuration trees can be created in the `etc/rootovl` directory. It
is not however possible to erase a file as for a specific host
configuration.

### Deploying on a real environment

Once the system works in a satisfactory way in the virtual
environment, the deployment on a real system requires mainly the two
following steps:

 1. set up real dhcp and tftp servers for providing ip address, boot
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

## How does it work

### Preparation of the root filesystem

The root filesystem image is created with the singularity software
package and the provided recipe files; the image can be set up as a
directory tree (sandbox container in singularity jargon) to be served
to the diskless client by nfs or as a squashfs (or possibly other
filesystems) image file to be served as a nbd device or iscsi target
(both untested).

The singularity recipe files provided perform mainly the following
steps:

 * bootstrap of the installation tree
 * addition of the files contained in the local `base/` directory to
   the installation tree
 * installation of the desired packages including kernel (triggering
   the generation of an intramfs image)
 * basic customisation of the installed system.

#### The `base/` directory tree

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

### Running the client system

The client system should boot on a network card with PXE technology,
it receives from the server by tftp the kernel and initramfs images
extracted from the installation tree.

In nfs mode the scripts on the initramfs image mount the root
filesystem tree read-only and overlay it with an in-memory tmpfs
filesystem. After chroot'ing on the prepared filesystem, the system
works as in an ordinary installation.


