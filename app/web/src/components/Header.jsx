import { useState } from 'react';
import { useI18n } from '../i18n.js';

// Logo files tried in this order; if none exists only the text wordmark "MiniBank" is shown.
// The logo appears only here, on the white bar, never recoloured (see public/brand/PUT-LOGO-HERE.txt).
const LOGOS = ['/brand/logo.svg', '/brand/logo.png'];

export default function Header({ scenario, customer, onLogout }) {
  const { lang, setLang, t } = useI18n();
  const [logoIndex, setLogoIndex] = useState(0);

  return (
    <header className="header">
      <div className="brand">
        {logoIndex < LOGOS.length && (
          <img className="brand-logo" src={LOGOS[logoIndex]} alt="MiniBank" onError={() => setLogoIndex((i) => i + 1)} />
        )}
        <span className="wordmark">MiniBank</span>
      </div>
      <div className="header-right">
        {scenario !== 'normal' && <span className="scenario-badge">{t('scenarioBadge', { name: scenario })}</span>}
        <div className="lang-toggle" role="group" aria-label="Language">
          <button type="button" className={lang === 'en' ? 'active' : ''} onClick={() => setLang('en')}>EN</button>
          |
          <button type="button" className={lang === 'id' ? 'active' : ''} onClick={() => setLang('id')}>ID</button>
        </div>
        {customer && <button type="button" className="link-button" onClick={onLogout} data-testid="logout">{t('logout')}</button>}
      </div>
    </header>
  );
}
