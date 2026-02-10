---
title: "Una Lección de Construyendo Microservicios"
date: 2026-01-07
layout: layouts/post.njk
language: es
place: brasil
locale: es
translationKey: one-lesson-from-building-microservices
description: "Por qué los microservicios son una decisión organizacional, no solo arquitectónica. Lecciones clave del libro Building Microservices de Sam Newman y la Ley de Conway."
tags:
  - microservices
---

¡Feliz 2026!

Uno de los objetivos que tenía el año pasado era leer más, y aunque cerré el año con un número tímido de 3 libros leídos, es una mejora sobre el número de 1 libro en 2024.

Uno de los libros que leí y del que aprendí mucho fue Building Microservices (2ª Edición) de Sam Newman. Podría hablar sobre los cientos, si no miles, de lecciones que saqué del libro, pero hay especialmente una que creo que debería quedarse con todos los que están construyendo sistemas ahora mismo: **por qué adoptar microservicios.**

Los microservicios generalmente se dice que escalan mejor que otras arquitecturas orientadas a servicios o monolitos, pero la complejidad que traen consigo a menudo es mayor que la complejidad necesaria para escalar monolitos. La elección de microservicios es mucho más una decisión organizacional que arquitectónica. Permite a los equipos entregar valor a los clientes de forma independiente de extremo a extremo. Empodera a los equipos para que sean dueños de una o más tuberías de valor del producto, aumentando el desacoplamiento del producto, la responsabilidad del equipo y, si se hace correctamente, la velocidad de entrega. Observación: Para saber más sobre la velocidad de entrega, recomendaría leer el libro, hay grandes ideas sobre el desacoplamiento de implementación y la salud de entrega a lo largo del libro.

Esto refleja cómo empresas como Netflix y Amazon dividen sus equipos en pequeños grupos de personas muy capaces con habilidades multidisciplinarias (front-end, back-end, infraestructura, redes, etc.) que son responsables de una parte muy pequeña del sistema general. Esta estructura desacopla a los equipos entre sí de una manera que les permite decidir qué es mejor para el cliente dentro de su microservicio. Por supuesto, esto viene con una larga lista de pros y contras, y si realmente quieres explorarlos, recomendaría leer el libro.

Una gran ilustración de esto es la propia Ley de Conway:

<div style="display: flex; justify-content: center;">
  <img src="/public/conways-law.jpeg" alt="Ley de Conway">
</div>
<p style="text-align: center;"><em>Crédito de la imagen: "Conway's Law" — Sketchplanations por Jono Hey</em></p>


Cuando los equipos se separan en unidades autónomas y enfocadas en el dominio, naturalmente crean arquitecturas independientes y desacopladas. Esta estructura los convierte en propietarios de un dominio específico, lo que a su vez simplifica y acelera la entrega de valor a clientes y stakeholders.
