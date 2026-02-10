---
title: "Cómo Tener Éxito en Entrevistas de Programación Asistidas por IA"
date: 2026-02-09
layout: layouts/post.njk
language: es
place: brasil
locale: es
translationKey: how-to-succeed-in-ai-assisted-coding-interviews
description: "Qué son, cómo salir bien en ellas y cómo comportarse en entrevistas asistidas por IA."
tags:
  - ai
  - career
---

Durante el último año muchas empresas han empezado a evaluar la competencia de los candidatos en IA agéntica y GenAI, por ejemplo Meta, Brex y Canva. Estas nuevas entrevistas evalúan la competencia en el desarrollo de software con LLMs e IA agéntica. Ver: [entrevista de programación habilitada por IA de Meta](https://www.metacareers.com/hiring-process), [entrevista de programación asistida por IA de Brex](https://www.youtube.com/watch?v=U3JHxXYBQXQ) y [entrevistas de programación asistidas por IA de Canva](https://www.canva.dev/blog/engineering/yes-you-can-use-ai-in-our-interviews/).

Estas entrevistas suelen ser de Estructuras de Datos y Algoritmos o entrevistas en las que el candidato construye una app, backend, sitio o funcionalidad fullstack muy simple. Pero el flujo es distinto; si no estás acostumbrado a cómo funcionan estas entrevistas concretas, puedes perderte aunque conozcas la IA agéntica y las entrevistas de DSA.

Otra diferencia importante respecto a las entrevistas clásicas es que suelen ser mucho más complejas. Si antes se esperaba que codearas un frontend y backend en memoria (crear y leer) con solo el proyecto base, ahora se espera que entregues algo muy cercano a código listo para producción para una aplicación completa: pruebas unitarias, pruebas de integración, UX del frontend, validación en el backend, contrato de API y definición de protocolo, creación del esquema de base de datos y otros requisitos que pueda indicar el entrevistador. Sin embargo, la IA será más rápida que la media de los desarrolladores para entregar todo eso; surgen preguntas como: ¿Cómo revisar cada archivo? ¿Cómo garantizar la ausencia de bugs? ¿Cómo depurar la aplicación al mostrar tus resultados si no la construiste tú solo?

En esta entrada comparto consejos sobre cómo afrontar estas entrevistas (como entrevistador yo mismo) y cómo sacar el mejor resultado de ellas —algunos para entrevistas de DSA y de estilo “Fullstack”, además de otros consejos generales al final.

**En resumen:** Define un ciclo de trabajo con el agente, planifica antes de construir, revisa por riesgo y prioridad, sé explícito sobre tus decisiones y practica con la herramienta antes.

**Contenido:** [Crear un ciclo de desarrollo](#crear-un-ciclo-de-desarrollo) · [Gestión del tiempo](#gestión-del-tiempo) · [Planificación y revisión de planes](#planificación-y-revisión-de-planes) · [Construcción](#construcción) · [Revisión del código construido](#revisión-del-código-construido) · [Demo y depuración](#demo-y-depuración) · [Después de la demo: próximos pasos](#después-de-la-demo-próximos-pasos) · [Uso de la herramienta](#uso-de-la-herramienta) · [Consejos generales](#consejos-generales) · [Tu checklist](#tu-checklist) · [Conclusión](#conclusión)

## Crear un ciclo de desarrollo

Todo buen producto se desarrolla dentro de un [buen ciclo virtuoso](https://medium.com/@cm/maps-to-guide-your-way-virtuous-cycles-eed7f71e165b); eso significa que necesitas un “playbook” para desarrollar: en ciertos momentos compruebas feedback, en ciertos momentos pausas y planificas. Amazon lo llama [mecanismos](https://docs.aws.amazon.com/wellarchitected/latest/operational-readiness-reviews/building-mechanisms.html), y se usa en toda la empresa; un ejemplo conocido es el flywheel de Amazon de Jeff Bezos.

<div style="display: flex; justify-content: center;">
  <img src="/public/amazon-flywheel.webp" alt="Diagrama del flywheel de Amazon: un ciclo virtuoso donde precios más bajos llevan a más clientes, más vendedores y mejor selección, lo que a su vez genera más tráfico y permite costes más bajos de nuevo.">
</div>

Si lo piensas, la mayor parte de tu actividad diaria en el trabajo encaja en esta definición de “ciclo”. Puedes tener varios ciclos que recordar y ejecutar, pero si lo haces bien, tienes al menos uno (virtuoso).

Cómo construir y qué hace falta para un ciclo virtuoso no es algo que yo tenga autoridad para decirte, porque al final tiene que funcionar para ti. Pero una cosa es segura: te presionan para que esos ciclos sean cada vez más rápidos. Cuanto más rápido iteres, más rápido obtienes feedback, más rápido te corriges y más rápido entregas valor al cliente.

El desarrollo con IA agéntica se beneficia mucho de estar dentro de un ciclo virtuoso. Crear estructura en el caos del “vibe coding” te permite saber qué hacer, cómo comprobar, cuándo comprobar y qué comprobar para no generar código espagueti de IA con bugs críticos de recorrido y problemas de seguridad.

Para entrevistas asistidas por IA, esto es obligatorio: **tienes que definir un ciclo de cómo trabajar con el agente**. Muchas entrevistas tienen menos de 1 hora de programación, así que esos ciclos tienen que ser granulares y permitirte iterar sobre ellos.

### Gestión del tiempo

Una regla sencilla: intenta unos 20% planificación, 40% construcción, 20% revisión y 20% demo y depuración, y ajusta si el entrevistador da pistas o restricciones de tiempo. Deja un margen para demo y depuración, porque es ahí donde suelen romperse las cosas.

Te recomiendo usar el siguiente ciclo:

<div style="display: flex; justify-content: center;">
  <img src="/public/ai-assisted-interview-cycle.png" alt="Diagrama del ciclo recomendado para entrevista asistida por IA: Planificar, Construir, Revisar, luego Demo y Depurar, con vuelta a Planificar para la siguiente iteración.">
</div>

Repasaremos cada paso, pero por ahora céntrate en tener un ciclo que funcione. Valídalo, repite y encuentra algo que funcione para ti y para la herramienta que usas. Normalmente sabes qué vas a usar durante la entrevista, así que pruébalo, prueba y repite hasta sentirte cómodo.

## Planificación y revisión de planes

Empieza siempre con un plan. Si la herramienta no tiene modo de planificación, no pasa nada —sé explícito en pedir un plan primero, todavía sin código. Por ejemplo: *“Primero muestra un plan paso a paso para esta funcionalidad; no escribas ni cambies código hasta que apruebe el plan.”* Si tu herramienta tiene modo de plan (como Cursor y Kiro), aprovéchalo.

Revisa el plan por completo y con cuidado; piensa de forma crítica sobre el dominio de la aplicación o del cambio que te piden implementar. ¿Es una app financiera? Entonces quizá la transaccionalidad y la seguridad sean requisitos fuertes. ¿Maneja datos personales? Entonces un requisito debe ser mantener la app en conformidad. Si crees que no debes incluir esos requisitos en este paso, dilo: asegúrate de que sea una decisión deliberada, no algo que estás dejando atrás.

Tener un plan claro y bueno es la clave para que el agente de IA haga bien su trabajo. Si el cambio va a ser grande, debes dedicar más tiempo a esta planificación que a la construcción, al menos durante la supervisión.

### Sobre el tamaño de los planes

Si puedes hacer planes muy pequeños, hazlo. Probablemente en tu día a día, planes y cambios pequeños son el camino con IA agéntica. Los cambios pequeños se revisan más rápido, se iteran más rápido y obtienes feedback más rápido.

Dicho esto, la mayoría de las empresas intentará evaluar tus habilidades de “entrega” en esta entrevista, así que si entregas menos de lo esperado en alcance, puedes suspender por falta de complejidad. Mi consejo es empezar pequeño, pero en la parte más crítica del software. Sé explícito sobre qué crees que debe ser el punto de partida y pregunta si el entrevistador está de acuerdo. Busca el plan más pequeño que siga demostrando un alcance relevante.

## Construcción

Esta es la parte más fácil de la entrevista: la IA generará el código según el plan que definiste. Puede tardar un rato, así que un truco útil es usar ese tiempo para ser explícito sobre qué esperas de esta construcción, qué vas a revisar y por qué tomaste ciertas decisiones (que aún no habías explicado) en el plan. Por ejemplo: *“Empiezo por el contrato de API y la capa de persistencia para tener una frontera clara; revisaré primero el flujo de pago porque es crítico.”* Si el agente se desvía del plan, redirígelo por nombre o por paso (ej.: “Sigue el paso 2 del plan; aún no estamos añadiendo eso”).

## Revisión del código construido

Esta es una parte delicada del ciclo porque: **no puedes revisarlo todo** —o mejor, deberías, pero no abrirías PRs a producción sin saber qué has añadido, ¿verdad? El volumen de cambios que generan los agentes de IA hace imposible revisarlo todo. Habla de esto con el entrevistador y deja claro qué vas a revisar.

De nuevo, es una parte en la que tienes que pensar de forma crítica. ¿La seguridad es una preocupación fuerte en este cambio? Entonces revisa todos los archivos relevantes de infraestructura. ¿Hay reglas de negocio clave? *(esta pregunta casi siempre es sí)* Entonces revisa los archivos donde están implementadas las reglas de negocio.

Sigue siendo explícito sobre qué buscas en estas revisiones y por qué solo revisas los archivos que elegiste. Por ejemplo: *“Me centro en la API y el manejador de pago porque están en el camino crítico; luego echaré un vistazo a los componentes de UI.”*

Un consejo: mira las pruebas automatizadas (si planeaste tenerlas), porque te muestran qué estás protegiendo realmente.

## Demo y depuración

La demo es la parte donde muestras el recorrido de usuario que estabas construyendo. Si la entrevista es de DSA, aquí es donde haces un “dry run”.

Es aquí donde todo suele romperse. La IA nunca lo acierta a la primera y, siendo sincero, yo tampoco. Así que tendrás que demostrar tus habilidades de depuración. Claro que la IA agéntica también puede ayudarte, pero quieres poder: formar hipótesis, validarlas y predecir correcciones.

Sinceramente no sé exactamente cómo manejar esto con IAs, pero creo que hay que hacer exactamente eso: decirle a la IA las hipótesis que tienes y pedirle que añada código para ayudarte a validarlas; una vez validadas, generar la corrección.

Si el bug es muy simple, y lo ves por el mensaje, como “invalid long time, panic!” o algo que suele ser un bug simple, pedir que lo corrija y dejar claros los pasos para reproducir el bug suele bastar para que el agente lo arregle.

Después de la corrección, vuelve a la demo de la app hasta que todo funcione bien.

## Después de la demo: próximos pasos

Si todo va bien tras la demo, deberías tener dos cosas: ideas de cómo construir y mejorar lo desarrollado, e ideas de cómo ampliar el “producto” o algoritmo que estás creando. Ambas deben salir de ti, y debes preguntar al entrevistador si les parece buena idea seguir. Eso muestra no solo alta agencia sino también ganas de evolucionar.

## Uso de la herramienta

Si sabes qué herramienta vas a usar en la entrevista (que probablemente sí), merece la pena dedicar tiempo a aprender a personalizarla para el desarrollo. Antes de la entrevista, prueba: (1) añadir una o dos reglas o salvaguardas para que el agente mantenga el foco, (2) un comando o atajo recurrente (ej.: ejecutar pruebas, formatear) y (3) un prompt de referencia que sepas que funciona para el tipo de tarea que te van a dar. Lo básico incluye: cómo configurar salvaguardas o reglas, cómo crear hooks para ejecutar las mismas tareas de forma consistente, algunas ideas de prompts que sepas que funcionan para cosas concretas, conocer los atajos si te gusta el teclado, y saber cómo interactuar con la herramienta en general.

## Consejos generales

- **No uses ChatGPT puro ni IAs conversacionales** para programar: usa una herramienta integrada en el IDE y consciente del código (Cursor, Claude Code, Copilot, etc.) para generar, navegar y editar en contexto.
- **Piensa de forma crítica en cada paso**: sobre el dominio (ej.: finanzas → transaccionalidad), qué revisar y por qué, y dónde está “suficientemente bien” para el tiempo disponible.
- **Narra tus decisiones** para que el entrevistador vea tu razonamiento (plan, construcción, revisión y cuando rediriges al agente al plan).
- **Practica con la herramienta real** antes de la entrevista (reglas, un atajo, un prompt que funciona).
- **Lleva una stack funcionando** si lo permiten (DB + API + UI básica) para dedicar tiempo a la tarea, no al setup, o familiarízate con su playground por adelantado.

## Tu checklist

**Antes de la entrevista**

- [ ] Herramienta asistida por IA lista (Cursor, Claude Code, Copilot, etc.), no ChatGPT puro
- [ ] Una o dos reglas/salvaguardas, un atajo y un prompt de referencia practicados
- [ ] Stack funcionando o su playground configurado y familiar (DB + API + UI básica si aplica)
- [ ] Un ciclo en mente: planificar → construir → revisar → demo/depurar; reparto aproximado de tiempo (30% / 20% / 20% / 30%)

**Durante la entrevista**

- [ ] Empieza con un plan; pide a la IA que muestre el plan primero, todavía sin código (o usa el modo plan)
- [ ] Revisa el plan por dominio (ej.: seguridad, conformidad); sé explícito sobre trade-offs
- [ ] Mientras construyes: narra qué esperas y qué vas a revisar; si el agente se desvía, redirígelo al plan
- [ ] Revisa por riesgo (camino crítico, reglas de negocio, infra); di qué estás comprobando y por qué
- [ ] Demo; cuando algo falle, forma hipótesis, valida, corrige; indica los pasos para reproducir en bugs simples
- [ ] Tras una demo limpia: sugiere próximos pasos y pregunta al entrevistador si es buena idea continuar

## Conclusión

Las entrevistas asistidas por IA premian lo que exige el trabajo real: proceso claro, decisiones deliberadas y buen uso de la herramienta. Define tu ciclo, planifica antes de construir, revisa por riesgo y narra tu razonamiento. Con un poco de práctica estarás bien preparado para cualquier ronda de MVP de 60 minutos. Buena suerte.
