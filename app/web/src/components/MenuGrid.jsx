import { useState } from 'react';
import { useI18n } from '../i18n.js';

// Simple inline SVG icons drawn with basic shapes (no icon packs, no images copied from anywhere).
export function Icon({ name, size = 26 }) {
  const svg = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
    strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true };
  switch (name) {
    case 'transfer':
      return <svg {...svg}><path d="M4 8h14l-3-3" /><path d="M20 16H6l3 3" /></svg>;
    case 'qris':
      return (
        <svg {...svg}>
          <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" />
          <rect x="3" y="14" width="7" height="7" /><path d="M14 14h3v3h-3zM20 14v7M14 20h3" />
        </svg>
      );
    case 'statement':
      return <svg {...svg}><rect x="5" y="3" width="14" height="18" rx="2" /><path d="M9 8h6M9 12h6M9 16h4" /></svg>;
    case 'bill':
      return <svg {...svg}><path d="M6 3h12v18l-3-2-3 2-3-2-3 2z" /><path d="M9 8h6M9 12h6" /></svg>;
    case 'flazz':
      return <svg {...svg}><rect x="3" y="6" width="18" height="12" rx="2" /><path d="M7 10h4M15 14h2" /></svg>;
    case 'cardless':
      return <svg {...svg}><rect x="6" y="2" width="12" height="20" rx="2" /><path d="M12 6v7M9 10l3 3 3-3M10 18h4" /></svg>;
    case 'eye':
      return <svg {...svg}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></svg>;
    case 'eye-off':
      return <svg {...svg}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><path d="M3 3l18 18" /></svg>;
    case 'check':
      return <svg {...svg}><circle cx="12" cy="12" r="10" /><path d="M7 12.5l3 3 7-7" /></svg>;
    case 'cross':
      return <svg {...svg}><circle cx="12" cy="12" r="10" /><path d="M8 8l8 8M16 8l-8 8" /></svg>;
    default:
      return null;
  }
}

// Transfer, QRIS and Statement work; the other three are shown disabled ("coming soon").
const ITEMS = [
  { icon: 'transfer', label: 'transfer', path: '/transfer' },
  { icon: 'qris', label: 'qris', path: '/qris' },
  { icon: 'statement', label: 'statement', path: '/statement' },
  { icon: 'bill', label: 'billPayment' },
  { icon: 'flazz', label: 'flazz' },
  { icon: 'cardless', label: 'cardless' },
];

export default function MenuGrid({ onSelect }) {
  const { t } = useI18n();
  const [notice, setNotice] = useState('');
  return (
    <div className="card">
      <div className="menu-grid">
        {ITEMS.map((item) => (
          <button key={item.icon} type="button" className={'menu-item' + (item.path ? '' : ' disabled')}
            aria-disabled={!item.path} data-testid={'menu-' + item.icon}
            onClick={() => (item.path ? onSelect(item.path) : setNotice(t(item.label) + ': ' + t('comingSoon')))}>
            <span className="menu-icon"><Icon name={item.icon} /></span>
            <span className="menu-label">{t(item.label)}</span>
            {!item.path && <span className="menu-soon">{t('comingSoon')}</span>}
          </button>
        ))}
      </div>
      {notice && <p className="notice">{notice}</p>}
    </div>
  );
}
