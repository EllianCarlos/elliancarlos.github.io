---
title: "LKD - #6 Notes on how the iio subsystems work"
date: 2026-04-17
layout: layouts/post.njk
language: en
place: brazil
description:
  "A summarized view of the IIO subsystem, a subsystem inside the Linux kernel
  with the purpose of providing support for devices that in some sense perform
  either analog-to-digital conversion (ADC) or digital-to-analog conversion
  (DAC) or both."
tags:
  - linux
  - kernel development
  - MAC0470
  - MAC5856
  - USP
  - open source software
  - iio
---

As part of my classes on [Open Source Software (OSS)](https://opensource.org/)
my whole class is starting to work on Linux Kernel Development. This post is a
series of my experiences throughout the class related to kernel development.
This post is a follow-up of
[this previous post](/posts/how-to-send-email-using-git-send-email-via-gmail)
and part of [this series](/posts/tag/MAC5856).

> **Note:** This post is a companion to the
> [The iio_simple_dummy Anatomy](https://flusp.ime.usp.br/iio/iio-dummy-anatomy/)
> and
> [IIO Dummy module Experiment One: Play with iio_dummy](https://flusp.ime.usp.br/iio/experiment-one-iio-dummy/)
> tutorials from FLUSP. I recommend following the tutorials first and then
> coming back here for my notes and troubleshooting tips.

In the last post we discussed how to submit linux patches. In today's post we
will investigate and dive deep into the IIO subsystem.

## What is the IIO subsystem in linux kernel?

> The main purpose of the Industrial I/O subsystem (IIO) is to provide support
> for devices that in some sense perform either analog-to-digital conversion
> (ADC) or digital-to-analog conversion (DAC) or both. The aim is to fill the
> gap between the somewhat similar hwmon and input subsystems. Hwmon is directed
> at low sample rate sensors used to monitor and control the system itself, like
> fan speed control or temperature measurement. Input is, as its name suggests,
> focused on human interaction input devices (keyboard, mouse, touchscreen). In
> some cases there is considerable overlap between these and IIO.
>
> Devices that fall into this category include:
>
> - analog to digital converters (ADCs)
> - accelerometers
> - capacitance to digital converters (CDCs)
> - digital to analog converters (DACs)
> - gyroscopes
> - inertial measurement units (IMUs)
> - color and light sensors
> - magnetometers
> - pressure sensors
> - proximity sensors
> - temperature sensors
>
> Usually these sensors are connected via SPI or I2C. A common use case of the
> sensors devices is to have combined functionality (e.g. light plus proximity
> sensor).

This excerpt was extracted from
[Industrial I/O Introduction](https://docs.kernel.org/driver-api/iio/intro.html).

That's what the IIO subsystem is for, supporting real hardware related to
Industrial Input Output devices. This ranges from Raspberry Pi all the way to
Linux servers which depend on these services.

### On the IIO dummy Anatomy

Following the
[The iio_simple_dummy Anatomy](https://flusp.ime.usp.br/iio/iio-dummy-anatomy/)
tutorial, we were able to get a pretty good overview of how the IIO subsystem
works by dissecting a toy driver instead of jumping into real hardware.

We were able to see which channels are set up with `iio_chan_spec` and all its
fields (`.type`, `.indexed`, `.differential`, the info masks that control what
attributes each channel exposes), and then how the `read_raw` and `write_raw`
functions use the mask and channel type as a sort of routing mechanism to figure
out which piece of state to access.

We also dove deep into how the `probe` function works, that's the function
responsible for allocating memory, initializing device fields and register the
device. The highlight for me was the use of `kzalloc`, the kernel variant of
allocating a memory and setting it to zero, it is similar to calloc, but it
handles under the hood
[some kernel magic](https://github.com/torvalds/linux/blob/master/include/linux/slab.h)
(which contains many hard-to-navigate macros). It was also interesting to see
how the error handling works, with "gotos" to the specific error handling scope
and not some fancy throw catch manipulation which is used by more modern
languages.

### On the creation of a Driver

In the
[IIO Dummy module Experiment One: Play with iio_dummy](https://flusp.ime.usp.br/iio/experiment-one-iio-dummy/)
we created a dummy driver enabled by the `nconfig` menu and then we compiled,
loaded and unloaded the module (`iio_dummy`). We were able to also create a new
device and add it to the devices running in IIO. This tutorial was pretty smooth
to navigate having completed the previous ones.

The addition of the channels for a 3-axis compass was very similar to the code
in the IIO Dummy channels, but it was weird because, the way the code is setup
does not seem like the usual "user space" I thought it was made to.

### Conclusion

Both posts were very useful for understanding the IIO structure and during the
contribution this deep dive will be very useful for understanding what we are
actually changing and to not break anything
([mainly user space](https://lkml.org/lkml/2012/12/23/75)).

## References

\[1\]
[The iio_simple_dummy Anatomy](https://flusp.ime.usp.br/iio/iio-dummy-anatomy/),
FLUSP, IME-USP

\[2\]
[IIO Dummy module Experiment One: Play with iio_dummy](https://flusp.ime.usp.br/iio/experiment-one-iio-dummy/),
FLUSP, IME-USP

\[3\] [IIO Introduction](https://docs.kernel.org/driver-api/iio/intro.html), The
kernel development community
