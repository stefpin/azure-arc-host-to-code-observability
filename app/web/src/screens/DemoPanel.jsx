import { useState } from 'react';
import { useI18n, SCENARIOS } from '../i18n.js';
import { getScenario, setScenario } from '../api.js';

// Presenter page #/demo: choose one of the 9 scenarios; stored in sessionStorage "minibank.scenario" (this tab only).
export default function DemoPanel({ customer, navigate, onScenarioChange }) {
  const { t } = useI18n();
  const [selected, setSelected] = useState(getScenario());
  const [message, setMessage] = useState('');

  const apply = (value) => {
    setScenario(value);
    setSelected(value);
    onScenarioChange();
    setMessage(t('applied', { name: value }));
  };

  return (
    <div className="card">
      <h1 className="title">{t('presenter')}</h1>
      <p className="muted">{t('scenarioNote')}</p>
      <div role="radiogroup" aria-label={t('scenario')}>
        {SCENARIOS.map((s) => (
          <label key={s} className="scenario-option">
            <input type="radio" name="scenario" value={s} checked={selected === s} onChange={() => setSelected(s)} />
            <span>
              <span className="scenario-name">{s}</span><br />
              <span className="muted">{t('sc_' + s)}</span>
            </span>
          </label>
        ))}
      </div>
      {message && <p className="notice">{message}</p>}
      <div className="button-row">
        <button type="button" className="pill-button secondary" onClick={() => apply('normal')}>{t('reset')}</button>
        <button type="button" className="pill-button" onClick={() => apply(selected)}>{t('apply')}</button>
      </div>
      <button type="button" className="link-button" onClick={() => navigate(customer ? '/home' : '/login')}>{t('goHome')}</button>
    </div>
  );
}
