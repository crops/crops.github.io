---
layout: post
title:  "[ANNOUNCE] Chameleonsocks 1.0 available"
date:   2016-05-09 08:23:04 -0700
categories: crops chameleonsocks announce
---

Chameleonsocks provides containerized system-wide redsocks-based TCP redirector to generic SOCKS or HTTP proxies. It is particularly useful for people who use Yocto on firewalled networks where the real Internet is accessed through proxies.

The installer script can be downloaded from the upstream repository:

[https://github.com/crops/chameleonsocks](https://github.com/crops/chameleonsocks)

This release includes the following functionality:

```
--install      : Install chameleonsocks
--upgrade      : Upgrade existing installation
--uninstall    : Uninstall chameleonsocks
--install-ui   : Install container management UI
--uninstall-ui : Uninstall container management UI
--start        : Stop chameleonsocks
--stop         : Start chameleonsocks
--version      : Display chameleonsocks version
```

[original announcement](https://lists.yoctoproject.org/pipermail/yocto/2016-May/029979.html)
