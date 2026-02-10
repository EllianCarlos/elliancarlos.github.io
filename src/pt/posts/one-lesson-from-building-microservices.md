---
title: "Uma Lição de Construindo Microsserviços"
date: 2026-01-07
layout: layouts/post.njk
language: pt
place: brasil
locale: pt
translationKey: one-lesson-from-building-microservices
description: "Por que microsserviços são uma decisão organizacional, não apenas arquitetural. Lições importantes do livro Building Microservices de Sam Newman e a Lei de Conway."
tags:
  - microservices
---

Feliz 2026!

Um dos objetivos que tinha no ano passado era ler mais, e embora tenha fechado o ano com um número tímido de 3 livros lidos, é uma melhoria em relação ao número de 1 livro em 2024.

Um dos livros que li e do qual aprendi muito foi Building Microservices (2ª Edição) de Sam Newman. Eu poderia falar sobre as centenas, se não milhares, de lições que tirei do livro, mas há especialmente uma que acho que deveria ficar com todos que estão construindo sistemas agora: **por que adotar microsserviços.**

Microsserviços são geralmente ditos para escalar melhor do que outras arquiteturas orientadas a serviços ou monólitos, mas a complexidade que eles trazem consigo é frequentemente maior do que a complexidade necessária para escalar monólitos. A escolha de microsserviços é muito mais uma decisão organizacional do que arquitetônica. Permite que as equipes entreguem valor aos clientes de forma independente, de ponta a ponta. Ela capacita as equipes a possuir um ou mais pipelines de valor do produto, aumentando o desacoplamento do produto, a responsabilidade da equipe e, se feito corretamente, a velocidade de entrega. Observação: Para saber mais sobre velocidade de entrega, eu recomendaria ler o livro, há ótimas ideias sobre desacoplamento de implantação e saúde de entrega ao longo do livro.

Isso reflete como empresas como Netflix e Amazon dividem suas equipes em pequenos grupos de pessoas muito capazes com habilidades multidisciplinares (front-end, back-end, infraestrutura, redes, etc.) que são responsáveis por uma parte muito pequena do sistema geral. Essa estrutura desacopla as equipes umas das outras de uma forma que as capacita a decidir o que é melhor para o cliente dentro de seu microsserviço. Claro, isso vem com uma longa lista de prós e contras, e se você realmente quiser explorá-los, eu recomendaria ler o livro.

Uma grande ilustração disso é a própria Lei de Conway:

<div style="display: flex; justify-content: center;">
  <img src="/public/conways-law.jpeg" alt="Lei de Conway">
</div>
<p style="text-align: center;"><em>Crédito da imagem: "Conway's Law" — Sketchplanations por Jono Hey</em></p>


Quando as equipes são separadas em unidades autônomas e focadas em domínio, elas naturalmente criam arquiteturas independentes e desacopladas. Essa estrutura as torna proprietárias de um domínio específico, o que por sua vez simplifica e acelera a entrega de valor aos clientes e stakeholders.
