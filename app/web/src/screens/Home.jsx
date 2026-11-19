import { useEffect, useState } from 'react';
import { useI18n } from '../i18n.js';
import { api, getActiveAccount, setActiveAccount } from '../api.js';
import AccountCard from '../components/AccountCard.jsx';
import MenuGrid from '../components/MenuGrid.jsx';
import { ErrorNote } from '../components/DemoBanner.jsx';
import { TransactionList } from './Statement.jsx';

// Blue greeting band, account card, menu and the last 3 transactions of the active account.
export default function Home({ customer, navigate }) {
  const { t } = useI18n();
  const [accounts, setAccounts] = useState([]);
  const [active, setActive] = useState(getActiveAccount() || '');
  const [error, setError] = useState(null);
  const [recent, setRecent] = useState(null); // null = loading

  useEffect(() => {
    api.accounts(customer.customerId).then((r) => {
      if (r.error) { setError(r); return; }
      setAccounts(r.data);
      setActive((current) => (r.data.some((a) => a.accountNo === current) ? current : (r.data[0] ? r.data[0].accountNo : '')));
    });
  }, [customer.customerId]);

  useEffect(() => {
    if (!active) return undefined;
    let cancelled = false;
    setActiveAccount(active);
    setRecent(null);
    api.statement(active, 30).then((r) => {
      if (!cancelled) setRecent(r.error ? { error: r } : { entries: (r.data.entries || []).slice(0, 3) });
    });
    return () => { cancelled = true; };
  }, [active]);

  return (
    <div className="stack">
      <div className="greeting" data-testid="home-greeting">{t('hello', { name: customer.fullName.toUpperCase() })}</div>
      <ErrorNote error={error} />
      <AccountCard account={accounts.find((a) => a.accountNo === active)} accounts={accounts}
        onSelectAccount={setActive} onStatement={() => navigate('/statement')} />
      <MenuGrid onSelect={navigate} />
      <div className="card" data-testid="home-recent" data-status={recent === null ? 'loading' : recent.error ? 'error' : 'ready'}>
        <h2 className="subtitle">{t('lastTransactions')}</h2>
        {recent === null && <p className="muted">{t('loading')}</p>}
        {recent && recent.error && <ErrorNote error={recent.error} />}
        {recent && recent.entries && <TransactionList entries={recent.entries} />}
      </div>
    </div>
  );
}
