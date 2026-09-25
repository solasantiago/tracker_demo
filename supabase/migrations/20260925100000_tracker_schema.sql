-- Tracker Hub · esquema de la prueba de concepto
-- Personas, perros, hábitos, ánimo, sueño/pasos, pantalla, paseos, comida, agenda y tareas de la casa.
-- Los días se interpretan en hora de Buenos Aires (America/Argentina/Buenos_Aires).

-- ───────────── Catálogos ─────────────

create table public.people (
  id            text primary key,              -- 'mica' | 'santi'
  name          text not null,
  short_name    text not null,
  color         text not null,
  steps_goal    int  not null default 8000,
  sleep_goal_min int not null default 420
);

create table public.dogs (
  id             text primary key,             -- 'mocka' | 'honey'
  name           text not null,
  weight_kg      numeric(4,1),
  daily_ration_g int  not null,
  walks_goal     int  not null default 3,
  vet            text,
  color          text not null
);

create table public.habits (
  id        bigint generated always as identity primary key,
  code      text unique,
  person_id text not null references public.people(id) on delete cascade,
  name      text not null,
  question  text,
  emoji     text,
  slot      text not null check (slot in ('manana','mediodia','tarde','noche')),
  days      smallint[] not null default '{0,1,2,3,4,5,6}',  -- 0 = domingo … 6 = sábado
  source    text not null default 'manual' check (source in ('manual','auto')),
  sort      int  not null default 0,
  active    boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.chores (
  id         bigint generated always as identity primary key,
  name       text not null,
  emoji      text,
  every_days int  not null,
  sort       int  not null default 0
);

-- ───────────── Registros personales ─────────────

create table public.habit_checkins (
  id          bigint generated always as identity primary key,
  habit_id    bigint not null references public.habits(id) on delete cascade,
  person_id   text   not null references public.people(id) on delete cascade,
  day         date   not null,
  status      text   not null check (status in ('si','no','na')),   -- na = hoy no aplica
  answered_at timestamptz not null default now(),
  unique (habit_id, day)
);

create table public.mood_entries (
  id          bigint generated always as identity primary key,
  person_id   text not null references public.people(id) on delete cascade,
  day         date not null,
  slot        text not null check (slot in ('manana','tarde','noche')),
  mood        smallint check (mood   between 1 and 5),
  energy      smallint check (energy between 1 and 5),
  stress      smallint check (stress between 1 and 5),
  feelings    text[] not null default '{}',
  influences  text[] not null default '{}',
  best_of_day text,
  created_at  timestamptz not null default now(),
  unique (person_id, day, slot)
);

create table public.health_daily (
  person_id text not null references public.people(id) on delete cascade,
  day       date not null,
  sleep_min int,
  bedtime   time,
  wake_time time,
  steps     int,
  primary key (person_id, day)
);

create table public.screen_time (
  person_id text not null references public.people(id) on delete cascade,
  day       date not null,
  app       text not null,
  category  text not null,
  minutes   int  not null check (minutes >= 0),
  primary key (person_id, day, app)
);

-- ───────────── Perros ─────────────

create table public.walks (
  id         bigint generated always as identity primary key,
  started_at timestamptz not null,
  ended_at   timestamptz,
  walker_id  text not null references public.people(id),
  created_at timestamptz not null default now()
);

create table public.walk_dogs (
  walk_id     bigint not null references public.walks(id) on delete cascade,
  dog_id      text   not null references public.dogs(id),
  poop        text check (poop in ('si','no','raro')),
  poop_detail text,
  pee         boolean,
  primary key (walk_id, dog_id)
);

create table public.dog_meals (
  id       bigint generated always as identity primary key,
  day      date not null,
  meal     text not null check (meal in ('desayuno','cena')),
  given_by text not null references public.people(id),
  given_at timestamptz not null default now(),
  unique (day, meal)
);

create table public.food_purchases (
  id        bigint generated always as identity primary key,
  bought_on date not null,
  kg        numeric(4,1) not null,
  bought_by text not null references public.people(id),
  created_at timestamptz not null default now()
);

create table public.food_refills (
  id    bigint generated always as identity primary key,
  at    timestamptz not null default now(),
  by_id text not null references public.people(id)
);

-- ───────────── Agenda y casa ─────────────

create table public.events (
  id           bigint generated always as identity primary key,
  title        text not null,
  starts_at    timestamptz not null,
  duration_min int,
  all_day      boolean not null default false,
  category     text not null check (category in ('facu','salud','perros','social','casa')),
  visibility   text not null check (visibility in ('personal','compartido')),
  owner_id     text references public.people(id),
  recurrence   text,          -- texto tipo RRULE, informativo en la PoC
  notes        text,
  created_at   timestamptz not null default now()
);

create table public.chore_logs (
  id       bigint generated always as identity primary key,
  chore_id bigint not null references public.chores(id) on delete cascade,
  done_by  text   not null references public.people(id),
  done_at  timestamptz not null default now()
);

-- ───────────── Índices ─────────────

create index on public.habit_checkins (person_id, day);
create index on public.mood_entries   (person_id, day);
create index on public.screen_time    (person_id, day);
create index on public.walks          (started_at);
create index on public.walks          (walker_id);
create index on public.walk_dogs      (dog_id);
create index on public.dog_meals      (given_by);
create index on public.food_purchases (bought_by);
create index on public.food_refills   (by_id);
create index on public.events         (starts_at);
create index on public.events         (owner_id);
create index on public.habits         (person_id);
create index on public.chore_logs     (chore_id, done_at);
create index on public.chore_logs     (done_by);

-- ───────────── Acceso (PoC sin login) ─────────────
-- La PoC usa un selector de persona sin login: la clave pública (anon) puede leer todo
-- y escribir los registros. Antes de cargar datos reales hay que pasar a Supabase Auth
-- y reemplazar estas políticas por reglas por usuario (ver docs/documento-funcional.md §7).

do $$
declare
  t text;
  read_only  text[] := array['people','dogs','habits','chores','health_daily','screen_time'];
  read_write text[] := array['habit_checkins','mood_entries','walks','walk_dogs','dog_meals',
                             'food_purchases','food_refills','events','chore_logs'];
begin
  foreach t in array read_only || read_write loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select on public.%I to anon, authenticated', t);
    execute format('create policy "poc_lectura" on public.%I for select to anon, authenticated using (true)', t);
  end loop;
  foreach t in array read_write loop
    execute format('grant insert, update, delete on public.%I to anon, authenticated', t);
    execute format('create policy "poc_alta" on public.%I for insert to anon, authenticated with check (true)', t);
    execute format('create policy "poc_edicion" on public.%I for update to anon, authenticated using (true) with check (true)', t);
    execute format('create policy "poc_baja" on public.%I for delete to anon, authenticated using (true)', t);
  end loop;
end $$;

grant usage on all sequences in schema public to anon, authenticated;

-- Tiempo real para el tablero del iPad
alter publication supabase_realtime add table
  public.habit_checkins, public.mood_entries, public.walks, public.walk_dogs,
  public.dog_meals, public.food_refills, public.food_purchases, public.events, public.chore_logs;
