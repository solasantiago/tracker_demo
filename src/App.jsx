import { useEffect, useMemo, useState } from 'react';
import { AppCtx } from './lib/appctx.js';
import { DataProvider, ToastProvider, useData } from './lib/data.jsx';
import { addDays, fmtDayLong, fmtDayShort, range, todayISO } from './lib/dates.js';
import { Segmented } from './components/ui.jsx';
import Today from './views/Today.jsx';
import Habits from './views/Habits.jsx';
import Wellbeing from './views/Wellbeing.jsx';
import Dogs from './views/Dogs.jsx';
import HomeAgenda from './views/HomeAgenda.jsx';
import Analysis from './views/Analysis.jsx';

const TABS = [
  { id: 'hoy', label: 'Hoy', icon: '☀️', shared: true, View: Today },
  { id: 'habitos', label: 'Hábitos', icon: '✅', period: true, View: Habits },
  { id: 'bienestar', label: 'Bienestar', icon: '🌿', period: true, View: Wellbeing },
  { id: 'perros', label: 'Perros', icon: '🐾', shared: true, period: true, View: Dogs },
  { id: 'casa', label: 'Agenda y casa', icon: '🏠', shared: true, View: HomeAgenda },
  { id: 'analisis', label: 'Análisis', icon: '🔍', period: true, View: Analysis },
];

const PERIODS = [
  { value: 7, label: '7 días' },
  { value: 30, label: '30 días' },
  { value: 90, label: '90 días' },
];

function readStore(key, fallback) {
  try {
    const v = window.localStorage.getItem(key);
    return v == null ? fallback : JSON.parse(v);
  } catch {
    return fallback;
  }
}

function usePersisted(key, initial) {
  const [v, setV] = useState(() => readStore(key, initial));
  useEffect(() => {
    try {
      window.localStorage.setItem(key, JSON.stringify(v));
    } catch {
      /* navegación privada: se ignora */
    }
  }, [key, v]);
  return [v, setV];
}

function useHashTab() {
  const read = () => (typeof window === 'undefined' ? 'hoy' : window.location.hash.replace(/^#\/?/, '') || 'hoy');
  const [tab, setTab] = useState(read);
  useEffect(() => {
    const on = () => setTab(read());
    window.addEventListener('hashchange', on);
    return () => window.removeEventListener('hashchange', on);
  }, []);
  const go = (id) => {
    if (window.location.hash !== `#${id}`) window.location.hash = id;
    setTab(id);
    window.scrollTo({ top: 0 });
  };
  return [tab, go];
}

function useNow() {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 60000);
    return () => clearInterval(t);
  }, []);
  return now;
}

export default function App() {
  return (
    <DataProvider>
      <ToastProvider>
        <Shell />
      </ToastProvider>
    </DataProvider>
  );
}

function Shell() {
  const { status, error, model, live, retry } = useData();
  const [person, setPerson] = usePersisted('tracker.person', 'santi');
  const [period, setPeriod] = usePersisted('tracker.period', 30);
  const [tabId, go] = useHashTab();
  const now = useNow();
  const today = todayISO(new Date(now));

  const tabs = person === 'casa' ? TABS.filter((t) => t.shared) : TABS;
  const tab = tabs.find((t) => t.id === tabId) ?? tabs[0];

  const ctx = useMemo(() => {
    const start = addDays(today, -(period - 1));
    return {
      person,
      today,
      now,
      period,
      days: range(start, today),
      prevDays: range(addDays(start, -period), addDays(start, -1)),
      start,
      go,
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [person, today, now, period]);

  const personOptions = [
    ...(model?.people ?? [
      { id: 'mica', short_name: 'Mica' },
      { id: 'santi', short_name: 'Santi' },
    ]).map((p) => ({ value: p.id, label: p.short_name, person: p.id })),
    { value: 'casa', label: 'Casa', icon: '🏡 ', person: 'casa' },
  ];

  return (
    <AppCtx.Provider value={ctx}>
      <div className="app" data-person={person}>
        <header className="topbar">
          <div className="brand">
            <span className="brand-mark" aria-hidden="true">
              🏡
            </span>
            <div>
              <h1>Tracker Hub</h1>
              <p className="brand-date">{fmtDayLong(today)}</p>
            </div>
          </div>
          <div className="topbar-right">
            <span className={`live ${live ? 'on' : ''}`} title={live ? 'Sincronizado en tiempo real' : 'Sin tiempo real'}>
              <span className="live-dot" aria-hidden="true" />
              {live ? 'En vivo' : 'Sin conexión en vivo'}
            </span>
            <Segmented label="Quién está usando la app" options={personOptions} value={person} onChange={setPerson} />
          </div>
        </header>

        <nav className="tabs" aria-label="Secciones">
          {tabs.map((t) => (
            <a
              key={t.id}
              href={`#${t.id}`}
              className={t.id === tab.id ? 'on' : ''}
              aria-current={t.id === tab.id ? 'page' : undefined}
              onClick={(e) => {
                e.preventDefault();
                go(t.id);
              }}
            >
              <span aria-hidden="true">{t.icon}</span>
              {t.label}
            </a>
          ))}
        </nav>

        <main className="main">
          {status === 'loading' ? (
            <div className="state">
              <span className="state-icon" aria-hidden="true">
                🐾
              </span>
              <p>Cargando los datos de la casa…</p>
            </div>
          ) : status === 'error' ? (
            <div className="state error">
              <span className="state-icon" aria-hidden="true">
                🔌
              </span>
              <p>No pudimos conectarnos con la base de datos.</p>
              <p className="muted small">{error?.message}</p>
              <button type="button" className="btn" onClick={retry}>
                Reintentar
              </button>
            </div>
          ) : (
            <>
              {tab.period ? (
                <div className="filters">
                  <Segmented label="Período" options={PERIODS} value={period} onChange={setPeriod} size="sm" />
                  <span className="filters-range">
                    {fmtDayShort(ctx.days[0])} – {fmtDayShort(today)}
                  </span>
                </div>
              ) : null}
              <tab.View key={`${tab.id}-${person}`} />
            </>
          )}
        </main>

        <footer className="foot">
          <p>
            Prueba de concepto con <strong>datos de ejemplo</strong> (3 meses simulados). Sin login: cualquiera con el link puede ver y cargar.
          </p>
        </footer>
      </div>
    </AppCtx.Provider>
  );
}
