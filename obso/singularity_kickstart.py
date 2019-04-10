#!/usr/bin/python

import sys
from imgcreate import kickstart

ks = kickstart.read_kickstart(sys.argv[1])
ksh = ks.handler
sysroot = sys.argv[2]

kickstart.LanguageConfig(sysroot).apply(ksh.lang)
kickstart.KeyboardConfig(sysroot).apply(ksh.keyboard)
kickstart.TimezoneConfig(sysroot).apply(ksh.timezone)
# requires /usr/sbin/authconfig in chroot (not fatal)
kickstart.AuthConfig(sysroot).apply(ksh.authconfig)
# requires /usr/bin/firewall-offline-cmd in chroot (fatal)
#kickstart.FirewallConfig(sysroot).apply(ksh.firewall)
# requires /usr/bin/passwd in chroot (probably fatal) 
kickstart.RootPasswordConfig(sysroot).apply(ksh.rootpw)
kickstart.ServicesConfig(sysroot).apply(ksh.services)
kickstart.XConfig(sysroot).apply(ksh.xconfig)
kickstart.NetworkConfig(sysroot).apply(ksh.network)
#kickstart.RPMMacroConfig(sysroot).apply(self.ks)
#        self._create_bootconfig()
#        self._run_post_scripts()
kickstart.SelinuxConfig(sysroot).apply(ksh.selinux)

