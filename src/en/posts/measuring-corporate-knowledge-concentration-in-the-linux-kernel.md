---
title: "Measuring Corporate Knowledge Concentration in the Linux Kernel"
date: 2026-07-01
layout: layouts/post.njk
language: en
place: brazil
description:
  "The research proposal I'm starting at IME-USP: measuring how corporate
  knowledge, not just activity, concentrates in the Linux kernel using
  cregit's token-level authorship, and what happens when a dominant company
  withdraws."
tags:
  - open source software
  - linux
  - kernel development
  - research
  - USP
---

Over the past months I have been writing about
[Linux kernel development](/posts/tag/MAC5856): how
[submissions work](/posts/how-linux-kernel-submissions-work), how the
[IIO subsystem is built](/posts/how-the-iio-module-works), and
[our own attempt at contributing to it](/posts/notes-on-the-contribution-for-the-linux-kernel).
That work left me with a question that did not fit inside a single patch, and it
has grown into the proposal for my master's research at
[IME-USP](https://www.ime.usp.br/), under the supervision of Prof. Paulo
Meirelles.

The short version of the question is this: **open source is no longer mostly a
volunteer effort.** In the Linux kernel, developers paid by companies author the
large majority of commits, and a handful of organizations account for most of
the changes. We know how to measure that corporate *activity* fairly well. What
we do not measure is corporate *knowledge*. And I think the difference between
the two matters a lot.

## Activity is not knowledge

When people say "company X dominates this subsystem", they almost always mean
company X submits the most commits or sends the most emails to the mailing list.
That is a measure of activity. It answers "who is busy here right now?".

Knowledge is a different thing. It answers "who actually understands this code,
because they wrote the parts that are still running?". A single commit can touch
thousands of tokens or a single character. Code written years ago by someone who
has since gone quiet can still be the backbone of a driver. Refactoring can move
attribution around without changing who understands the design. So activity and
knowledge can point in different directions, and my central claim is that it is
**knowledge concentration, not activity, that decides how fragile a project is
when a company walks away.**

The proposal organizes this into four questions:

1. **Measurement.** How concentrated is source-code knowledge at the *company*
   level, and how does a company-level truck factor compare to the classic
   individual one?
2. **Divergence.** Does corporate activity dominance line up with corporate
   knowledge dominance, or do they split apart?
3. **Fragility.** Does measured knowledge concentration actually predict what
   happens when a firm withdraws: files orphaned, absorbed by another company,
   or retained?
4. **Governance.** Does the concentration of maintainer authority track the
   concentration of code knowledge and of mailing-list participation? Do the
   different axes agree?

## Measuring knowledge with cregit

To measure knowledge rather than activity, I build on
[cregit](https://github.com/cregit-codev/cregit), a tool that had been dormant
since 2023, so getting it to run again was a project in itself, which I wrote
about in
[my notes on contributing to cregit](/posts/cregit-open-source-contributions).
Instead of attributing whole commits, cregit works at the level of individual
**tokens** of surviving source code, and traces each token back to the author
who introduced it. That gives a much more honest answer to "who holds the
knowledge of this code as it exists today" than commit-level `git blame` does.

The pipeline then joins three independent sources for each subsystem:

- **cregit** for token-level authorship of the code that survives today.
- A layered **affiliation map** (a curated override, then email domain, then the
  most recent corporate commit email) that resolves each developer, and each
  maintainer, to an employer. This borrows from
  [gitdm](https://github.com/gitdm/gitdm)-style resolution. Whatever stays
  unmapped is a genuine personal-email contributor, which is itself a signal.
- A **mailing-list corpus** for the participation and review side of the story.

From there I aggregate per-developer
[Degree-of-Authorship](https://dl.acm.org/doi/10.1145/2512207) up to the company,
and compute a **company-level truck factor**: greedily remove companies until the
majority of files are orphaned. The idea is lifted straight from Avelino et al.'s
[truck factor work](https://doi.org/10.1109/ICPC.2016.7503718) on individuals,
which the kernel-development literature already knows well, but pointed at firms
instead of people. I summarize concentration with the usual inequality tools (the
Herfindahl index, the effective number of firms, and the Gini coefficient), and I
report affiliation coverage next to every number so the reader knows how much of
the code the claim actually rests on.

Two guards keep the instrument honest. A **provenance gate** strips
machine-generated register and enum headers, so I am measuring hand-written code
and not auto-generated noise. And a **job-mobility pass** collapses each developer
to a single lifetime employer, to check that the results are not an artifact of
where someone happened to work on a given day.

## A spectrum across three subsystems

The three cases were not sampled randomly. Following a case-study logic, each was
picked to sit at a predicted point on the corporate-concentration spectrum, so
the instrument can be shown to read low concentration where ownership really is
spread out, and high where one company dominates:

- **`drivers/iio`** (industrial I/O sensors): consultancy-mixed, predicted to be
  in the middle.
- **`net`** (the networking stack): many companies, the distributed case.
- **`drivers/gpu/drm/amd`** (the AMD GPU driver): single-vendor, the extreme.

The preliminary numbers, from a working notebook with bootstrapped confidence
intervals, land almost exactly where the case selection predicted:

- **`iio`** — roughly **62%** of surviving tokens are corporate-authored, spread
  across about **eight effective firms** (HHI ≈ 0.12), led by Analog Devices.
- **`net`** — roughly **59%** corporate and the most distributed case, about
  **thirteen effective firms** (HHI ≈ 0.08), led by Red Hat and Intel across a
  long tail.
- **`amd`** — about **98%** corporate and effectively **one firm** (HHI ≈ 0.97):
  AMD authors essentially all of the surviving tokens.

The AMD result is the one that surprised me the most, so I pushed on it. The
obvious objection is that a GPU driver is full of generated register headers, and
that the concentration is just auto-generated echo. It is not. Excluding the
machine-generated headers, even removing 13% of all of amd's token mass as a
stress test, moves AMD's share by **less than a tenth of a percentage point** and
leaves the concentration metrics unchanged. Single-vendor capture is a property
of the hand-written driver, not of generated content.

The truck factor tells the same story from another angle. The *company* truck
factor, the number of firms you remove before most files are orphaned, is
**1 for amd**, **7 for iio**, and **17 for net**. One corporate decision at AMD
would strand the majority of the driver; the networking stack would shrug off
sixteen. That single-firm result for amd is pinned tight: across a thousand
bootstrap resamples of the files, it never moves off 1.

I want to be honest about the limits here, the same way the proposal is. Every
developer is mapped to an employer by the **domain of their commit email**, and
that mapping is far from complete: it resolves about **98%** of amd's tokens but
only around **62%** of iio's and **59%** of net's. Two different things defeat it.
Some contributors commit from personal or free-provider addresses like Gmail or
`kernel.org`, which are perfectly valid but say nothing about who pays them; this
is most of iio's gap, roughly a fifth of its tokens. Others commit from company
domains that were simply never added to the affiliation map, so they fall into an
`(Unknown)` bucket; this dominates net, close to a third of its tokens, because it
is a huge, long-lived subsystem with a long tail of small vendors.

The reason amd is almost fully resolved is the same reason it is so concentrated:
it is a corporate monoculture where nearly everyone commits from `@amd.com`. And
crucially, the unresolved tail skews toward individuals, since large companies
enforce corporate email and their people are therefore already captured. So
resolving that tail would most likely **raise** the corporate share and **lower**
the effective-firm count, not the other way around. That is why the net and iio
corporate percentages are best read as **lower bounds**: at least this
concentrated, probably more. The amd numbers, by contrast, rest on very high
coverage and a confidence interval so tight it never moves.

## What happens when a company leaves

The whole point of measuring knowledge concentration is to say something about
fragility. So I test it directly, with a year-by-year replay of git history that
identifies the files a departing firm dominated *before* it left, and then
measures what actually happened to those files afterward. Two cases stand out,
and they pull in opposite directions:

- **Pengutronix leaving `iio`.** This was a genuine consultancy disengagement,
  their share dropping from about **7.2% to 0.1%**. The metric correctly flagged
  the at-risk files, but most of them were **absorbed** by other companies rather
  than orphaned. The community re-engaged.
- **Mellanox in `net`, acquired by NVIDIA.** Here the dominated files were simply
  **retained**. The same engineers kept working, just under a new email domain.
  An acquisition is not a withdrawal.

That nuance is the interesting part. The metric identifies the set of files that
are *strategically dependent* on one firm, which is exactly what a company-level
truck factor of 1 should mean. But whether that risk actually materializes
depends on absorption. This lines up with
[Rigby et al.](https://doi.org/10.1145/2884781.2884851)'s caution that naive
truck-factor estimates exaggerate loss: a firm has many engineers, its departure
is a decision rather than an accident, and knowledge can transfer intact.

## Code, governance, and conversation point the same way

The last piece is a convergent-validity check. If corporate influence is real, it
should show up on more than one axis. So I measure three independently: **code**
ownership, **governance** (which company the maintainers work for), and
**participation** (mailing-list discussion).

They agree, subsystem by subsystem. In amd, governance concentration is total:
all **eight** maintainers work for AMD, a governance HHI of **1.00** that mirrors
the code capture. In `net`, governance is dispersed across about **eleven**
effective employers (HHI ≈ 0.09), Red-Hat-led but spread wide, mirroring its
distributed code. `iio` sits in between, led by Analog Devices on both axes. Code,
governance, and conversation telling the same story in each case is, to me, the
strongest sign that the instrument is measuring something real and not an artifact
of one data source.

## Where this goes next

The measurement pipeline exists and the correctness work is done. What is left is
depth and scale: a sensitivity sweep on the authorship threshold, better
affiliation coverage for `net`, and then extending the case set toward subsystems
that test new predictions, a vendor handoff (btrfs), a second single-vendor case
(s390), and an individual-dominated extreme (bcachefs). Further out, I want to
operationalize *why* firms retain knowledge, measuring how durable a company's
knowledge is after it stops contributing, and whether corporate dominance crowds
out newcomers.

Coming to this from the contributor side first, having actually sent patches and
watched the review process up close, changed how I read these numbers. A truck
factor of 1 is not a doomsday counter. It is a map of where a project has quietly
made a strategic bet on a single company, and open source is full of those bets.
Being able to point at them, and to say which ones the community would absorb and
which ones it would not, feels like a useful thing to be able to do. I will keep
writing here as the research develops.
