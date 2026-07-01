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

- **`iio`**: roughly **62%** of surviving tokens are corporate-authored, spread
  across about **eight effective firms** (HHI ≈ 0.12), led by Analog Devices.
- **`net`**: roughly **59%** corporate and the most distributed case, about
  **thirteen effective firms** (HHI ≈ 0.08), led by Red Hat and Intel across a
  long tail.
- **`amd`**: about **98%** corporate and effectively **one firm** (HHI ≈ 0.97),
  AMD authors essentially all of the surviving tokens.

<div style="display: flex; justify-content: center;">
  <img src="/public/kc-topfirms-over-time.png" alt="Three panels showing the top-five firms' share of surviving code tokens over time in the iio, amd, and net subsystems. AMD stays pinned near 100 percent across the entire history, while iio and net show several firms rising and falling.">
</div>
<p style="text-align: center;"><em>Top firms over time. AMD holds ~100% of amdgpu from the start; iio and net are contested, with firms rising and declining. Single-vendor capture versus a distributed field, in one picture.</em></p>

The AMD result is the one that surprised me the most, so I pushed on it. The
obvious objection is that a GPU driver is full of generated register headers, and
that the concentration is just auto-generated echo. It is not. Excluding the
machine-generated headers, even removing 13% of all of amd's token mass as a
stress test, moves AMD's share by **less than a tenth of a percentage point** and
leaves the concentration metrics unchanged. Single-vendor capture is a property
of the hand-written driver, not of generated content.

Another way to see the gradient is to stack up who owns the surviving code, year
by year. In amd it is a single blue slab of AMD; in iio and net the same view is
a shifting patchwork of firms, and the grey `(Unknown)` band is a visible
reminder of how much of those subsystems we cannot yet attribute to any company.

<div style="display: flex; justify-content: center;">
  <img src="/public/kc-ownership-over-time.png" alt="Four stacked-area charts showing each firm's share of surviving tokens over time for jq, iio, amd, and net. The amd panel is almost entirely one color (AMD); the others are layered across many firms with a large Unknown band in net.">
</div>
<p style="text-align: center;"><em>Surviving-token ownership by firm. amd is one company end to end; jq, iio, and net are shared across many, with a large unattributed band in net.</em></p>

The truck factor tells the same story from another angle. The *company* truck
factor, the number of firms you remove before most files are orphaned, is
**1 for amd**, **7 for iio**, and **17 for net**. One corporate decision at AMD
would strand the majority of the driver; the networking stack would shrug off
sixteen. That single-firm result for amd is pinned tight: across a thousand
bootstrap resamples of the files, it never moves off 1.

<div style="display: flex; justify-content: center;">
  <img src="/public/kc-bootstrap-ci.png" alt="Point estimates with 95 percent bootstrap confidence intervals for firm file truck factor, firm HHI, corporate percentage, and effective firms, for iio, amd, and net. The amd intervals are so narrow they render as dots.">
</div>
<p style="text-align: center;"><em>95% bootstrap confidence intervals (1,000 file resamples). The three subsystems separate cleanly on every metric, and amd's intervals are tight enough to render as dots.</em></p>

There is a fair objection lurking here: a truck factor depends on where you draw
the line for what counts as "knowing" a file, and if the whole picture flips when
you nudge that threshold, the metric is not measuring much. So I swept it, from a
generous 2% of a file's tokens up to a strict 20%. The individual counts move
around, as you would expect, but the thing I actually care about, the ordering of
the three subsystems, never flips: amd stays pinned at a company truck factor of 1
across the entire range, and net stays far above iio. The regimes are a property
of the code, not of a tuning knob.

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
it is a corporate monoculture where nearly everyone commits from `@amd.com`. So
the net and iio **corporate percentages are best read as lower bounds**: when I
actually resolve part of that tail with a few extra signals, the corporate share
climbs substantially (by roughly 11 points in iio and 17 in net), because a lot
of those personal-email commits do come from company engineers.

But I have to be careful about what that does *not* say. My first instinct was
that resolving the tail would also make each subsystem look *more concentrated*,
fewer firms, higher share each. It turns out to be the opposite: the unattributed
tail resolves into *more distinct* companies, not the existing giants, so the
effective number of firms goes **up** (in net, from about 13 to 15) and the
concentration indices edge **down**. The concentrated part of each subsystem is
the *known* head; the hidden tail is comparatively diverse. So the corporate
*share* is a floor, but the *concentration* figure is closer to a ceiling, and I
would rather say that plainly than oversell the result. The amd numbers sidestep
all of this, resting on ~98% coverage and a confidence interval so tight it never
moves.

<div style="display: flex; justify-content: center;">
  <img src="/public/kc-concentration-coverage-over-time.png" alt="Three panels over time for iio, amd, and net: firm HHI, effective number of firms, and organization-attribution coverage percentage. amd sits near an HHI of 1 with ~98 percent coverage; iio and net trend toward dispersion with coverage stuck around 60 percent.">
</div>
<p style="text-align: center;"><em>Concentration and coverage over time. The right panel is the caveat made visible: amd is attributed at ~98%, while iio and net plateau near 60%, so their concentration is measured on a partial view.</em></p>

## What happens when a company leaves

The whole point of measuring knowledge concentration is to say something about
fragility. So I test it directly, with a year-by-year replay of git history that
identifies the files a departing firm dominated *before* it left, and then
measures what actually happened to those files afterward. Rather than eyeball one
or two departures, I enumerated **fifteen** firm-exit events across the three
subsystems and classified every predicted-fragile file as orphaned, absorbed by
another company, or retained.

The aggregate result is striking, and it is the opposite of alarming. Across the
genuine firm disengagements, of the files the metric flagged as at-risk, only
about **5% were actually orphaned**; roughly **93% were absorbed** by other
companies and the rest retained. The truck factor reliably points at the files
that depend on one firm, but the community, most of the time, catches them.

<div style="display: flex; justify-content: center;">
  <img src="/public/kc-withdrawal-outcomes.png" alt="Bar charts of firm-withdrawal outcomes. Across true firm disengagements, about 93 percent of predicted-fragile files are absorbed by other firms, about 5 percent orphaned, and a few retained. A second panel shows acquisitions are almost entirely retained.">
</div>
<p style="text-align: center;"><em>Outcomes of the files the truck factor flagged as at-risk, across the catalogue of firm exits. Genuine disengagements are mostly absorbed; acquisitions are retained under a new domain. Orphaning is the rare case.</em></p>

Two exits are worth calling out because they pull in opposite directions and
explain what decides the outcome:

- **Pengutronix leaving `iio`.** A genuine consultancy disengagement, their share
  dropping from about **7.2% to 0.1%**. Almost all of that work was one engineer,
  Uwe Kleine-König, who authored roughly **85%** of Pengutronix's code in the
  subsystem. Of his dominated files, most were **absorbed** by other companies,
  ten by BayLibre, four by Huawei, one by Intel, and only two genuinely orphaned:
  the header files `bmg160.h` and `ltc2497.h`, which received no further attention
  from any known firm. The community re-engaged around almost everything else.
- **Mellanox in `net`, acquired by NVIDIA.** The Mellanox networking team, led in
  the data by Jiri Pirko, one of netdev's most prolific contributors, simply kept
  working after the acquisition. Their dominated files show NVIDIA as the top
  post-exit contributor: the same people, a new email domain. An acquisition is
  not a withdrawal, and a naive method that missed the `mellanox.com → nvidia.com`
  rename would have scored this as a catastrophic 100% loss instead of business
  as usual.

That is the interesting part. The metric identifies the set of files that are
*strategically dependent* on one firm, which is exactly what a company-level truck
factor of 1 should mean. But whether that risk actually materializes is decided by
the *kind* of exit, not the truck-factor number: consultancy disengagement tends
to get absorbed, acquisition just relabels the same people, and a partial decline
means the firm never really left. This lines up with
[Rigby et al.](https://doi.org/10.1145/2884781.2884851)'s caution that naive
truck-factor estimates exaggerate loss: a firm has many engineers, its departure
is a decision rather than an accident, and knowledge can transfer intact. A truck
factor of 1 is a map of *strategic dependency*, not a forecast of loss.

Following the people rather than the files tells the same story from the other
direction. Some engineers carry a large body of knowledge with them when they
genuinely change employers. Eric Dumazet, one of the most prolific networking
developers, moved to Google carrying well over a hundred thousand surviving tokens
of `net` code; in `iio`, Alexandru Ardelean went from Analog Devices to BayLibre,
the very consultancy that then absorbed much of the orphaned-risk work above. That
is knowledge moving between firms in the most literal way, one career at a time.

But this is also exactly where the measurement has to be careful, because a naive
reading double-counts. The single largest apparent "job switch" in `iio` is
Jean-Baptiste Maneyrol moving from InvenSense to TDK, except that is not a move at
all: TDK *acquired* InvenSense, so it is the same person at the same desk under a
renamed employer. The same is true of the Mellanox-to-NVIDIA and Free-Electrons-to-
Bootlin transitions. If you do not fold these corporate rebrands back together,
you will mistake an acquisition for a talent exodus, which is why every mobility
number I quote is corrected for known renames before anything is counted.

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

## The firm outlives its people

There is an obvious objection to all of this. Kernel developers move around a
lot. People change jobs, hand off drivers, and drift away from subsystems. So if
knowledge is concentrated in a few companies today, surely all that individual
churn erodes it over time? I went in expecting turnover to be the great leveller.
It is not, and the way it fails to be is the most interesting thing I have found
so far.

The clearest way to see it is to put two truck factors side by side over time:
the classic *individual* one (how many people you remove before the code is
orphaned) and the *company* one. Individual turnover is real and relentless: the
person-level truck factor climbs steadily in every subsystem, roughly **2 to 39**
in iio, **3 to 21** in amd, **5 to 37** in net, as more and more distinct people
have to leave before the knowledge is lost. But the company truck factor barely
moves. In amd it is **literally pinned at 1 for twelve straight years** while the
individual figure octuples.

<div style="display: flex; justify-content: center;">
  <img src="/public/kc-turnover-person-vs-firm-tf.png" alt="Two panels. Left: person-level truck factor (solid lines) climbing steeply for iio, amd, and net while the firm-level truck factor (dashed lines) stays flat near the bottom. Right: the person-to-firm truck-factor ratio widening over time, most sharply for amd.">
</div>
<p style="text-align: center;"><em>Individual turnover rises steeply while the firm-level grip holds. People churn beneath a stable corporate layer, and the gap between the two truck factors widens roughly sevenfold in iio and amd.</em></p>

The trend lines on that second panel are fitted with a *Theil-Sen slope*, which
is worth a one-line explanation because it does a lot of quiet work here. Rather
than fit a single line by least squares, which one freak year (a big refactor, a
mass file move) can tilt, it takes the slope between every pair of points and
uses the median of them all. That makes it robust: a single outlier year cannot
drag the estimate around. By that measure the individual truck factor pulls away
from the company one by about **2.4 per year** in iio, **1.9** in amd, and **1.8**
in net, and the gap is statistically clear (the confidence interval excludes zero)
in all three subsystems.

So the people churn, but the *firm* stays the durable unit that holds the
knowledge. And when developers genuinely do switch employers, the effect is the
opposite of what you might guess: it **spreads** knowledge rather than
concentrating it. In net, the most mobile of the three, about a quarter of the
attributable code is held by people who have worked for more than one company,
but reassigning each of them to a single employer actually *lowers* the measured
concentration. Mobility disperses; it does not enclose. (I had to be careful here,
because an acquisition looks exactly like a job change to an email-domain based
method: Mellanox becoming NVIDIA, or InvenSense and TDK, are the same people under
a new name, not real moves. Correcting for those rebrands removed roughly a third
of net's apparent mobility.)

Knowledge also outlives the people who wrote it. Around **12 to 15%** of the
attributable code in iio and net was authored by companies whose developers
stopped committing three or more years ago and never came back, code that persists
in the tree long after its authors left. In `net`, half the living code is more
than a decade old. That is the individual-level echo of the firm-withdrawal story
above: when a contributor leaves, their code is usually absorbed and carried
forward, not orphaned. I want to be honest that this is a *survivorship* view,
since I can only see the tokens that are still alive today, so it describes how
persistent surviving knowledge is rather than a true decay half-life, which would
need a full year-by-year replay I have not run yet. But the direction is
consistent everywhere I look: the firm is what endures.

## Where this goes next

The measurement pipeline exists and the correctness work is done. What is left is
depth and scale: a sensitivity sweep on the authorship threshold, better
affiliation coverage for `net`, and then extending the case set toward subsystems
that test new predictions, a vendor handoff (btrfs), a second single-vendor case
(s390), and an individual-dominated extreme (bcachefs). The turnover results above
also point to their own next steps: turning that survivorship view of durability
into a true year-by-year decay half-life, and testing whether corporate dominance
actively crowds newcomers out rather than merely coexisting with them.

Coming to this from the contributor side first, having actually sent patches and
watched the review process up close, changed how I read these numbers. A truck
factor of 1 is not a doomsday counter. It is a map of where a project has quietly
made a strategic bet on a single company, and open source is full of those bets.
Being able to point at them, and to say which ones the community would absorb and
which ones it would not, feels like a useful thing to be able to do. I will keep
writing here as the research develops.
