// Texts in English (DEFAULT) and Indonesian. The choice is stored in localStorage "minibank.lang".
import { createContext, useContext } from 'react';

const STORAGE_KEY = 'minibank.lang';

export const SCENARIOS = ['normal', 'slow-sql', 'slow-oracle', 'slow-python', 'slow-postgres',
  'fail-oracle', 'fail-java', 'fail-python', 'fail-api'];

const TEXT = {
  en: {
    demoBanner: 'DEMO APPLICATION – not a real bank app. Synthetic data only.',
    welcome: 'Hello, Welcome!', loginSubtitle: 'Log in to MiniBank', userId: 'User ID', password: 'Password',
    show: 'Show', hide: 'Hide', login: 'Login', loggingIn: 'Logging in…', instantAccess: 'Instant Access',
    loginFirst: 'Please log in first to use {feature}.',
    demoUsers: 'Demo users: ANDI.WIJAYA, SITI.RAHAYU, BUDI.SANTOSO – password Demo123!',
    logout: 'Log out', hello: 'Hello, {name}', balance: 'Balance', showBalance: 'Show balance', hideBalance: 'Hide balance',
    statement: 'Statement', otherAccounts: 'Other accounts', lastTransactions: 'Last transactions',
    noTransactions: 'No transactions in the last 30 days.', loading: 'Loading…', account: 'Account',
    transfer: 'Transfer', qris: 'QRIS', billPayment: 'Bill Payment', flazz: 'Flazz', cardless: 'Cardless',
    comingSoon: 'coming soon', stepDetails: 'Details', stepConfirm: 'Confirm', stepPin: 'PIN',
    fromAccount: 'From account', toAccount: 'To account', chooseAccount: 'Choose an account', amount: 'Amount',
    note: 'Note (optional)', next: 'Next', back: 'Back', confirm: 'Confirm', enterPin: 'Enter your MiniBank PIN',
    demoPin: 'Demo PIN: 123456', wrongPin: 'Wrong PIN. Please try again.', processing: 'Processing…',
    amountRequired: 'Enter an amount.', scanTitle: 'QRIS', scanHint: 'Simulated scan – choose a demo merchant',
    merchant: 'Merchant', pay: 'Pay', last30: 'Last 30 days', debit: 'DB', credit: 'CR',
    success: 'Transaction successful', failed: 'Transaction failed', referenceNo: 'Reference no.',
    dateTime: 'Date / time', status: 'Status', to: 'To', fraudCheck: 'Fraud check', traceId: 'Trace ID',
    traceHint: 'Paste this Trace ID into Application Insights (Transaction search) to see the whole transaction.',
    copy: 'Copy', copied: 'Copied', backHome: 'Back to Home', noReceipt: 'No transaction yet.',
    presenter: 'Presenter panel', scenario: 'Scenario', scenarioBadge: 'Scenario: {name}', apply: 'Apply',
    reset: 'Reset to normal', applied: 'Scenario "{name}" is active in this browser tab.', goHome: 'Home',
    scenarioNote: 'The scenario is sent with every request from this browser tab. Transfer and QRIS pass all services; '
      + 'Statement passes only minibank-api, minibank-transfer and Oracle.',
    sc_normal: 'Everything succeeds in about 100–300 ms.',
    'sc_slow-sql': 'SQL Server waits 1.5 s (WAITFOR DELAY) in minibank-api.',
    'sc_slow-oracle': 'Oracle waits 2 s (DBMS_SESSION.SLEEP) in minibank-transfer.',
    'sc_slow-python': 'minibank-fraud sleeps 1.5 s in Python code.',
    'sc_slow-postgres': 'PostgreSQL waits 1.5 s (pg_sleep) in minibank-fraud.',
    'sc_fail-oracle': 'Oracle query on a missing table (ORA-00942), then HTTP 500 and 502 up the chain.',
    'sc_fail-java': 'minibank-transfer throws an exception.',
    'sc_fail-python': 'minibank-fraud raises an exception.',
    'sc_fail-api': 'minibank-api throws before calling anything else.',
  },
  id: {
    demoBanner: 'APLIKASI DEMO – bukan aplikasi bank sungguhan. Data fiktif.',
    welcome: 'Halo, Selamat Datang!', loginSubtitle: 'Masuk ke MiniBank', userId: 'User ID', password: 'Kata Sandi',
    show: 'Lihat', hide: 'Sembunyikan', login: 'Masuk', loggingIn: 'Sedang masuk…', instantAccess: 'Akses Instan',
    loginFirst: 'Silakan masuk terlebih dahulu untuk menggunakan {feature}.',
    demoUsers: 'Pengguna demo: ANDI.WIJAYA, SITI.RAHAYU, BUDI.SANTOSO – kata sandi Demo123!',
    logout: 'Keluar', hello: 'Halo, {name}', balance: 'Saldo', showBalance: 'Lihat saldo', hideBalance: 'Sembunyikan saldo',
    statement: 'Mutasi Rekening', otherAccounts: 'Rekening lain', lastTransactions: 'Transaksi terakhir',
    noTransactions: 'Tidak ada transaksi dalam 30 hari terakhir.', loading: 'Memuat…', account: 'Rekening',
    transfer: 'Transfer', qris: 'QRIS', billPayment: 'Bayar Tagihan', flazz: 'Flazz', cardless: 'Tarik Tunai',
    comingSoon: 'segera hadir', stepDetails: 'Rincian', stepConfirm: 'Konfirmasi', stepPin: 'PIN',
    fromAccount: 'Dari rekening', toAccount: 'Ke rekening', chooseAccount: 'Pilih rekening', amount: 'Jumlah',
    note: 'Berita (opsional)', next: 'Lanjut', back: 'Kembali', confirm: 'Konfirmasi', enterPin: 'Masukkan PIN MiniBank',
    demoPin: 'PIN demo: 123456', wrongPin: 'PIN salah. Silakan coba lagi.', processing: 'Memproses…',
    amountRequired: 'Masukkan jumlah.', scanTitle: 'QRIS', scanHint: 'Simulasi pindai – pilih merchant demo',
    merchant: 'Merchant', pay: 'Bayar', last30: '30 hari terakhir', debit: 'DB', credit: 'CR',
    success: 'Transaksi Berhasil', failed: 'Transaksi Gagal', referenceNo: 'No. Referensi',
    dateTime: 'Tanggal / waktu', status: 'Status', to: 'Ke', fraudCheck: 'Cek fraud', traceId: 'Trace ID',
    traceHint: 'Tempel Trace ID ini di Application Insights (Transaction search) untuk melihat seluruh transaksi.',
    copy: 'Salin', copied: 'Tersalin', backHome: 'Kembali ke Beranda', noReceipt: 'Belum ada transaksi.',
    presenter: 'Panel presenter', scenario: 'Skenario', scenarioBadge: 'Skenario: {name}', apply: 'Terapkan',
    reset: 'Kembali ke normal', applied: 'Skenario "{name}" aktif di tab browser ini.', goHome: 'Beranda',
    scenarioNote: 'Skenario dikirim bersama setiap permintaan dari tab browser ini. Transfer dan QRIS melewati semua '
      + 'layanan; Mutasi hanya melewati minibank-api, minibank-transfer dan Oracle.',
    sc_normal: 'Semua berhasil dalam sekitar 100–300 ms.',
    'sc_slow-sql': 'SQL Server menunggu 1,5 detik (WAITFOR DELAY) di minibank-api.',
    'sc_slow-oracle': 'Oracle menunggu 2 detik (DBMS_SESSION.SLEEP) di minibank-transfer.',
    'sc_slow-python': 'minibank-fraud tidur 1,5 detik di kode Python.',
    'sc_slow-postgres': 'PostgreSQL menunggu 1,5 detik (pg_sleep) di minibank-fraud.',
    'sc_fail-oracle': 'Query Oracle ke tabel yang tidak ada (ORA-00942), lalu HTTP 500 dan 502 ke atas.',
    'sc_fail-java': 'minibank-transfer melempar exception.',
    'sc_fail-python': 'minibank-fraud memunculkan exception.',
    'sc_fail-api': 'minibank-api gagal sebelum memanggil layanan lain.',
  },
};

export function loadLang() {
  try {
    return localStorage.getItem(STORAGE_KEY) === 'id' ? 'id' : 'en'; // English unless "id" was chosen
  } catch {
    return 'en';
  }
}

export function saveLang(lang) {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    // storage blocked: the choice is kept only until the page is reloaded
  }
}

// translate('id', 'hello', { name: 'ANDI' }) -> "Halo, ANDI"
export function translate(lang, key, vars = {}) {
  const text = (TEXT[lang] && TEXT[lang][key]) || TEXT.en[key] || key;
  return text.replace(/\{(\w+)\}/g, (match, name) => (vars[name] !== undefined ? String(vars[name]) : match));
}

// 1250000 -> "IDR 1.250.000" (Indonesian digit grouping in both languages)
export function formatIDR(amount) {
  return 'IDR ' + new Intl.NumberFormat('id-ID', { maximumFractionDigits: 2 }).format(Number(amount) || 0);
}

// ISO date -> "10 Nov 2026, 15:34:44 WIB" (Asia/Jakarta = UTC+7)
export function formatDateTimeWIB(value, lang) {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat(lang === 'id' ? 'id-ID' : 'en-GB', {
    timeZone: 'Asia/Jakarta', day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  }).format(date) + ' WIB';
}

// "9901000011" -> "••••••0011"
export function maskAccount(accountNo) {
  const s = String(accountNo || '');
  return s.length >= 4 ? '••••••' + s.slice(-4) : s;
}

export const I18nContext = createContext({ lang: 'en', setLang: () => {}, t: (key) => key });
export const useI18n = () => useContext(I18nContext);
