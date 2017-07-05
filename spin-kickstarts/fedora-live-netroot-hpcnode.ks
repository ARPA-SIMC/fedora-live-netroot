%include fedora-live-netroot.ks

services --enabled=rdma --disabled=auditd,mdmonitor,firewalld,dbus,atd

%packages
# admin, debug
ipmitool
perf
ganglia
ganglia-gmond
ganglia-gmetad
# hpc applications and libraries
libgfortran
openmpi
hdf5-openmpi
netcdf-openmpi
netcdf-fortran-openmpi
hdf5
netcdf
netcdf-fortran
grib_api
# scheduling of hpc applications
torque
torque-libs
# slurm not provided in official repos
# for infiniband
rdma
libcxgb3
libcxgb4
libmlx4
libipathverbs
libmthca
libnes
ibutils
libibverbs
libibverbs-utils
infiniband-diags
perftest
# for glusterfs
glusterfs
glusterfs-server
glusterfs-rdma
glusterfs-cli
glusterfs-fuse
%end

%post

# fix to ssh server required for remotely launching parallel processes
# that make use of Infiniband (analog of ulimit -l unlimited)
mkdir -p /etc/systemd/system/sshd.service.d
cat  <<EOF > /etc/systemd/system/sshd.service.d/memlock.conf
[Service]
LimitMEMLOCK=infinity
EOF
%end
