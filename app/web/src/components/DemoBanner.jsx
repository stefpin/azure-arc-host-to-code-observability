import { useI18n } from '../i18n.js';

// Thin yellow bar shown on EVERY screen (rendered once in App.jsx above the header).
export default function DemoBanner() {
  const { t } = useI18n();
  return <div className="demo-banner" role="note">{t('demoBanner')}</div>;
}

// Small error note used by the screens: message plus the Trace ID of the failed call.
export function ErrorNote({ error }) {
  const { t } = useI18n();
  if (!error) return null;
  return (
    <p className="error-text" data-testid="error-note">
      {error.error}
      {error.traceId && <span className="trace-small"><br />{t('traceId')}: {error.traceId}</span>}
    </p>
  );
}
