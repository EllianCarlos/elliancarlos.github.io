---
title: "LKD - #3 Notes on creating and deploying custom module"
date: 2026-03-23
layout: layouts/post.njk
language: en
place: brazil
description:
  "A personal log of creating and deploying a custom Linux kernel module inside
  the IIO subtree, with notes on disk locking issues and NixOS compatibility
  from my Open Source Software class at USP."
tags:
  - linux
  - kernel development
  - MAC0470
  - MAC5856
  - USP
  - open source software
  - kw
  - kernel workflow
---

As part of my classes on [Open Source Software (OSS)](https://opensource.org/)
my whole class is starting to work on Linux Kernel Development. This post is a
series of my experiences throughout the class related to kernel development.
This post is a follow-up of
[this previous post](/posts/howbuilding-custom-arm-linux-kernel-with-kw) and
part of [this series](/posts/tag/MAC5856).

> **Note:** This post is a companion to the
> [Introduction to Linux kernel build configuration and modules](https://flusp.ime.usp.br/kernel/modules-intro/)
> tutorial from FLUSP. I recommend following the tutorial first and then coming
> back here for my notes and troubleshooting tips.

In the last post we talked about kernel modules and built the IIO subtree and
deployed it. This time we are creating our own modules inside the IIO subtree!

## Tutorial

This tutorial is about creating your own module and deploying it to the VM in
order to see changes. This should be the easier one, since there is no more
setup or installation needed. The module is a dummy module that just prints a
hello from the module name. So the tutorial is pretty good to get a grasp of how
modules are set up with things like init and exit and also, on how to use
[dmesg](https://www.man7.org/linux/man-pages/man1/dmesg.1.html) which prints and
controls the kernel ring buffer.

## Problems

In fact, NixOS did not interfere with this one and the only problem I had was
with a disk locking issue for the VM. This meant that when I was mounting the
built modules, I couldn't because the disk was locked, so I had to:

```bash
# 1. Kill any hidden QEMU processes locking the disk
sudo pkill -9 qemu
sudo pkill -9 guestmount

# 2. Clear the stale mount point (Lazy unmount)
sudo umount -l "${VM_MOUNT_POINT}" 2>/dev/null

# 3. Mount the CORRECT partition (you need to check your correct partition in the last tutorials)
sudo guestmount --rw -a "${VM_DIR}/arm64_img.qcow2" -m /dev/sda2 "${VM_MOUNT_POINT}"
```

Aside from this, the module was built, deployed and tested successfully.

## Conclusion

The experience was pretty good and now we can create our own kernel modules, so
if in the future you need to connect with something that does not have Linux
support, just build it :P.

Jokes aside, this was a pretty great experience and by far the most NixOS
friendly tutorial.

## References

\[1\]
[Introduction to Linux kernel build configuration and modules](https://flusp.ime.usp.br/kernel/modules-intro/)
FLUSP, IME-USP

\[2\] Tanenbaum, Andrew S., _Modern Operating Systems_

\[3\]
[Linux Device Drivers Development Course for Beginner](https://www.youtube.com/watch?v=iSiyDHobXHA),
[freeCodeCamp.org](https://www.freecodecamp.org/).

\[4\] [Kernel Workflow](https://kworkflow.org/).
