# Capital (versión Godot)

Simulador de negocios en 3D: empiezas con un puesto de café y construyes un imperio. Es la versión del juego en
**Godot 4**; la versión original en Python no está en este repositorio.

## Cómo jugar

- **`Jugar Capital.bat`** abre el juego.
- **`Abrir en el editor de Godot.bat`** abre el proyecto en el editor para verlo o modificarlo.
- La primera vez que lo abres, el juego **importa tus partidas de la versión de Python** (`../capital/partida*.json`, si existe).
- Las partidas y los ajustes se guardan en `%APPDATA%\Godot\app_userdata\Capital`.

Controles: WASD caminar · Shift correr · Espacio saltar · Mouse mirar · Rueda o V cámara · E interactuar ·
Tab celular · O oficina · Esc pausa · P pausa rápida · 1/2/3 velocidad · M música · H ayuda · F11 pantalla completa ·
Alt soltar o capturar el mouse. La lista completa está en Pausa → Controles.

## Qué tiene

Todo lo de la versión de Python, con gráficos de Godot:

- **Economía idéntica** (`scripts/sim.gd`, traducción de `sim.py`): productos, sucursales, inventario, precios,
  calidad, marketing, préstamos, bonos, fondo de inversión, impuestos, ciclo económico, 13 decisiones urgentes (soborno,
  influencer, huelga, franquicia, ciberataque, auspicio del club del barrio, proveedor exclusivo...), rivales que compran
  terrenos y te ofrecen comprar tus locales, rangos y modos normal e inversionista.
- **Celular** con las 8 pestañas (Resumen, Negocios, Mercado, Finanzas, Crecimiento, Reportes, Noticias, Conceptos),
  menú, 3 espacios de guardado y ventanas de decisión.
- **Ciudad 3D**: avenida comercial, Distrito Financiero, Parque Central, Barrio Las Lomas y Paseo de la Playa con mar,
  muelle, veleros y faro; cerros con nieve alrededor.
- **Luz de verdad**: sol con sombras largas y luz de cielo débil (las caras a la sombra quedan oscuras), color del sol
  por temperatura (6300 K al mediodía, hora dorada al atardecer), tonemap AgX. De noche: luna con cráteres y fases (una
  vuelta por mes de juego) que cruza el cielo, da la luz y las sombras y se refleja en el mar; estrellas que giran
  alrededor del polo; y el ojo que se acostumbra a la oscuridad para que se vea todo. También:
  niebla que se tiñe al mirar al sol, cielo con nubes y estrellas. De noche los faroles, los locales y los puestos
  tiran luz cálida que se ve desde lejos, y las vitrinas brillan ámbar (`shaders/lamp_light.gdshader`: volúmenes que leen la profundidad, sin el
  límite de luces del modo Compatibilidad).
- **Gráficos Bajo, Medio, Alto y Personalizado** (Pausa → Gráficos). Alto imita el shader Eclipse de Minecraft:
  sombras de 4096 px en 4 tramos hasta 140 m y oclusión ambiental (`shaders/ao.gdshader`, hecha a mano porque el modo
  Compatibilidad no trae SSAO). Personalizado deja elegir sombras, bordes suaves (MSAA), oclusión y resplandor.
- **Vidrios con reflejos**: la torre de la oficina, los rascacielos y las vitrinas reflejan el cielo, las nubes, el sol
  y la silueta de la ciudad según el ángulo, y cada panel quiebra el reflejo distinto; de noche se prenden las oficinas.
- **Agua** con varias capas de olas, turquesa en la orilla y azul profundo mar adentro, espuma en las crestas, reflejo
  del cielo y del sol, y de noche el camino de luz de la luna. Se puede caminar por la arena, meterse al mar hasta la
  cintura y caminar (y saltar) hasta la punta del muelle. La avenida baja en rampa hasta el mar y los autos salen de ahí.
- **Tutorial** la primera vez que empiezas una partida (7 páginas con capturas del juego; meta: que la empresa valga
  $10 millones). Se vuelve a ver en Pausa → Controles. Las imágenes salen de `tests/make_tutorial_images.gd`.
- **Clima que cambia la economía** (`data.gd` → `WEATHER`, `scripts/world/weather.gd`): soleado, parcialmente nublado,
  nublado, lluvia, ola de calor y tormenta, según la estación; cada clima dura unos días y hay pronóstico. Con sol la
  playa se llena; con lluvia hay menos gente en la calle pero el café se dispara y la playa y los puestos al aire libre
  venden menos (las megatiendas techadas no pierden clientes); con calor lo perecedero se echa a perder más rápido; la
  tormenta casi vacía la calle y trae relámpagos. El chip del HUD dice cuánto mueve cada negocio, y el kiosco
  **ELDIARIO** muestra el clima, la temperatura, la hora y el pronóstico.
- **Estrellas de cada local** (1 a 5): suben si atiendes a todos, con buena reputación, calidad y precio justo (y si
  atiendes tú). Con 5 estrellas un local vende 15% más que con 3 y la guía de la ciudad lo recomienda; las estrellas
  saltan sobre el local cuando suben o bajan (quedan anotadas en Noticias).
- **Íconos dibujados** (`scripts/ui/icons.gd`): clima, estrellas, apps de los avisos y decisiones usan íconos hechos
  con formas, no emojis; se dibujan una vez en una textura y después cuestan casi nada.
- **Cada local es distinto por dentro** (`Blueprints._varied`): distribución (repisas en las dos paredes, repisa y
  mesas o vitrinas, repisas al fondo con exhibición adelante; góndolas en distinta cantidad en las megatiendas),
  mostrador corrido, colores, piso con o sin baldosas, plantas, cuadros, reloj, pizarras, maniquíes, carritos y
  lámparas, a veces en espejo. Los locales de la competencia también.
- **Clientes que conversan** (`scripts/world/customer.gd`): con el producto en la mano le preguntan a otro cliente si
  comprarlo, llaman por teléfono, miran el precio, comparan, se sacan fotos o le piden consejo al empleado, y según la
  respuesta lo compran o lo devuelven a la repisa. En la calle los peatones conversan de tus locales, del clima, de
  la competencia o del diario, miran vitrinas, sacan el paraguas o corren con la lluvia, y hay comentarios en la fila.
- **Empleados que trabajan** (`scripts/world/store.gd`): 2 cajas por local y 3 por megatienda; los cajeros solo se
  mueven al cobrar y nunca se sientan. Los demás ordenan repisas, revisan el inventario, barren, trapean, limpian mesas
  y vitrinas, traen cajas de la bodega y reponen, y cada tanto se sientan a descansar en la banca del fondo. Caminan
  por una grilla (AStarGrid2D) que esquiva paredes, repisas, mesones, mesas y a los otros empleados.
- **Tu empresa tiene nombre**: lo eligen al empezar la partida y sale en los letreros, la oficina, el HUD y lo que
  dicen los clientes.
- **Teclas configurables** en Pausa → Controles (clic en la tecla y aprieta la nueva).
- **Vida en la ciudad** (`scripts/world/life.gd`, `dog.gd`): perritos con correa y sueltos en el parque, palomas que
  vuelan si te acercas, gaviotas en la playa y gente sentada en las bancas.
- **Velocidades** x1, x2 y x4 de verdad; el cielo también se acelera.
- **Día y noche de 24 horas** (un minuto real por día): el sol sale tierra adentro y se pone en el mar, y al irse
  sale la luna y hace su recorrido hasta el amanecer.
- **Sol** grande con destello en la cámara al mirarlo (gráficos Medio y Alto, `shaders/lens_flare.gdshader`): se apaga
  si un edificio o un cerro lo tapa.
- Los empleados **atienden**: se giran hacia el cliente con el producto de su negocio en la mano (café, pan,
  hamburguesa, bolsa de ropa o caja de electrónica) y el cliente se va con lo que compró.
- Clientes que hacen fila, pagan o se van enojados; autos que te pueden atropellar; oficina con computadora, pizarra
  de estrategia, pantalla de la bolsa, vitrina de trofeos, asistente y armario con fotos de cada prenda.
- **Interfaz de videojuego**: pantalla de inicio con el logo y el menú sobre la ciudad que gira de fondo y la
  tarjeta de tu última partida; menú de pausa con las opciones a la izquierda y Ajustes, Gráficos, Controles y Guardar
  a la derecha; tarjeta de la empresa arriba a la izquierda (caja, valor, rango con barra, racha y reputación) y
  decisiones urgentes como cartas de evento, con cada opción marcada como segura o con riesgo.
- **Avisos como notificaciones del celular** (arriba a la derecha, con el ícono de cada "app": Banco, Noticias,
  Mensajes de los rivales, Decisiones...), carteles grandes al centro para los hitos (rango, récord, racha), alerta
  fija de quiebra y contador de no leídos junto al celular. Alarma de quiebra, confeti, música que se pone tensa en peligro, menú de pausa con ajustes.

## Rendimiento

El proyecto usa el modo gráfico **Compatibilidad** (OpenGL/ANGLE) para funcionar en tarjetas como la Intel HD 4600.
En esa tarjeta, a 1600 × 900 y con una partida andando: Bajo va a unos 53 FPS, Medio a 45 y Alto a 32. Lo que más cuesta son los bordes suaves
(MSAA, unos 7 ms por cuadro) y la oclusión ambiental (unos 6 ms); por eso MSAA solo está en Personalizado. No hay opción
de resolución: en Compatibilidad dibujar a menos resolución resulta más lento. `tests/shot_graphics.gd` saca capturas
de cada nivel de día, al atardecer y de noche, y mide los FPS.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `scripts/sim.gd`, `data.gd`, `fmt.gd` | Motor económico, datos fijos y formato de números |
| `scripts/admin.gd`, `imui.gd` | Pantallas del celular y menús (interfaz en modo inmediato) |
| `scripts/city.gd` | La ciudad: jugador, cámara, clientes, autos, oficina y reacciones a las noticias |
| `scripts/world/` | Construcción del mundo: edificios, terreno, personas, cielo y luz, materiales |
| `scripts/ui/` | HUD, avisos, ventanas (pausa, armario, trofeos, estrategia) y fotos de prendas |
| `shaders/` | Vidrio reflectante, agua, cielo y desenfoque de los menús |
| `tests/` | Pruebas del motor (`run_tests.tscn`) y escenarios que sacan capturas |

## Pruebas

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/run_tests.tscn
```

Corre las mismas pruebas del motor que la versión de Python (identidad contable, dilemas, guardado, armario, modos,
fondo, estrategias y terrenos de los rivales). Los escenarios con capturas se corren así:
`Godot... --path . -- --scenario=res://tests/shot_game.gd` (las capturas quedan en `tests/shots/`). Las pruebas
guardan en una carpeta aparte (`user://pruebas`), así que no tocan tus partidas.

## Licencia

Copyright © 2026 Brandon Alvis (NoName-IA). **Todos los derechos reservados.**

El código está publicado solo para que se pueda ver. No se permite copiarlo, modificarlo, distribuirlo ni usarlo en
otros proyectos sin permiso escrito del autor. Ver [`LICENSE`](LICENSE).
