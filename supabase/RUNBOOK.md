# Runbook — Backend de Sistema Bs

Guía paso a paso para levantar el backend en un proyecto Supabase **nuevo y vacío**. Corre todo desde el **SQL Editor** del Dashboard, en el orden exacto de esta lista — no hay CLI de Supabase configurada en este repositorio, así que se aplica manualmente, igual que en Sistema AS.

## 1. Crear el proyecto

En [supabase.com](https://supabase.com), crea un proyecto nuevo. Anota `Project Settings → API`:
- **Project URL** → va en `SUPABASE_URL` de tu `.env`.
- **anon public key** → va en `SUPABASE_ANON_KEY` de tu `.env`.
- **service_role key** → **no va en `.env`**. Se usa solo como secreto de las Edge Functions (paso 5) y en `bootstrap_admin.sql` (paso 4).

## 2. Correr las migraciones, en este orden

Pega el contenido completo de cada archivo en el SQL Editor y ejecútalo antes de pasar al siguiente. Ninguno debería fallar si se respeta el orden.

| # | Archivo | Qué crea |
|---|---|---|
| 1 | `migrations/001_auth_users.sql` | `profiles`, `user_activity_logs`, trigger de alta automática de perfil, RLS por rol |
| 2 | `migrations/002_base_schema.sql` | Tipo `register_status`, tablas `products` y `cash_registers` con su RLS — **la migración que no existía en Sistema AS** |
| 3 | `migrations/003_product_images_storage.sql` | Bucket `product-images` y sus políticas |
| 4 | `migrations/004_inventory.sql` | `stock_movements`, `restock_requests`, función `adjust_product_stock`, Realtime sobre `products` |
| 5 | `migrations/005_sales.sql` | `sales`, `sale_items`, función `confirm_sale` |
| 6 | `migrations/006_cancellations_and_alerts.sql` | `sale_cancellations`, `low_stock_alerts` |
| 7 | `migrations/007_qr_and_receipt_photo.sql` | `store_settings`, buckets `store-assets`/`receipt-photos`, redefine `confirm_sale` |
| 8 | `migrations/008_expenses.sql` | `expense_categories`, `expenses` |
| 9 | `migrations/009_closing.sql` | Agrega `'closing'` al enum, funciones `start_register_closing`/`close_register` |
| 10 | `migrations/010_weekly_report.sql` | Columnas de reporte semanal en `store_settings`, `pg_cron`/`pg_net`, cron job (opcional — ver nota abajo) |

### Nota sobre `010_weekly_report.sql`

Esta migración necesita las extensiones `pg_cron` y `pg_net`. Si el `CREATE EXTENSION` falla por permisos, actívalas primero desde **Database → Extensions** en el Dashboard, y vuelve a correr el resto del archivo. El bloque final (`cron.schedule`) trae dos placeholders — `<PROJECT_REF>` y `<SERVICE_ROLE_KEY>` — que tienes que reemplazar por los valores reales de **tu** proyecto antes de ejecutarlo. Si no vas a usar el reporte semanal todavía, puedes saltarte esta migración por completo; nada más depende de ella.

## 3. Checklist de verificación

Después de correr todo, confirma en **Table Editor**:

- [ ] Existen las 13 tablas: `profiles`, `user_activity_logs`, `products`, `cash_registers`, `stock_movements`, `restock_requests`, `sales`, `sale_items`, `sale_cancellations`, `low_stock_alerts`, `store_settings`, `expense_categories`, `expenses`.
- [ ] `products` y `cash_registers` tienen RLS habilitado (ícono de escudo en Table Editor).
- [ ] En **Database → Functions** existen: `handle_new_user`, `handle_user_login`, `adjust_product_stock`, `confirm_sale`, `start_register_closing`, `close_register`.
- [ ] En **Storage** existen los buckets: `product-images`, `store-assets`, `receipt-photos`.
- [ ] En **Database → Replication** (o Publications), `products` aparece en `supabase_realtime`.
- [ ] `store_settings` tiene exactamente una fila (`id = 1`) — la inserta automáticamente `007_qr_and_receipt_photo.sql`

Si algo de esta lista falta o algún paso del SQL Editor tira error, compártelo tal cual — se corrige la migración correspondiente antes de seguir.

## 4. Crear el AdminMaster inicial

Ver `bootstrap_admin.sql` en esta misma carpeta. Resumen:

1. Crea el usuario desde **Authentication → Add user** en el Dashboard (o con `supabase.auth.admin.createUser` si prefieres scripting). Esto dispara `handle_new_user()` y crea su fila en `profiles` con `role = 'cajero'` por defecto.
2. Corre `bootstrap_admin.sql` en el SQL Editor, reemplazando el correo del placeholder por el que usaste en el paso anterior.

## 5. Desplegar las Edge Functions

Requiere el [CLI de Supabase](https://supabase.com/docs/guides/cli) instalado y autenticado (`supabase login`, `supabase link --project-ref <tu-project-ref>`).

```bash
supabase functions deploy create-cashier
supabase functions deploy toggle-cashier-status
supabase functions deploy send-weekly-report
```

Secretos necesarios (**Project Settings → Edge Functions → Secrets**, o `supabase secrets set`):

| Secreto | Requerida para | Notas |
|---|---|---|
| `SUPABASE_URL` | Las tres | Ya la inyecta Supabase automáticamente en cada función — no hace falta configurarla a mano |
| `SUPABASE_SERVICE_ROLE_KEY` | Las tres | También automática |
| `SUPABASE_ANON_KEY` | `create-cashier`, `send-weekly-report` | También automática |
| `RESEND_API_KEY` | `send-weekly-report` | Solo si vas a activar el reporte semanal — cuenta gratuita en [resend.com](https://resend.com) |
| `REPORT_FROM_EMAIL` | `send-weekly-report` | Opcional, cae a `onboarding@resend.dev` si no la configuras |

## 6. Probar

```bash
flutter run -d chrome
```

Inicia sesión con el correo del AdminMaster que creaste en el paso 4. Si el login funciona y el dashboard carga sin errores en la consola del navegador, el backend está listo.
