# Tracker Hub

Web app para seguir los hábitos del día a día en casa: check-ins personales, estado de ánimo, cuidado de los perros (Mocka y Honey) y una agenda interna. Tiene un tablero fijo en el iPad y se usa desde el celular como PWA.

🌐 **Web:** https://solasantiago.github.io/tracker_demo/
📄 **[Documento funcional de la prueba de concepto](docs/documento-funcional.md)**

## Qué hay en esta versión

Una sola página responsive (celular, iPad y compu) que lee y escribe en Supabase. Arriba a la derecha se elige quién la usa: **Mica**, **Santi** o **Casa** (el tablero del iPad, que solo muestra lo compartido).

| Sección | Qué muestra |
|---|---|
| **Hoy** | Check-ins por franja (Sí / Todavía no / No aplica), ánimo del momento, estado de Mocka y Honey, registrar paseo y comida, agenda de la semana, tareas que tocan y avisos automáticos. |
| **Hábitos** | Cumplimiento del período y contra el anterior, rachas, cumplimiento por semana y por día de la semana, mapa de calor de 90 días (general y por hábito) y ranking. |
| **Bienestar** | Ánimo, energía y estrés (diario + promedio de 7 días), calendario de ánimo, etiquetas, "lo mejor del día", sueño, pasos y uso de pantalla por categoría y por app. |
| **Perros** | Paseos por día contra la meta, horarios, duración, caca por perro (90 días, con lo raro marcado), comida registrada, stock de alimento y refills. |
| **Agenda y casa** | Calendario mensual, próximos eventos, alta de eventos, tareas recurrentes y su constancia. |
| **Análisis** | Frases con diferencias concretas (por ejemplo: "los días con menos de 6 h de sueño, tu ánimo baja X puntos"), mapa de correlaciones y gráficos de dispersión con tendencia. |

Los filtros de **7, 30 o 90 días** afectan a todas las métricas de la sección.

### Cómo se calculan las métricas

- **Cumplimiento** = check-ins con "Sí" / (Sí + No + sin responder). "No aplica" y los días en que el hábito no toca no cuentan.
- **Racha** = días programados seguidos con "Sí" hasta hoy. "No aplica" no la corta; hoy sin responder tampoco.
- **Ánimo del día** = promedio de las respuestas de mañana, tarde y noche. Energía sale de la mañana y estrés de la tarde.
- **Correlación** = Pearson entre dos variables día a día (solo días completos con ambos datos). Muestra qué va junto, no qué causa qué.
- **Alimento restante** = kilos de la última bolsa − días desde la compra × ración diaria de los dos perros.

## Datos

La base está en Supabase (`supabase/migrations`). La app usa la clave pública `anon`, que va en el código por diseño.

⚠️ **Por ahora no hay login**: las políticas dejan leer y escribir a cualquiera que tenga el link. Sirve para probar con datos de ejemplo. Antes de cargar datos reales hay que activar Supabase Auth y cambiar las políticas por reglas por usuario (ver §7 del documento funcional).

### Datos de ejemplo (3 meses)

Hay un generador que simula 92 días con una historia coherente: vacaciones de invierno y semana de parciales de Santi, una semana pesada de trabajo de Mica, dos días de caca blanda de Honey y la bolsa de alimento por terminarse. Hoy queda casi vacío para cargarlo desde la app.

Para regenerar todo terminando en la fecha de hoy, correr en el SQL editor de Supabase:

```sql
select demo.seed();
```

⚠️ Borra todos los datos del tracker antes de generar. La función vive en el esquema `demo`, que la web no puede llamar.

## Desarrollo

```bash
npm install
npm run dev      # http://localhost:5173/
npm run build    # genera dist/
```

Cada push a `main` compila y publica en GitHub Pages con `.github/workflows/pages.yml`.

| Carpeta | Contenido |
|---|---|
| `src/lib/` | Conexión a Supabase, carga de datos y tiempo real (`data.jsx`), cálculos puros (`metrics.js`) y fechas en hora de Buenos Aires (`dates.js`). |
| `src/views/` | Una vista por sección. |
| `src/components/charts/` | Gráficos en SVG propio: líneas, columnas, dispersión, calendario de días y matriz de correlaciones. Todos tienen tooltip y la opción "Ver tabla". |
| `supabase/` | Migraciones del esquema y el generador de datos de ejemplo. |
