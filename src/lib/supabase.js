import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../config.js';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Tabla → columnas de orden estable (necesario para paginar de a 1000 filas).
export const TABLES = {
  people: ['id'],
  dogs: ['id'],
  habits: ['id'],
  chores: ['id'],
  habit_checkins: ['id'],
  mood_entries: ['id'],
  health_daily: ['person_id', 'day'],
  screen_time: ['person_id', 'day', 'app'],
  walks: ['id'],
  walk_dogs: ['walk_id', 'dog_id'],
  dog_meals: ['id'],
  food_purchases: ['id'],
  food_refills: ['id'],
  events: ['id'],
  chore_logs: ['id'],
};

// Tablas que se escriben desde la app y se escuchan en tiempo real.
export const LIVE_TABLES = [
  'habit_checkins',
  'mood_entries',
  'walks',
  'walk_dogs',
  'dog_meals',
  'food_purchases',
  'food_refills',
  'events',
  'chore_logs',
];

const PAGE = 1000;

export async function fetchTable(table) {
  const order = TABLES[table] ?? [];
  const rows = [];
  for (let from = 0; ; from += PAGE) {
    let q = supabase.from(table).select('*');
    for (const col of order) q = q.order(col, { ascending: true });
    const { data, error } = await q.range(from, from + PAGE - 1);
    if (error) throw new Error(`${table}: ${error.message}`);
    rows.push(...data);
    if (data.length < PAGE) break;
  }
  return rows;
}
