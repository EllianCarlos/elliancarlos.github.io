---
title: "LKD - #6 Notes on our contribution to the Linux Kernel"
date: 2026-04-21
layout: layouts/post.njk
language: en
place: brazil
description:
  "The journey of how we (attempted) to contribute to the linux kernel, the
  changes we made, how we analyzed and evolved them and the state of the
  reviews."
tags:
  - linux
  - kernel development
  - MAC0470
  - MAC5856
  - USP
  - open source software
  - patch
---

As part of my classes on [Open Source Software (OSS)](https://opensource.org/)
my whole class is starting to work on Linux Kernel Development. This post is a
series of my experiences throughout the class related to kernel development.
This post is a follow-up of
[this previous post](/posts/how-the-iio-module-works) and part of
[this series](/posts/tag/MAC5856).

Throughout the whole series of posts we were learning how the kernel works and
understanding how we could make smart changes to the Linux kernel. In this post
we will talk about what we submitted, how and the process until today.

### My group

My group was made by me: [Ellian Carlos](https://elliancarlos.com.br),
[Ricardo Kojo](https://ricardokojo.github.io/) and
[Gabriel Braga](https://gabrielbraga7.github.io), all masters students from the
"Sistemas de software e aplicações de sistemas computacionais" research group.
We didn't talk much before starting working in the submissions, but when we
started finding what to contribute to we talked more and focused most of the
communication via a telegram group.

### Choosing a submission

Since this would be the first submission of a major part of the class, the
professor together with the teaching assistants made a curated list of places to
work, they were:

1. A curated list of 100% duplicated code inside functions in the IIO subsystem
   created by the
   [ArKanjo tool](https://repositorio.usp.br/directbitstream/79e2d2c0-7364-4dd6-a17e-e4081dfef2c7/3285219.pdf);
2. A curated list of 90% duplicated code inside functions in the IIO subsystem
   created by the
   [ArKanjo tool](https://repositorio.usp.br/directbitstream/79e2d2c0-7364-4dd6-a17e-e4081dfef2c7/3285219.pdf);
3. A curated list of 100% duplicated code inside functions in the AMD subsystem
   created by the
   [ArKanjo tool](https://repositorio.usp.br/directbitstream/79e2d2c0-7364-4dd6-a17e-e4081dfef2c7/3285219.pdf);
4. A curated list of 90% duplicated code inside functions in the AMD subsystem
   created by the
   [ArKanjo tool](https://repositorio.usp.br/directbitstream/79e2d2c0-7364-4dd6-a17e-e4081dfef2c7/3285219.pdf);
5. The possibility to change from `mutex_lock(&lock)` and `mutex_unlock(&lock)`
   functions to use the macros `guard(mutex)(&lock)` and
   `scoped_guard(mutex)(&lock)` where we find it would be best;
6. The possibility to change from bitfield operations of hexadecimal numbers to
   use the `FIELD_GET()`, `FIELD_PREP()` and `FIELD_MODIFY()`.
7. Improvements in the IIO area of staging.
8. Update IIO drivers to be Include-What-You-Use complianct (IWYU)
9. Convert logging to drm\_\* functions with drm_device parameter
10. Read and expand the subsystem documentation

All explanations of each is what is available at
[linux kernel patch suggestions](https://flusp.ime.usp.br/courses/linux-kernel-patch-suggestions/).

My group decided to implement:

1. Refactor a 100% duplication of code in the `hw_init` function for the
   [veml6030 and the veml6035](https://github.com/torvalds/linux/blob/master/drivers/iio/light/veml6030.c)
   sensors.
2. Use `guards` and `scoped_guard` instead of mutex locks in the
   [`null_blk` device driver](https://github.com/torvalds/linux/tree/master/drivers/block/null_blk).

### Development, Submission and Current Review

Developing the changes was a collaborative process, I'll separate the narratives
over each change to be more specific to my contributions.

To clarify, we were also sending the patches to review via telegram, applying
them and reviewing in our local machines. We found it better to review it this
way instead of sending an e-mail to ourselves. Also, for all changes here made
we used IME-USP's Kernel Continuous Integration pipeline, available
[here](https://gitlab.freedesktop.org/marcelomspessoto/dsl-linux/-/pipelines).

#### veml6030 and veml6035 duplication in hw_init function

This change was led by Gabriel, where he developed a struct to store each
sensor's configuration and use that as an input parameter to the `hw_init`
function. Initially the changes made by Gabriel were already pretty solid, but
Ricardo reviewed the patch internally and got some insights of where to improve.
The major suggestions were to use pointers instead of values in the init
function, removing unnecessary `const` modifiers and variable naming to follow
iio subsystems kernel conventions (e.g. `cfg` instead of `config` for sensors).
I also reviewed the changes made by Ricardo and pointed out just two minor
stylistics problems, one yield by the `checkpatch` script and another one which
was just a weird double empty line.

These changes allowed us to totally remove the duplication, resulting in a delta
of -16 lines:

```git
 drivers/iio/light/veml6030.c | 98 +++++++++++++++---------------------
 1 file changed, 41 insertions(+), 57 deletions(-)
```

The initial e-mail with the patch is available
[here](https://lore.kernel.org/all/20260420201441.18055-1-gabrielblo@ime.usp.br/).

##### Current Review

This patch was reviewed already by
[David Lechner](https://github.com/sponsors/dlech) which is a maintainer of the
LEGO MINDSTORMS EV3 and related drivers in the Linux Kernel. His feedback was
solid: Not use x to generalize sensor versions since this is not futureproof and
keep just veml6030; Add the different information needed to call `hw_init` in
the chip info instead of creating new structs and drop the wrapper functions;
And move the comments directly to the `hw_init` calls instead of above the
structs. You can check his full answer
[ here ](https://lore.kernel.org/all/26330121-79bd-4273-b8e4-17efa19454eb@baylibre.com/).

Until today (one day later) we still couldn't work on his comments, but we
already talked about it and how to implement.

#### Use `guards` and `scoped_guard` instead of mutex locks in the `null_blk` device driver

This change was started by Ricardo, where he removed the major simple
`mutex_lock(&lock)` and `mutex_unlock(&lock)` by the `guard(mutex)(&lock)` on
the `null_blk/main.c`. I worked extensively on it to add the `scoped_guard`
where there were still `mutex` related functions and also extended it to the
`zoned.c` file that also had many locks not just `main.c`, with these changes we
submitted a v1 with two commits that the 0/2 can be found
[here](https://lore.kernel.org/all/20260418043837.721045-1-ricardo.kojo@ime.usp.br/).

We quickly got a feedback from a reviewer about a simplification route that we
did not take, so we sent a v2 pretty fast after that, the 0/2 of the V2 can be
found
[here](https://lore.kernel.org/all/20260419051009.796491-1-ricardo.kojo@ime.usp.br/).

##### Current Review

We are still awaiting feedback from the v2 from any reviewer.

## Conclusion

The experience has been very different from the usual code revision process in
the industry, but it is a nice breath of fresh air.

The table with the updated statuses of our submissions is:

|                                         Change                                         | status               | last update                       | Stale for |
| :------------------------------------------------------------------------------------: | -------------------- | --------------------------------- | --------- |
|                 veml6030 and veml6035 duplication in hw_init function                  | Working on v2        | v2 PATCH review on 2026-04-20     | 1 day     |
| Use `guards` and `scoped_guard` instead of mutex locks in the `null_blk` device driver | Waiting review on v2 | v2 PATCH submission on 2026-04-19 | 2 days    |
