// Browser telemetry for minibank-web (Application Insights JavaScript SDK).
// The connection string is NOT built into the page: it is loaded at start-up from GET /api/config.
// v1.4: every browser item carries the custom dimension trafficSource (people or robot), the logged-in User ID is the
// authenticated user (real demo User IDs; account numbers stay masked), and customer journeys are sent as the custom
// event "minibank.journey" (stage start/end). window.__minibankFlush() sends buffered telemetry now (used by the robot).
import { ApplicationInsights, DistributedTracingModes } from '@microsoft/applicationinsights-web';
import { getCustomer, getTrafficSource } from './api.js';

const TEN_DIGITS = /\b\d{10}\b/g; // account numbers have 10 digits
const JOURNEY_KEY = 'minibank.journey'; // sessionStorage: the open journey of this browser tab
let appInsights = null;
let queue = []; // page views tracked before the SDK is ready
let eventQueue = []; // journey events tracked before the SDK is ready

export function maskDigits(value) {
  return typeof value === 'string' ? value.replace(TEN_DIGITS, (m) => '******' + m.slice(-4)) : value;
}

function maskStrings(obj) {
  if (!obj || typeof obj !== 'object') return;
  Object.keys(obj).forEach((key) => {
    if (typeof obj[key] === 'string') obj[key] = maskDigits(obj[key]);
  });
}

// The logged-in User ID is the authenticated user of every browser item; cleared at logout.
function applyUser() {
  if (!appInsights) return;
  const customer = getCustomer();
  if (customer && customer.userId) appInsights.setAuthenticatedUserContext(customer.userId, undefined, true);
  else appInsights.clearAuthenticatedUserContext();
}

// Called by App.jsx right after login and logout.
export const refreshTelemetryUser = applyUser;

// The robot calls this before it closes a page, so no browser telemetry is lost. Returns false while telemetry is off.
window.__minibankFlush = () => {
  if (!appInsights) return false;
  appInsights.flush();
  return true;
};

export async function initTelemetry() {
  try {
    const response = await fetch('/api/config', { cache: 'no-store', headers: { 'X-MiniBank-Source': getTrafficSource() } });
    const config = await response.json();
    if (!config.appInsightsConnectionString) {
      console.warn('MiniBank: no connection string from /api/config, browser telemetry is off');
      return;
    }
    appInsights = new ApplicationInsights({
      config: {
        connectionString: config.appInsightsConnectionString,
        enableAutoRouteTracking: true, // new operation ID for every hash route (#/home, #/transfer, ...)
        distributedTracingMode: DistributedTracingModes.W3C, // "traceparent" header: one trace browser -> databases
        enableCorsCorrelation: true,
        disableFetchTracking: false, // every API call becomes a dependency of minibank-web
      },
    });
    appInsights.loadAppInsights();
    appInsights.addTelemetryInitializer((item) => {
      item.tags = item.tags || {};
      item.tags['ai.cloud.role'] = 'minibank-web'; // cloud role name
      // auto route tracking also sends a page view; keep only ours (they carry the custom property "screen")
      if (item.baseType === 'PageviewData' && !(item.data && item.data.screen)) return false;
      item.data = item.data || {};
      item.data.trafficSource = getTrafficSource(); // v1.4: custom dimension on every browser item
      maskStrings(item.data); // custom properties
      if (item.baseData) {
        maskStrings(item.baseData); // names, URLs and targets
        maskStrings(item.baseData.properties);
      }
      return true;
    });
    if (appInsights.context && appInsights.context.application) {
      appInsights.context.application.ver = config.appVersion || '1.2.0';
    }
    applyUser();
    queue.forEach((pageView) => appInsights.trackPageView(pageView));
    queue = [];
    eventQueue.forEach((event) => appInsights.trackEvent(event));
    eventQueue = [];
  } catch (e) {
    console.warn('MiniBank: browser telemetry is off', e);
  }
}

// One page view per screen, for example "MiniBank Transfer".
export function trackScreen(screen) {
  const pageView = { name: 'MiniBank ' + screen, uri: window.location.href, properties: { screen } };
  if (appInsights) appInsights.trackPageView(pageView);
  else queue.push(pageView);
}

// ---- v1.4 customer journeys ------------------------------------------------------------------
// Custom event "minibank.journey": stage "start" when the customer opens Transfer, QRIS or Statement, stage "end" when the
// receipt (or the statement) shows the result. Properties are strings: journeyId, journeyType (transfer|qris|statement),
// trafficSource, and on "end" success (true|false), failedStep (load|payment|statement), amountIdr, traceId, errorCode,
// httpStatus. A journey that is left without a result (customer goes back) has no "end".

// UUID v4 from crypto.getRandomValues: crypto.randomUUID exists only on https:// pages, the lab page is http://.
function newJourneyId() {
  const b = new Uint8Array(16);
  window.crypto.getRandomValues(b);
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const h = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

function sendJourneyEvent(stage, journey, extra) {
  const properties = { stage, journeyId: journey.journeyId, journeyType: journey.journeyType, trafficSource: getTrafficSource() };
  Object.keys(extra).forEach((key) => {
    if (extra[key] !== undefined && extra[key] !== null && extra[key] !== '') properties[key] = String(extra[key]);
  });
  const event = { name: 'minibank.journey', properties };
  if (appInsights) appInsights.trackEvent(event);
  else eventQueue.push(event);
}

// journeyType: transfer | qris | statement. A new journey replaces an open one of the same tab.
export function startJourney(journeyType) {
  const journey = { journeyId: newJourneyId(), journeyType };
  try {
    sessionStorage.setItem(JOURNEY_KEY, JSON.stringify(journey));
  } catch {
    // storage blocked: the end event of this journey is not sent
  }
  sendJourneyEvent('start', journey, {});
}

// Ends the open journey of this type once: { success, failedStep, amountIdr, traceId, errorCode, httpStatus }.
export function endJourney(journeyType, result) {
  let journey = null;
  try {
    journey = JSON.parse(sessionStorage.getItem(JOURNEY_KEY));
  } catch {
    journey = null;
  }
  if (!journey || journey.journeyType !== journeyType) return;
  sessionStorage.removeItem(JOURNEY_KEY);
  const r = result || {};
  sendJourneyEvent('end', journey, {
    success: r.success ? 'true' : 'false',
    failedStep: r.success ? '' : r.failedStep,
    amountIdr: r.amountIdr,
    traceId: r.traceId,
    errorCode: r.errorCode,
    httpStatus: r.httpStatus,
  });
}
