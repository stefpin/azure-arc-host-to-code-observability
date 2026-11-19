import { useState } from 'react';
import { useI18n, formatIDR, maskAccount } from '../i18n.js';
import { Icon } from './MenuGrid.jsx';

// Active account: masked number, balance hidden behind the eye button, links Statement / Other accounts.
export default function AccountCard({ account, accounts, onSelectAccount, onStatement }) {
  const { t } = useI18n();
  const [visible, setVisible] = useState(false);
  const [showOthers, setShowOthers] = useState(false);
  if (!account) return <div className="card muted">{t('loading')}</div>;
  const others = (accounts || []).filter((a) => a.accountNo !== account.accountNo);

  return (
    <div className="card">
      <div className="account-product">{account.productName}</div>
      <div className="account-no">{maskAccount(account.accountNo)}</div>
      <div className="balance-row">
        <span className="muted">{t('balance')}</span>
        <span className="balance">{visible ? formatIDR(account.balance) : 'IDR ••••••••'}</span>
        <button type="button" className="icon-button" onClick={() => setVisible(!visible)}
          aria-label={visible ? t('hideBalance') : t('showBalance')} title={visible ? t('hideBalance') : t('showBalance')}>
          <Icon name={visible ? 'eye-off' : 'eye'} size={20} />
        </button>
      </div>
      <div className="account-links">
        <button type="button" className="link-button" onClick={onStatement}>{t('statement')}</button>
        <button type="button" className="link-button" onClick={() => setShowOthers(!showOthers)}>{t('otherAccounts')}</button>
      </div>
      {showOthers && (
        <ul className="list">
          {others.map((a) => (
            <li key={a.accountNo}>
              <button type="button" className="list-button"
                onClick={() => { setShowOthers(false); setVisible(false); onSelectAccount(a.accountNo); }}>
                <span>{a.productName}</span>
                <span className="muted">{maskAccount(a.accountNo)}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
