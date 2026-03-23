---
title:
  "LKD - #2 Notes on how to build and boot a custom Linux kernel for ARM using
  KW"
date: 2026-03-22
layout: layouts/post.njk
language: en
place: brazil
description:
  "A personal log of setting up a Linux kernel development environment using
  QEMU and libvirt, with notes on NixOS-specific hurdles and workarounds from my
  Open Source Software class at USP."
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

> **Note:** This post is a companion to the
> [Building and booting a custom Linux kernel for ARM using kw](https://flusp.ime.usp.br/kernel/build-linux-for-arm-kw/)
> tutorial from FLUSP. I recommend following the tutorial first and then coming
> back here for my notes and troubleshooting tips.

As part of my classes on [Open Source Software (OSS)](https://opensource.org/)
my whole class is starting to work on Linux Kernel Development. This post is a
series of my experiences throughout the class related to kernel development.
This post is a follow-up of [this previous post](/posts/how-to-setup-lkd-notes)
and part of [this series](/posts/tag/MAC5856).

## Kernel types

Linux kernel is a
[Monolithic kernel](https://en.wikipedia.org/wiki/Monolithic_kernel), this means
it is just a very huge binary all together in the kernel space. This also means
that the whole code of the kernel is together in the
[same place](https://github.com/torvalds/linux). So even highly scoped changes,
like updating a device driver for an NVIDIA graphics cards issue would take you
to build the whole kernel. This also means, that, the code for everything in the
kernel is in the same repository and, theoretically, any part of the kernel code
could access any other part of it, of course, keeping the limitations of
languages in mind. The opposite of a monolithic kernel is a
[Microkernel](https://en.wikipedia.org/wiki/Microkernel), which has a limited
"core" which runs in kernel space while other functionalities like specific
device drivers, file systems, etc are kept in the user space.

Monolithic kernels are usually faster than Microkernels since everything runs in
kernel mode and requires less
[context switching](https://en.wikipedia.org/wiki/Context_switch) between kernel
and user modes. This comes with a price of:

1. Security: a problem in any part of the kernel becomes a level 0 threat, while
   in a Microkernel a compromised device driver would be isolated in user space.
2. Modularity: adding a new driver or module will require the addition of a
   whole new organization into the kernel source code.
3. Stability: a kernel panic can happen inside a device driver's code, while in
   the microkernel this panic would be limited to the device driver in the user
   space.

Nonetheless, Linux development is so well done, that it outperforms most of
other popular microkernels, check
[this source](https://lwn.net/Articles/220255/) from 2007 comparing Linux and
the Microkernel MINIX 3.

### Linux Kernel modules

The way the linux kernel attempts to reduce the impact of these problems is
through the use of
[modules](https://linux-kernel-labs.github.io/refs/heads/master/labs/kernel_modules.html),
kernel modules are "isolated" kernel pieces of code which have one
responsibility, for example the IIO module is responsible for supporting all
[industrial input/output](https://www.kernel.org/doc/html/latest/driver-api/iio/intro.html)
devices that in some sense perform either analog-to-digital conversion or
digital-to-analog conversion, some (which is not all) examples are:
accelerometers, gyroscopes, temperature sensors, etc. Most devices that are
supported by this module are the ones that communicate via
[SPI](https://www.kernel.org/doc/html/latest/driver-api/spi.html) or
[I2C](https://www.kernel.org/doc/html/latest/driver-api/i2c.html).

Throughout this and the other tutorials we follow we will be using the IIO
module as an example.

## Kernel workflow - KW

Kernel development has a very unique workflow, first it is based on C and widely
uses the [Makefile](https://www.gnu.org/software/make/manual/make.html) to build
the binaries and second every test requires a deploy. If you have a working
build of some module already deployed to a sandboxed linux distro, then any new
changes can be summarized with:

1. Implement the code changes
2. Compile the kernel modules updates
3. Deploy the changes to the sandboxed Linux
4. Test and validate the module changes

Which seems simple, but working with a codebase as large and complex as the
Linux kernel will require some steps which will be repeated for every single
code change. The [Kernel Workflow (kw)](https://kworkflow.org/) tools try to
bring ease to this development process by setting up usual kernel commands
directly connected to your environment so that changes and deployment are
easier.

Of course, kw is not a required tool, since Makefiles on the linux kernel are
matured and are enough for development, but when we follow the tutorial, we will
use kw.

## The build and deploy process

Similar to the previous post, on this one we will follow the tutorial linked
above from FLUSP.

The tutorial is pretty straightforward and I had only one issue related to the
installation of KW in NixOS.

### Installing KW in NixOS

When installing kw from the tutorial my computer was missing a LOT of modules,
so I created a [devenv.nix](https://devenv.sh/) to enable all packages to be
installed and handled declaratively, how it ended up looking:

```nix
# devenv.nix
{ pkgs, lib, config, ... }:
let
  # Nix's aarch64 cross-compiler uses aarch64-unknown-linux-gnu-* prefix, but the
  # Linux kernel and kw expect aarch64-linux-gnu-*. This wrapper provides the
  # expected names via symlinks.
  aarch64CrossCc = pkgs.pkgsCross.aarch64-multiplatform.stdenv.cc;
  aarch64LinuxGnuWrapper = pkgs.runCommand "aarch64-linux-gnu-wrapper" {
    buildInputs = [ pkgs.coreutils ];
  } ''
    mkdir -p $out/bin
    for f in ${aarch64CrossCc}/bin/aarch64-unknown-linux-gnu-*; do
      base=$(basename "$f")
      # aarch64-unknown-linux-gnu-X -> aarch64-linux-gnu-X
      link=$(echo "$base" | sed 's/aarch64-unknown-linux-gnu-/aarch64-linux-gnu-/')
      ln -sf "$f" "$out/bin/$link"
    done
  '';
in
{
  languages.python = {
    enable = true;
    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  languages.c.enable = true;

  languages.texlive.enable = true;

  packages = [
    pkgs.python3
    pkgs.git
    pkgs.gnutar
    pkgs.pulseaudio
    pkgs.libpulseaudio
    pkgs.dunst
    pkgs.imagemagick
    pkgs.graphviz
    pkgs.librsvg
    pkgs.bzip2
    pkgs.lzip
    pkgs.lzop
    pkgs.zstd
    pkgs.xz
    pkgs.bc
    pkgs.perlPackages.AuthenSASL
    pkgs.perlPackages.IOSocketSSL
    pkgs.sqlite
    pkgs.pv
    pkgs.rsync
    pkgs.ccache
    pkgs.dialog
    pkgs.curl
    pkgs.perlPackages.XMLXPath
    pkgs.coreutils
    pkgs.b4
    pkgs.procps
    pkgs.pciutils
    pkgs.libnotify
    pkgs.sphinx
    pkgs.python3Packages.setuptools
    # Kernel build dependencies
    pkgs.gnumake
    pkgs.gcc
    pkgs.flex
    pkgs.bison
    pkgs.openssl
    pkgs.ncurses
    pkgs.pahole
    pkgs.xmlto
    pkgs.kmod
    pkgs.elfutils
    pkgs.cpio
    pkgs.perl
    pkgs.gawk
    pkgs.autoconf
    pkgs.pkg-config
    pkgs.llvm
    pkgs.clang
    pkgs.lld
    pkgs.ctags

    # aarch64 cross-compiler with aarch64-linux-gnu-* names (kernel build expects these)
    aarch64LinuxGnuWrapper
    aarch64CrossCc
  ];

  scripts.docs-build.exec = "uv run sphinx-build docs build/docs";
  scripts.docs-build.description = "Build documentation using sphinx-build";

  enterShell = ''
    # Replace /path/to/kworkflow with where you cloned the kworkflow repo
    alias kw='/path/to/kworkflow/kw'
  '';
}
```

Of course, I also needed to add support for nixpkgs-python, since I don't have a
channel for python packages natively setup.

```yaml
# devenv.yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  nixpkgs-python:
    url: github:cachix/nixpkgs-python
    inputs:
      nixpkgs:
        follows: nixpkgs
```

If you look into the `devenv.nix` file, I needed to add a specific cross
compiling support, again this is needed because NixOS does not handle package
linking perfectly and binaries for arm64 (which is not my native computer
architecture) are needed. To get to this point took me a lot of looking URLs
online and talking with the Cursor agent to know how to allow this to happen.

Also, if you think I have way too many tools on the devenv.nix for KW you're
correct, I added all of them even the ones like sphinx and texlive, which are
only needed for specific documentation purposes.

To always use this devenv's shell in my terminal I managed
[direnv](https://direnv.net):

```bash
# .envrc
#!/usr/bin/env bash

export DIRENV_WARN_TIMEOUT=20s

eval "$(devenv direnvrc)"

# `use devenv` supports the same options as the `devenv shell` command.
#
# To silence all output, use `--quiet`.
#
# Example usage: use devenv --quiet --impure --option services.postgres.enable:bool true
use devenv
```

Together with a [zsh hook](https://direnv.net/docs/hook.html) for direnv I was
always using this devenv definition. After this I only did (replace
`$PLACE_WHERE_KW_IS` with the path to your kworkflow clone):

```bash
alias kw='$PLACE_WHERE_KW_IS/kw'
```

So that I could use the kw commands for building (ps.: we could add this to the
devenv.nix).

Another thing I needed was to add the parameters directly to kw's build.config
(replace `$PLACE_WHERE_KW_IS` with your kworkflow path):

```bash
# $PLACE_WHERE_KW_IS/etc/build.config
arch=arm64
kernel_img_name=Image
cross_compile=aarch64-unknown-linux-gnu-
```

This worked on my machine with the Nix wrapper above; your setup may differ if
you're using a different cross-compiler or distro.

### Issues not related to the tutorial (Network)

I haven't discovered why yet, but on the day I followed this tutorial my VM
network lost all connection and was not showing in the `virsh` network, so
`kw ssh` was not working.

Before resorting to static IP, you can try checking if the network is active
with `virsh net-list` and `virsh net-info default`. If the default network isn't
running, `virsh net-start default` might bring it back. If that doesn't work,
what I needed to do was to deactivate the
[DHCP](https://wiki.debian.org/DHCP_Client) and statically assign an IP to the
VM:

```bash
sudo mkdir -p "${VM_MOUNT_POINT}/etc/systemd/network"
printf '[Match]
Name=enp1s0

[Network]
Address=192.168.122.2/24
Gateway=192.168.122.1
'
  | sudo tee "${VM_MOUNT_POINT}/etc/systemd/network/10-enp1s0.network"
```

This meant that the machine will be in the IP: `192.168.122.2` which in my
network is a free address. This will easily allow you to:
`ssh root@192.168.122.2`, in case this IP is different than the first one you
used in the tutorial, just run this again:

```
kw remote --add arm64 root@<VM-IP-address> --set-default
```

### The rest of the tutorial

The rest of the tutorial was smooth, all configuration steps done by KW were
pretty handy instead of manually editing the .config.

In case you're curious the local name I chose for the kernel obviously was
(`$IIO` is the path to your kernel tree):

```bash
# $IIO/.config
#
# General setup
#
CONFIG_INIT_ENV_ARG_LIMIT=32
# CONFIG_COMPILE_TEST is not set
# CONFIG_WERROR is not set
CONFIG_LOCALVERSION="_HELLO_WORLD"
# CONFIG_LOCALVERSION_AUTO is not set
```

I don't believe in curses, but better safe than sorry.

## Conclusion

The experience was pretty good and we've made exceptional progress in kernel
development with this tutorial; being able to build and deploy our own changes
to a kernel is exciting. For our next steps we will make changes directly into
the IIO tree and create our own modules.

## References

\[1\]
[Building and booting a custom Linux kernel for ARM using kw](https://flusp.ime.usp.br/kernel/build-linux-for-arm-kw/),
FLUSP, IME-USP

\[2\] Tanenbaum, Andrew S., _Modern Operating Systems_

\[3\]
[Linux Device Drivers Development Course for Beginner](https://www.youtube.com/watch?v=iSiyDHobXHA),
[freeCodeCamp.org](https://www.freecodecamp.org/).

\[4\] [Kernel Workflow](https://kworkflow.org/).
