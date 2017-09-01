Summary: Create Fedora images with read-only root fs on network and writable overlay in memory
Name: live-netroot
Version: 0.1
#Release: 1
Release: %{dist_free_release}%{?dist}
License: GPL
Group: System Environment/Base
URL: https://github.com/ARPA-SIMC/fedora-live-netroot
Packager: Davide Cesari <dcesari@arpae.it>
Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires: dracut dracut-network

%description
Live-netroot provides dracut scripts and user callable scripts
allowing to create and boot a Fedora or other similar distribution
(CentOS) system image from network in a way similar to the live image,
i.e. mounting a read-only base image on network and overlaying it with
a writable filesystem in memory.

%prep

%setup -q -n %{name}-%{version}

%build

%configure --libdir=%{_prefix}/lib
#make

%install
%if 0%{?fedora} || 0%{?rhel}
echo rm -rf -- %{buildroot}
%endif
make DESTDIR=%{buildroot} libdir=%{_prefix}/lib install

%clean
[ "%{buildroot}" != / ] && rm -rf "%{buildroot}"

%files
%defattr(-, root, root)
%{_prefix}/lib/dracut/modules.d/*
%{_bindir}/*
