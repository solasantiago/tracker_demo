-- Regenera los 3 meses de datos de prueba terminando hoy (hora de Buenos Aires).
-- ⚠ Borra todos los datos del tracker antes de generar.
-- Correr desde el SQL editor de Supabase. La función está en el esquema "demo",
-- que no está expuesto por la API: la web no puede llamarla.

select demo.seed();

-- Variantes:
--   select demo.seed(p_end => date '2026-10-15');   -- que la historia termine en otra fecha
--   select demo.seed(p_days => 30);                 -- solo un mes
