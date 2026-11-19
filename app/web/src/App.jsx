import { useEffect, useMemo, useState } from 'react';
import Header from './components/Header.jsx';
import DemoBanner from './components/DemoBanner.jsx';
import Login from './screens/Login.jsx';
import Home from './screens/Home.jsx';
import Transfer from './screens/Transfer.jsx';
import Qris from './screens/Qris.jsx';
import Statement from './screens/Statement.jsx';
import Receipt from './screens/Receipt.jsx';
import DemoPanel from './screens/DemoPanel.jsx';
import { I18nContext, loadLang, saveLang, translate } from './i18n.js';
import { getCustomer, getScenario, setCustomer } from './api.js';
import { refreshTelemetryUser, trackScreen } from './telemetry.js';

// Hash router written by hand: #/login #/home #/transfer #/qris #/statement #/receipt #/demo
const ROUTES = {
  '/login': { Screen: Login, name: 'Login', needsLogin: false },
  '/home': { Screen: Home, name: 'Home', needsLogin: true },
  '/transfer': { Screen: Transfer, name: 'Transfer', needsLogin: true },
  '/qris': { Screen: Qris, name: 'QRIS', needsLogin: true },
  '/statement': { Screen: Statement, name: 'Statement', needsLogin: true },
  '/receipt': { Screen: Receipt, name: 'Receipt', needsLogin: true },
  '/demo': { Screen: DemoPanel, name: 'Demo panel', needsLogin: false },
};

function currentPath() {
  const path = window.location.hash.replace(/^#/, '');
  if (!ROUTES[path]) return getCustomer() ? '/home' : '/login';
  if (ROUTES[path].needsLogin && !getCustomer()) return '/login';
  return path;
}

// pushState keeps the browser history; the Application Insights SDK sees the route change (enableAutoRouteTracking)
function navigate(path) {
  if (window.location.hash !== '#' + path) window.history.pushState(null, '', '#' + path);
  window.dispatchEvent(new Event('minibank:navigate'));
}

export default function App() {
  const [path, setPath] = useState(currentPath);
  const [lang, setLang] = useState(loadLang);
  const [scenario, setScenarioState] = useState(getScenario);
  const [customer, setCustomerState] = useState(getCustomer);

  useEffect(() => {
    const sync = () => setPath(currentPath());
    ['hashchange', 'popstate', 'minibank:navigate'].forEach((e) => window.addEventListener(e, sync));
    return () => ['hashchange', 'popstate', 'minibank:navigate'].forEach((e) => window.removeEventListener(e, sync));
  }, []);

  // one page view per screen + browser tab title
  useEffect(() => {
    if (window.location.hash !== '#' + path) window.history.replaceState(null, '', '#' + path);
    document.title = 'MiniBank – ' + ROUTES[path].name;
    trackScreen(ROUTES[path].name);
  }, [path]);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const i18n = useMemo(() => ({
    lang,
    setLang: (value) => { saveLang(value); setLang(value); },
    t: (key, vars) => translate(lang, key, vars),
  }), [lang]);

  // v1.4: the User ID becomes the authenticated user of the browser telemetry after login and is cleared at logout
  const onLogin = (c) => { setCustomer(c); setCustomerState(c); refreshTelemetryUser(); navigate('/home'); };
  const onLogout = () => { setCustomer(null); setCustomerState(null); refreshTelemetryUser(); navigate('/login'); };
  const onScenarioChange = () => setScenarioState(getScenario());

  const { Screen } = ROUTES[path];
  return (
    <I18nContext.Provider value={i18n}>
      <div className="app">
        <DemoBanner />
        <Header scenario={scenario} customer={customer} onLogout={onLogout} />
        <main className="content">
          <Screen customer={customer} navigate={navigate} onLogin={onLogin} onScenarioChange={onScenarioChange} />
        </main>
        <footer className="footer">
          <a href="#/demo">{i18n.t('presenter')}</a> · MiniBank 1.2.0
        </footer>
      </div>
    </I18nContext.Provider>
  );
}
