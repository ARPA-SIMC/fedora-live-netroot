# Fedora-live-netroot

This package extends the
[livecd-tools](https://github.com/rhinstaller/livecd-tools) package
with a script that allows to easily transform a -slightly modified-
Fedora live iso image into a bootable system having the root
filesystem readonly on a network device/filesystem, overlaid by a
writable live filesystem in memory.

This approach is suitable e.g. for creating diskless desktop thin
clients or diskless HPC computing nodes. It has been tested with
Fedora on x86_64 architecture, but it should work on other distros
using dracut and livecd-tools.

The image to be generated can be easily customized by editing the
kickstart file to be used. The package includes a small set of ready
kickstart files for creating targeted live images, but in principle
all the kickstart files available in Fedora packages for building live
CD's can work with fedora-live-netroot with minimal modification (the
minimum compulsory differences are the inclusion of `nbd` and
`dracut-network` packages).

This approach differs from the `livecd-iso-to-pxeboot` shipped with
the livecd-tools in that here the root file system image is not loaded
in memory but it is kept untouched on a server and accessed through
the network, keeping in memory only the departures from the original
image, so there are not strict limitations on the size of the base
image and the memory overhead with respect to a diskful system is
moderate.

Care has been taken in order to make all the system work with no
modification to the [dracut](https://fedoraproject.org/wiki/Dracut)
scripts managing the initramfs boot stage, and with minimal
modifications to the generation of the live iso image. This means that
the process is not ideal but it is more or less guaranteed to work
with future relaeses of the operating systems and related tools.

At the moment the system has been tested only with nbd (network boot
device) for serving the root image.

## Quick documentation about generating a live netroot image

### Prerequisites

For generating the image, at least the following packages have to be
installed:

livecd-tools, spin-kickstarts, fedora-kickstarts, syslinux,
syslinux-nonlinux

For image testing with an emulator, the following packages are recommended:

qemu-system-x86, nbd

### Generating a live image

This is not specific to this package, the Fedora `livecd-creator` is
used in this step:

``` livecd-creator --verbose \
--config=/usr/share/spin-kickstarts/fedora-live-base.ks \
--fslabel=Fedora-LiveCD --cache=/var/cache/live ```

see `man livecd-creator` for the options.

If the specific kickstart files provided by this package are to be
used, since `livecd-creator` lacks an equivalent of `-I` for
compilers, all the kickstart files have to be merged in a single tree,
so, assuming to be in the root directory of the package:

```
 cp -a /usr/share/spin-kickstarts/* spin/kickstarts
 livecd-creator --verbose \
  --config=spin-kickstarts/fedora-live-netroot-hpcnode.ks \
  --fslabel=Fedora-LiveHPCNode --cache=/var/cache/live
 ```

A reminder for the unlucky users living behind an http proxy, the
correct environment variable for proxifying the livecd installation
is:

``` export http_proxy=http://<user>:<passwd>@<host>:<port>/ ```

### Generating a netroot live image

Given the iso image generated at the previous step,
e.g. `Fedora-LiveCD.iso`:

```
livecd-iso-to-pxenetroot Fedora-LiveCD.iso
```

This will install the root image to be served by nbd, together with an
nbd-server configuration file, in the subdirectory `images/` of the
current directory and the bootstrap files to be served by tftp in the
`tftp/` subdirectory.

Files from different iso images can be served in the same directory
tree provided that the iso images have a different label.

### Testing the image within an emulator

An ordinary live image, included the ones suitable for conversion into
netroot, can be tested with qemu (possibly with kvm harware
virtualization) using the following command line:

```
qemu-kvm -m 2048 -vga qxl -cdrom Fedora-LiveCD.iso
```

After conversion to a netroot tree, the setup for testing images
becomes (to be run by root):

```
# start the nbd server in debug mode, no daemon
nbd-server -C images/nbd.conf -d &
# start qemu with the embedded tftp server and pxe nic client
qemu-kvm -m 2048 -net nic -net user,tftp=$PWD,bootfile=/pxelinux.0
```

assuming to start it from the directory where
`livecd-iso-to-pxenetroot` has been launched. This is a great tool and
it can save a lot of time with respect to testing on a real
client-server setup. The `livecd-iso-to-pxenetroot` creates a file
`tftp/pxelinux.cfg/default` containing a pxelinux configuration
suitable for running with the qemu user mode network defaults.

### debugging qemu output

As a general suggestion, if the boot process is unsuccessful, you can
obtain the early output of the kernel and initramfs boot process by
passing the following options to qemu:

```
qemu ... -append '... rd.debug console=ttyS0,38400' -serial file:serial.out
```

`rd.debug` is an kernel command line argument specific to dracut,
which records each shell command executed by dracut, all the output
will be redirected to `serial.out` on the host system; alternatively
you can use the full [dracut debugging
capabilities](https://www.kernel.org/pub/linux/utils/boot/dracut/dracut.html#debugging-dracut)
for obtaining a shell and access to the logs within the emulated guest
system.

### Running the image on real hardware




