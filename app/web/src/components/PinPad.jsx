import { useState } from 'react';
import { useI18n } from '../i18n.js';

// 6-digit PIN pad. The demo PIN is 123456 (checked by minibank-api).
const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];

export default function PinPad({ onComplete, busy, error }) {
  const { t } = useI18n();
  const [pin, setPin] = useState('');

  const press = (key) => {
    if (busy) return;
    if (key === 'del') { setPin(pin.slice(0, -1)); return; }
    const next = (pin + key).slice(0, 6);
    if (next.length === 6) { setPin(''); onComplete(next); } else { setPin(next); }
  };

  return (
    <div className="pinpad" data-testid="pinpad">
      <p className="pin-title">{t('enterPin')}</p>
      <div className="pin-dots" aria-label="PIN">
        {[0, 1, 2, 3, 4, 5].map((i) => <span key={i} className={'pin-dot' + (i < pin.length ? ' filled' : '')} />)}
      </div>
      {error && <p className="error-text">{error}</p>}
      {busy && <p className="muted">{t('processing')}</p>}
      <div className="keypad">
        {KEYS.map((key, i) => (key === '' ? <span key={i} /> : (
          <button key={i} type="button" className="key" disabled={busy} onClick={() => press(key)}
            aria-label={key === 'del' ? 'Delete' : key} data-testid={'pin-key-' + key}>
            {key === 'del' ? '⌫' : key}
          </button>
        )))}
      </div>
      <p className="hint">{t('demoPin')}</p>
    </div>
  );
}
