<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.44.4-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/Dart-3.12.2-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
<img src="https://img.shields.io/badge/Supabase-2.x-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" />
<img src="https://img.shields.io/badge/Plataforma-Web%20Escritorio-4285F4?style=for-the-badge&logo=googlechrome&logoColor=white" />
<img src="https://img.shields.io/badge/Estado-Planificaci%C3%B3n-yellow?style=for-the-badge" />

</div>

<br />

<div align="center">
  <h1>Sistema Bs</h1>
  <p><strong>Sistema de Administración y Punto de Venta Web para Escritorio</strong></p>
  <p>Flutter Web · Dart · Supabase · Riverpod · Pistola lectora de códigos de barras</p>
</div>

---

## Descripción General

**Sistema Bs** es la versión web de escritorio de un sistema integral de punto de venta para tiendas: venta con pistola lectora de códigos de barras, gestión de inventario, control de caja, gastos, reportes y analítica de negocio. Está pensado para operarse desde el computador de la caja, con teclado y lector físico, no desde un celular.

> El nombre **Sistema Bs** es provisional y corresponde al nombre del repositorio. Cuando se defina la marca del negocio, se cambia en el título de este README, en `APP_NAME` del archivo `.env` y en `pubspec.yaml`.

### Estado actual

**Sprints 1 y 2 completos (34 de 209 SP).**

- **SB-01 — Backend**: las 10 migraciones SQL que levantan el esquema completo en un proyecto Supabase nuevo (incluida `002_base_schema.sql`, que reconstruye lo que en Sistema AS se creó a mano desde el Dashboard), las tres Edge Functions, el runbook de despliegue y el script de bootstrap del AdminMaster.
- **SB-02 — Base web**: el código Flutter portado desde Sistema AS (106 archivos), compilando y arrancando en navegador, con la identidad renombrada y 32 dependencias sin uso podadas del `pubspec.yaml`.

**La interfaz todavía es la de móvil.** La adaptación a escritorio (barra lateral, tablas densas, operación por teclado) empieza en SB-03. El plan de cada sprint restante está en [docs/ROADMAP.md](docs/ROADMAP.md).

El desarrollo parte del código de [Sistema AS](https://github.com/johan-850/SIstema_AS) (Abarrotería Pro), la versión móvil de esta misma solución, donde ya están construidas y funcionando contra Supabase real diez épicas de lógica de negocio.

### Roles del Sistema

| Rol | Descripción |
|-----|-------------|
| **AdminMaster (AM)** | Acceso completo: gestión de usuarios, productos, inventario, configuración, reportes y analítica |
| **Cajero (CAJ)** | Operativo de punto de venta: ventas, caja, gastos del turno |

---

## Diferencias con Sistema AS

Sistema Bs no es un despliegue web de la app móvil: es otro producto, para otro negocio, con otra forma de operarse.

| | Sistema AS | Sistema Bs |
|---|---|---|
| **Plataforma** | Android / iOS | Web de escritorio (navegador) |
| **Base de datos** | Su propio proyecto Supabase | Proyecto Supabase **independiente**, sin datos compartidos |
| **Lectura de códigos** | Cámara del celular (`mobile_scanner`) | Pistola lectora física (teclado HID) |
| **Navegación** | Menú desplegable y barra inferior | Menú lateral permanente |
| **Formularios** | Paneles desde el borde inferior | Ventanas centradas |
| **Punto de venta** | Carrito en pantalla aparte | Catálogo y carrito lado a lado |
| **Operación** | Táctil | Teclado, mouse y lector |
| **Recibo** | Se comparte como PDF | Se imprime en impresora térmica |

Lo que **sí** se hereda: entidades, repositorios, casos de uso, funciones RPC de Supabase, políticas de seguridad, providers de estado y el design system.

---

## Arquitectura

El proyecto sigue **Clean Architecture** por features, con separación en capas:

```
lib/
├── core/
│   ├── constants/         # Constantes de la app
│   ├── errors/            # Manejo de errores (Failures)
│   ├── providers/         # Providers transversales
│   ├── router/            # GoRouter con guards de rol
│   ├── services/          # Servicios de dispositivo (preferencias locales)
│   ├── theme/             # Design system (colores, tipografía, breakpoints)
│   ├── utils/             # Utilitarios generales
│   └── widgets/           # Widgets compartidos entre features
│
└── features/
    ├── auth/              # Login, sesiones, roles
    ├── cash_register/     # Apertura y cierre de caja
    ├── products/          # CRUD de productos, import CSV
    ├── inventory/         # Stock, movimientos, restock
    ├── pos/               # Punto de venta y cobro
    ├── expenses/          # Gastos de caja
    ├── dashboard/         # Panel de administración, historial, estadísticas
    ├── users/             # Gestión de cajeros
    └── settings/          # Configuración (incluye la pistola lectora)
```

### Patrón por Feature

```
feature/
├── data/         # Models, datasources, repository impl
├── domain/       # Entities, repository interface, use cases
└── presentation/
    ├── pages/    # Screens
    ├── widgets/  # Componentes propios del feature
    └── providers/# Riverpod providers
```

---

## Stack Tecnológico

| Capa | Tecnología | Uso |
|------|-----------|-----|
| **UI** | Flutter Web 3.44 + Dart 3.12 | Interfaz de escritorio en navegador |
| **Estado** | Riverpod 2.x | Gestión de estado reactivo |
| **Backend** | Supabase (PostgreSQL) | Base de datos + Auth + Storage + Realtime |
| **Auth** | Supabase Auth (JWT + RLS) | Roles por metadata |
| **Códigos de barras** | Captura de teclado (HID) | Pistola lectora física, sin librería externa |
| **PDF e impresión** | pdf + printing | Recibos de tiquete y reportes |
| **Charts** | fl_chart | Gráficas y tendencias |
| **Navegación** | GoRouter | Rutas con guards de rol |
| **Preferencias** | shared_preferences | Configuración por dispositivo (pistola, feedback) |

---

## Modelo de Base de Datos (Supabase)

```sql
profiles           -- Perfil de usuarios con rol (adminmaster | cajero)
user_activity_logs -- Auditoría de accesos
products           -- Catálogo con código de barras, stock, precio y costo
stock_movements    -- Historial de entradas y salidas de inventario
restock_requests   -- Solicitudes de reabastecimiento
cash_registers     -- Turnos de caja (apertura → cierre → cuadre)
sales              -- Cabecera de ventas
sale_items         -- Ítems de cada venta (con nombre y precio congelados)
sale_cancellations -- Auditoría de carritos cancelados
low_stock_alerts   -- Registro de alertas de stock bajo mostradas
expenses           -- Gastos registrados por cajero
expense_categories -- Categorías de gasto configurables
store_settings     -- Configuración del negocio (fila única)
```

**Buckets de Storage:** `product-images`, `store-assets`, `receipt-photos`.

**Funciones RPC:** `confirm_sale`, `adjust_product_stock`, `start_register_closing`, `close_register`.

---

## Épicas del Product Backlog

Detalle completo en [BACKLOG.md](BACKLOG.md).

| # | Épica | US | SP | Sprint | Estado |
|---|-------|----|----|--------|--------|
| EPB-01 | Fundación: esquema completo e independiente | 5 | 21 | SB-01 | Completo |
| EPB-02 | Base del proyecto web | 4 | 13 | SB-02 | Completo |
| EPB-03 | Shell responsive de escritorio | 6 | 37 | SB-03 | Planeado |
| EPB-04 | POS de escritorio | 4 | 31 | SB-04 | Planeado |
| EPB-05 | Productos e inventario en escritorio | 5 | 29 | SB-05 | Planeado |
| EPB-06 | Caja y gastos en escritorio | 3 | 15 | SB-06 | Planeado |
| EPB-07 | Reportes y estadísticas en pantalla grande | 4 | 26 | SB-07 | Planeado |
| EPB-08 | Impresión de recibos | 2 | 13 | SB-06 | Planeado |
| EPB-09 | Despliegue y operación | 3 | 13 | SB-08 | Planeado |
| EPB-10 | Pistola lectora HID | 4 | 21 | SB-09 | Planeado |
| EPB-11 | Gestión de cajeros en escritorio | 1 | 8 | SB-08 | Planeado |
| **Total** | | **41** | **227** | **9 Sprints** | |

---

## Configuración del Proyecto

### Prerrequisitos

- [Flutter SDK](https://flutter.dev) ≥ 3.44.4 con soporte web habilitado (`flutter config --enable-web`)
- [Dart SDK](https://dart.dev) ≥ 3.12.2
- Cuenta en [Supabase](https://supabase.com) con un proyecto **nuevo y vacío**
- Navegador basado en Chromium para desarrollo
- VS Code o Android Studio con la extensión de Flutter

### 1. Clonar el repositorio

```bash
git clone https://github.com/johan-850/Sistema-Bs.git
cd Sistema-Bs
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
```

Edita `.env` con las credenciales de **tu** proyecto Supabase. Ambos valores están en el Dashboard, en **Project Settings → API**:

```env
SUPABASE_URL=https://tu-project-ref.supabase.co
SUPABASE_ANON_KEY=tu_clave_anon_publica
```

El archivo `.env` está ignorado por git y nunca debe subirse al repositorio.

### 3. Instalar dependencias

```bash
flutter pub get
```

### 4. Aplicar las migraciones

Ver la sección [Migraciones SQL](#migraciones-sql--supabase). Este paso es obligatorio antes del primer arranque: sin él la aplicación no encuentra ninguna tabla.

### 5. Ejecutar en el navegador

```bash
flutter run -d chrome
```

### 6. Compilar para producción

```bash
flutter build web --release
```

El resultado queda en `build/web/`, listo para publicarse en cualquier hospedaje de sitios estáticos.

---

## Migraciones SQL — Supabase

Los scripts se ejecutan **en orden** desde el **SQL Editor** del proyecto Supabase. No hay CLI de Supabase configurada para las migraciones, así que se aplican manualmente. Guía completa con checklist de verificación en [`supabase/RUNBOOK.md`](supabase/RUNBOOK.md).

| Migración | Contenido |
|-----------|-----------|
| `001_auth_users.sql` | `profiles`, `user_activity_logs`, triggers de alta y último acceso, RLS por rol |
| `002_base_schema.sql` | Tipo `register_status`, tablas `products` y `cash_registers`, índices y RLS |
| `003_product_images_storage.sql` | Bucket `product-images` y sus políticas |
| `004_inventory.sql` | `stock_movements`, `restock_requests`, función `adjust_product_stock`, Realtime sobre `products` |
| `005_sales.sql` | `sales`, `sale_items`, función atómica `confirm_sale` |
| `006_cancellations_and_alerts.sql` | `sale_cancellations`, `low_stock_alerts` |
| `007_qr_and_receipt_photo.sql` | `store_settings`, buckets `store-assets` y `receipt-photos` |
| `008_expenses.sql` | `expense_categories`, `expenses`, columnas de configuración de gastos |
| `009_closing.sql` | Agrega `'closing'` al enum, funciones `start_register_closing` y `close_register` |
| `010_weekly_report.sql` | Configuración del reporte semanal por correo (opcional) |

### Sobre la migración `002`

Sistema AS creó las tablas `products` y `cash_registers` a mano desde el Dashboard, así que sus migraciones **no reconstruyen la base de datos completa**. La migración `002` de este proyecto existe precisamente para cerrar ese hueco y garantizar que el esquema se levante entero desde cero — va después de `001` porque sus columnas `created_by`/`cashier_id` referencian `profiles`. Es la primera historia del backlog ([USB-001](BACKLOG.md#epb-01--fundación-esquema-completo-e-independiente)).

### Usuario administrador inicial

El primer AdminMaster se crea mediante el procedimiento en [`supabase/bootstrap_admin.sql`](supabase/bootstrap_admin.sql) (historia USB-003), no a mano desde el Dashboard.

### Edge Functions

El código ya vive en `supabase/functions/` (`create-cashier`, `toggle-cashier-status`, `send-weekly-report`), copiado de Sistema AS sin cambios — son genéricas, sin ninguna dependencia de la plataforma. Se despliegan con la CLI de Supabase:

```bash
supabase functions deploy create-cashier
supabase functions deploy toggle-cashier-status
supabase functions deploy send-weekly-report
```

El reporte semanal es opcional: requiere un proveedor de correo transaccional y las extensiones `pg_cron` y `pg_net` habilitadas. Detalle de secretos necesarios en el runbook.

---

## Seguridad y RLS

- Todas las tablas tienen **Row Level Security** habilitado
- Los cajeros solo acceden a los datos de su propio turno activo
- Los AdminMasters tienen acceso completo mediante políticas sobre `role = 'adminmaster'`
- Las políticas se basan en los claims del JWT de Supabase Auth
- Las operaciones críticas (confirmar venta, cerrar caja, ajustar stock) se ejecutan en funciones `SECURITY DEFINER` que calculan los totales del lado del servidor y nunca confían en valores enviados por el cliente
- Las credenciales viven en `.env`, fuera del control de versiones

---

## La pistola lectora

La pistola de códigos de barras se conecta por USB o se empareja desde el sistema operativo, y se comporta como un **teclado (HID)**: escribe los dígitos del código muy rápido y termina con un separador, normalmente Enter.

Eso significa que la aplicación no "conecta" la pistola ni necesita librerías de Bluetooth: la reconoce por la velocidad con la que llegan los caracteres. La configuración (separador, prefijo, sufijo y umbral de velocidad) se ajusta desde la pantalla de ajustes, con un campo de prueba para validar cualquier modelo.

Es la última épica del backlog ([EPB-10](BACKLOG.md#epb-10--pistola-lectora-hid)), por decisión del negocio. Hasta que se implemente, los códigos se escriben a mano.

---

## Roadmap de Sprints

Plan detallado de cada sprint en [docs/ROADMAP.md](docs/ROADMAP.md).

| Sprint | Foco | SP | Estado |
|--------|------|----|--------|
| SB-01 | Backend independiente y reproducible | 21 | Completo |
| SB-02 | Base del proyecto web | 13 | Completo |
| [SB-03](docs/sprints/SB-03.md) | Shell de escritorio + correcciones heredadas | 37 | Planeado |
| [SB-04](docs/sprints/SB-04.md) | Punto de venta de escritorio | 31 | Planeado |
| [SB-05](docs/sprints/SB-05.md) | Productos e inventario | 29 | Planeado |
| [SB-06](docs/sprints/SB-06.md) | Caja, gastos e impresión | 28 | Planeado |
| [SB-07](docs/sprints/SB-07.md) | Reportes y estadísticas | 26 | Planeado |
| [SB-08](docs/sprints/SB-08.md) | Despliegue y gestión de cajeros | 21 | Planeado |
| [SB-09](docs/sprints/SB-09.md) | Pistola lectora | 21 | Planeado |

---

## Contribución

Flujo de trabajo de una rama por épica, igual que en Sistema AS:

1. Crea una rama desde `develop`: `git checkout -b epica_N`
2. Implementa las historias de esa épica, con commits en formato `feat(epbN): USB-XXX - descripción`
3. Abre un Pull Request hacia `develop` referenciando los identificadores de historia incluidos

---

## Licencia

Todos los derechos reservados © 2026 — Sistema Bs

---

<div align="center">
  <sub>Desarrollado con Flutter Web & Supabase</sub>
</div>
