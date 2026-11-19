import { useI18n, formatIDR } from '../i18n.js';

// Amount entry with its own number pad and a "000" key; the amount is shown as "IDR 1.250.000".
const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', 'del'];

export default function AmountInput({ value, onChange }) {
  const { t } = useI18n();
  const digits = value ? String(value) : '';

  const press = (key) => {
    let next;
    if (key === 'del') next = digits.slice(0, -1);
    else if (digits === '' && (key === '0' || key === '000')) next = ''; // no leading zeros
    else next = digits + key;
    if (next.length > 9) return; // up to IDR 999.999.999 (the API accepts up to 500.000.000)
    onChange(next ? Number(next) : 0);
  };

  return (
    <div>
      <div className="muted">{t('amount')}</div>
      <div className="amount-display" data-testid="amount-display">{formatIDR(value || 0)}</div>
      <div className="keypad">
        {KEYS.map((key) => (
          <button key={key} type="button" className="key" onClick={() => press(key)} aria-label={key === 'del' ? 'Delete' : key}
            data-testid={'amount-key-' + key}>
            {key === 'del' ? '⌫' : key}
          </button>
        ))}
      </div>
    </div>
  );
}
