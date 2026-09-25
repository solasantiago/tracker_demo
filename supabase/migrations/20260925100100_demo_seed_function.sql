-- Tracker Hub · generador de datos de prueba (3 meses)
--
-- Uso (desde el SQL editor de Supabase):   select demo.seed();
-- Vuelve a generar todo terminando en la fecha de hoy (hora de Buenos Aires).
-- ⚠ Borra TODOS los datos de las tablas del tracker antes de generar.
--
-- Los datos no son al azar puro: siguen una historia para que las métricas muestren algo.
--   · Un factor diario de "cómo viene el día" (autocorrelacionado) mueve sueño, pasos, pantalla, ánimo y hábitos.
--   · Santi: vacaciones de invierno (~2 semanas, hace 2,5 meses), vuelta a clases y semana de parciales al final.
--   · Mica: una semana pesada de trabajo hace ~5 semanas.
--   · Honey: dos días con caca blanda seguidos de un control en el veterinario.
--   · Alimento: la última bolsa se compró hace 24 días, así que hoy salta el aviso de compra.
-- El día de hoy queda casi vacío (solo el sueño de anoche) para poder cargarlo desde la app.

create schema if not exists demo;
revoke all on schema demo from public, anon, authenticated;

create or replace function demo.rnorm() returns double precision
language sql volatile set search_path = '' as
$$ select sqrt(-2 * ln(1 - random())) * cos(2 * pi() * random()) $$;

create or replace function demo.clamp5(x double precision) returns smallint
language sql immutable set search_path = '' as
$$ select least(5, greatest(1, round(x)))::smallint $$;

create or replace function demo.seed(
  p_end  date default (now() at time zone 'America/Argentina/Buenos_Aires')::date,
  p_days int  default 92
) returns text
language plpgsql
set search_path = public, demo
as $$
declare
  tz constant text := 'America/Argentina/Buenos_Aires';
  v_start date := p_end - (p_days - 1);
  d date; k int; dow int; wkend boolean; rain boolean; vac boolean; mica_bad boolean;
  exam double precision;
  q_s double precision := 0; q_m double precision := 0; q double precision;
  per text; w_s int; w_m int; w_p int;
  n_walks int; slots text[]; s text; idx int; walker text; wid bigint;
  st_min int; dur int; dogs_on text[]; dg text; p_poop double precision; poop text; detail text;
  pooped_mocka boolean; pooped_honey boolean;
  sleep_m int; wake_min int; steps_v int; social int; goal int;
  m_base double precision; energy smallint; stress smallint; mood_n smallint;
  feel text[]; infl text[]; best text;
  h record; logit double precision; p double precision; r double precision; st text; ans_min int;
  c record; t date; who text;
  n_rows int;
  best_list text[] := array[
    'Paseo largo con Mocka y Honey','Cena rica en casa','Terminé lo que tenía pendiente',
    'Charla larga con amigos','Siesta','Salió el sol','Mate en el balcón','Película en el sillón',
    'Honey me hizo reír','Llamada con la familia','Día tranquilo','Mocka durmió encima mío',
    'Entrené bien','Cocinamos juntos','Plaza con los perros'];
begin
  perform setseed(0.4242);

  truncate public.habit_checkins, public.mood_entries, public.health_daily, public.screen_time,
           public.walk_dogs, public.walks, public.dog_meals, public.food_purchases,
           public.food_refills, public.events, public.chore_logs, public.chores,
           public.habits, public.dogs, public.people
    restart identity cascade;

  insert into public.people (id, name, short_name, color, steps_goal, sleep_goal_min) values
    ('mica',  'Micaela',  'Mica',  '#B4543A', 10000, 450),
    ('santi', 'Santiago', 'Santi', '#3F6E8C',  8000, 420);

  insert into public.dogs (id, name, weight_kg, daily_ration_g, walks_goal, vet, color) values
    ('mocka', 'Mocka', 14.5, 300, 3, 'Vet. San Roque', '#8A5A3B'),
    ('honey', 'Honey',  9.2, 220, 3, 'Vet. San Roque', '#D9A441');

  insert into public.habits (code, person_id, name, question, emoji, slot, days, source, sort) values
    ('s_pastillas', 'santi', 'Pastillas de la mañana', '¿Tomaste las pastillas?',         '💊', 'manana',   '{0,1,2,3,4,5,6}', 'manual', 1),
    ('s_desayuno',  'santi', 'Desayunar',              '¿Desayunaste?',                   '🥣', 'manana',   '{0,1,2,3,4,5,6}', 'manual', 2),
    ('s_agua',      'santi', 'Tomar agua',             '¿Tomaste agua?',                  '💧', 'tarde',    '{0,1,2,3,4,5,6}', 'manual', 3),
    ('s_estudiar',  'santi', 'Estudiar 1 h',           '¿Estudiaste una hora?',           '📚', 'tarde',    '{1,2,3,4,5}',     'manual', 4),
    ('s_gym',       'santi', 'Gimnasio',               '¿Fuiste al gimnasio?',            '🏋️', 'tarde',    '{1,3,5}',         'manual', 5),
    ('s_celular',   'santi', 'Celular fuera de la cama','¿Dejaste el celular antes de dormir?','📵','noche', '{0,1,2,3,4,5,6}', 'manual', 6),
    ('s_pasos',     'santi', 'Meta de pasos',          'Se marca sola al llegar a 8.000', '👟', 'noche',    '{0,1,2,3,4,5,6}', 'auto',   7),
    ('m_pastillas_m','mica', 'Pastillas de la mañana', '¿Tomaste las pastillas?',         '💊', 'manana',   '{0,1,2,3,4,5,6}', 'manual', 1),
    ('m_desayuno',  'mica',  'Desayunar',              '¿Desayunaste?',                   '🥣', 'manana',   '{0,1,2,3,4,5,6}', 'manual', 2),
    ('m_estirar',   'mica',  'Estirar 10 min',         '¿Estiraste un rato?',             '🧘', 'manana',   '{1,2,3,4,5}',     'manual', 3),
    ('m_almuerzo',  'mica',  'Decidir el almuerzo',    '¿Decidiste qué almorzar?',        '🥗', 'mediodia', '{1,2,3,4,5}',     'manual', 4),
    ('m_leer',      'mica',  'Leer 20 min',            '¿Leíste un rato?',                '📖', 'noche',    '{0,1,2,3,4,5,6}', 'manual', 5),
    ('m_pastillas_n','mica', 'Pastillas de la noche',  '¿Tomaste las pastillas de la noche?','💊','noche',  '{0,1,2,3,4,5,6}', 'manual', 6),
    ('m_pasos',     'mica',  'Meta de pasos',          'Se marca sola al llegar a 10.000','👟', 'noche',    '{0,1,2,3,4,5,6}', 'auto',   7);

  insert into public.chores (name, emoji, every_days, sort) values
    ('Sacar la basura',     '🗑️', 2, 1),
    ('Reciclables',         '♻️', 7, 2),
    ('Lavar ropa',          '🧺', 4, 3),
    ('Limpieza general',    '🧹', 7, 4),
    ('Regar plantas',       '🪴', 3, 5),
    ('Compras del súper',   '🛒', 7, 6),
    ('Cambiar sábanas',     '🛏️', 14, 7);

  for d in select g::date from generate_series(v_start, p_end, interval '1 day') g loop
    k := p_end - d;
    dow := extract(dow from d)::int;
    wkend := dow in (0, 6);
    rain := random() < 0.13;
    vac := k between 61 and 74;                   -- vacaciones de invierno de Santi
    mica_bad := k between 35 and 39;              -- semana pesada de Mica
    exam := case when k <= 11 then 0.3 + 0.9 * (11 - k) / 11.0   -- semana de parciales
                 when k <= 46 then 0.25                          -- cursada
                 when vac then -0.4
                 else 0.1 end;

    q_s := 0.6 * q_s + 0.75 * rnorm();
    q_m := 0.6 * q_m + 0.75 * rnorm();

    -- ── Paseos, caca, comida (compartido) ──
    w_s := 0; w_m := 0;
    if k > 0 then
      n_walks := case when rain then 2 when random() < 0.12 then 2
                      when wkend and random() < 0.3 then 4 else 3 end;
      slots := case n_walks when 2 then array['manana','noche']
                            when 3 then array['manana','tarde','noche']
                            else array['manana','mediodia','tarde','noche'] end;
      pooped_mocka := false; pooped_honey := false; idx := 0;
      foreach s in array slots loop
        idx := idx + 1;
        walker := case s
          when 'manana' then case when random() < (case when exam > 0.6 then 0.4 else 0.72 end) then 'santi' else 'mica' end
          when 'tarde'  then case when random() < 0.6  then 'mica' else 'santi' end
          when 'noche'  then case when random() < 0.55 then 'mica' else 'santi' end
          else case when random() < 0.5 then 'mica' else 'santi' end end;
        st_min := case s when 'manana' then 440 + (random() * 80)::int + case when wkend then 90 else 0 end
                         when 'mediodia' then 750 + (random() * 120)::int
                         when 'tarde' then 1050 + (random() * 90)::int
                         else 1290 + (random() * 80)::int end;
        dur := greatest(8, round(case s when 'manana' then 30 when 'mediodia' then 15 when 'tarde' then 25 else 20 end
                                 + 7 * rnorm() + case when wkend then 12 else 0 end)::int);
        if rain then dur := greatest(8, (dur * 0.6)::int); end if;
        insert into public.walks (started_at, ended_at, walker_id, created_at)
          values ((d + make_interval(mins => st_min)) at time zone tz,
                  (d + make_interval(mins => st_min + dur)) at time zone tz, walker,
                  (d + make_interval(mins => st_min + dur)) at time zone tz)
          returning id into wid;
        r := random();
        dogs_on := case when r < 0.92 then array['mocka','honey'] when r < 0.96 then array['mocka'] else array['honey'] end;
        foreach dg in array dogs_on loop
          p_poop := case s when 'manana' then 0.72 when 'mediodia' then 0.3 when 'tarde' then 0.4 else 0.5 end;
          if (dg = 'mocka' and pooped_mocka) or (dg = 'honey' and pooped_honey) then p_poop := p_poop * 0.45; end if;
          if idx = n_walks and not ((dg = 'mocka' and pooped_mocka) or (dg = 'honey' and pooped_honey)) then p_poop := 0.9; end if;
          poop := case when random() < p_poop then 'si' else 'no' end;
          detail := null;
          if dg = 'honey' and k in (43, 44) and s = 'manana' then poop := 'raro'; detail := 'blanda'; end if;
          if dg = 'mocka' and k = 57 and s = 'manana' then poop := 'raro'; detail := 'esfuerzo'; end if;
          if poop <> 'no' then
            if dg = 'mocka' then pooped_mocka := true; else pooped_honey := true; end if;
          end if;
          insert into public.walk_dogs (walk_id, dog_id, poop, poop_detail, pee)
            values (wid, dg, poop, detail, random() < 0.95);
        end loop;
        if walker = 'santi' then w_s := w_s + 1; else w_m := w_m + 1; end if;
      end loop;

      if random() > 0.02 then
        insert into public.dog_meals (day, meal, given_by, given_at) values
          (d, 'desayuno', case when random() < 0.55 then 'mica' else 'santi' end,
           (d + make_interval(mins => 470 + (random() * 60)::int + case when wkend then 60 else 0 end)) at time zone tz);
      end if;
      if random() > 0.02 then
        insert into public.dog_meals (day, meal, given_by, given_at) values
          (d, 'cena', case when random() < 0.55 then 'santi' else 'mica' end,
           (d + make_interval(mins => 1185 + (random() * 75)::int)) at time zone tz);
      end if;
      if random() < 0.34 then
        insert into public.food_refills (at, by_id) values
          ((d + make_interval(mins => 480 + (random() * 780)::int)) at time zone tz,
           case when random() < 0.5 then 'mica' else 'santi' end);
      end if;
    end if;

    -- ── Personal ──
    foreach per in array array['santi', 'mica'] loop
      if per = 'santi' then
        q := q_s - 0.35 * greatest(exam, 0) + case when vac then 0.3 else 0 end; w_p := w_s;
      else
        q := q_m - case when mica_bad then 1.2 else 0 end; w_p := w_m;
      end if;

      sleep_m := round((case per when 'santi' then 405 else 440 end) + 22 * q
                       + case when wkend then 45 else 0 end
                       - case when per = 'santi' then 45 * greatest(exam - 0.3, 0) else 0 end
                       + case when vac and per = 'santi' then 30 else 0 end
                       + 32 * rnorm())::int;
      sleep_m := least(610, greatest(230, sleep_m));
      wake_min := case when wkend then 550 else case per when 'santi' then 435 else 420 end end + (18 * rnorm())::int;

      if k = 0 then
        insert into public.health_daily (person_id, day, sleep_min, bedtime, wake_time, steps)
          values (per, d, sleep_m, time '00:00' + make_interval(mins => wake_min - sleep_m - 15),
                  time '00:00' + make_interval(mins => wake_min), null);
        continue;
      end if;

      steps_v := round((case per when 'santi' then 6200 else 7600 end) + 2300 * w_p + 900 * q
                       + case when dow = 6 then 1800 else 0 end - case when rain then 1800 else 0 end
                       + 1700 * rnorm())::int;
      steps_v := least(21000, greatest(1100, steps_v));
      insert into public.health_daily (person_id, day, sleep_min, bedtime, wake_time, steps)
        values (per, d, sleep_m, time '00:00' + make_interval(mins => wake_min - sleep_m - 15),
                time '00:00' + make_interval(mins => wake_min), steps_v);

      social := round((case per when 'santi' then 95 else 115 end) - 20 * q
                      + case when vac and per = 'santi' then 45 else 0 end
                      + case when wkend then 25 else 0 end
                      - case when per = 'santi' then 20 * greatest(exam - 0.3, 0) else 0 end
                      + 20 * rnorm())::int;
      social := least(300, greatest(25, social));

      if per = 'santi' then
        insert into public.screen_time (person_id, day, app, category, minutes)
        select per, d, v.app, v.cat, greatest(0, round(v.m))::int from (values
          ('Instagram', 'Redes',        social * 0.48 + 4 * rnorm()),
          ('TikTok',    'Redes',        social * 0.34 + 4 * rnorm()),
          ('X',         'Redes',        social * 0.18 + 3 * rnorm()),
          ('WhatsApp',  'Mensajería',   38 + 8 * rnorm()),
          ('Discord',   'Mensajería',   15 + 25 * greatest(exam, 0) + 8 * rnorm()),
          ('YouTube',   'Video',        35 + case when vac then 35 else 0 end + case when wkend then 25 else 0 end + 12 * rnorm()),
          ('Safari',    'Navegación',   22 + 8 * rnorm()),
          ('Gmail',     'Productividad', 8 + 3 * rnorm())
        ) v(app, cat, m) where v.m > 0.5;
      else
        insert into public.screen_time (person_id, day, app, category, minutes)
        select per, d, v.app, v.cat, greatest(0, round(v.m))::int from (values
          ('Instagram', 'Redes',        social * 0.45 + 4 * rnorm()),
          ('TikTok',    'Redes',        social * 0.35 + 4 * rnorm()),
          ('Pinterest', 'Redes',        social * 0.20 + 3 * rnorm()),
          ('WhatsApp',  'Mensajería',   52 + 12 * rnorm()),
          ('Netflix',   'Video',        case when wkend then 75 else 25 end + case when rain then 20 else 0 end + 15 * rnorm()),
          ('Spotify',   'Música',       14 + 5 * rnorm()),
          ('Safari',    'Navegación',   18 + 6 * rnorm()),
          ('Gmail',     'Productividad', case when wkend then 3 else 14 end + 3 * rnorm())
        ) v(app, cat, m) where v.m > 0.5;
      end if;

      -- ánimo
      m_base := 3.05 + 0.55 * q + 0.5 * (sleep_m - 420) / 60.0 + 0.15 * w_p - 0.0045 * (social - 100)
                - case when rain then 0.3 else 0 end + case when wkend then 0.25 else 0 end;
      energy := clamp5(3.0 + 0.85 * (sleep_m - 420) / 60.0 + 0.3 * q + 0.55 * rnorm());
      stress := clamp5(2.6 - 0.45 * q
                       + case when per = 'santi' then 1.1 * greatest(exam, 0) else 0 end
                       + case when per = 'mica' and mica_bad then 0.9 else 0 end
                       - 0.4 * w_p + case when wkend then -0.3 else 0.3 end + 0.6 * rnorm());

      if random() < 0.86 then
        insert into public.mood_entries (person_id, day, slot, mood, energy, feelings, created_at)
          values (per, d, 'manana', clamp5(m_base + 0.55 * rnorm()), energy,
                  case when energy <= 2 then array['cansado'] else '{}' end,
                  (d + make_interval(mins => wake_min + 20 + (random() * 60)::int)) at time zone tz);
      end if;
      if random() < 0.72 then
        insert into public.mood_entries (person_id, day, slot, mood, stress, feelings, created_at)
          values (per, d, 'tarde', clamp5(m_base - 0.15 * (stress - 3) + 0.5 * rnorm()), stress,
                  case when stress >= 4 then array['ansioso'] else '{}' end,
                  (d + make_interval(mins => 990 + (random() * 90)::int)) at time zone tz);
      end if;
      if random() < 0.84 then
        mood_n := clamp5(m_base + 0.5 * rnorm());
        feel := '{}'; infl := '{}';
        if mood_n >= 4 then feel := feel || (array['tranquilo','contento','motivado'])[1 + floor(random() * 3)::int]; end if;
        if mood_n = 5 and not 'contento' = any(feel) then feel := feel || 'contento'::text; end if;
        if energy <= 2 or sleep_m < 360 then feel := feel || 'cansado'::text; end if;
        if stress >= 4 then feel := feel || 'ansioso'::text; end if;
        if mood_n <= 2 then feel := feel || (array['triste','irritable'])[1 + floor(random() * 2)::int]; end if;
        if cardinality(feel) = 0 then feel := array['tranquilo']; end if;
        if sleep_m < 360 or sleep_m > 500 then infl := infl || 'sueño'::text; end if;
        if per = 'santi' and exam > 0.2 and random() < 0.6 then infl := infl || 'facu'::text; end if;
        if per = 'mica' and not wkend and random() < (case when mica_bad then 0.9 else 0.35 end) then infl := infl || 'trabajo'::text; end if;
        if w_p >= 1 and random() < 0.3 then infl := infl || 'perros'::text; end if;
        if rain then infl := infl || 'clima'::text; end if;
        if wkend and random() < 0.45 then infl := infl || 'social'::text; end if;
        if random() < 0.15 then infl := infl || 'pareja'::text; end if;
        if random() < 0.06 then infl := infl || 'salud'::text; end if;
        best := case when random() < (case when mood_n >= 3 then 0.6 else 0.3 end)
                     then best_list[1 + floor(random() * array_length(best_list, 1))::int] end;
        if per = 'santi' and exam > 0.5 and best is not null and random() < 0.4 then best := 'Me salió un ejercicio difícil'; end if;
        insert into public.mood_entries (person_id, day, slot, mood, feelings, influences, best_of_day, created_at)
          values (per, d, 'noche', mood_n, feel, infl, best,
                  (d + make_interval(mins => 1290 + (random() * 70)::int)) at time zone tz);
      end if;

      -- hábitos
      select steps_goal into goal from public.people where id = per;
      for h in select * from public.habits where person_id = per order by sort loop
        continue when not (dow = any(h.days));
        if h.source = 'auto' then
          insert into public.habit_checkins (habit_id, person_id, day, status, answered_at)
            values (h.id, per, d, case when steps_v >= goal then 'si' else 'no' end,
                    (d + time '23:55') at time zone tz);
          continue;
        end if;
        logit := case h.code
          when 's_pastillas'   then 2.4
          when 's_desayuno'    then 1.3 - case when wkend then 0.4 else 0 end
          when 's_agua'        then 0.9
          when 's_estudiar'    then 0.1 + 1.8 * greatest(exam, 0)
          when 's_gym'         then 0.4 - 1.8 * greatest(exam - 0.6, 0) + 0.3 * q
          when 's_celular'     then -0.3 - 0.012 * (social - 100)
          when 'm_pastillas_m' then 2.7
          when 'm_pastillas_n' then 2.0
          when 'm_desayuno'    then 2.0
          when 'm_estirar'     then 0.4 + 0.4 * (sleep_m - 440) / 60.0
          when 'm_almuerzo'    then 1.0
          when 'm_leer'        then 0.5 - 0.009 * (social - 115)
          else 1.0 end + 0.7 * q;
        p := 1 / (1 + exp(-logit));
        r := random();
        if (h.code = 's_estudiar' and vac and random() < 0.75)
           or (h.code = 's_gym' and exam > 0.9 and random() < 0.5)
           or random() < 0.025 then
          st := 'na';
        elsif r < p then st := 'si';
        elsif r < p + (1 - p) * 0.55 then st := 'no';
        else st := null;                      -- sin responder: cuenta como no cumplido
        end if;
        if st is not null then
          ans_min := case h.slot when 'manana' then 510 when 'mediodia' then 765 when 'tarde' then 1110 else 1335 end
                     + (25 * rnorm())::int;
          insert into public.habit_checkins (habit_id, person_id, day, status, answered_at)
            values (h.id, per, d, st, (d + make_interval(mins => ans_min)) at time zone tz);
        end if;
      end loop;
    end loop;
  end loop;

  -- ── Alimento ──
  insert into public.food_purchases (bought_on, kg, bought_by, created_at) values
    (p_end - 82, 15, 'santi', ((p_end - 82) + time '18:30') at time zone tz),
    (p_end - 53, 15, 'mica',  ((p_end - 53) + time '11:10') at time zone tz),
    (p_end - 24, 15, 'santi', ((p_end - 24) + time '19:05') at time zone tz);

  -- ── Tareas de la casa ──
  for c in select * from public.chores loop
    t := v_start - floor(random() * c.every_days)::int;
    loop
      t := t + greatest(1, round(c.every_days + demo.rnorm() * c.every_days * 0.25)::int);
      exit when t >= p_end;
      who := case
        when c.name = 'Sacar la basura' then case when random() < 0.65 then 'santi' else 'mica' end
        when c.name = 'Lavar ropa'      then case when random() < 0.6  then 'mica'  else 'santi' end
        else case when random() < 0.5 then 'mica' else 'santi' end end;
      insert into public.chore_logs (chore_id, done_by, done_at)
        values (c.id, who, (t + make_interval(mins => 600 + (random() * 720)::int)) at time zone tz);
    end loop;
  end loop;

  -- ── Agenda (k negativo = futuro) ──
  insert into public.events (title, starts_at, duration_min, all_day, category, visibility, owner_id, recurrence, notes) values
    ('Antipulgas Mocka y Honey',           ((p_end - 80) + time '10:00') at time zone tz, null, false, 'perros', 'compartido', null, 'FREQ=DAILY;INTERVAL=30', 'Pipeta mediana para Mocka, chica para Honey'),
    ('Antipulgas Mocka y Honey',           ((p_end - 50) + time '10:00') at time zone tz, null, false, 'perros', 'compartido', null, 'FREQ=DAILY;INTERVAL=30', 'Pipeta mediana para Mocka, chica para Honey'),
    ('Antipulgas Mocka y Honey',           ((p_end - 20) + time '10:00') at time zone tz, null, false, 'perros', 'compartido', null, 'FREQ=DAILY;INTERVAL=30', 'Pipeta mediana para Mocka, chica para Honey'),
    ('Antipulgas Mocka y Honey',           ((p_end + 10) + time '10:00') at time zone tz, null, false, 'perros', 'compartido', null, 'FREQ=DAILY;INTERVAL=30', 'Pipeta mediana para Mocka, chica para Honey'),
    ('Vacuna antirrábica Honey',           ((p_end - 60) + time '10:30') at time zone tz, 45,   false, 'perros', 'compartido', 'mica', 'FREQ=YEARLY', 'Llevar la libreta'),
    ('Veterinario Honey · control digestivo', ((p_end - 42) + time '17:30') at time zone tz, 45, false, 'perros', 'compartido', 'santi', null, 'Dos días con caca blanda'),
    ('Desparasitario Mocka y Honey',       ((p_end + 17) + time '09:00') at time zone tz, null, false, 'perros', 'compartido', null, 'FREQ=MONTHLY;INTERVAL=3', null),
    ('Inicio de clases 2C',                ((p_end - 46) + time '18:00') at time zone tz, 240,  false, 'facu',   'personal',   'santi', null, null),
    ('Checkpoint TP Sistemas Operativos',  ((p_end - 6)  + time '23:59') at time zone tz, null, false, 'facu',   'personal',   'santi', null, 'Entrega del grupo'),
    ('1er parcial Análisis Matemático II', ((p_end)      + time '19:00') at time zone tz, 120,  false, 'facu',   'personal',   'santi', null, null),
    ('1er parcial Sistemas Operativos',    ((p_end + 12) + time '19:00') at time zone tz, 120,  false, 'facu',   'personal',   'santi', null, null),
    ('Turno médico clínico',               ((p_end - 30) + time '09:15') at time zone tz, 30,   false, 'salud',  'personal',   'mica',  null, 'Llevar estudios'),
    ('Turno dentista',                     ((p_end + 3)  + time '16:30') at time zone tz, 45,   false, 'salud',  'personal',   'mica',  null, null),
    ('Presentación de fin de mes',         ((p_end - 38) + time '11:00') at time zone tz, 60,   false, 'casa',   'personal',   'mica',  null, 'Trabajo'),
    ('Cumpleaños de Lucas',                ((p_end - 15) + time '21:00') at time zone tz, 180,  false, 'social', 'compartido', null,   'FREQ=YEARLY', 'Llevar vino'),
    ('Cena con amigos',                    ((p_end + 1)  + time '21:00') at time zone tz, 180,  false, 'social', 'compartido', null,   null, 'En casa de Juli'),
    ('Cumpleaños de Sofi',                 ((p_end + 6)  + time '00:00') at time zone tz, null, true,  'social', 'compartido', null,   'FREQ=YEARLY', 'Comprar regalo'),
    ('Service del calefón',                ((p_end - 25) + time '14:00') at time zone tz, 90,   false, 'casa',   'compartido', 'santi', null, null),
    ('Reunión de consorcio',               ((p_end + 9)  + time '19:30') at time zone tz, 60,   false, 'casa',   'compartido', 'mica',  null, null),
    ('Turno médico',                       ((p_end + 20) + time '08:40') at time zone tz, 30,   false, 'salud',  'personal',   'santi', null, 'Pedir la orden antes');

  select count(*) into n_rows from (
    select 1 from public.habit_checkins union all select 1 from public.mood_entries
    union all select 1 from public.health_daily union all select 1 from public.screen_time
    union all select 1 from public.walks union all select 1 from public.walk_dogs
    union all select 1 from public.dog_meals union all select 1 from public.chore_logs
    union all select 1 from public.events) x;

  return format('Datos de prueba generados: %s a %s (%s filas)', v_start, p_end, n_rows);
end $$;

revoke all on function demo.seed(date, int) from public, anon, authenticated;
revoke all on function demo.rnorm() from public, anon, authenticated;
revoke all on function demo.clamp5(double precision) from public, anon, authenticated;
