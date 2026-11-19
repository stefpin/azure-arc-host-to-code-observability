// Fetch wrapper for the MiniBank API (same origin as the page) plus small session helpers.
// Every call carries the header X-MiniBank-Scenario (value from sessionStorage "minibank.scenario").
// v1.4: every call also carries X-MiniBank-Source = "robot" in the browser robot's profiles (localStorage
// "minibank.trafficSource"), else "people".
// On error a call returns { error, code, traceId, status }; traceId comes from the JSON body or the "traceparent" header.
import { SCENARIOS } from './i18n.js';

const SCENARIO_KEY = 'minibank.scenario';
const CUSTOMER_KEY = 'minibank.customer';
const ACCOUNT_KEY = 'minibank.account';
const RECEIPT_KEY = 'minibank.receipt';
const SOURCE_KEY = 'minibank.trafficSource'; // localStorage, set to "robot" only by the browser robot

// v1.4 traffic-source label of this browser: "robot" or "people" (real persons, the default).
export function getTrafficSource() {
  try {
    return localStorage.getItem(SOURCE_KEY) === 'robot' ? 'robot' : 'people';
  } catch {
    return 'people';
  }
}

export function getScenario() {
  const value = sessionStorage.getItem(SCENARIO_KEY);
  return SCENARIOS.includes(value) ? value : 'normal';
}

export function setScenario(value) {
  if (!value || value === 'normal') sessionStorage.removeItem(SCENARIO_KEY);
  else sessionStorage.setItem(SCENARIO_KEY, value);
}

function readJson(key) {
  try {
    return JSON.parse(sessionStorage.getItem(key));
  } catch {
    return null;
  }
}

export const getCustomer = () => readJson(CUSTOMER_KEY);
export const loadReceipt = () => readJson(RECEIPT_KEY);
export const saveReceipt = (receipt) => sessionStorage.setItem(RECEIPT_KEY, JSON.stringify(receipt));
export const getActiveAccount = () => sessionStorage.getItem(ACCOUNT_KEY);
export const setActiveAccount = (accountNo) => accountNo && sessionStorage.setItem(ACCOUNT_KEY, accountNo);

export function setCustomer(customer) {
  if (customer) {
    sessionStorage.setItem(CUSTOMER_KEY, JSON.stringify(customer));
    return;
  }
  [CUSTOMER_KEY, ACCOUNT_KEY, RECEIPT_KEY].forEach((key) => sessionStorage.removeItem(key));
}

// "traceparent: 00-<32 hex trace id>-<16 hex span id>-01" -> trace id
function traceIdFromHeader(response) {
  const parts = (response.headers.get('traceparent') || '').split('-');
  return parts.length >= 3 && /^[0-9a-f]{32}$/i.test(parts[1]) ? parts[1] : null;
}

export async function request(path, { method = 'GET', body } = {}) {
  const headers = { Accept: 'application/json', 'X-MiniBank-Scenario': getScenario(), 'X-MiniBank-Source': getTrafficSource() };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  let response;
  try {
    response = await fetch(path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  } catch (e) {
    return { error: 'Network error: ' + e.message, code: 'NETWORK', traceId: null, status: 0 };
  }
  let data = null;
  try {
    data = await response.json();
  } catch {
    data = null;
  }
  const traceId = (data && data.traceId) || traceIdFromHeader(response);
  if (!response.ok) {
    return {
      error: (data && (data.error || data.title)) || 'HTTP ' + response.status,
      code: data && data.code,
      detail: data && data.detail,
      traceId,
      status: response.status,
    };
  }
  return { data, traceId, status: response.status };
}

// The scenario is also sent as JSON field "scenario" for Transfer and QRIS.
export const api = {
  login: (userId, password) => request('/api/login', { method: 'POST', body: { userId, password } }),
  accounts: (customerId) => request('/api/accounts?customerId=' + encodeURIComponent(customerId)),
  allAccounts: () => request('/api/accounts'),
  statement: (accountNo, days = 30) =>
    request('/api/accounts/' + encodeURIComponent(accountNo) + '/statement?days=' + days),
  merchants: () => request('/api/qris/merchants'),
  transfer: (payload) => request('/api/transfer', { method: 'POST', body: { ...payload, scenario: getScenario() } }),
  qrisPay: (payload) => request('/api/qris/pay', { method: 'POST', body: { ...payload, scenario: getScenario() } }),
};
