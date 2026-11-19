import { useState } from 'react';
import { useI18n, formatIDR, formatDateTimeWIB } from '../i18n.js';
import { loadReceipt } from '../api.js';
import { Icon } from '../components/MenuGrid.jsx';

// http:// pages (lab) have no clipboard API, so fall back to a hidden text area.
function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
  const area = document.createElement('textarea');
  area.value = text;
  document.body.appendChild(area);
  area.select();
  document.execCommand('copy');
  document.body.removeChild(area);
  return Promise.resolve();
}

// Success: reference no, date/time WIB, amount, status. Failure: big Trace ID for Application Insights.
export default function Receipt({ navigate }) {
  const { t, lang } = useI18n();
  const [copied, setCopied] = useState(false);
  const r = loadReceipt();
  if (!r) {
    return (
      <div className="card" data-testid="receipt" data-status="none">
        <p>{t('noReceipt')}</p>
        <button type="button" className="pill-button" onClick={() => navigate('/home')}>{t('backHome')}</button>
      </div>
    );
  }

  return (
    <div className="card" data-testid="receipt" data-status={r.ok ? 'ok' : 'fail'} data-trace-id={r.traceId || ''}>
      <div className={'receipt-icon ' + (r.ok ? 'ok' : 'fail')}><Icon name={r.ok ? 'check' : 'cross'} size={64} /></div>
      <h1 className="receipt-title">{r.ok ? t('success') : t('failed')}</h1>
      <table className="summary">
        <tbody>
          {r.referenceNo && <tr><td>{t('referenceNo')}</td><td>{r.referenceNo}</td></tr>}
          <tr><td>{t('dateTime')}</td><td>{formatDateTimeWIB(r.createdAt, lang)}</td></tr>
          <tr><td>{r.channel === 'QRIS' ? t('merchant') : t('to')}</td><td>{r.counterparty || '-'}</td></tr>
          <tr><td>{t('amount')}</td><td>{formatIDR(r.amount)}</td></tr>
          <tr><td>{t('status')}</td><td className={r.ok ? 'ok-text' : 'error-text'}>{r.ok ? r.status : 'FAILED'}</td></tr>
          {r.ok && r.fraudDecision && <tr><td>{t('fraudCheck')}</td><td>{r.fraudDecision}</td></tr>}
        </tbody>
      </table>
      {!r.ok && (
        <>
          <p className="error-text">{r.error}</p>
          <div className="trace-box">
            <div className="muted">{t('traceId')}</div>
            <div className="trace-id" data-testid="receipt-trace-id">{r.traceId || 'n/a'}</div>
            <p className="hint">{t('traceHint')}</p>
            {r.traceId && (
              <button type="button" className="pill-button secondary" onClick={() => copyText(r.traceId).then(() => setCopied(true))}>
                {copied ? t('copied') : t('copy')}
              </button>
            )}
          </div>
        </>
      )}
      {r.ok && r.traceId && <p className="trace-small">{t('traceId')}: {r.traceId}</p>}
      <button type="button" className="pill-button" onClick={() => navigate('/home')} data-testid="receipt-home">{t('backHome')}</button>
    </div>
  );
}
