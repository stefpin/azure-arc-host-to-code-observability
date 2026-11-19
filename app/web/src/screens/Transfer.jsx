import { useEffect, useRef, useState } from 'react';
import { useI18n, formatIDR, maskAccount } from '../i18n.js';
import { api, getActiveAccount, getScenario, saveReceipt } from '../api.js';
import AmountInput from '../components/AmountInput.jsx';
import PinPad from '../components/PinPad.jsx';
import { ErrorNote } from '../components/DemoBanner.jsx';
import { endJourney, startJourney } from '../telemetry.js';

const Steps = ({ labels, current }) => (
  <div className="steps">
    {labels.map((label, i) => <div key={label} className={'step' + (i + 1 === current ? ' active' : '')}>{i + 1}. {label}</div>)}
  </div>
);

// Transfer in 3 steps: details -> confirm -> PIN. The destination is another demo account.
// v1.4: opening the screen starts a "transfer" journey; the receipt (or a failed load) ends it.
export default function Transfer({ customer, navigate }) {
  const { t } = useI18n();
  const [step, setStep] = useState(1);
  const [own, setOwn] = useState([]);
  const [all, setAll] = useState([]);
  const [from, setFrom] = useState(getActiveAccount() || '');
  const [to, setTo] = useState('');
  const [amount, setAmount] = useState(0);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const journeyStarted = useRef(false);

  useEffect(() => {
    if (journeyStarted.current) return;
    journeyStarted.current = true;
    startJourney('transfer');
  }, []);

  useEffect(() => {
    Promise.all([api.accounts(customer.customerId), api.allAccounts()]).then(([mine, everyone]) => {
      if (mine.error || everyone.error) {
        const failed = mine.error ? mine : everyone;
        setError(failed);
        endJourney('transfer', { success: false, failedStep: 'load', traceId: failed.traceId, errorCode: failed.code, httpStatus: failed.status });
        return;
      }
      setOwn(mine.data);
      setAll(everyone.data);
      setFrom((current) => (mine.data.some((a) => a.accountNo === current) ? current : (mine.data[0] ? mine.data[0].accountNo : '')));
    });
  }, [customer.customerId]);

  const fromAccount = own.find((a) => a.accountNo === from);
  const toAccount = all.find((a) => a.accountNo === to);
  const toLabel = toAccount ? toAccount.ownerName + ' – ' + maskAccount(toAccount.accountNo) : '';
  const scenario = getScenario();

  const goConfirm = () => {
    if (!toAccount) { setError({ error: t('chooseAccount') }); return; }
    if (!amount) { setError({ error: t('amountRequired') }); return; }
    setError(null);
    setStep(2);
  };

  const send = async (pin) => {
    setBusy(true);
    setError(null);
    const r = await api.transfer({ fromAccount: from, toAccount: to, amount, note, pin });
    setBusy(false);
    if (r.error && r.code === 'WRONG_PIN') { setError({ error: t('wrongPin') }); return; }
    endJourney('transfer', r.error
      ? { success: false, failedStep: 'payment', amountIdr: amount, traceId: r.traceId, errorCode: r.code, httpStatus: r.status }
      : { success: true, amountIdr: amount, traceId: r.traceId });
    saveReceipt(r.error
      ? { ok: false, channel: 'TRANSFER', error: r.error, traceId: r.traceId, amount, counterparty: toLabel,
        referenceNo: r.detail && r.detail.referenceNo, createdAt: new Date().toISOString() }
      : { ok: true, ...r.data, counterparty: toLabel });
    navigate('/receipt');
  };

  return (
    <div className="card" data-testid="transfer" data-step={step}>
      <h1 className="title">{t('transfer')}</h1>
      <Steps labels={[t('stepDetails'), t('stepConfirm'), t('stepPin')]} current={step} />
      {step === 1 && (
        <>
          <label className="field">
            <span>{t('fromAccount')}</span>
            <select value={from} onChange={(e) => { setFrom(e.target.value); setTo(''); }} data-testid="transfer-from">
              {own.map((a) => (
                <option key={a.accountNo} value={a.accountNo}>{a.productName} – {maskAccount(a.accountNo)} – {formatIDR(a.balance)}</option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>{t('toAccount')}</span>
            <select value={to} onChange={(e) => setTo(e.target.value)} data-testid="transfer-to">
              <option value="">{t('chooseAccount')}</option>
              {all.filter((a) => a.accountNo !== from).map((a) => (
                <option key={a.accountNo} value={a.accountNo}>{a.ownerName} – {maskAccount(a.accountNo)}</option>
              ))}
            </select>
          </label>
          <AmountInput value={amount} onChange={setAmount} />
          <label className="field">
            <span>{t('note')}</span>
            <input value={note} maxLength={50} onChange={(e) => setNote(e.target.value)} data-testid="transfer-note" />
          </label>
          <ErrorNote error={error} />
          <button type="button" className="pill-button" onClick={goConfirm} data-testid="transfer-next">{t('next')}</button>
        </>
      )}
      {step === 2 && (
        <>
          <table className="summary">
            <tbody>
              <tr><td>{t('fromAccount')}</td><td>{fromAccount ? fromAccount.productName + ' – ' + maskAccount(fromAccount.accountNo) : '-'}</td></tr>
              <tr><td>{t('toAccount')}</td><td>{toLabel}</td></tr>
              <tr><td>{t('amount')}</td><td>{formatIDR(amount)}</td></tr>
              {note && <tr><td>{t('note')}</td><td>{note}</td></tr>}
              {scenario !== 'normal' && <tr><td>{t('scenario')}</td><td>{scenario}</td></tr>}
            </tbody>
          </table>
          <div className="button-row">
            <button type="button" className="pill-button secondary" onClick={() => setStep(1)}>{t('back')}</button>
            <button type="button" className="pill-button" onClick={() => setStep(3)} data-testid="transfer-confirm">{t('confirm')}</button>
          </div>
        </>
      )}
      {step === 3 && (
        <>
          <PinPad onComplete={send} busy={busy} error={error && error.error} />
          <button type="button" className="pill-button secondary" disabled={busy} onClick={() => { setError(null); setStep(2); }}>
            {t('back')}
          </button>
        </>
      )}
    </div>
  );
}
