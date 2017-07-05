# fedora-live-netroot

This package extends the [livecd-tools](https://github.com/rhinstaller/livecd-tools) package with a script that allows
to easily transform a Fedora live iso image into a bootable system having the root filesystem readonly on a network
device/filesystem, overlaid by a rw live filesystem in memory.

This system is suitable e.g. for creating diskless desktop thin clients of diskless HPC computing nodes.

The image to be generated can be easily customized by editing the kickstart file to be used.
The package includes a small set of ready kickstart files for creating targeted live images, but in principle all the kickstart
files available in Fedora packages for building live CD's can work with fedora-live-netroot with minimal modification.

This differs from the livecd-iso-to-pxeboot in that the root file system image is not loaded in memory but it is kept
untouched on a server and accessed through the network, keeping in memory only the departures from the original image.

At the moment the system has been tested only with nbd (network boot device) for serving the root image.

Some documentation will follow soon.
