import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './theme.css';
import { initTelemetry } from './telemetry.js';
import App from './App.jsx';

// Starts browser telemetry in the background (connection string from GET /api/config); the page does not wait for it.
initTelemetry();

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
