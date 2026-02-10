---
title: "One Lesson From Building Microservices"
date: 2026-01-07
layout: layouts/post.njk
language: en 
place: brazil
description: "Why microservices are an organizational decision, not just an architectural one. Key lessons from Sam Newman's Building Microservices and Conway's Law."
tags:
  - microservices
---

Happy 2026!

One of the goals I had last year was reading more, and although I closed the year with a shy number of 3 books read, it is an improvement over the number of 1 book in 2024.

One of the books I read that I learned a lot from was Building Microservices (2nd Edition) by Sam Newman. I could go over the hundreds, if not thousands, of lessons I drew from the book, but there is especially one that I think should stick with everyone building systems right now: **why adopt microservices.**

Microservices are usually said to scale better than other service-oriented architectures or monoliths, but the complexity they bring with them is often greater than the complexity needed to scale monoliths. The choice of microservices is much more an organizational decision than an architectural one. It allows teams to independently deliver value to customers from end to end. It empowers teams to own one or more product value pipelines, increasing product decoupling, team responsibility, and, if done correctly, delivery speed. Observation: To know more about delivery speed I would recommend reading the book, there are great insights on deployment decoupling and delivery health throughout the book.

This reflects how companies like Netflix and Amazon divide their teams into small groups of very capable people with multidisciplinary skills (front-end, back-end, infrastructure, networking, etc.) who are responsible for a very small part of the overall system. This structure decouples teams from one another in a way that empowers them to decide what is best for the customer within their microservice. Of course, this comes with a long list of pros and cons, and if you really want to explore them, I would recommend reading the book.

A great illustration of this is Conway's Law itself:

<div style="display: flex; justify-content: center;">
  <img src="/public/conways-law.jpeg" alt="Conway's Law">
</div>
<p style="text-align: center;"><em>Image credit: “Conway’s Law” — Sketchplanations by Jono Hey</em></p>


When teams are separated into autonomous, domain-focused units, they naturally create independent and uncoupled architectures. This structure makes them owners of a specific domain, which in turn simplifies and accelerates the delivery of value to customers and stakeholders.
