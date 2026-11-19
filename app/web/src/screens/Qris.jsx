import { useEffect, useRef, useState } from 'react';
import { useI18n, formatIDR, maskAccount } from '../i18n.js';
import { api, getActiveAccount, getScenario, saveReceipt } from '../api.js';
import AmountInput from '../components/AmountInput.jsx';
import PinPad from '../components/PinPad.jsx';
import { Icon } from '../components/MenuGrid.jsx';
import { ErrorNote } from '../components/DemoBanner.jsx';
import { endJourney, startJourney } from '../telemetry.js';

const Steps = ({ labels, current }) => (
  <div className="steps">
    {labels.map((label, i) => <div key={label} className={'step' + (i + 1 === current ? ' active' : '')}>{i + 1}. {label}</div>)}
  </div>
);

// Simulated QRIS scan: pick a demo merchant -> amount -> confirm -> PIN.
// v1.4: opening the screen starts a "qris" journey; the receipt (or a failed load) ends it.
export default function Qris({ customer, navigate }) {
  const { t } = useI18n();
  const [step, setStep] = useState(1);
  const [merchants, setMerchants] = useState([]);
  const [own, setOwn] = useState([]);
  const [from, setFrom] = useState(getActiveAccount() || '');
  const [merchant, setMerchant] = useState(null);
  const [amount, setAmount] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const journeyStarted = useRef(false);

  useEffect(() => {
    if (journeyStarted.current) return;
    journeyStarted.current = true;
    startJourney('qris');
  }, []);

  useEffect(() => {
    Promise.all([api.merchants(), api.accounts(customer.customerId)]).then(([list, mine]) => {
      if (list.error || mine.error) {
        const failed = list.error ? list : mine;
        setError(failed);
        endJourney('qris', { success: false, failedStep: 'load', traceId: failed.traceId, errorCode: failed.code, httpStatus: failed.status });
        return;
      }
      setMerchants(list.data);
      setOwn(mine.data);
      setFrom((current) => (mine.data.some((a) => a.accountNo === current) ? current : (mine.data[0] ? mine.data[0].accountNo : '')));
    });
  }, [customer.customerId]);

  const fromAccount = own.find((a) => a.accountNo === from);
  const scenario = getScenario();

  const goConfirm = () => {
    if (!amount) { setError({ error: t('amountRequired') }); return; }
    setError(null);
    setStep(3);
  };

  const pay = async (pin) => {
    setBusy(true);
    setError(null);
    const r = await api.qrisPay({ fromAccount: from, merchantId: merchant.merchantId, amount, pin });
    setBusy(false);
    if (r.error && r.code === 'WRONG_PIN') { setError({ error: t('wrongPin') }); return; }
    endJourney('qris', r.error
      ? { success: false, failedStep: 'payment', amountIdr: amount, traceId: r.traceId, errorCode: r.code, httpStatus: r.status }
      : { success: true, amountIdr: amount, traceId: r.traceId });
    saveReceipt(r.error
      ? { ok: false, channel: 'QRIS', error: r.error, traceId: r.traceId, amount, counterparty: merchant.name,
        referenceNo: r.detail && r.detail.referenceNo, createdAt: new Date().toISOString() }
      : { ok: true, ...r.data, counterparty: merchant.name });
    navigate('/receipt');
  };

  return (
    <div className="card" data-testid="qris" data-step={step}>
      <h1 className="title">{t('scanTitle')}</h1>
      <Steps labels={[t('merchant'), t('amount'), t('stepConfirm'), t('stepPin')]} current={step} />
      {step === 1 && (
        <>
          <div className="scan-frame"><Icon name="qris" size={96} /></div>
          <p className="muted center">{t('scanHint')}</p>
          <ErrorNote error={error} />
          <ul className="list">
            {merchants.map((m) => (
              <li key={m.merchantId}>
                <button type="button" className="list-button" onClick={() => { setMerchant(m); setStep(2); }}
                  data-testid={'qris-merchant-' + m.merchantId}>
                  <span>{m.name}</span>
                  <span className="muted">{m.city}</span>
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
      {step === 2 && merchant && (
        <>
          <p className="subtitle">{merchant.name}</p>
          <label className="field">
            <span>{t('fromAccount')}</span>
            <select value={from} onChange={(e) => setFrom(e.target.value)} data-testid="qris-from">
              {own.map((a) => (
                <option key={a.accountNo} value={a.accountNo}>{a.productName} – {maskAccount(a.accountNo)} – {formatIDR(a.balance)}</option>
              ))}
            </select>
          </label>
          <AmountInput value={amount} onChange={setAmount} />
          <ErrorNote error={error} />
          <div className="button-row">
            <button type="button" className="pill-button secondary" onClick={() => setStep(1)}>{t('back')}</button>
            <button type="button" className="pill-button" onClick={goConfirm} data-testid="qris-next">{t('next')}</button>
          </div>
        </>
      )}
      {step === 3 && merchant && (
        <>
          <table className="summary">
            <tbody>
              <tr><td>{t('merchant')}</td><td>{merchant.name}</td></tr>
              <tr><td>{t('fromAccount')}</td><td>{fromAccount ? fromAccount.productName + ' – ' + maskAccount(fromAccount.accountNo) : '-'}</td></tr>
              <tr><td>{t('amount')}</td><td>{formatIDR(amount)}</td></tr>
              {scenario !== 'normal' && <tr><td>{t('scenario')}</td><td>{scenario}</td></tr>}
            </tbody>
          </table>
          <div className="button-row">
            <button type="button" className="pill-button secondary" onClick={() => setStep(2)}>{t('back')}</button>
            <button type="button" className="pill-button" onClick={() => setStep(4)} data-testid="qris-pay">{t('pay')}</button>
          </div>
        </>
      )}
      {step === 4 && merchant && (
        <>
          <PinPad onComplete={pay} busy={busy} error={error && error.error} />
          <button type="button" className="pill-button secondary" disabled={busy} onClick={() => { setError(null); setStep(3); }}>
            {t('back')}
          </button>
        </>
      )}
    </div>
  );
}
