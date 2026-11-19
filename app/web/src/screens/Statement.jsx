import { useEffect, useRef, useState } from 'react';
import { useI18n, formatIDR, formatDateTimeWIB, maskAccount } from '../i18n.js';
import { api, getActiveAccount, setActiveAccount } from '../api.js';
import { ErrorNote } from '../components/DemoBanner.jsx';
import { endJourney, startJourney } from '../telemetry.js';

// Account numbers are masked; merchant names are shown as they are.
const counterpartyText = (value) => (/^\d{10}$/.test(value || '') ? maskAccount(value) : value || '-');

export function TransactionList({ entries }) {
  const { t, lang } = useI18n();
  if (!entries.length) return <p className="muted">{t('noTransactions')}</p>;
  return (
    <ul className="list">
      {entries.map((e, i) => (
        <li key={e.referenceNo + e.direction + i} className="tx">
          <span className="tx-main">
            <span>{e.channel} · {counterpartyText(e.counterparty)}</span>
            <span className="tx-date">{formatDateTimeWIB(e.createdAt, lang)} · {e.referenceNo}</span>
          </span>
          <span className={'tx-amount ' + (e.direction === 'D' ? 'debit' : 'credit')}>
            {formatIDR(e.amount)} {e.direction === 'D' ? t('debit') : t('credit')}
          </span>
        </li>
      ))}
    </ul>
  );
}

// Statement of the last 30 days (GET /api/accounts/{accountNo}/statement?days=30 -> Java -> Oracle).
// v1.4: opening the screen starts a "statement" journey; the first statement result (or a failed load) ends it.
export default function Statement({ customer }) {
  const { t } = useI18n();
  const [accounts, setAccounts] = useState([]);
  const [account, setAccount] = useState(getActiveAccount() || '');
  const [result, setResult] = useState(null); // null = loading
  const journey = useRef('new'); // new -> open -> done

  const finishJourney = (r, failedStep) => {
    if (journey.current !== 'open') return;
    journey.current = 'done';
    endJourney('statement', r.error
      ? { success: false, failedStep, traceId: r.traceId, errorCode: r.code, httpStatus: r.status }
      : { success: true, traceId: r.traceId });
  };

  useEffect(() => {
    if (journey.current !== 'new') return;
    journey.current = 'open';
    startJourney('statement');
  }, []);

  useEffect(() => {
    api.accounts(customer.customerId).then((r) => {
      if (r.error) { setResult({ error: r }); finishJourney(r, 'load'); return; }
      setAccounts(r.data);
      setAccount((current) => (r.data.some((a) => a.accountNo === current) ? current : (r.data[0] ? r.data[0].accountNo : '')));
    });
  }, [customer.customerId]);

  useEffect(() => {
    if (!account) return undefined;
    let cancelled = false;
    setActiveAccount(account);
    setResult(null);
    api.statement(account, 30).then((r) => {
      if (cancelled) return;
      setResult(r.error ? { error: r } : { entries: r.data.entries || [] });
      finishJourney(r, 'statement');
    });
    return () => { cancelled = true; };
  }, [account]);

  return (
    <div className="stack">
      <div className="card">
        <h1 className="title">{t('statement')}</h1>
        <p className="muted">{t('last30')}</p>
        <label className="field">
          <span>{t('account')}</span>
          <select value={account} onChange={(e) => setAccount(e.target.value)} data-testid="statement-account">
            {accounts.map((a) => (
              <option key={a.accountNo} value={a.accountNo}>{a.productName} – {maskAccount(a.accountNo)}</option>
            ))}
          </select>
        </label>
      </div>
      <div className="card" data-testid="statement-result" data-status={result === null ? 'loading' : result.error ? 'error' : 'ready'}
        data-trace-id={(result && result.error && result.error.traceId) || ''}>
        {result === null && <p className="muted">{t('loading')}</p>}
        {result && result.error && <ErrorNote error={result.error} />}
        {result && result.entries && <TransactionList entries={result.entries} />}
      </div>
    </div>
  );
}
