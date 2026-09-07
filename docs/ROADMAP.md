# Roadmap de implementación — Sistema Bs

Secuencia de sprints, dependencias entre ellos y decisiones transversales. El *qué* y el *por qué* de cada historia vive en [BACKLOG.md](../BACKLOG.md); acá está el *cuándo* y el *en qué orden*.

---

## Estado

| Sprint | Foco | Historias | SP | Estado |
|---|---|---|---|---|
| SB-01 | Fundación del backend | USB-001 → USB-005 | 21 | Completo (`891449c`) |
| SB-02 | Base del proyecto web | USB-006 → USB-009 | 13 | Completo (`49635e4`) |
| [SB-03](sprints/SB-03.md) | Shell de escritorio | USB-010 → USB-013, USB-038 | 32 | Planeado |
| [SB-04](sprints/SB-04.md) | POS de escritorio | USB-014 → USB-017 | 31 | Planeado |
| [SB-05](sprints/SB-05.md) | Productos e inventario | USB-018 → USB-021 | 24 | Planeado |
| [SB-06](sprints/SB-06.md) | Caja, gastos e impresión | USB-022 → USB-024, USB-029, USB-030 | 28 | Planeado |
| [SB-07](sprints/SB-07.md) | Reportes y estadísticas | USB-025 → USB-028 | 26 | Planeado |
| [SB-08](sprints/SB-08.md) | Despliegue | USB-031 → USB-033 | 13 | Planeado |
| [SB-09](sprints/SB-09.md) | Pistola lectora HID | USB-034 → USB-037 | 21 | Planeado |

**Pendiente: 175 SP en 7 sprints.** Completado: 34 SP.

---

## Por qué el roadmap cambió

El backlog original planeaba 8 sprints. Ahora son 9, por dos razones documentadas acá para que no se pierda el rastro.

### SB-02 entregó menos de lo asignado

El roadmap original ponía `USB-006 → USB-011` en SB-02 (29 SP). Lo que se implementó fue `USB-006 → USB-009` (13 SP): traer el código, podar dependencias, quitar supuestos de móvil y verificar el arranque.

**`USB-010` (sistema de puntos de quiebre) y `USB-011` (barra lateral permanente) quedaron sin hacer** y arrastran a SB-03. No fue un descuido silencioso: SB-02 tenía sentido cerrarlo cuando el proyecto compilaba y arrancaba, y meterle además el rediseño de navegación lo habría convertido en un sprint de 29 SP con dos objetivos distintos.

### La impresión resultó mucho más barata de lo estimado

EPB-08 (impresión de recibos) estaba estimada en 13 SP asumiendo que había que construir el formato de tiquete desde cero. Al revisar el código heredado, ya está casi todo: [`receipt_pdf.dart:42`](../lib/core/utils/receipt_pdf.dart) genera `PdfPageFormat(58 * PdfPageFormat.mm, double.infinity)` — formato de rollo, no A4 — y [`receipt_page.dart:156`](../lib/features/pos/presentation/pages/receipt_page.dart) ya usa `Printing.layoutPdf`, que en web abre el diálogo de impresión del navegador.

Por eso la impresión sube a SB-06, junto al flujo de caja al que pertenece, en vez de quedar aislada al final.

---

## Dependencias entre sprints

```
SB-03 (shell)
  ├─> SB-04 (POS)         necesita breakpoints y ShellRoute
  ├─> SB-05 (productos)   necesita breakpoints y diálogos
  ├─> SB-06 (caja)        necesita breakpoints y diálogos
  └─> SB-07 (reportes)    necesita breakpoints

SB-04 (POS)
  └─> SB-09 (pistola)     el foco y los atajos se montan sobre el layout del POS

SB-08 (despliegue) — sin dependencias técnicas; se puede adelantar
```

**SB-03 es el cuello de botella.** Todo lo demás se apoya en el sistema de puntos de quiebre y en el shell persistente. Construir cualquier pantalla de escritorio antes de eso significa rehacerla.

**SB-09 depende de SB-04, no al revés.** La pistola escribe en un campo del punto de venta; ese campo y su manejo de foco se construyen en SB-04. Es coherente con la decisión de negocio de dejar la pistola al final: hasta entonces los códigos se escriben a mano, que es un flujo que ya funciona.

---

## Decisiones transversales

Cosas que se deciden una vez, temprano, y condicionan varios sprints.

### Puntos de quiebre

Tres anchos, definidos en un solo lugar y consultados por todas las pantallas:

| Nombre | Ancho | Uso |
|---|---|---|
| Compacto | < 768 px | Una columna, comportamiento heredado de móvil |
| Medio | 768 – 1279 px | Dos columnas donde aplique, barra lateral colapsada a íconos |
| Expandido | ≥ 1280 px | Layout completo de escritorio, barra lateral con etiquetas |

El objetivo real es el rango expandido: es un sistema para el computador de una caja. Los otros dos existen para que la aplicación no se rompa en una ventana angosta, no porque haya que optimizar para celular.

### Ancho máximo de contenido

Ninguna vista de lectura debe estirarse a 1920 px. El contenido se limita con `ConstrainedBox`, salvo las tablas densas y el punto de venta, que sí aprovechan todo el ancho.

### Hojas emergentes a diálogos

Hay **14 `showModalBottomSheet` en 13 archivos**. La conversión no se hace archivo por archivo con `if (esEscritorio)` repetido: se hace con un helper único (`showAdaptiveSheet`) que decide entre `showDialog` y `showModalBottomSheet` según el ancho, conservando la firma genérica `Future<T?>`. Así ninguna pantalla necesita saber en qué plataforma está.

### Exportación por descarga del navegador

Hay **11 puntos de exportación en 10 archivos** (10 `Share.shareXFiles` + 1 `Printing.sharePdf`), repartidos en 6 features: reportes, estadísticas, gastos, inventario, productos y usuarios. Todos siguen el mismo patrón, con los bytes ya en memoria, así que un solo helper `downloadBytes(bytes, nombre, mime)` los reemplaza todos.

`USB-028` está redactada como si esto fuera solo de reportes. No lo es: el helper se construye en SB-07 pero se aplica a los 11 puntos, incluidos los que pertenecen a features de otros sprints.

### Paginación

Ni el catálogo de productos ni el historial de ventas paginan en la interfaz. La capa de datos sí ([`product_providers.dart:154`](../lib/features/products/presentation/providers/product_providers.dart) acepta `page`, y el datasource usa `.range()` con `pageSize: 20`), pero la interfaz nunca pide una página distinta de la primera.

En móvil pasaba desapercibido. En una tabla de escritorio, ver 20 registros y nada más es un defecto visible. Se cablea en el sprint de cada pantalla: productos e inventario en SB-05, historial de ventas en SB-07.

---

## Riesgos conocidos

| Riesgo | Sprint | Mitigación |
|---|---|---|
| Introducir `ShellRoute` toca las 24 rutas del router de una vez | SB-03 | Es mecánico pero extenso; se hace primero en el sprint, con la aplicación compilando en cada paso |
| El rediseño del POS es la historia más grande del proyecto (13 SP en una sola) | SB-04 | El estado del carrito ya sirve sin cambios; el trabajo es de composición visual, no de lógica |
| La impresión depende del diálogo del navegador (no se puede imprimir en silencio) | SB-06 | Validar temprano con la impresora real del negocio |
| Modelos de pistola con comportamiento distinto al esperado | SB-09 | El campo de prueba de `USB-035` permite ajustar sin tocar código |
| El nombre del producto sigue siendo provisional | Cualquiera | Está aislado en pocos lugares; cambiarlo es de minutos |

---

## Sobre el detalle de estos planes

Los planes de sprint no tienen todos la misma profundidad, y es deliberado:

- **SB-03 y SB-04** están al detalle: archivos concretos, forma del cambio y orden de ejecución.
- **SB-05, SB-06 y SB-07** están a nivel de enfoque técnico y decisiones tomadas.
- **SB-08 y SB-09** están como dirección arquitectónica y decisiones pendientes.

Escribir los siete con el mismo detalle sería precisión falsa. El plan de la pistola depende del layout que se construya en SB-04, y el de reportes depende del sistema de puntos de quiebre de SB-03. **Cada plan se refina al empezar su sprint**, con el código real de ese momento a la vista.
