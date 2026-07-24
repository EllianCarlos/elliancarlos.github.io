---
title:
  "DSL - #8 Cregit - working to contribute to the kernel's token tracking tool"
date: 2026-06-26
layout: layouts/post.njk
language: en
place: brazil
description:
  "Notes on cregit, the token-level blame tool for the Linux kernel, and how my
  group worked to modernize it, contribute fixes, and collaborate with its
  maintainer."
tags:
  - linux
  - cregit
  - MAC0470
  - MAC5856
  - USP
  - open source software
  - oss
---

As part of the second evaluation of my classes on
[Open Source Software (OSS)](https://opensource.org/) my whole class is
contributing to an OSS project which each group can choose. This post is a
follow-up of
[my notes on our first contribution to the Linux Kernel](/posts/notes-on-the-contribution-for-the-linux-kernel)
and part of [this series](/posts/tag/mac5856/).

As my master's will be about corporate contributions to the kernel's source code
and cregit is one of the tools tied to the Linux Foundation's
[CHAOSS](https://chaoss.community/) project for open source health analytics, I
will also use it in this part of the discipline.

## What (exactly) is cregit?

Cregit is a tool that lets you see exactly when and by whom a specific token was
added. It works kind of like a git-blame for tokens. It was created by
[Daniel M. German](https://turingmachine.org/) and colleagues, and the idea is
described in detail in their paper
[cregit: Token-level blame information in git version control repositories](https://doi.org/10.1007/s10664-019-09704-x)
(Empirical Software Engineering, 2019).

Tokens are just any sequence of non-blank chars that is meaningful for a
language. For most of the kernel code, this means any sequence of chars.

### Why not just use `git blame`?

Regular `git blame` works at the granularity of a whole line, and that
granularity breaks down surprisingly often. Reindent a block, wrap a long line,
split a function signature across two lines, or run a formatter over the file,
and `git blame` will happily attribute all of those lines to whoever touched the
whitespace last, even though the actual code was written years earlier by
someone else.

Cregit sidesteps this by attributing each individual token, so a reformat that
moves code around without changing it keeps the original authorship intact. That
distinction is exactly what I care about for my master's: if you want to measure
how much of the kernel a given company actually wrote, line-level blame will
quietly credit the wrong people every time the code is reshaped, while
token-level blame stays honest.

Take a look at how cregit works:

![Cregit attributing each token to the commit and developer that introduced it](/public/cregit-token-blame.png)

In the image above, every token is colored and labeled with the commit and
developer that introduced it (`c-1`/dev A, `c-2`/dev B, `c-3`/dev C). That is
the "git-blame for tokens" idea in practice.

Currently cregit supports `.c`/`.h` files as well as Go, Java and m4.

### How the pipeline works

Under the hood, cregit is less a single program and more a pipeline of steps
glued together. Roughly, it works like this:

1. **Tokenize** each source file using [srcML](https://www.srcml.org/) and ctags
   so that every token ends up on its own line.
2. **Rebuild the history** as a parallel git repository of these tokenized
   blobs, preserving the original commits and authorship.
3. **Blame** the tokenized repository with plain `git blame`. Because every
   token is now its own "line", the blame is effectively per-token.
4. **Map back** the results onto the original source to produce the colored,
   token-level HTML view you saw above.

This is also why cregit was hard to run: each stage depends on external tools
(srcML, ctags) and on the Scala/Perl modules that stitch them together, so if
any one link in the chain is outdated the whole pipeline falls over.

## What contribution would we do?

Mapping our exact contribution was hard, because running cregit itself is a
challenge. The tool had its most recent update back in 2023 and it is written
across several languages, mostly Scala and Perl, with Python and shell scripts
tying the pipeline together, which made getting it to run hard.

So we started by updating the modules we needed to run the tool, with the help
of LLM analysis since we have little to no expertise in Scala and Perl. To give
a concrete sense of what "getting it to run" actually meant, some of the things
that were broken:

- **The build tool was stuck in the past.** sbt `0.13.7` threw a
  `NoClassDefFoundError` on any modern JVM, so nothing compiled until we bumped
  it to `0.13.18`.
- **A dependency had vanished.** cregit pinned `sqlite-jdbc 3.8.0-SNAPSHOT`,
  which no longer exists in the Sonatype repositories, so resolution failed
  outright and we moved it to the stable `3.45.3.0`.
- **Hardcoded and insecure fetches.** The jgit resolver was still pulling over
  plain HTTP, and the Perl scripts used a fixed `#!/usr/bin/perl` shebang that
  breaks on distributions where Perl lives elsewhere (`#!/usr/bin/env perl`
  fixes it).
- **A subtle srcML incompatibility.** `tokenBySha.pl` wrote temp files without
  an extension, and newer srcML (1.1.0) refuses to parse a file it can't
  identify by suffix. It was a one-line change that cost a disproportionate
  amount of debugging.

You can see all of these changes in
[this pull request](https://github.com/cregit-codev/cregit/pull/1).

Another problem we had was that the maintainer of the cregit tool was
unavailable to talk to, so we moved to work on our own fork:
[cregit-codev/cregit](https://github.com/cregit-codev/cregit).

This fork ended up being our group's solution for mapping the issues,
contributing and collaborating.

In the issues of this fork we mapped the work we needed to do and separated it
into phases
([GitHub milestones](https://github.com/cregit-codev/cregit/issues)).

## First contribution

We ended up sending our first changes, fixing cregit to run on modern
environments and updating the modules, as a contribution on the main git repo,
and we actually got a response from the maintainer:
[cregit/cregit#16](https://github.com/cregit/cregit/pull/16).

They suggested we keep development on our fork, since by that point we had
already developed more there than in this first fix, and added that they had
forgotten about their GitHub notification e-mail.

## Other contributions

From there we made a good number of contributions around modernization and
housekeeping of our fork: improving the docs, removing hardcoded paths for
temporary files, and
[making it easy to run through a single script](https://github.com/cregit-codev/cregit/pull/8).
All of our contributions can be seen in the
[list of closed issues](https://github.com/cregit-codev/cregit/issues?q=is%3Aissue%20state%3Aclosed).

We merged a total of 9 PRs into our fork and mapped another 18 issues that are
further improvements to the cregit tool, and we expect there are more to come.

## Collaborating with the maintainer

We had an incredible discussion with Daniel German, the creator and maintainer
of cregit, about the future of the tool; you can find it in
[this discussion thread](https://github.com/cregit-codev/cregit/discussions/39).
In it, performance was highlighted as a key problem for cregit and the next
thing to work on, and a total architectural change to how the tool works was
done pretty quickly by the maintainer with incredible results:
[cregit-codev/cregit#41](https://github.com/cregit-codev/cregit/pull/41).

## Conclusion

Getting cregit to run again turned out to be a contribution in itself: the tool
had been dormant since 2023 and its Scala/Perl pipeline no longer worked on
modern environments. By modernizing the build, removing hardcoded paths and
wrapping everything in a single run script, we made cregit usable again, and in
the process our fork became a small hub of activity, with merged PRs, a backlog
of mapped improvements, and a renewed conversation with the original maintainer
about where the tool should go next (starting with performance).

For my master's on corporate contributions to the kernel, having a working,
hackable cregit is a solid foundation, and I expect to keep contributing to it
as the research moves forward. If you want to see where this is heading, I wrote
up the research proposal it feeds into in
[Measuring Corporate Knowledge Concentration in the Linux Kernel](/posts/measuring-corporate-knowledge-concentration-in-the-linux-kernel).

## References

\[1\] D. M. German, B. Adams, and K. Stewart,
[cregit: Token-level blame information in git version control repositories](https://doi.org/10.1007/s10664-019-09704-x),
Empirical Software Engineering, vol. 24, no. 4, pp. 2725-2763, 2019

\[2\]
[Cregit: token-level blame information for the Linux kernel](https://www.linux.com/topic/linux/cregit-token-level-blame-information-linux-kernel/),
Linux.com

\[3\] [cregit - token-level blame browser](https://cregit.linuxsources.org/),
cregit

\[4\]
[cregit for the Linux kernel (4.19)](https://cregit.origin.kernel.org/code/4.19/),
kernel.org

\[5\] [cregit/cregit - original repository](https://github.com/cregit/cregit),
GitHub

\[6\] [cregit-codev/cregit - our fork](https://github.com/cregit-codev/cregit),
GitHub

\[7\]
[CHAOSS - Community Health Analytics in Open Source Software](https://chaoss.community/),
The Linux Foundation
