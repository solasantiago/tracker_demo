import { useEffect, useRef } from 'react';

export function Avatar({ person, size = 'md' }) {
  if (!person) return null;
  return (
    <span className={`avatar ${size}`} data-person={person.id} aria-hidden="true">
      {person.short_name.slice(0, 1)}
    </span>
  );
}

export function Segmented({ options, value, onChange, label, size }) {
  return (
    <div className={`segmented ${size ?? ''}`} role="radiogroup" aria-label={label}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={value === o.value}
          className={value === o.value ? 'on' : ''}
          onClick={() => onChange(o.value)}
          data-person={o.person}
        >
          {o.icon ? <span aria-hidden="true">{o.icon}</span> : null}
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** "¿Quién lo hizo?" — en el iPad hay que elegir; en el celular ya viene la persona. */
export function WhoPicker({ people, value, onChange }) {
  return (
    <Segmented
      label="Quién"
      value={value}
      onChange={onChange}
      options={people.map((p) => ({ value: p.id, label: p.short_name, person: p.id }))}
    />
  );
}

export function Chip({ children, tone = 'neutral', icon }) {
  return (
    <span className={`chip ${tone}`}>
      {icon ? <span aria-hidden="true">{icon}</span> : null}
      {children}
    </span>
  );
}

export function Card({ title, subtitle, actions, children, className = '', as: Tag = 'section' }) {
  return (
    <Tag className={`card ${className}`}>
      {title || actions ? (
        <header className="card-head">
          <div>
            {title ? <h3>{title}</h3> : null}
            {subtitle ? <p className="card-sub">{subtitle}</p> : null}
          </div>
          {actions ? <div className="card-actions">{actions}</div> : null}
        </header>
      ) : null}
      {children}
    </Tag>
  );
}

export function SectionTitle({ children, sub }) {
  return (
    <div className="section-title">
      <h2>{children}</h2>
      {sub ? <p>{sub}</p> : null}
    </div>
  );
}

export function Empty({ children }) {
  return <p className="empty">{children}</p>;
}

/** Diálogo modal nativo. */
export function Dialog({ open, onClose, title, children, footer }) {
  const ref = useRef(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal?.();
    if (!open && d.open) d.close?.();
  }, [open]);
  return (
    <dialog ref={ref} className="dialog" onClose={onClose} onCancel={onClose}>
      <form method="dialog" className="dialog-inner" onSubmit={(e) => e.preventDefault()}>
        <header className="dialog-head">
          <h3>{title}</h3>
          <button type="button" className="btn ghost icon" aria-label="Cerrar" onClick={onClose}>
            ✕
          </button>
        </header>
        <div className="dialog-body">{children}</div>
        {footer ? <footer className="dialog-foot">{footer}</footer> : null}
      </form>
    </dialog>
  );
}
