---
title: "LKD - #4 Notes on char device drivers"
date: 2026-03-23
layout: layouts/post.njk
language: en
place: brazil
description:
  "A personal log of writing and exercising a char device driver inside the
  Linux kernel, with notes from my Open Source Software class at USP."
tags:
  - linux
  - kernel development
  - MAC0470
  - MAC5856
  - USP
  - open source software
  - kw
  - kernel workflow
  - char devices
---

As part of my classes on [Open Source Software (OSS)](https://opensource.org/)
my whole class is starting to work on Linux Kernel Development. This post is a
series of my experiences throughout the class related to kernel development.
This post is a follow-up of
[this previous post](/posts/intro-linuxkernelbuildconfigandmodules) and part of
[this series](/posts/tag/MAC5856).

> **Note:** This post is a companion to the
> [Introduction to Linux kernel char device drivers](https://flusp.ime.usp.br/kernel/char-drivers-intro/)
> tutorial from FLUSP. I recommend following the tutorial first and then coming
> back here for my notes and troubleshooting tips.

In the last post we created and deployed our own module inside the IIO subtree.
This time we are writing a char device driver!

## Tutorial

This tutorial is about writing an actual char device driver and exercising it
from user-space. The driver, `simple_char`, implements the basic file
operations (`open`, `release`, `read`, `write`) through a `struct
file_operations`, allocates a major number, and registers a `cdev` so that once
the module is loaded it shows up in `/proc/devices`. From there you create a
device node with `mknod` and read/write to it like any other file. So the
tutorial is pretty good to get a grasp of how a `read`/`write` syscall actually
gets routed to a driver, and on how `file_operations`, `cdev`, and major/minor
numbers fit together.

## Problems

Similar to the previous one, NixOS did not really get in the way here. The same
disk-locking issue from mounting the built module into the VM came back, so the
workaround from the previous post was still needed, but nothing
char-drivers-specific caused trouble.

## Conclusion

If in the future you need to connect with something that does not have Linux
support, just build it :P.

Jokes aside, this was another pretty great experience and a natural next step
from the modules tutorial.

## References

\[1\]
[Introduction to Linux kernel char device drivers](https://flusp.ime.usp.br/kernel/char-drivers-intro/)
FLUSP, IME-USP

\[2\] Tanenbaum, Andrew S., _Modern Operating Systems_

\[3\]
[Linux Device Drivers Development Course for Beginner](https://www.youtube.com/watch?v=iSiyDHobXHA),
[freeCodeCamp.org](https://www.freecodecamp.org/).

\[4\] [Kernel Workflow](https://kworkflow.org/).
