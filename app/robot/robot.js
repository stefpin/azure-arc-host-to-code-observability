'use strict';
// =============================================================================================
// minibank-robot (v1.4, Priority 1 feature C) - browser robot on APP-WIN: Node.js 24 + playwright-core + the installed
// Microsoft Edge (channel msedge, headless). It plays the robot customers of customers.json (every customer except the
// presenter ANDI.WIJAYA) on the REAL MiniBank page, so Application Insights receives page views, browser timings,
// authenticated users, sessions and the journey events "minibank.journey" from simulated customers all day.
//   * one journey = login -> home -> transfer | QRIS | statement -> confirm -> PIN -> receipt -> flush telemetry (2 s)
//     -> logout -> close the browser
//   * one persistent Edge profile per customer: C:\ProgramData\MiniBank\robot\profiles\<User ID>. An init script sets
//     localStorage minibank.trafficSource = "robot" in every page, so the page labels its API calls and telemetry "robot";
//     each journey checks the label before it logs in
//   * the scenario of a journey is set the way the presenter page sets it: sessionStorage "minibank.scenario", this tab only
//   * normal pace: 1 journey every 2 minutes (transfer, QRIS, statement), 2 % of the journeys with scenario slow-oracle,
//     no other failures
//   * incident windows: the note C:\ProgramData\MiniBank\robot\incident.json (written by scripts\incident.ps1 on HV-HOST-02
//     and copied in with Copy-VMFile) is read every 30 s. While a phase is active: 1 payment journey every 30 s (at most
//     2 browsers at once). Counting starts again with every phase: every 3rd journey carries the phase scenario and the
//     amounts follow the fixed cycle INCIDENT_CYCLE; amounts >= IDR 25 million come from Prioritas/Solitaire customers,
//     smaller ones from Reguler customers (both round-robin). After the last phase the robot returns to the normal pace.
//   * one line per journey in C:\BuildLog\robot.log (time, customer, type, amount, scenario, result, ms)
// Note format: {"scene":5,"writtenUtc":"2026-11-12T08:00:00Z","phases":[{"scenario":"slow-oracle","endUtc":"2026-11-12T08:05:00Z"},
//   {"scenario":"fail-oracle","endUtc":"2026-11-12T08:15:00Z"}]}. A phase runs from the end of the previous phase (the first
//   one from writtenUtc) to its endUtc. "phases": [] (incident.ps1 -Stop) or a note whose phases have ended = normal pace.
// Run:  node robot.js [--base-url URL] [--data-dir DIR] [--log FILE] [--note FILE] [--customers FILE] [--edge PATH] [--headed]
//       node robot.js --once [--type transfer|qris|statement] [--customer USERID] [--amount IDR] [--scenario NAME]
//            one journey in the foreground, exit code 0 = success (deploy check)
//       node robot.js --plan [--note FILE]   prints the journeys of the incident note without a browser
// DEMO ONLY: synthetic customers; the demo password and PIN are documented in the runbook.
// =============================================================================================
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const args = parseArgs(process.argv.slice(2));
const BASE_URL = String(args['base-url'] || process.env.MINIBANK_BASE_URL || 'http://192.168.110.31:8080').replace(/\/+$/, '');
const DATA_DIR = String(args['data-dir'] || 'C:\\ProgramData\\MiniBank\\robot');
const PROFILES_DIR = path.join(DATA_DIR, 'profiles');
const NOTE_FILE = String(args.note || path.join(DATA_DIR, 'incident.json'));
const LOG_FILE = String(args.log || 'C:\\BuildLog\\robot.log');
const CUSTOMERS_FILE = String(args.customers || path.join(__dirname, 'customers.json'));
const EDGE_PATH = String(args.edge || process.env.MINIBANK_EDGE_PATH || '');   // empty = the installed Edge (channel msedge)
const HEADLESS = !args.headed;
const LOG_TO_FILE = !args.plan;

const DEMO_PASSWORD = 'Demo123!';   // demo password (documented, synthetic users)
const DEMO_PIN = '123456';          // demo PIN (documented)
const RESERVED = new Set(['ANDI.WIJAYA']);   // presenter account: never used by the robot
const TIERS = ['Reguler', 'Prioritas', 'Solitaire'];
const SCENARIOS = ['normal', 'slow-sql', 'slow-oracle', 'slow-python', 'slow-postgres',
  'fail-oracle', 'fail-java', 'fail-python', 'fail-api'];

const NORMAL_EVERY_MS = 120_000;     // normal pace: 1 journey every 2 minutes
const INCIDENT_EVERY_MS = 30_000;    // incident window: 1 journey every 30 seconds
const NOTE_EVERY_MS = 30_000;        // the incident note is read every 30 seconds
const MAX_BROWSERS = 2;              // APP-WIN (4 vCPU, 8 GB) also runs the API
const SLOW_SHARE = 0.02;             // normal pace: 2 % of the journeys with scenario slow-oracle
const STEP_TIMEOUT_MS = 30_000;      // one page step (click, wait for a screen)
const RESULT_TIMEOUT_MS = 60_000;    // receipt or statement (slow scenarios take about 4 s, the API gives up after 20 s)
const JOURNEY_TIMEOUT_MS = 150_000;  // hard limit for a whole journey, then the browser is closed
const FLUSH_WAIT_MS = 2_000;         // after window.__minibankFlush(), before logout

// Normal pace: the journey types in turn (40 % transfer, 40 % QRIS, 20 % statement).
const NORMAL_TYPES = ['transfer', 'qris', 'transfer', 'statement', 'qris'];
// Normal pace amounts per tier: [min, max, step] in IDR, random and rounded to the step.
const NORMAL_AMOUNTS = {
  Reguler: { transfer: [50_000, 2_500_000, 50_000], qris: [10_000, 250_000, 5_000] },
  Prioritas: { transfer: [500_000, 20_000_000, 100_000], qris: [50_000, 1_000_000, 5_000] },
  Solitaire: { transfer: [1_000_000, 50_000_000, 500_000], qris: [100_000, 2_000_000, 10_000] },
};
// Incident windows: payments only, this cycle starts again with every phase (T = transfer, Q = QRIS).
const INCIDENT_CYCLE = [
  { type: 'transfer', amount: 2_500_000 }, { type: 'qris', amount: 85_000 },
  { type: 'transfer', amount: 25_000_000 }, { type: 'qris', amount: 150_000 },
  { type: 'transfer', amount: 600_000 }, { type: 'transfer', amount: 60_000_000 },
  { type: 'qris', amount: 45_000 }, { type: 'transfer', amount: 5_000_000 },
  { type: 'transfer', amount: 150_000_000 }, { type: 'qris', amount: 220_000 },
];
const PREMIUM_FROM_IDR = 25_000_000;   // amounts from here on are paid by Prioritas/Solitaire customers
const EVERY_NTH_HIT = 3;               // every 3rd journey of a phase carries the phase scenario

const state = {
  customers: [], premium: [], reguler: [],
  running: new Set(),                  // User IDs with an open browser (one profile cannot be opened twice)
  note: { phases: [] }, noteText: null, lastNoteProblem: '',
  window: null,                        // the active incident phase and its counters
  normalCursor: { next: 0 }, normalTypeIndex: 0, normalDue: 0,
  stopping: false,
};

// ---- small helpers ---------------------------------------------------------------------------
function parseArgs(list) {
  const out = {};
  for (let i = 0; i < list.length; i += 1) {
    if (!list[i].startsWith('--')) continue;
    const key = list[i].slice(2);
    const next = list[i + 1];
    if (next !== undefined && !next.startsWith('--')) { out[key] = next; i += 1; } else { out[key] = true; }
  }
  return out;
}

const pad = (n, width = 2) => String(n).padStart(width, '0');
function stamp(ms = Date.now()) {
  const d = new Date(ms);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}
const clock = (ms) => stamp(ms).slice(11);
const firstLine = (text) => String(text || '').split(/\r?\n/)[0].slice(0, 300);
const pick = (list) => list[Math.floor(Math.random() * list.length)];
const T = (id) => `[data-testid="${id}"]`;

function log(line) {
  const text = `${stamp()} ${line}`;
  console.log(text);
  if (!LOG_TO_FILE) return;
  try {
    fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
    try {
      if (fs.statSync(LOG_FILE).size > 5 * 1024 * 1024) fs.renameSync(LOG_FILE, `${LOG_FILE}.1`);
    } catch {
      // no log file yet
    }
    fs.appendFileSync(LOG_FILE, `${text}\r\n`);
  } catch {
    // logging must never stop the robot
  }
}

function randomAmount(tier, type) {
  const [min, max, step] = NORMAL_AMOUNTS[tier][type];
  return min + step * Math.floor(Math.random() * (Math.floor((max - min) / step) + 1));
}

// "150000000" -> 1 5 0 000 000: the amount pad has a "000" key (no leading zero is possible)
function amountKeys(digits) {
  const keys = [];
  let i = 0;
  while (i < digits.length) {
    if (i > 0 && digits.startsWith('000', i)) { keys.push('000'); i += 3; } else { keys.push(digits[i]); i += 1; }
  }
  return keys;
}

// ---- customers and incident note ---------------------------------------------------------------
function loadCustomers() {
  const raw = JSON.parse(fs.readFileSync(CUSTOMERS_FILE, 'utf8').replace(/^\uFEFF/, ''));
  const list = (raw.customers || [])
    .filter((c) => c && typeof c.userId === 'string' && TIERS.includes(c.tier) && !RESERVED.has(c.userId.toUpperCase()))
    .map((c) => ({ userId: c.userId.trim().toUpperCase(), tier: c.tier }));
  if (!list.length) throw new Error(`no robot customers in ${CUSTOMERS_FILE}`);
  state.customers = list;
  state.premium = list.filter((c) => c.tier !== 'Reguler');
  state.reguler = list.filter((c) => c.tier === 'Reguler');
  if (!state.premium.length || !state.reguler.length) throw new Error('customers.json needs Reguler and Prioritas/Solitaire customers');
}

function parseNote(text) {
  const note = JSON.parse(text.replace(/^\uFEFF/, ''));
  const written = Date.parse(note.writtenUtc);
  if (Number.isNaN(written)) throw new Error('writtenUtc is missing or not a date');
  const phases = [];
  let start = written;
  (Array.isArray(note.phases) ? note.phases : []).forEach((p, index) => {
    const end = Date.parse(p && p.endUtc);
    const scenario = String((p && p.scenario) || '').trim().toLowerCase();
    if (Number.isNaN(end) || end <= start) throw new Error(`phase ${index + 1}: endUtc is missing, not a date or not after the phase start`);
    if (!SCENARIOS.includes(scenario)) throw new Error(`phase ${index + 1}: unknown scenario "${scenario}"`);
    phases.push({ index, scenario, start, end, key: `${note.writtenUtc}#${index}` });
    start = end;
  });
  return { scene: note.scene, writtenUtc: note.writtenUtc, phases };
}

function describeNote(note) {
  if (!note.phases.length) return `written ${note.writtenUtc || '-'}, no phases (normal pace)`;
  const parts = note.phases.map((p) => `${p.scenario} ${clock(p.start)}-${clock(p.end)}`);
  const active = Date.now() < note.phases[note.phases.length - 1].end ? '' : ' (already ended)';
  return `scene ${note.scene === undefined ? '-' : note.scene}: ${parts.join(', ')}${active}`;
}

function noteProblem(text) {
  if (text === state.lastNoteProblem) return;
  state.lastNoteProblem = text;
  log(text);
}

// A missing note means normal pace. An unreadable or half-written note keeps the previous one and is read again soon.
function readNote(retry = true) {
  let text;
  try {
    text = fs.readFileSync(NOTE_FILE, 'utf8');
  } catch (e) {
    if (e.code === 'ENOENT') {
      if (state.note.phases.length) log('incident note removed: normal pace');
      state.note = { phases: [] };
      state.noteText = null;
    } else {
      noteProblem(`incident note not readable (${e.code || firstLine(e.message)}): keeping the previous one`);
      if (retry) setTimeout(() => readNote(false), 2_000);
    }
    return;
  }
  if (text === state.noteText) return;
  try {
    state.note = parseNote(text);
    state.noteText = text;
    state.lastNoteProblem = '';
    log(`incident note: ${describeNote(state.note)}`);
  } catch (e) {
    noteProblem(`incident note ignored (${firstLine(e.message)}): keeping the previous one`);
    if (retry) setTimeout(() => readNote(false), 2_000);
  }
}

// ---- plans ---------------------------------------------------------------------------------------
// Next customer of a pool in round-robin order; customers with an open browser are skipped.
function takeNext(pool, cursor) {
  for (let i = 0; i < pool.length; i += 1) {
    const customer = pool[(cursor.next + i) % pool.length];
    if (!state.running.has(customer.userId)) {
      cursor.next = (cursor.next + i + 1) % pool.length;
      return customer;
    }
  }
  return null;
}

function nextNormalPlan() {
  const customer = takeNext(state.customers, state.normalCursor);
  if (!customer) return null;
  const type = NORMAL_TYPES[state.normalTypeIndex % NORMAL_TYPES.length];
  state.normalTypeIndex += 1;
  return {
    customer, type, amount: type === 'statement' ? null : randomAmount(customer.tier, type),
    scenario: Math.random() < SLOW_SHARE ? 'slow-oracle' : 'normal', mode: 'normal',
  };
}

function newWindow(phase) {
  return { key: phase.key, scenario: phase.scenario, end: phase.end, k: 0, premium: { next: 0 }, reguler: { next: 0 }, due: Date.now() };
}

// k-th journey of the phase (1, 2, 3, ...): amount and type from the cycle, every 3rd one carries the phase scenario.
function nextIncidentPlan(win) {
  const k = win.k + 1;
  const step = INCIDENT_CYCLE[(k - 1) % INCIDENT_CYCLE.length];
  const premium = step.amount >= PREMIUM_FROM_IDR;
  const customer = takeNext(premium ? state.premium : state.reguler, premium ? win.premium : win.reguler);
  if (!customer) return null;
  win.k = k;
  return {
    customer, type: step.type, amount: step.amount,
    scenario: k % EVERY_NTH_HIT === 0 ? win.scenario : 'normal', mode: `incident:${win.scenario}#${k}`,
  };
}

// ---- one journey in Edge ---------------------------------------------------------------------------
async function launchBrowser(userId) {
  const { chromium } = require('playwright-core');   // loaded on first use, so --plan works without node_modules
  const options = { headless: HEADLESS, viewport: { width: 412, height: 915 }, locale: 'en-US', timezoneId: 'Asia/Jakarta' };
  if (EDGE_PATH) options.executablePath = EDGE_PATH; else options.channel = 'msedge';
  const context = await chromium.launchPersistentContext(path.join(PROFILES_DIR, userId), options);
  await context.addInitScript(() => {
    try {
      window.localStorage.setItem('minibank.trafficSource', 'robot');
    } catch (e) {
      // about:blank has no storage
    }
  });
  for (const extra of context.pages().slice(1)) await extra.close().catch(() => {});
  return context;
}

async function login(page, customer) {
  await page.goto(`${BASE_URL}/#/login`, { waitUntil: 'domcontentloaded' });
  await page.locator(T('login-submit')).waitFor();
  const label = await page.evaluate(() => {
    try { return window.localStorage.getItem('minibank.trafficSource'); } catch (e) { return null; }
  });
  if (label !== 'robot') throw new Error(`self-check failed: the page label is "${label}", not "robot"`);
  await page.locator(T('login-userid')).fill(customer.userId);
  await page.locator(T('login-password')).fill(DEMO_PASSWORD);
  await page.locator(T('login-submit')).click();
  await page.locator(`${T('home-greeting')}, form ${T('error-note')}`).first().waitFor();
  const refused = page.locator(`form ${T('error-note')}`);
  if (await refused.count()) throw new Error(`login refused: ${firstLine(await refused.first().innerText())}`);
  // Home has loaded the accounts and the last transactions (or shows an error)
  await page.locator(`${T('home-recent')}:not([data-status="loading"]), ${T('error-note')}`).first().waitFor();
}

// Same storage key and scope as the presenter page (DemoPanel -> setScenario in api.js): sessionStorage, this tab only.
async function setScenario(page, scenario) {
  await page.evaluate((s) => {
    if (s === 'normal') window.sessionStorage.removeItem('minibank.scenario');
    else window.sessionStorage.setItem('minibank.scenario', s);
  }, scenario);
}

async function errorResult(page) {
  const text = await page.locator(T('error-note')).first().innerText().catch(() => '');
  const match = /[0-9a-f]{32}/i.exec(text);
  return { ok: false, traceId: match ? match[0] : '', detail: `load failed: ${firstLine(text)}` };
}

async function enterAmount(page, amount) {
  const digits = String(Math.round(amount));
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    for (const key of amountKeys(digits)) await page.locator(T(`amount-key-${key}`)).click();
    const shown = (await page.locator(T('amount-display')).innerText()).replace(/\D/g, '');
    if (shown === digits) return;
    for (let i = 0; i < 12; i += 1) await page.locator(T('amount-key-del')).click();
  }
  throw new Error(`the amount pad does not show ${digits}`);
}

async function enterPin(page) {
  await page.locator(T('pinpad')).waitFor();
  for (const digit of DEMO_PIN) await page.locator(T(`pin-key-${digit}`)).click();
}

async function waitReceipt(page) {
  const receipt = page.locator(`${T('receipt')}:not([data-status="none"])`);
  await receipt.waitFor({ timeout: RESULT_TIMEOUT_MS });
  return { ok: (await receipt.getAttribute('data-status')) === 'ok', traceId: (await receipt.getAttribute('data-trace-id')) || '' };
}

async function transfer(page, plan) {
  await page.locator(T('menu-transfer')).click();
  await page.locator(`${T('transfer')}[data-step="1"]`).waitFor();
  await page.waitForFunction(() => {
    const from = document.querySelector('[data-testid="transfer-from"]');
    const to = document.querySelector('[data-testid="transfer-to"]');
    return (from && to && from.options.length > 0 && to.options.length > 1) || !!document.querySelector('[data-testid="error-note"]');
  });
  if (await page.locator(T('error-note')).count()) return errorResult(page);
  const own = await page.locator(`${T('transfer-from')} option`).evaluateAll((os) => os.map((o) => o.value));
  const all = await page.locator(`${T('transfer-to')} option`).evaluateAll((os) => os.map((o) => o.value).filter(Boolean));
  const others = all.filter((value) => !own.includes(value));   // another customer's account
  await page.locator(T('transfer-to')).selectOption(pick(others.length ? others : all));
  await enterAmount(page, plan.amount);
  await page.locator(T('transfer-next')).click();
  await page.locator(`${T('transfer')}[data-step="2"]`).waitFor();
  await page.locator(T('transfer-confirm')).click();
  await enterPin(page);
  return waitReceipt(page);
}

async function qris(page, plan) {
  await page.locator(T('menu-qris')).click();
  await page.locator(`${T('qris')}[data-step="1"]`).waitFor();
  await page.waitForFunction(() => document.querySelectorAll('[data-testid^="qris-merchant-"]').length > 0
    || !!document.querySelector('[data-testid="error-note"]'));
  if (await page.locator(T('error-note')).count()) return errorResult(page);
  const merchants = await page.locator('[data-testid^="qris-merchant-"]').evaluateAll((els) => els.map((e) => e.getAttribute('data-testid')));
  await page.locator(T(pick(merchants))).click();
  await page.locator(`${T('qris')}[data-step="2"]`).waitFor();
  await enterAmount(page, plan.amount);
  await page.locator(T('qris-next')).click();
  await page.locator(`${T('qris')}[data-step="3"]`).waitFor();
  await page.locator(T('qris-pay')).click();
  await enterPin(page);
  return waitReceipt(page);
}

async function statement(page) {
  await page.locator(T('menu-statement')).click();
  const result = page.locator(`${T('statement-result')}:not([data-status="loading"])`);
  await result.waitFor({ timeout: RESULT_TIMEOUT_MS });
  return { ok: (await result.getAttribute('data-status')) === 'ready', traceId: (await result.getAttribute('data-trace-id')) || '' };
}

// Clear the scenario, send the buffered browser telemetry, log out (the login page view is flushed too).
async function finish(page) {
  await page.evaluate(() => window.sessionStorage.removeItem('minibank.scenario'));
  await page.evaluate(() => (typeof window.__minibankFlush === 'function' ? window.__minibankFlush() : false));
  await page.waitForTimeout(FLUSH_WAIT_MS);
  await page.locator(T('logout')).click();
  await page.locator(T('login-submit')).waitFor();
  await page.evaluate(() => (typeof window.__minibankFlush === 'function' ? window.__minibankFlush() : false));
  await page.waitForTimeout(500);
}

// Never throws. result: success | failed (the page showed a failure: receipt, statement or load error) | error (robot problem)
async function runJourney(plan) {
  const started = Date.now();
  const outcome = { result: 'error', ms: 0, traceId: '', detail: '' };
  let context = null;
  let step = 'launch';
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    outcome.detail = `timeout after ${JOURNEY_TIMEOUT_MS / 1000} s in step ${step}`;
    if (context) context.close().catch(() => {});
  }, JOURNEY_TIMEOUT_MS);
  try {
    context = await launchBrowser(plan.customer.userId);
    if (timedOut) throw new Error('the browser started after the journey timeout');
    const page = context.pages()[0] || (await context.newPage());
    page.setDefaultTimeout(STEP_TIMEOUT_MS);
    step = 'login';
    await login(page, plan.customer);
    await setScenario(page, plan.scenario);
    step = plan.type;
    let r;
    if (plan.type === 'transfer') r = await transfer(page, plan);
    else if (plan.type === 'qris') r = await qris(page, plan);
    else r = await statement(page);
    outcome.result = r.ok ? 'success' : 'failed';
    outcome.traceId = r.traceId || '';
    if (r.detail) outcome.detail = r.detail;
    step = 'logout';
    await finish(page);
  } catch (e) {
    if (!outcome.detail) outcome.detail = `step ${step}: ${firstLine(e && e.message)}`;
  } finally {
    clearTimeout(timer);
    if (context) await context.close().catch(() => {});
    outcome.ms = Date.now() - started;
  }
  return outcome;
}

function logJourney(plan, r) {
  const parts = ['journey', `customer=${plan.customer.userId}`, `tier=${plan.customer.tier}`, `type=${plan.type}`,
    `amount=${plan.amount === null ? '-' : plan.amount}`, `scenario=${plan.scenario}`, `result=${r.result}`, `ms=${r.ms}`,
    `mode=${plan.mode}`];
  if (r.traceId && r.result !== 'success') parts.push(`trace=${r.traceId}`);
  if (r.detail) parts.push(`detail="${r.detail.replace(/"/g, "'")}"`);
  log(parts.join(' '));
}

function launch(plan) {
  state.running.add(plan.customer.userId);
  runJourney(plan)
    .then((r) => logJourney(plan, r))
    .catch((e) => logJourney(plan, { result: 'error', ms: 0, traceId: '', detail: firstLine(e && e.message) }))
    .finally(() => state.running.delete(plan.customer.userId));
}

// ---- scheduler (every second) ------------------------------------------------------------------------
function tick() {
  if (state.stopping) return;
  const now = Date.now();
  const phase = state.note.phases.find((p) => now >= p.start && now < p.end) || null;
  if (phase) {
    if (!state.window || state.window.key !== phase.key) {
      state.window = newWindow(phase);
      log(`incident window ${phase.scenario} until ${clock(phase.end)}: 1 payment journey every 30 s, every 3rd with ${phase.scenario}`);
    }
    const win = state.window;
    if (now >= win.due && state.running.size < MAX_BROWSERS) {
      const plan = nextIncidentPlan(win);
      if (plan) {
        launch(plan);
        win.due = Math.max(win.due + INCIDENT_EVERY_MS, now + 5_000);
      }
    }
    return;
  }
  if (state.window) {
    log('incident window ended: normal pace again');
    state.window = null;
    state.normalDue = Math.max(state.normalDue, now + 60_000);
  }
  if (now >= state.normalDue && state.running.size < MAX_BROWSERS) {
    const plan = nextNormalPlan();
    if (plan) {
      launch(plan);
      state.normalDue = now + NORMAL_EVERY_MS;
    }
  }
}

// Edge processes left behind when the task was stopped hard would lock their profile: stop them at start-up.
function cleanupStrayBrowsers() {
  if (process.platform !== 'win32') return;
  const marker = PROFILES_DIR.replace(/'/g, "''");
  const script = "Get-CimInstance Win32_Process -Filter \"Name='msedge.exe'\" | Where-Object { $_.CommandLine -like '*"
    + marker + "*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $_.ProcessId }";
  try {
    const out = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script], { encoding: 'utf8', timeout: 60_000 });
    const count = out.split(/\r?\n/).filter((line) => line.trim()).length;
    if (count) log(`stopped ${count} Edge processes left over from an earlier run`);
  } catch (e) {
    log(`could not check for left-over Edge processes: ${firstLine(e && e.message)}`);
  }
}

function stop(signal) {
  if (state.stopping) return;
  state.stopping = true;
  log(`stopping (${signal}): waiting for ${state.running.size} running journey(s)`);
  const deadline = Date.now() + JOURNEY_TIMEOUT_MS;
  const wait = setInterval(() => {
    if (state.running.size === 0 || Date.now() > deadline) {
      clearInterval(wait);
      log('minibank-robot stopped');
      process.exit(0);
    }
  }, 500);
}

// ---- modes -------------------------------------------------------------------------------------------
function printPlan() {
  let note;
  try {
    note = parseNote(fs.readFileSync(NOTE_FILE, 'utf8'));
  } catch (e) {
    console.log(`No usable incident note at ${NOTE_FILE} (${firstLine(e.message)}): showing one 10-minute fail-oracle phase.`);
    const now = Date.now();
    note = { scene: '-', phases: [{ index: 0, scenario: 'fail-oracle', start: now, end: now + 600_000, key: 'example#0' }] };
  }
  let failedIdr = 0;
  const affected = new Set();
  note.phases.forEach((phase) => {
    const win = newWindow(phase);
    const count = Math.max(1, Math.round((phase.end - phase.start) / INCIDENT_EVERY_MS));
    console.log(`phase ${phase.index + 1}: ${phase.scenario} ${clock(phase.start)}-${clock(phase.end)}, about ${count} journeys`);
    for (let i = 0; i < count; i += 1) {
      const plan = nextIncidentPlan(win);
      const hit = plan.scenario !== 'normal';
      if (hit && plan.scenario.startsWith('fail-')) {
        failedIdr += plan.amount;
        affected.add(plan.customer.userId);
      }
      console.log(`  #${String(win.k).padStart(2)} ${plan.type.padEnd(8)} ${String(plan.amount).padStart(11)} `
        + `${plan.customer.userId.padEnd(18)} ${plan.customer.tier.padEnd(9)} ${plan.scenario}${hit ? '   <-- scenario' : ''}`);
    }
  });
  console.log(`Failed payment value of the robot in fail-* phases: IDR ${failedIdr.toLocaleString('en-US')}, `
    + `customers affected: ${affected.size} (${[...affected].join(', ')})`);
}

async function runOnce() {
  const type = String(args.type || 'transfer');
  if (!['transfer', 'qris', 'statement'].includes(type)) throw new Error('--type must be transfer, qris or statement');
  const scenario = String(args.scenario || 'normal');
  if (!SCENARIOS.includes(scenario)) throw new Error(`--scenario must be one of ${SCENARIOS.join(', ')}`);
  const wanted = args.customer ? String(args.customer).toUpperCase() : state.customers[0].userId;
  const customer = state.customers.find((c) => c.userId === wanted);
  if (!customer) throw new Error(`${wanted} is not a robot customer (customers.json; ANDI.WIJAYA is reserved)`);
  const amount = type === 'statement' ? null : Number(args.amount || randomAmount(customer.tier, type));
  fs.mkdirSync(PROFILES_DIR, { recursive: true });
  const plan = { customer, type, amount, scenario, mode: 'once' };
  const r = await runJourney(plan);
  logJourney(plan, r);
  process.exit(r.result === 'success' ? 0 : 1);
}

async function main() {
  loadCustomers();
  if (args.plan) { printPlan(); return; }
  if (args.once) { await runOnce(); return; }
  fs.mkdirSync(PROFILES_DIR, { recursive: true });
  cleanupStrayBrowsers();
  log(`minibank-robot started: ${BASE_URL}, ${state.customers.length} customers (${state.reguler.length} Reguler, `
    + `${state.premium.length} Prioritas/Solitaire), profiles ${PROFILES_DIR}, note ${NOTE_FILE}, Edge ${EDGE_PATH || 'channel msedge'}`
    + `${HEADLESS ? ' headless' : ' headed'}`);
  readNote();
  state.normalDue = Date.now() + 20_000;
  setInterval(() => readNote(), NOTE_EVERY_MS);
  setInterval(tick, 1_000);
  process.on('SIGINT', () => stop('SIGINT'));
  process.on('SIGTERM', () => stop('SIGTERM'));
}

process.on('unhandledRejection', (e) => log(`unhandled rejection: ${firstLine(e && e.message ? e.message : e)}`));
main().catch((e) => {
  log(`minibank-robot cannot run: ${firstLine(e && e.message)}`);
  process.exit(1);
});
