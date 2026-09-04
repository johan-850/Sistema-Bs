# Product Backlog — Sistema Bs

**Versión 1.0** · Sistema de Administración y Punto de Venta web para escritorio, operado con pistola lectora de códigos de barras.

| | |
|---|---|
| **Épicas** | 10 (EPB-01 → EPB-10) |
| **Historias de usuario** | 37 (USB-001 → USB-037) |
| **Story Points** | 206 |
| **Sprints estimados** | 8 (2 semanas cada uno) |
| **Roles** | AdminMaster (AM), Cajero (CAJ) |

---

## Punto de partida

Sistema Bs no se construye desde cero: reutiliza el código Flutter de **Sistema AS** (Abarrotería Pro), donde ya están implementadas y probadas contra Supabase real diez épicas de lógica de negocio — autenticación, apertura y cierre de caja, CRUD de productos, inventario, punto de venta, gastos, historial, reportes y estadísticas.

Lo que este backlog cubre es lo que **no** se hereda:

| Se hereda de AS | Hay que construirlo aquí |
|---|---|
| Entidades, repositorios y casos de uso | Base de datos independiente y completa |
| Funciones RPC de Supabase (`confirm_sale`, `close_register`, ...) | Adaptación de toda la UI a escritorio |
| Políticas RLS y modelo de roles | Operación por teclado y pistola HID |
| Providers de Riverpod y router | Impresión de recibos |
| Design system y tema oscuro | Despliegue web |

Por eso el total (206 SP) es aproximadamente la mitad de los 397 SP de AS.

---

## Diferencias de fondo con Sistema AS

Estas cuatro decisiones explican por qué el backlog no es una copia del de AS:

1. **Base de datos independiente.** Sistema Bs es otro negocio. No comparte ni un dato con AS. Esto obliga a que las migraciones levanten el esquema completo desde cero, cosa que hoy en AS **no ocurre** (ver EPB-01).
2. **Escritorio, no móvil.** El código heredado no tiene una sola línea de lógica responsive: cero usos de `LayoutBuilder`, `kIsWeb`, `Platform.is` o `MediaQuery.size`. Toda la navegación es móvil (menú lateral desplegable, barra inferior, hojas emergentes).
3. **Pistola lectora en vez de cámara.** La pistola se comporta como un teclado (HID): escribe el código y envía un separador. No hay Bluetooth que emparejar desde la app — de eso se encarga el sistema operativo.
4. **La caja es un computador.** Eso trae impresora térmica de recibos y operación por teclado, dos cosas que en la versión móvil no existían.

---

## EPB-01 — Fundación: esquema completo e independiente

**Levantar un backend Supabase propio que se reconstruya entero desde migraciones versionadas.**

Al preparar este proyecto se detectó que las migraciones de Sistema AS **no reconstruyen la base de datos**. Solo 11 tablas tienen `CREATE TABLE`; faltan `products` y `cash_registers` —las dos centrales del sistema— y el tipo enum `register_status`. En AS nunca se notó porque esas tablas se crearon a mano desde el Dashboard y la base ya existía. Con un proyecto nuevo eso es bloqueante: sin ese DDL no arranca nada. Esta épica va primero por eso.

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-001 | Como equipo de desarrollo quiero una migración base que cree las tablas faltantes para poder levantar el sistema en un proyecto Supabase limpio. | Migración `000_base_schema.sql` con `CREATE TYPE register_status`, `CREATE TABLE products` y `CREATE TABLE cash_registers`, reconstruidas a partir de las entidades Dart y de las referencias FK existentes. Incluye índices, constraints y RLS. Corre antes de `001`. | Alta | 8 | — |
| USB-002 | Como equipo de desarrollo quiero verificar la cadena completa de migraciones en un proyecto vacío para garantizar que el esquema es reproducible. | Las migraciones `000` → `009` se ejecutan en orden sobre un proyecto Supabase nuevo sin un solo error. Se documenta el orden y los pasos manuales. Queda una checklist de verificación por tabla, función y bucket. | Alta | 5 | — |
| USB-003 | Como AdminMaster quiero que el primer usuario administrador se cree con un procedimiento documentado y no a mano en el Dashboard. | Script o función que da de alta el AdminMaster inicial con su rol correcto en `profiles` y en el `app_metadata` de Auth. Documentado en el README. Idempotente. | Alta | 3 | AM |
| USB-004 | Como equipo de desarrollo quiero un archivo de ejemplo de variables de entorno sin credenciales reales para configurar el proyecto sin filtrar secretos. | `.env.example` solo con placeholders. `.env` ignorado por git. El README explica de dónde sale cada valor en el Dashboard de Supabase. | Alta | 2 | — |
| USB-005 | Como equipo de desarrollo quiero desplegar las Edge Functions en el proyecto nuevo para que la gestión de cajeros y el reporte semanal funcionen. | `create-cashier`, `toggle-cashier-status` y `send-weekly-report` desplegadas y respondiendo. Secretos configurados. El reporte semanal queda documentado como opcional (necesita proveedor de correo). | Media | 3 | — |

**Total: 21 SP**

---

## EPB-02 — Base del proyecto web

**Traer el código de AS y dejarlo compilando y corriendo en navegador contra el backend nuevo.**

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-006 | Como equipo de desarrollo quiero el código de Sistema AS en este repositorio para partir de una base funcional. | Código Dart, migraciones y Edge Functions copiados. Sin artefactos de build, sin `.env` real, sin historial de git de AS. Compila con `flutter pub get`. | Alta | 3 | — |
| USB-007 | Como equipo de desarrollo quiero eliminar las dependencias móviles que no se usan para reducir el peso y los conflictos del build web. | Se eliminan de `pubspec.yaml`: `flutter_blue_plus`, `image_cropper`, `flutter_secure_storage`, `open_filex`, `vibration`, `audioplayers`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `drift`, `sqlite3_flutter_libs`, `path_provider`. Ninguna se importa hoy en `lib/`. `flutter analyze` sigue limpio. | Alta | 3 | — |
| USB-008 | Como usuario quiero que la aplicación no se comporte como una app de celular para poder usarla cómodamente en un monitor. | Se elimina el bloqueo de orientación vertical de `main.dart`. Se revisan los `SafeArea` heredados. La ventana se puede redimensionar sin romper el layout. | Alta | 2 | AM/CAJ |
| USB-009 | Como equipo de desarrollo quiero la aplicación corriendo en navegador contra el Supabase nuevo para validar que el backend quedó bien. | `flutter run -d chrome` levanta la app. Login funcional contra el proyecto nuevo. Se puede crear un producto y verlo persistido. Sin errores en la consola del navegador. | Alta | 5 | — |

**Total: 13 SP**

---

## EPB-03 — Shell responsive de escritorio

**Reemplazar la navegación móvil por una de escritorio y hacer que el layout use el ancho disponible.**

El código heredado navega con menú lateral desplegable en el panel de administración y con barra inferior en el punto de venta. Además usa hojas emergentes desde abajo en 14 lugares distintos, un patrón que en escritorio se siente fuera de lugar.

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-010 | Como equipo de desarrollo quiero un sistema de puntos de quiebre para que cada pantalla sepa adaptarse al ancho disponible. | Puntos de quiebre definidos en un solo lugar (compacto, medio, expandido). Utilidad reutilizable para consultarlos. Documentado en el README. Ninguna pantalla vuelve a leer el ancho a mano. | Alta | 8 | — |
| USB-011 | Como usuario quiero un menú lateral siempre visible para navegar sin abrir y cerrar paneles. | Barra de navegación lateral permanente en ancho de escritorio, con las mismas secciones del menú actual y respetando los permisos por rol. Se colapsa a menú desplegable en ventanas angostas. Marca la sección activa. | Alta | 8 | AM/CAJ |
| USB-012 | Como usuario quiero que los formularios se abran como ventanas centradas y no como paneles desde abajo. | Las 14 hojas emergentes se muestran como diálogo centrado en escritorio, conservando el comportamiento actual en ventanas angostas. Se cierran con Escape. El foco entra al primer campo. | Alta | 8 | AM/CAJ |
| USB-013 | Como usuario quiero una interfaz con densidad de escritorio para ver más información sin desplazarme. | Espaciados, tipografía y alturas de fila ajustados para mouse. Estados de hover en filas y botones. Cursor correcto en elementos interactivos. Las cuadrículas de tarjetas usan el ancho en lugar de fijar dos columnas. | Media | 5 | AM/CAJ |

**Total: 29 SP**

---

## EPB-04 — POS de escritorio

**La épica más pesada: convertir un punto de venta pensado para el pulgar en uno pensado para teclado y monitor.**

En la versión móvil el carrito vive en otra pantalla y se llega por la barra inferior. En una caja de escritorio el cajero necesita ver el carrito y el catálogo al mismo tiempo, y no debería tocar el mouse durante una venta normal.

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-014 | Como Cajero quiero ver el catálogo y el carrito al mismo tiempo para no cambiar de pantalla en cada producto. | Layout de dos columnas: búsqueda y catálogo a la izquierda, carrito con total a la derecha, siempre visible. El carrito se actualiza al instante. En ventanas angostas vuelve al comportamiento de una columna. | Alta | 13 | CAJ |
| USB-015 | Como Cajero quiero operar la venta con el teclado para atender más rápido y sin soltar la pistola. | Atajos para cobrar, cancelar la venta, enfocar la búsqueda y cambiar cantidad del último ítem. Ayuda de atajos visible en pantalla. Ningún atajo se dispara mientras se escribe en un campo de texto. | Alta | 8 | CAJ |
| USB-016 | Como Cajero quiero que el campo de búsqueda esté siempre listo para recibir lo que escribo o escaneo. | El foco vuelve al campo de búsqueda después de cada acción (agregar producto, cerrar diálogo, cobrar). Indicador visual de que el campo está activo. Nunca se pierde el foco silenciosamente. | Alta | 5 | CAJ |
| USB-017 | Como Cajero quiero cobrar sin perder de vista la venta para confirmar montos antes de aceptar. | El cobro se hace en un diálogo sobre la pantalla de venta, con el detalle del carrito visible. Cálculo de cambio en vivo. Se confirma con Enter y se cancela con Escape. | Alta | 5 | CAJ |

**Total: 31 SP**

---

## EPB-05 — Productos e inventario en escritorio

**Aprovechar la pantalla grande para trabajar con muchos productos a la vez.**

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-018 | Como AdminMaster quiero una tabla de productos con muchas filas visibles para revisar el catálogo de un vistazo. | Tabla con columnas de código, nombre, categoría, precio, costo, stock y estado. Orden por columna. Filtros y búsqueda conservados. Paginación o desplazamiento eficiente sobre catálogos grandes. | Alta | 8 | AM |
| USB-019 | Como AdminMaster quiero crear y editar productos sin salir de la lista para no perder el contexto de lo que estaba revisando. | El formulario se abre como diálogo o panel lateral sobre la tabla. Al guardar, la fila se actualiza sin recargar toda la lista. Validaciones actuales conservadas. | Alta | 5 | AM |
| USB-020 | Como AdminMaster quiero ver y ajustar el inventario en formato de tabla para gestionar el stock más rápido. | Tabla de inventario con semáforo de stock, filtro por estado de alerta y ajuste de stock desde la misma fila. Historial de movimientos accesible por producto. Actualización en tiempo real conservada. | Alta | 8 | AM |
| USB-021 | Como AdminMaster quiero subir la foto del producto desde el explorador de archivos del computador. | Selección de archivo desde el sistema. Vista previa antes de guardar. Validación de tamaño y formato. Se elimina la dependencia de cámara y recorte del flujo de escritorio. | Media | 3 | AM |

**Total: 24 SP**

---

## EPB-06 — Caja y gastos en escritorio

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-022 | Como Cajero quiero abrir y cerrar el turno en una pantalla ancha para revisar el cuadre con comodidad. | Apertura y cierre adaptados a escritorio, con el desglose de billetes y monedas en varias columnas. El resumen del cuadre se ve completo sin desplazarse. Reglas de comentario obligatorio por diferencia conservadas. | Alta | 5 | CAJ |
| USB-023 | Como Cajero quiero registrar los gastos del turno desde el computador. | Registro y edición de gastos adaptados a escritorio. Lista del turno con totales visibles. Ventana de edición y límites configurados conservados. | Media | 5 | CAJ |
| USB-024 | Como AdminMaster quiero revisar el historial de cajas y cuadres en formato de tabla. | Tabla de turnos con cajero, fechas, montos y diferencia. Indicador de color por diferencia. Detalle expandible con el cuadre completo. Filtros conservados. | Media | 5 | AM |

**Total: 15 SP**

---

## EPB-07 — Reportes y estadísticas en pantalla grande

**Lo que en un celular eran tarjetas apiladas, en un monitor puede ser una vista de control completa.**

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-025 | Como AdminMaster quiero el historial de ventas como tabla con filtros a la vista para analizar sin abrir paneles. | Tabla con fecha, cajero, método de pago, productos y total. Filtros siempre visibles en barra superior o lateral. Orden por columna. Clic en la fila abre el detalle. | Alta | 8 | AM |
| USB-026 | Como AdminMaster quiero un panel de control con los indicadores clave visibles al entrar. | Indicadores de ventas del día, semana y mes con comparativa, distribuidos aprovechando el ancho. Accesos rápidos a los módulos. Sin desplazamiento para ver lo esencial. | Alta | 5 | AM |
| USB-027 | Como AdminMaster quiero gráficas grandes y legibles para interpretar tendencias sin forzar la vista. | Gráficas de productos más vendidos, tendencia de ventas, categorías rentables y desempeño por cajero, dimensionadas para monitor. Información al pasar el mouse. Varias gráficas visibles a la vez. | Media | 8 | AM |
| USB-028 | Como AdminMaster quiero descargar los reportes como archivo para guardarlos o enviarlos. | Exportación a CSV y PDF mediante descarga del navegador. Se reemplaza el mecanismo de compartir de móvil, que en escritorio no aplica. Nombre de archivo con fecha y filtros aplicados. | Media | 5 | AM |

**Total: 26 SP**

---

## EPB-08 — Impresión de recibos

**Épica que no existe en Sistema AS.** En móvil el recibo se comparte como PDF; una caja de escritorio normalmente tiene impresora térmica conectada.

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-029 | Como Cajero quiero imprimir el recibo al terminar la venta para entregárselo al cliente. | Impresión directa al terminar el cobro, mediante el diálogo de impresión del navegador. Opción de reimprimir desde el detalle de una venta. Si no hay impresora, la venta igual se completa. | Alta | 8 | CAJ |
| USB-030 | Como AdminMaster quiero que el recibo tenga formato de tiquete para que salga bien en la impresora térmica. | Formato de ancho de tiquete (58 mm y 80 mm). Datos del negocio, ítems, totales, método de pago y fecha. Configurable desde ajustes. Vista previa antes de imprimir. | Media | 5 | AM |

**Total: 13 SP**

---

## EPB-09 — Despliegue y operación

**Épica que no existe en Sistema AS.** Una aplicación web necesita estar publicada en algún lado.

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-031 | Como equipo de desarrollo quiero la aplicación publicada en una dirección web para que el negocio la use sin instalar nada. | Proveedor de hospedaje elegido y configurado. Compilación de producción publicada. Dirección web funcional con HTTPS. Documentado en el README. | Alta | 5 | — |
| USB-032 | Como equipo de desarrollo quiero separar la configuración por ambiente para no mezclar datos de prueba con los reales. | Configuración distinta para desarrollo y producción. Las credenciales no quedan en el repositorio. Proceso de publicación documentado y repetible. | Alta | 5 | — |
| USB-033 | Como usuario quiero abrir el sistema como una aplicación del computador para no depender de buscar una pestaña. | Aplicación instalable desde el navegador, con ícono y nombre propios. Abre en ventana sin barra de direcciones. Funciona a pantalla completa. | Baja | 3 | AM/CAJ |

**Total: 13 SP**

---

## EPB-10 — Pistola lectora HID

**Va de último por decisión del negocio.** Hasta entonces se opera escribiendo el código a mano, que es un flujo que ya funciona.

La pistola se conecta por USB o se empareja desde el sistema operativo y se comporta como un teclado: escribe los dígitos del código muy rápido y termina con un separador (normalmente Enter). La aplicación no la "conecta" — la reconoce por cómo escribe.

| ID | Historia de Usuario | Criterios de Aceptación | Prior. | SP | Rol |
|---|---|---|---|---|---|
| USB-034 | Como Cajero quiero que el sistema reconozca lo que llega de la pistola y lo distinga de lo que escribo a mano. | Detección por velocidad de escritura (la pistola envía los caracteres en menos de 100 ms). El código escaneado se procesa completo, no carácter por carácter. Escribir el mismo código a mano sigue funcionando igual. | Alta | 8 | CAJ |
| USB-035 | Como AdminMaster quiero configurar el comportamiento de la pistola para que funcione con cualquier modelo. | Pantalla de configuración con separador (Enter o Tab), prefijo y sufijo a ignorar, y umbral de velocidad. Campo de prueba que muestra exactamente qué recibió el sistema. Configuración guardada en el dispositivo. | Alta | 5 | AM |
| USB-036 | Como Cajero quiero escanear sin tener que hacer clic en ningún campo primero. | El código escaneado se captura aunque el foco no esté en un campo de texto. En el punto de venta agrega el producto directo al carrito. En el formulario de producto llena el campo de código. Nunca interfiere con lo que se está escribiendo. | Alta | 5 | CAJ |
| USB-037 | Como Cajero quiero saber de inmediato si el escaneo salió bien o mal para no equivocarme de producto. | Confirmación visual clara al escanear correctamente, con el nombre del producto agregado. Aviso distinto cuando el código no existe, cuando el producto está archivado y cuando falla la consulta. Sonido opcional configurable. | Media | 3 | CAJ |

**Total: 21 SP**

---

## Roadmap de Sprints

Sprints de dos semanas. La pistola queda al final, como se definió.

| Sprint | Foco | Historias | SP | Épica(s) |
|---|---|---|---|---|
| SB-01 | Backend independiente y reproducible | USB-001 → USB-005 | 21 | EPB-01 |
| SB-02 | Base web + navegación de escritorio | USB-006 → USB-011 | 29 | EPB-02 / EPB-03 |
| SB-03 | Shell completo + caja y gastos | USB-012, USB-013, USB-022 → USB-024 | 28 | EPB-03 / EPB-06 |
| SB-04 | Punto de venta de escritorio | USB-014 → USB-017 | 31 | EPB-04 |
| SB-05 | Productos e inventario | USB-018 → USB-021 | 24 | EPB-05 |
| SB-06 | Reportes y estadísticas | USB-025 → USB-028 | 26 | EPB-07 |
| SB-07 | Impresión y publicación | USB-029 → USB-033 | 26 | EPB-08 / EPB-09 |
| SB-08 | Pistola lectora | USB-034 → USB-037 | 21 | EPB-10 |

**Total: 206 SP en 8 sprints (~16 semanas)**

---

## Riesgos y supuestos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| El esquema reconstruido en USB-001 no coincide exactamente con el de AS | Alto: errores sutiles de tipos o restricciones que solo aparecen en producción | Reconstruir desde las entidades Dart y verificar contra el proyecto de AS antes de dar por buena la migración |
| La impresión desde navegador depende del diálogo del sistema operativo | Medio: no se puede imprimir en silencio sin intervención del usuario | Validar temprano con la impresora real del negocio; si no alcanza, evaluar un puente local |
| Modelos de pistola con comportamiento distinto al esperado | Medio: el sistema no reconoce los escaneos | El campo de prueba de USB-035 permite ajustar sin tocar código |
| Flutter Web tiene un arranque más lento que una app nativa | Bajo: primera carga más lenta en equipos modestos | Medir en el equipo real del negocio; la aplicación instalable de USB-033 mitiga la carga repetida |

---

<div align="center">
  <sub>Sistema Bs — Product Backlog v1.0</sub>
</div>
