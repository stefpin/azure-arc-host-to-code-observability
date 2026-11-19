import { useState } from 'react';
import { useI18n } from '../i18n.js';
import { api } from '../api.js';
import { Icon } from '../components/MenuGrid.jsx';
import { ErrorNote } from '../components/DemoBanner.jsx';

// "Hello, Welcome!" card: User ID + password (show/hide), pill Login button, Instant Access row.
export default function Login({ onLogin }) {
  const { t } = useI18n();
  const [userId, setUserId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState('');

  const submit = async (event) => {
    event.preventDefault();
    setBusy(true);
    setError(null);
    const result = await api.login(userId.trim().toUpperCase(), password);
    setBusy(false);
    if (result.error) setError(result);
    else onLogin(result.data);
  };

  return (
    <div className="stack">
      <form className="card" onSubmit={submit}>
        <h1 className="title">{t('welcome')}</h1>
        <p className="muted">{t('loginSubtitle')}</p>
        <label className="field">
          <span>{t('userId')}</span>
          <input value={userId} onChange={(e) => setUserId(e.target.value)} autoComplete="username" placeholder="ANDI.WIJAYA" required
            data-testid="login-userid" />
        </label>
        <label className="field">
          <span>{t('password')}</span>
          <span className="input-row">
            <input type={showPassword ? 'text' : 'password'} value={password} onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password" required data-testid="login-password" />
            <button type="button" className="link-button" onClick={() => setShowPassword(!showPassword)}>
              {showPassword ? t('hide') : t('show')}
            </button>
          </span>
        </label>
        <ErrorNote error={error} />
        <button type="submit" className="pill-button" disabled={busy} data-testid="login-submit">{busy ? t('loggingIn') : t('login')}</button>
        <p className="hint">{t('demoUsers')}</p>
      </form>

      <div className="card">
        <h2 className="subtitle">{t('instantAccess')}</h2>
        <div className="instant-row">
          {['qris', 'transfer'].map((key) => (
            <button key={key} type="button" className="menu-item" onClick={() => setNotice(t('loginFirst', { feature: t(key) }))}>
              <span className="menu-icon"><Icon name={key} /></span>
              <span className="menu-label">{t(key)}</span>
            </button>
          ))}
        </div>
        {notice && <p className="notice">{notice}</p>}
      </div>
    </div>
  );
}
