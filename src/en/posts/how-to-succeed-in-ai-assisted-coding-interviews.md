---
title: "How to Succeed in AI Assisted Interviews"
date: 2026-02-09
layout: layouts/post.njk
language: en
place: brazil
locale: en
translationKey: how-to-succeed-in-ai-assisted-coding-interviews
description:
  "What they are, how to nail them, and how to behave in AI-assisted interviews."
---

Over the last year many companies have started evaluating candidates' Agentic AI and GenAI proficiency, for example Meta, Brex, and Canva. These new interviews assess competency in developing software with LLMs and Agentic AI. See: [Meta's AI-enabled coding interview](https://www.metacareers.com/hiring-process), [Brex's AI-assisted coding interview](https://www.youtube.com/watch?v=U3JHxXYBQXQ), and [Canva's AI-assisted coding interviews](https://www.canva.dev/blog/engineering/yes-you-can-use-ai-in-our-interviews/).

These interviews usually take place in either Data Structures and Algorithms coding interviews or interviews where the candidate builds a very simple app, backend, website or fullstack functionality. But they have a different flow; if you're not used to how these specific interviews work, you might get lost even if you're familiar with Agentic AI and DSA interviews.

Another main way these interviews differ from classic ones is that they're usually much more complex. If before you were expected to code a frontend and backend in-memory create-and-read with just the scaffolding project, now you're expected to deliver results very similar to production-ready code for a full application: unit tests, integration testing, frontend UX, backend validation, API contract and protocol definition, database schema creation, and other requirements your interviewer might have. However, AI will be faster than the average developer at delivering all of that; issues arise such as: How do you review every file? How do you guarantee the lack of bugs? How do you debug the application when showing your results if you didn't build it yourself?

In this blog post I'll share some tips on how to handle those interviews (as an interviewer myself) and how to get the best results out of this interview, some for both DSA and "Fullstack" style interviews as well as other general tips at the end.

**TL;DR:** Define a cycle for working with the agent, plan before building, review by risk and priority, be vocal about your choices, and practice with the tool beforehand.

**Contents:** [Create a working cycle of development](#create-a-working-cycle-of-development) · [Time management](#time-management) · [Planning and Reviewing Plans](#planning-and-reviewing-plans) · [Building](#building) · [Reviewing the built code](#reviewing-the-built-code) · [Demo and Debug](#demo-and-debug) · [After the demo: next steps](#after-the-demo-next-steps) · [Tool handling](#tool-handling) · [General tips](#general-tips) · [Your checklist](#your-checklist) · [Conclusion](#conclusion)

## Create a working cycle of development

Every good product is developed inside a [good virtuous cycle](https://medium.com/@cm/maps-to-guide-your-way-virtuous-cycles-eed7f71e165b); this means you need a "playbook" for developing: in certain moments you check for feedback, in certain moments you pause and plan. Amazon calls this [mechanisms](https://docs.aws.amazon.com/wellarchitected/latest/operational-readiness-reviews/building-mechanisms.html), and it is used throughout the company; a well-known example is Jeff Bezos's Amazon flywheel.

<div style="display: flex; justify-content: center;">
  <img src="/public/amazon-flywheel.webp" alt="Diagram of Amazon’s flywheel: a virtuous cycle where lower prices lead to more customers, more sellers, and better selection, which in turn drives more traffic and enables lower costs again.">
</div>

If you think about it, most of your day-to-day activities in your job fit this "cycle" definition. You might have multiple cycles you need to remember and perform, but if you do a good job, you have at least one (virtuous) of them.

How to build and what is needed for a virtuous cycle is something I don't have the authority to tell you, because ultimately it needs to work for you. But one thing I can say for sure: you are pushed to always make these cycles faster. The faster you iterate, the faster you get feedback, the faster you correct yourself and the faster you deliver value to your customer.

AI-Agentic development benefits a lot from being inside one virtuous cycle. Creating structure in the madness of vibe coding allows you to know what to do, how to check, when to check and what to check so you're not generating AI-spaghetti code with critical journey bugs and safety issues.

For AI-assisted interviews, this is a must: **you must define a cycle for how to work with the agent**. Many interviews are less than 1 hour of coding, so you need these cycles to be granular and allow you to iterate over them.

### Time management

A simple rule of thumb: aim for about 20% planning, 40% build, 20% review, and 20% demo and debug, and adjust if the interviewer gives time cues or constraints. Leave a small buffer for demo and debug, since that's where things often go wrong.

I would advise you to use the following cycle:

<div style="display: flex; justify-content: center;">
  <img src="/public/ai-assisted-interview-cycle.png" alt="Diagram of the recommended AI-assisted interview cycle: Plan, Build, Review, then Demo and Debug, with a loop back to Plan for the next iteration.">
</div>

We'll go over each step, but for now, focus on having a cycle that works. Validate it, retry, and find something that works for you, and for the tool you're using. You usually get to know what you are going to be using during the interview, so give it a try, and try and retry until you're comfortable with it.

## Planning and Reviewing Plans

Always start with a plan. If you're using a tool that does not have plan mode, that's fine, just be explicit that you want a plan first, not code yet. For example: *"First output a step-by-step plan for this feature; do not write or change any code until I approve the plan."* If your tool has plan mode, like Cursor and Kiro, take advantage of it.

Review your plan in full and carefully; think critically about the domain of the application or change you're asked to implement. Is it a financial app? Then maybe transactionality and security are strong requirements. Does it handle personal information? Then a requirement should be to keep your app compliant with that. If you think you should not add these requirements in this step, be vocal about it: make sure that's a deliberate decision, not something you're leaving behind.

Having a clear, good plan is the key for the AI agent to do its job correctly. If your change will be big, you should spend more time on this planning than on the build process, at least during supervision.

### On the size of the plans

If you can make plans that are very small, you should go for it. Probably, in your day-to-day small plans and small changes are the way to go with Agentic AI. Small changes can be reviewed faster, iterated faster and you will get faster feedback.

That being said, most companies will try to assess your "delivery" skills in this interview, so if you deliver less than expected in scope, you might fail this step due to lack of complexity. My advice is to start small, but in the most critical part of the software. Be vocal about what you think should be the starting point and ask if the interviewer agrees with it. Aim for the smallest plan that still demonstrates meaningful scope.

## Building

This is the easiest part of the interview: the AI will generate the code as specified in the plan you developed. This might take a while, so a useful trick is to use this time to be vocal about what you're expecting from this build, what you will be reviewing, and why you made certain decisions (that you haven't explained before) in the plan. For example: *"I'm starting with the API contract and persistence layer so we have a clear boundary; I'll review the payment flow first since that's critical."* If the agent drifts from the plan, refer it back by name or by step (e.g. "Stick to step 2 of the plan; we're not adding that yet").

## Reviewing the built code

This is a tricky part of the cycle because: **You can't review everything**: or rather, you should, but you won't open PRs to production without knowing what you added, right? The sheer amount of changes AI agents generate makes it impossible to review everything. Talk about this with your interviewer and be clear on what you will review.

Again, this is a part where you need to think critically. Is security a strong concern for this change? Then check all infrastructure-relevant files. Are there key business rules? *(this question is almost always yes)* Then review the files where the business rules are implemented.

Make sure to keep being vocal about what you're looking for in these reviews and why you're reviewing only the files you chose. For example: *"I'm focusing on the API and the payment handler because they're on the critical path; I'll skim the UI components next."*

One tip: look at the automated tests (if you planned to have them), because they will show you what you're actually safeguarding.

## Demo and Debug

The demo is the part where you show the user journey you were building. If this interview is a DSA-related one, this is where you run a "dry run".

This is where everything goes wrong. The AI never gets it on the first time and to be honest, neither do I. So you will need to demonstrate your debugging skills. Of course the agentic AI can also help you with that, but you want to be able to: form hypotheses, validate them, and predict fixes.

To be honest I don't know exactly how to handle this with AIs, but I think you need to do exactly that, tell the AI the hypotheses you have and ask it to add code to help you validate them; once validated, generate a fix.

If the bug is very simple, and you can know this by the message, like "invalid long time, panic!" or something that is usually a simple bug, asking it to fix that and clearly stating the steps to reproduce the bug will often be enough for the agent to fix it.

After the fix, you go back to the app demo until everything is running smoothly.

## After the demo: next steps

If everything goes smoothly after the demo you should have two things: ideas on how to build and improve upon what has been developed, and ideas on how to expand the "product" or algorithm you're creating. Both should come from you, and you should ask your interviewer if they think it's a good idea to proceed. This shows not only high agency but also a drive for development.

## Tool handling

If you know the tool you're going to use in the interview (which you probably do), it's worth taking time to learn how to customize it for development. Before the interview, try: (1) adding one or two rules or safeguards so the agent stays on task, (2) one recurring command or shortcut (e.g. run tests, format), and (3) one go-to prompt you know works for the kind of task you'll get. Basics include: how to set up safeguards or rules, how to create hooks to run the same tasks consistently, a few prompt ideas that you know work for specific things, knowing the keybindings if you're a keyboard person, and knowing how to interact with the tool in general.

## General tips

- **Don't use raw ChatGPT or conversational AIs** for coding: use an IDE-integrated, code-aware tool (Cursor, Claude Code, Copilot, etc.) so you can generate, navigate, and edit in context.
- **Think critically at every step**: about domain (e.g. finance → transactionality), what to review and why, and where "good enough" is for the time box.
- **Narrate your choices** so the interviewer sees your reasoning (plan, build, review, and when you refer the agent back to the plan).
- **Practice with the real tool** before the interview (rules, one shortcut, one prompt that works).
- **Bring a working stack** if allowed (DB + API + basic UI) so you spend time on the task, not setup, or get comfortable with their playground in advance.

## Your checklist

**Before the interview**

- [ ] AI-assisted tool ready (Cursor, Claude Code, Copilot, etc.),not raw ChatGPT
- [ ] One or two rules/safeguards, one shortcut, and one go-to prompt practiced
- [ ] Working stack or their playground set up and familiar (DB + API + basic UI if applicable)
- [ ] A cycle in mind: plan → build → review → demo/debug; rough time split (30% / 20% / 20% / 30%)

**During the interview**

- [ ] Start with a plan; get AI to output the plan first, no code yet (or use plan mode)
- [ ] Review the plan for domain (e.g. security, compliance); be vocal about trade-offs
- [ ] While building: narrate what you expect and what you’ll review; if the agent drifts, refer it back to the plan
- [ ] Review by risk (critical path, business rules, infra); say what you’re checking and why
- [ ] Demo; when things break, form hypotheses, validate, fix; state steps to reproduce for simple bugs
- [ ] After a clean demo: suggest next steps and ask the interviewer if it's a good idea to proceed

## Conclusion

AI-assisted interviews reward what real work does: a clear process, deliberate choices, and good use of the tool. Define your cycle, plan before you build, review by risk, and narrate your reasoning. With a bit of practice, you'll be in good shape for any 60-minute MVP-style round. Good luck.