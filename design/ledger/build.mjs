// Generates the ledger direction artboards from one synthetic data set, so the
// three directions differ only in look. Run: node design/ledger/build.mjs
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = dirname(fileURLToPath(import.meta.url));

// ---------- synthetic data (not from any real statement) ----------
const OPENING = 310419100; // minor units, end of August
const rows = [
  { d: '09.02', payee: 'Golomt Visa', memo: 'Card payment', cat: 'Transfer', kind: 'transfer', amt: -35000000, st: 'rec' },
  { d: '09.05', payee: 'Өргөө кино театр', memo: 'POS · Сүхбаатар дүүрэг', cat: 'Entertainment', amt: -4800000, st: 'rec' },
  { d: '09.08', payee: 'УБЦТС ТӨХК', memo: 'Electricity · August', cat: 'Utilities', amt: -6421050, st: 'rec' },
  { d: '09.10', payee: 'Altan Gadas LLC', memo: 'Цалин · September', cat: 'Salary', amt: 250000000, st: 'rec' },
  { d: '09.12', payee: 'E-Mart Хан-Уул', memo: 'QPay', cat: 'Groceries', amt: -21475050, st: 'clr' },
  { d: '09.13', payee: 'Шунхлай', memo: 'Fuel · АИ-92', cat: 'Transport', amt: -12000000, st: 'clr' },
  { d: '09.14', payee: 'Sakura Coffee', memo: 'POS', cat: 'Dining out', amt: -800000, st: 'clr' },
  { d: '09.15', payee: 'TDB', memo: 'CHARGE: 380.00 ₮', cat: 'Bank fees', amt: -38000, st: 'clr' },
  { d: '09.15', payee: 'Khan Savings', memo: 'Monthly savings', cat: 'Transfer', kind: 'transfer', amt: -50000000, st: 'clr' },
  { d: '09.16', payee: 'Unitel', memo: 'Postpaid · 9911-XXXX', cat: 'Phone & internet', amt: -3000000, st: 'unc', selected: true },
  { d: '09.16', payee: 'Номин супермаркет', memo: 'Groceries ₮61,900 · Household ₮24,500', cat: '2 categories', kind: 'split', amt: -8640000, st: 'unc' },
];
let bal = OPENING;
for (const r of rows) { bal += r.amt; r.bal = bal; }
const WORKING = bal;
const CLEARED = OPENING + rows.filter(r => r.st !== 'unc').reduce((s, r) => s + r.amt, 0);
const RECONCILED = OPENING + rows.filter(r => r.st === 'rec').reduce((s, r) => s + r.amt, 0);
const IN = rows.filter(r => r.amt > 0).reduce((s, r) => s + r.amt, 0);
const OUT_ = -rows.filter(r => r.amt < 0).reduce((s, r) => s + r.amt, 0);
const scheduled = { d: '09.20', payee: 'Zaisan Residence', memo: 'Rent · repeats monthly', cat: 'Housing', amt: -180000000 };
scheduled.bal = WORKING + scheduled.amt;
const register = [...rows].reverse();

const accounts = [
  { group: 'Cash & bank', items: [
    { name: 'TDB Checking', bal: WORKING, active: true },
    { name: 'Khan Savings', bal: 1260000000 },
    { name: 'Cash wallet', bal: 8650000 },
  ]},
  { group: 'Credit', items: [{ name: 'Golomt Visa', bal: -64020000 }] },
];
const NET = accounts.flatMap(g => g.items).reduce((s, a) => s + a.bal, 0);

// ---------- formatting ----------
const whole = m => Math.trunc(Math.abs(m) / 100).toLocaleString('en-US');
const cents = m => '.' + String(Math.abs(m) % 100).padStart(2, '0');
const money = (m, centStyle, { sign = false } = {}) =>
  `${sign && m < 0 ? '−' : ''}₮${whole(m)}<span style="${centStyle}">${cents(m)}</span>`;

// ---------- icons (1.5px stroke, 16px grid) ----------
const ic = (d, c, s = 16) => `<svg width="${s}" height="${s}" viewBox="0 0 16 16" fill="none" stroke="${c}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink: 0; display: block">${d}</svg>`;
const I = {
  search: '<circle cx="7" cy="7" r="4.5"></circle><path d="M10.5 10.5 14 14"></path>',
  plus: '<path d="M8 3v10M3 8h10"></path>',
  import: '<path d="M8 2.5v8M4.5 7 8 10.5 11.5 7M2.5 13.5h11"></path>',
  filter: '<path d="M2.5 4h11M4.5 8h7M6.5 12h3"></path>',
  cal: '<rect x="2.5" y="3.5" width="11" height="10" rx="1.5"></rect><path d="M2.5 6.5h11M5.5 2v3M10.5 2v3"></path>',
  split: '<path d="M3 8h4l3-4h3M7 8l3 4h3"></path>',
  transfer: '<path d="M3 5.5h10M10.5 3 13 5.5 10.5 8M13 10.5H3M5.5 8 3 10.5 5.5 13"></path>',
  chev: '<path d="M6 4l4 4-4 4"></path>',
  chevDown: '<path d="M4 6l4 4 4-4"></path>',
  repeat: '<path d="M3 7V6a2 2 0 0 1 2-2h8M11 2l2 2-2 2M13 9v1a2 2 0 0 1-2 2H3M5 14l-2-2 2-2"></path>',
  lock: '<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"></rect><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"></path>',
  ledger: '<path d="M3 3.5h10M3 8h10M3 12.5h10"></path>',
  budget: '<circle cx="8" cy="8" r="5.5"></circle><path d="M8 2.5V8l4 3"></path>',
  reports: '<path d="M3 13V8M8 13V3M13 13V6"></path>',
};

const statusGlyph = (st, t) => {
  if (st === 'unc') return `<div style="width: 9px; height: 9px; border-radius: 50%; border: 1.5px solid ${t.unc}; box-sizing: border-box"></div>`;
  if (st === 'clr') return `<div style="width: 9px; height: 9px; border-radius: 50%; background: ${t.clr}"></div>`;
  return `<div style="width: 8px; height: 8px; background: ${t.rec}; transform: rotate(45deg)"></div>`; // gold diamond, from the mark
};

const kindGlyph = (r, c) => r.kind ? ic(I[r.kind], c, 14) : '';

// ---------- Direction A: Private Banking ----------
function privateBanking() {
  const t = {
    ground: '#F6F5F1', paper: '#FFFFFF', ink: '#03173E', ink2: '#5A6272', ink3: '#8C92A0',
    rule: '#E6E3DB', gold: '#C9A96B', blue: '#0342B2', green: '#1E7150',
    unc: '#8C92A0', clr: '#03173E', rec: '#C9A96B',
  };
  const serif = "'Literata', Georgia, 'Times New Roman', serif";
  const sans = "'Golos Text', 'Segoe UI', system-ui, sans-serif";
  const centMuted = `color: ${t.ink3}; font-size: 0.82em`;
  const cols = 'grid-template-columns: 28px 88px minmax(0, 1fr) 190px 150px 150px 170px';

  const row = (r, extra = '') => {
    const sel = r.selected;
    return `<div style="display: grid; ${cols}; align-items: center; column-gap: 16px; padding: 0 32px; height: 60px; border-bottom: 1px solid ${t.rule}; background: ${sel ? '#FBF8F0' : 'transparent'}; box-shadow: ${sel ? `inset 3px 0 0 ${t.gold}` : 'none'}; ${extra}">
      <div style="display: flex; justify-content: center">${statusGlyph(r.st, t)}</div>
      <div style="font-size: 13px; color: ${t.ink2}; font-variant-numeric: tabular-nums">2026.${r.d}</div>
      <div style="display: flex; flex-direction: column; gap: 3px; min-width: 0">
        <div style="display: flex; align-items: center; gap: 8px; font-size: 15px; font-weight: 500; color: ${t.ink}">${r.kind === 'transfer' ? '<span style="color: ' + t.ink3 + '; font-weight: 400">To</span> ' : ''}${r.payee}${kindGlyph(r, t.ink3)}</div>
        <div style="font-size: 12.5px; color: ${t.ink3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${r.memo}</div>
      </div>
      <div style="display: flex">${sel
        ? `<div style="display: flex; align-items: center; justify-content: space-between; width: 100%; height: 34px; padding: 0 10px; box-sizing: border-box; background: ${t.paper}; border: 1px solid ${t.ink}; border-radius: 4px; box-shadow: 0 0 0 3px rgba(201, 169, 107, 0.28); font-size: 13.5px; color: ${t.ink}">${r.cat}${ic(I.chevDown, t.ink2, 14)}</div>`
        : `<div style="font-size: 13.5px; color: ${r.kind ? t.ink3 : t.ink2}; ${r.kind === 'split' ? 'font-style: italic' : ''}">${r.cat}</div>`}</div>
      <div style="text-align: right; font-family: ${serif}; font-size: 15px; color: ${t.ink}; font-variant-numeric: lining-nums tabular-nums">${r.amt < 0 ? money(r.amt, centMuted) : ''}</div>
      <div style="text-align: right; font-family: ${serif}; font-size: 15px; color: ${t.green}; font-variant-numeric: lining-nums tabular-nums">${r.amt > 0 ? '+' + money(r.amt, 'opacity: 0.7; font-size: 0.82em') : ''}</div>
      <div style="text-align: right; font-family: ${serif}; font-size: 15px; color: ${r.st === 'unc' ? t.ink2 : t.ink}; font-variant-numeric: lining-nums tabular-nums">${money(r.bal, centMuted, { sign: true })}</div>
    </div>`;
  };

  const balanceBlock = (label, m, note, strong) => `<div style="display: flex; flex-direction: column; gap: 6px">
      <div style="font-size: 11px; letter-spacing: 0.14em; text-transform: uppercase; color: ${t.ink3}">${label}</div>
      <div style="font-family: ${serif}; font-size: ${strong ? 40 : 24}px; font-weight: ${strong ? 400 : 400}; letter-spacing: -0.01em; color: ${t.ink}; font-variant-numeric: lining-nums tabular-nums; line-height: 1">${money(m, `color: ${t.ink3}; font-size: 0.55em`)}</div>
      <div style="font-size: 12.5px; color: ${t.ink3}">${note}</div>
    </div>`;

  const sidebar = `<div style="width: 264px; flex-shrink: 0; background: ${t.ink}; color: #E9ECF2; display: flex; flex-direction: column; padding: 28px 0">
    <div style="display: flex; align-items: center; gap: 12px; padding: 0 28px 36px">
      <div style="width: 12px; height: 12px; background: ${t.gold}; transform: rotate(45deg)"></div>
      <div style="font-family: ${serif}; font-size: 20px; letter-spacing: -0.01em; color: #FFFFFF">BetterBudget</div>
    </div>
    <div style="display: flex; flex-direction: column; gap: 2px; padding: 0 16px 28px">
      ${[['ledger', 'Ledger', true], ['budget', 'Budget'], ['reports', 'Reports']].map(([k, l, a]) => `<div style="display: flex; align-items: center; gap: 12px; padding: 9px 12px; border-radius: 6px; background: ${a ? 'rgba(255, 255, 255, 0.07)' : 'transparent'}; font-size: 14px; color: ${a ? '#FFFFFF' : '#9AA3B5'}">${ic(I[k], a ? t.gold : '#6F7A90')}${l}</div>`).join('')}
    </div>
    <div style="height: 1px; background: rgba(255, 255, 255, 0.08); margin: 0 28px 24px"></div>
    ${accounts.map(g => `<div style="display: flex; flex-direction: column; gap: 2px; padding: 0 16px 20px">
      <div style="font-size: 10.5px; letter-spacing: 0.14em; text-transform: uppercase; color: #6F7A90; padding: 0 12px 8px">${g.group}</div>
      ${g.items.map(a => `<div style="display: flex; justify-content: space-between; align-items: baseline; padding: 9px 12px; border-radius: 6px; background: ${a.active ? 'rgba(201, 169, 107, 0.14)' : 'transparent'}">
        <div style="font-size: 14px; color: ${a.active ? '#FFFFFF' : '#C3C9D5'}">${a.name}</div>
        <div style="font-family: ${serif}; font-size: 13px; color: ${a.active ? '#FFFFFF' : '#9AA3B5'}; font-variant-numeric: lining-nums tabular-nums">${a.bal < 0 ? '−' : ''}₮${whole(a.bal)}</div>
      </div>`).join('')}
    </div>`).join('')}
    <div style="margin-top: auto; padding: 20px 28px 0; border-top: 1px solid rgba(255, 255, 255, 0.08); display: flex; justify-content: space-between; align-items: baseline">
      <div style="font-size: 12px; letter-spacing: 0.1em; text-transform: uppercase; color: #6F7A90">Net worth</div>
      <div style="font-family: ${serif}; font-size: 17px; color: #FFFFFF; font-variant-numeric: lining-nums tabular-nums">₮${whole(NET)}</div>
    </div>
  </div>`;

  const headRow = `<div style="display: grid; ${cols}; column-gap: 16px; padding: 0 32px; height: 40px; align-items: center; border-bottom: 1px solid ${t.ink}; font-size: 11px; letter-spacing: 0.12em; text-transform: uppercase; color: ${t.ink3}">
    <div></div><div>Date</div><div>Payee</div><div>Category</div><div style="text-align: right">Outflow</div><div style="text-align: right">Inflow</div><div style="text-align: right">Balance</div>
  </div>`;

  const body = `<div style="flex-grow: 1; display: flex; flex-direction: column; min-width: 0; background: ${t.ground}">
    <div style="display: flex; flex-direction: column; gap: 28px; padding: 36px 32px 28px">
      <div style="display: flex; justify-content: space-between; align-items: flex-end">
        <div style="display: flex; flex-direction: column; gap: 6px">
          <div style="font-size: 12.5px; color: ${t.ink3}">Trade and Development Bank · Checking ··4410</div>
          <div style="font-family: ${serif}; font-size: 34px; letter-spacing: -0.015em; color: ${t.ink}; line-height: 1.1">TDB Checking</div>
        </div>
        <div style="display: flex; gap: 10px">
          <div style="display: flex; align-items: center; gap: 8px; height: 38px; padding: 0 16px; border: 1px solid ${t.rule}; background: ${t.paper}; border-radius: 6px; font-size: 13.5px; color: ${t.ink}">${ic(I.import, t.ink2)}Import statement</div>
          <div style="display: flex; align-items: center; gap: 8px; height: 38px; padding: 0 16px; background: ${t.ink}; border-radius: 6px; font-size: 13.5px; color: #FFFFFF">${ic(I.plus, t.gold)}New transaction</div>
        </div>
      </div>
      <div style="display: flex; gap: 56px; align-items: flex-end; padding-top: 24px; border-top: 1px solid ${t.gold}">
        ${balanceBlock('Working balance', WORKING, 'Includes 2 uncleared', true)}
        <div style="width: 1px; align-self: stretch; background: ${t.rule}"></div>
        ${balanceBlock('Cleared', CLEARED, 'Matches the bank today')}
        ${balanceBlock('Reconciled', RECONCILED, 'Statement of 2026.09.10')}
      </div>
    </div>
    <div style="margin: 0 32px; background: ${t.paper}; border: 1px solid ${t.rule}; border-radius: 8px; display: flex; flex-direction: column; overflow: hidden; flex-grow: 1">
      <div style="display: flex; align-items: center; gap: 12px; padding: 14px 32px; border-bottom: 1px solid ${t.rule}">
        <div style="display: flex; align-items: center; gap: 10px; flex-grow: 1; font-size: 14px; color: ${t.ink3}">${ic(I.search, t.ink3)}Search payee, memo or amount</div>
        ${['This month', 'All categories', 'Any status'].map(f => `<div style="display: flex; align-items: center; gap: 6px; height: 30px; padding: 0 12px; border: 1px solid ${t.rule}; border-radius: 15px; font-size: 13px; color: ${t.ink2}">${f}${ic(I.chevDown, t.ink3, 12)}</div>`).join('')}
      </div>
      ${headRow}
      <div style="display: flex; align-items: center; gap: 12px; padding: 0 32px; height: 52px; background: #FBF8F0; border-bottom: 1px solid ${t.rule}">
        ${ic(I.repeat, t.gold, 14)}
        <div style="font-size: 13px; color: ${t.ink2}">Scheduled</div>
        <div style="font-size: 13px; color: ${t.ink}">2026.${scheduled.d} · ${scheduled.payee} · ${scheduled.cat}</div>
        <div style="margin-left: auto; font-family: ${serif}; font-size: 15px; color: ${t.ink2}; font-variant-numeric: lining-nums tabular-nums">${money(scheduled.amt, centMuted, { sign: true })}</div>
        <div style="font-size: 12.5px; color: ${t.gold}; padding-left: 12px">Confirm</div>
      </div>
      <div style="display: flex; align-items: baseline; gap: 16px; padding: 18px 32px 10px">
        <div style="font-family: ${serif}; font-size: 17px; color: ${t.ink}">September 2026</div>
        <div style="font-size: 12.5px; color: ${t.ink3}; font-variant-numeric: tabular-nums">${rows.length} transactions · in ₮${whole(IN)} · out ₮${whole(OUT_)}</div>
      </div>
      <div style="border-top: 1px solid ${t.rule}">${register.slice(0, 7).map(r => row(r)).join('')}</div>
    </div>
    <div style="height: 32px"></div>
  </div>`;

  return artboard({
    title: 'Private Banking',
    fonts: 'family=Literata:opsz,wght@7..72,400;7..72,500&family=Golos+Text:wght@400;500',
    bg: t.ground, font: sans, color: t.ink, link: t.blue,
    html: `<div style="display: flex; width: 1440px; height: 900px; overflow: hidden">${sidebar}${body}</div>`,
  });
}

// ---------- Direction B: Midnight ----------
function midnight() {
  const t = {
    ground: '#060D1E', panel: '#0B1630', raised: '#10204A', rule: 'rgba(214, 224, 255, 0.07)',
    ink: '#EEF1F8', ink2: '#A3AEC6', ink3: '#66728E', blue: '#4F7BFF', gold: '#D9B878', green: '#5CCB9A',
    unc: '#66728E', clr: '#A3AEC6', rec: '#D9B878',
  };
  const sans = "'Onest', 'Segoe UI', system-ui, sans-serif";
  const centMuted = `color: ${t.ink3}`;
  const cols = 'grid-template-columns: 24px 76px minmax(0, 1fr) 200px 140px 140px 160px';

  // running balance across the month, drawn as a quiet area line
  const pts = [OPENING, ...rows.map(r => r.bal)];
  const W = 420, H = 72, min = Math.min(...pts), max = Math.max(...pts);
  const xy = pts.map((v, i) => [(i / (pts.length - 1)) * W, H - 6 - ((v - min) / (max - min)) * (H - 16)]);
  const line = xy.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
  const [lx, ly] = xy[xy.length - 1];
  const spark = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" style="display: block; overflow: visible">
    <defs><linearGradient id="fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${t.blue}" stop-opacity="0.22"></stop><stop offset="1" stop-color="${t.blue}" stop-opacity="0"></stop></linearGradient></defs>
    <path d="${line} L${W} ${H} L0 ${H} Z" fill="url(#fill)"></path>
    <path d="${line}" fill="none" stroke="${t.blue}" stroke-width="1.75" stroke-linejoin="round"></path>
    <circle cx="${lx}" cy="${ly}" r="3.5" fill="${t.ground}" stroke="${t.ink}" stroke-width="1.5"></circle>
  </svg>`;

  const row = r => {
    const sel = r.selected;
    return `<div style="display: grid; ${cols}; align-items: center; column-gap: 16px; padding: 0 20px; margin: 0 12px; height: 54px; border-radius: 10px; background: ${sel ? 'rgba(79, 123, 255, 0.12)' : 'transparent'}; box-shadow: ${sel ? 'inset 0 0 0 1px rgba(79, 123, 255, 0.35)' : 'none'}">
      <div style="display: flex; justify-content: center">${statusGlyph(r.st, t)}</div>
      <div style="font-size: 13px; color: ${t.ink3}; font-variant-numeric: tabular-nums">${r.d.replace('.', ' · ')}</div>
      <div style="display: flex; align-items: center; gap: 12px; min-width: 0">
        <div style="width: 32px; height: 32px; border-radius: 9px; flex-shrink: 0; background: ${t.raised}; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 600; color: ${t.ink2}">${r.kind ? ic(I[r.kind], t.ink2, 15) : r.payee[0]}</div>
        <div style="display: flex; flex-direction: column; gap: 2px; min-width: 0">
          <div style="font-size: 14.5px; font-weight: 500; color: ${t.ink}">${r.kind === 'transfer' ? '→ ' : ''}${r.payee}</div>
          <div style="font-size: 12.5px; color: ${t.ink3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${r.memo}</div>
        </div>
      </div>
      <div style="display: flex">${sel
        ? `<div style="display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px 0 12px; border-radius: 8px; background: ${t.ground}; box-shadow: 0 0 0 1.5px ${t.blue}, 0 0 0 5px rgba(79, 123, 255, 0.18); font-size: 13px; color: ${t.ink}">${r.cat}${ic(I.chevDown, t.ink2, 12)}</div>`
        : `<div style="height: 26px; display: flex; align-items: center; padding: 0 10px; border-radius: 13px; background: ${r.kind ? 'transparent' : 'rgba(214, 224, 255, 0.06)'}; font-size: 12.5px; color: ${t.ink2}">${r.cat}</div>`}</div>
      <div style="text-align: right; font-size: 14.5px; color: ${t.ink}; font-variant-numeric: tabular-nums">${r.amt < 0 ? money(r.amt, centMuted) : ''}</div>
      <div style="text-align: right; font-size: 14.5px; color: ${t.green}; font-variant-numeric: tabular-nums">${r.amt > 0 ? '+' + money(r.amt, 'opacity: 0.6') : ''}</div>
      <div style="text-align: right; font-size: 14.5px; color: ${r.st === 'unc' ? t.ink2 : t.ink}; font-variant-numeric: tabular-nums">${money(r.bal, centMuted, { sign: true })}</div>
    </div>`;
  };

  const sidebar = `<div style="width: 248px; flex-shrink: 0; display: flex; flex-direction: column; padding: 24px 12px; border-right: 1px solid ${t.rule}">
    <div style="display: flex; align-items: center; gap: 12px; padding: 4px 12px 32px">
      <div style="width: 10px; height: 10px; background: ${t.gold}; transform: rotate(45deg)"></div>
      <div style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em; color: ${t.ink}">BetterBudget</div>
    </div>
    ${[['ledger', 'Ledger', true], ['budget', 'Budget'], ['reports', 'Reports']].map(([k, l, a]) => `<div style="display: flex; align-items: center; gap: 12px; padding: 9px 12px; border-radius: 8px; background: ${a ? t.panel : 'transparent'}; font-size: 14px; color: ${a ? t.ink : t.ink3}">${ic(I[k], a ? t.blue : t.ink3)}${l}</div>`).join('')}
    <div style="height: 28px"></div>
    ${accounts.map(g => `<div style="display: flex; flex-direction: column; gap: 2px; padding-bottom: 20px">
      <div style="font-size: 12px; color: ${t.ink3}; padding: 0 12px 8px">${g.group}</div>
      ${g.items.map(a => `<div style="display: flex; flex-direction: column; gap: 2px; padding: 9px 12px; border-radius: 8px; background: ${a.active ? t.panel : 'transparent'}; box-shadow: ${a.active ? `inset 2px 0 0 ${t.blue}` : 'none'}">
        <div style="font-size: 13.5px; color: ${a.active ? t.ink : t.ink2}">${a.name}</div>
        <div style="font-size: 12.5px; color: ${a.bal < 0 ? '#F08A8A' : t.ink3}; font-variant-numeric: tabular-nums">${a.bal < 0 ? '−' : ''}₮${whole(a.bal)}</div>
      </div>`).join('')}
    </div>`).join('')}
    <div style="margin-top: auto; padding: 16px 12px 0; border-top: 1px solid ${t.rule}; display: flex; flex-direction: column; gap: 4px">
      <div style="font-size: 12px; color: ${t.ink3}">Net worth</div>
      <div style="font-size: 18px; font-weight: 500; color: ${t.ink}; font-variant-numeric: tabular-nums">₮${whole(NET)}</div>
    </div>
  </div>`;

  const body = `<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 20px; min-width: 0; padding: 24px 28px 28px">
    <div style="display: flex; justify-content: space-between; align-items: center">
      <div style="display: flex; align-items: center; gap: 8px; font-size: 13px; color: ${t.ink3}">Ledger${ic(I.chev, t.ink3, 12)}<span style="color: ${t.ink2}">TDB Checking</span></div>
      <div style="display: flex; gap: 10px">
        <div style="display: flex; align-items: center; gap: 10px; width: 280px; height: 36px; padding: 0 12px; border-radius: 9px; background: ${t.panel}; font-size: 13px; color: ${t.ink3}; box-sizing: border-box">${ic(I.search, t.ink3, 14)}Search<span style="margin-left: auto; font-size: 11.5px; padding: 2px 6px; border-radius: 5px; background: ${t.raised}">⌘K</span></div>
        <div style="display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 14px; border-radius: 9px; background: ${t.panel}; font-size: 13px; color: ${t.ink}">${ic(I.import, t.ink2, 14)}Import</div>
        <div style="display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 14px; border-radius: 9px; background: ${t.blue}; font-size: 13px; font-weight: 500; color: #FFFFFF">${ic(I.plus, '#FFFFFF', 14)}Add</div>
      </div>
    </div>
    <div style="display: flex; align-items: stretch; justify-content: space-between; padding: 28px 32px; border-radius: 16px; background: ${t.panel}; border: 1px solid ${t.rule}">
      <div style="display: flex; flex-direction: column; justify-content: space-between; gap: 18px">
        <div style="display: flex; flex-direction: column; gap: 8px">
          <div style="font-size: 13px; color: ${t.ink2}">TDB Checking · Working balance</div>
          <div style="font-size: 48px; font-weight: 500; letter-spacing: -0.03em; color: ${t.ink}; font-variant-numeric: tabular-nums; line-height: 1">${money(WORKING, `color: ${t.ink3}; font-size: 0.5em; letter-spacing: 0`)}</div>
        </div>
        <div style="display: flex; gap: 28px">
          ${[['Cleared', CLEARED, t.clr, 'dot'], ['Reconciled 09.10', RECONCILED, t.rec, 'dia']].map(([l, m, c, g]) => `<div style="display: flex; align-items: center; gap: 10px">
            ${g === 'dot' ? `<div style="width: 7px; height: 7px; border-radius: 50%; background: ${c}"></div>` : `<div style="width: 7px; height: 7px; background: ${c}; transform: rotate(45deg)"></div>`}
            <div style="font-size: 13px; color: ${t.ink3}">${l}</div>
            <div style="font-size: 14px; color: ${t.ink}; font-variant-numeric: tabular-nums">₮${whole(m)}${cents(m)}</div>
          </div>`).join('')}
        </div>
      </div>
      <div style="display: flex; flex-direction: column; justify-content: space-between; align-items: flex-end; gap: 12px">
        <div style="display: flex; gap: 20px; font-size: 13px; font-variant-numeric: tabular-nums">
          <div style="color: ${t.ink3}">September</div>
          <div style="color: ${t.green}">+₮${whole(IN)}</div>
          <div style="color: ${t.ink2}">−₮${whole(OUT_)}</div>
        </div>
        ${spark}
      </div>
    </div>
    <div style="flex-grow: 1; display: flex; flex-direction: column; border-radius: 16px; background: ${t.panel}; border: 1px solid ${t.rule}; overflow: hidden; padding-bottom: 8px">
      <div style="display: flex; align-items: center; gap: 8px; padding: 14px 20px">
        ${['All', 'Uncleared', 'Scheduled'].map((f, i) => `<div style="height: 28px; display: flex; align-items: center; padding: 0 12px; border-radius: 8px; font-size: 13px; background: ${i === 0 ? t.raised : 'transparent'}; color: ${i === 0 ? t.ink : t.ink3}">${f}</div>`).join('')}
        <div style="margin-left: auto; display: flex; align-items: center; gap: 8px; font-size: 13px; color: ${t.ink3}">${ic(I.cal, t.ink3, 14)}Sep 2026${ic(I.filter, t.ink3, 14)}</div>
      </div>
      <div style="display: grid; ${cols}; column-gap: 16px; padding: 0 20px; margin: 0 12px; height: 32px; align-items: center; font-size: 12px; color: ${t.ink3}">
        <div></div><div>Date</div><div>Payee</div><div>Category</div><div style="text-align: right">Out</div><div style="text-align: right">In</div><div style="text-align: right">Balance</div>
      </div>
      <div style="display: grid; ${cols}; align-items: center; column-gap: 16px; padding: 0 20px; margin: 0 12px 4px; height: 50px; border-radius: 10px; border: 1px dashed rgba(217, 184, 120, 0.35)">
        <div style="display: flex; justify-content: center">${ic(I.repeat, t.gold, 13)}</div>
        <div style="font-size: 13px; color: ${t.gold}; font-variant-numeric: tabular-nums">09 · 20</div>
        <div style="font-size: 14px; color: ${t.ink2}">${scheduled.payee} <span style="color: ${t.ink3}">· Scheduled</span></div>
        <div style="font-size: 12.5px; color: ${t.ink3}">${scheduled.cat}</div>
        <div style="text-align: right; font-size: 14.5px; color: ${t.ink2}; font-variant-numeric: tabular-nums">${money(scheduled.amt, centMuted)}</div>
        <div></div>
        <div style="text-align: right; font-size: 13px; color: ${t.gold}">Confirm</div>
      </div>
      ${register.slice(0, 8).map(row).join('')}
    </div>
  </div>`;

  return artboard({
    title: 'Midnight',
    fonts: 'family=Onest:wght@400;500;600',
    bg: t.ground, font: sans, color: t.ink, link: t.blue,
    html: `<div style="display: flex; width: 1440px; height: 900px; overflow: hidden; background: ${t.ground}">${sidebar}${body}</div>`,
  });
}

// ---------- Direction C: Precision ----------
function precision() {
  const t = {
    ground: '#FBFBFC', paper: '#FFFFFF', ink: '#0E1525', ink2: '#4B5566', ink3: '#8A93A3', rule: '#E8EAEF', rule2: '#F1F2F5',
    blue: '#0342B2', navy: '#03173E', gold: '#B8904A', green: '#177A4E',
    unc: '#8A93A3', clr: '#0342B2', rec: '#C9A96B',
  };
  const sans = "'IBM Plex Sans', 'Segoe UI', system-ui, sans-serif";
  const mono = "'IBM Plex Mono', ui-monospace, 'SF Mono', Menlo, monospace";
  const centMuted = `color: ${t.ink3}`;
  const cols = 'grid-template-columns: 32px 20px 92px minmax(0, 1.1fr) minmax(0, 1fr) 170px 130px 130px 150px';

  const row = (r, i) => {
    const sel = r.selected;
    const cell = 'height: 100%; display: flex; align-items: center';
    return `<div style="display: grid; ${cols}; height: 38px; border-bottom: 1px solid ${t.rule2}; background: ${sel ? '#EEF3FC' : i % 2 ? '#FCFCFD' : t.paper}; font-size: 13px; color: ${t.ink}">
      <div style="${cell}; justify-content: center">${sel ? `<div style="width: 13px; height: 13px; border-radius: 3px; background: ${t.blue}; display: flex; align-items: center; justify-content: center">${ic('<path d="M3.5 8.5 6.5 11.5 12.5 4.5"></path>', '#FFFFFF', 10)}</div>` : `<div style="width: 13px; height: 13px; border-radius: 3px; border: 1px solid #CBD0D9; box-sizing: border-box"></div>`}</div>
      <div style="${cell}; justify-content: center">${statusGlyph(r.st, t)}</div>
      <div style="${cell}; padding-left: 8px; font-family: ${mono}; font-size: 12.5px; color: ${t.ink2}">2026.${r.d}</div>
      <div style="${cell}; gap: 6px; padding: 0 10px; min-width: 0; font-weight: 500">${r.kind ? ic(I[r.kind], t.blue, 13) : ''}${r.payee}</div>
      <div style="${cell}; padding: 0 10px; min-width: 0; color: ${t.ink3}"><span style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${r.memo}</span></div>
      <div style="${cell}; padding: 0 10px">${sel
        ? `<div style="display: flex; align-items: center; justify-content: space-between; width: 100%; height: 28px; padding: 0 8px; box-sizing: border-box; background: ${t.paper}; border: 1.5px solid ${t.blue}; border-radius: 3px; color: ${t.ink}">${r.cat}${ic(I.chevDown, t.blue, 12)}</div>`
        : `<span style="color: ${r.kind ? t.ink3 : t.ink2}">${r.cat}</span>`}</div>
      <div style="${cell}; justify-content: flex-end; padding: 0 12px; font-family: ${mono}; font-size: 13px; border-left: 1px solid ${t.rule2}">${r.amt < 0 ? money(r.amt, centMuted) : ''}</div>
      <div style="${cell}; justify-content: flex-end; padding: 0 12px; font-family: ${mono}; font-size: 13px; color: ${t.green}; border-left: 1px solid ${t.rule2}">${r.amt > 0 ? money(r.amt, 'opacity: 0.6') : ''}</div>
      <div style="${cell}; justify-content: flex-end; padding: 0 16px 0 12px; font-family: ${mono}; font-size: 13px; font-weight: 500; border-left: 1px solid ${t.rule}; background: ${sel ? 'transparent' : 'rgba(3, 23, 62, 0.018)'}">${money(r.bal, centMuted, { sign: true })}</div>
    </div>`;
  };

  // three balances read as a chain: reconciled + cleared since = cleared; + uncleared = working
  const chain = [
    ['Reconciled', '2026.09.10', RECONCILED, t.rec, 'dia'],
    ['Cleared', 'Since reconcile ' + (CLEARED - RECONCILED < 0 ? '−' : '+') + '₮' + whole(CLEARED - RECONCILED) + cents(CLEARED - RECONCILED), CLEARED, t.clr, 'dot'],
    ['Working', 'Uncleared −₮' + whole(WORKING - CLEARED) + cents(WORKING - CLEARED), WORKING, t.ink, 'ring'],
  ];
  const glyph = (g, c) => g === 'dia' ? `<div style="width: 7px; height: 7px; background: ${c}; transform: rotate(45deg)"></div>` : g === 'dot' ? `<div style="width: 8px; height: 8px; border-radius: 50%; background: ${c}"></div>` : `<div style="width: 8px; height: 8px; border-radius: 50%; border: 1.5px solid ${t.ink3}; box-sizing: border-box"></div>`;

  const topbar = `<div style="height: 52px; flex-shrink: 0; display: flex; align-items: center; gap: 28px; padding: 0 20px; background: ${t.navy}; color: #FFFFFF">
    <div style="display: flex; align-items: center; gap: 10px; font-size: 14.5px; font-weight: 600">
      <div style="width: 9px; height: 9px; background: #C9A96B; transform: rotate(45deg)"></div>BetterBudget
    </div>
    <div style="display: flex; gap: 4px; height: 100%">
      ${['Ledger', 'Budget', 'Reports'].map((l, i) => `<div style="height: 100%; display: flex; align-items: center; padding: 0 12px; font-size: 13px; color: ${i === 0 ? '#FFFFFF' : '#8E9AB3'}; box-shadow: ${i === 0 ? 'inset 0 -2px 0 #C9A96B' : 'none'}">${l}</div>`).join('')}
    </div>
    <div style="margin-left: auto; display: flex; align-items: center; gap: 10px; width: 320px; height: 32px; padding: 0 10px; border-radius: 4px; background: rgba(255, 255, 255, 0.08); font-size: 13px; color: #8E9AB3; box-sizing: border-box">${ic(I.search, '#8E9AB3', 14)}Search all accounts<span style="margin-left: auto; font-family: ${mono}; font-size: 11px">⌘K</span></div>
  </div>`;

  const sidebar = `<div style="width: 232px; flex-shrink: 0; border-right: 1px solid ${t.rule}; background: ${t.paper}; display: flex; flex-direction: column; padding: 16px 0">
    ${accounts.map(g => `<div style="display: flex; flex-direction: column; padding-bottom: 14px">
      <div style="display: flex; justify-content: space-between; padding: 6px 16px; font-size: 11px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; color: ${t.ink3}"><span>${g.group}</span></div>
      ${g.items.map(a => `<div style="display: flex; justify-content: space-between; align-items: center; height: 32px; padding: 0 16px; background: ${a.active ? '#EEF3FC' : 'transparent'}; box-shadow: ${a.active ? `inset 2px 0 0 ${t.blue}` : 'none'}; font-size: 13px">
        <span style="color: ${a.active ? t.blue : t.ink}; font-weight: ${a.active ? 500 : 400}">${a.name}</span>
        <span style="font-family: ${mono}; font-size: 12px; color: ${a.bal < 0 ? '#B3261E' : t.ink2}">${a.bal < 0 ? '−' : ''}${whole(a.bal)}</span>
      </div>`).join('')}
    </div>`).join('')}
    <div style="margin-top: auto; display: flex; justify-content: space-between; align-items: center; height: 40px; padding: 0 16px; border-top: 1px solid ${t.rule}; font-size: 12px; color: ${t.ink3}">
      <span>Net worth</span><span style="font-family: ${mono}; color: ${t.ink}; font-weight: 500">₮${whole(NET)}</span>
    </div>
  </div>`;

  const body = `<div style="flex-grow: 1; display: flex; flex-direction: column; min-width: 0">
    <div style="display: flex; align-items: center; justify-content: space-between; padding: 18px 24px 16px; background: ${t.paper}; border-bottom: 1px solid ${t.rule}">
      <div style="display: flex; flex-direction: column; gap: 2px">
        <div style="font-size: 20px; font-weight: 600; letter-spacing: -0.01em; color: ${t.ink}">TDB Checking</div>
        <div style="font-size: 12.5px; color: ${t.ink3}">Trade and Development Bank · ··4410 · MNT</div>
      </div>
      <div style="display: flex; align-items: stretch">
        ${chain.map(([l, sub, m, c, g], i) => `${i ? `<div style="display: flex; align-items: center; padding: 0 14px; color: #C3C8D2">${ic(I.chev, '#C3C8D2', 14)}</div>` : ''}<div style="display: flex; flex-direction: column; gap: 3px; padding: 6px 14px; border-radius: 4px; background: ${i === 2 ? '#F3F6FB' : 'transparent'}">
          <div style="display: flex; align-items: center; gap: 6px; font-size: 11.5px; font-weight: 500; color: ${t.ink2}">${glyph(g, c)}${l}</div>
          <div style="font-family: ${mono}; font-size: ${i === 2 ? 19 : 16}px; font-weight: ${i === 2 ? 600 : 500}; color: ${t.ink}">${money(m, `color: ${t.ink3}; font-weight: 400`)}</div>
          <div style="font-size: 11.5px; color: ${t.ink3}; font-variant-numeric: tabular-nums">${sub}</div>
        </div>`).join('')}
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 8px; padding: 10px 24px; background: ${t.paper}; border-bottom: 1px solid ${t.rule}">
      ${[['cal', '2026.09.01 – 2026.09.30'], ['filter', 'Category'], [null, 'Status: Any'], [null, 'Amount']].map(([k, l]) => `<div style="display: flex; align-items: center; gap: 6px; height: 28px; padding: 0 10px; border: 1px solid ${t.rule}; border-radius: 4px; font-size: 12.5px; color: ${t.ink2}">${k ? ic(I[k], t.ink3, 13) : ''}${l}</div>`).join('')}
      <div style="margin-left: auto; display: flex; gap: 8px">
        <div style="display: flex; align-items: center; gap: 6px; height: 30px; padding: 0 12px; border: 1px solid ${t.rule}; border-radius: 4px; font-size: 13px; color: ${t.ink}">${ic(I.lock, t.ink2, 14)}Reconcile</div>
        <div style="display: flex; align-items: center; gap: 6px; height: 30px; padding: 0 12px; border: 1px solid ${t.rule}; border-radius: 4px; font-size: 13px; color: ${t.ink}">${ic(I.import, t.ink2, 14)}Import</div>
        <div style="display: flex; align-items: center; gap: 6px; height: 30px; padding: 0 12px; background: ${t.blue}; border-radius: 4px; font-size: 13px; font-weight: 500; color: #FFFFFF">${ic(I.plus, '#FFFFFF', 14)}Transaction</div>
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 12px; height: 36px; padding: 0 24px; background: ${t.navy}; font-size: 12.5px; color: #DCE3F0">
      <span style="font-weight: 600; color: #FFFFFF">1 selected</span>
      ${['Categorize', 'Mark cleared', 'Add tag', 'Delete'].map(a => `<span style="padding: 0 8px; color: ${a === 'Delete' ? '#F4A3A3' : '#DCE3F0'}">${a}</span>`).join('')}
      <span style="margin-left: auto; color: #8E9AB3">Tab to move · Enter to commit · Esc to cancel</span>
    </div>
    <div style="flex-grow: 1; display: flex; flex-direction: column; background: ${t.paper}; overflow: hidden">
      <div style="display: grid; ${cols}; height: 32px; border-bottom: 1px solid ${t.rule}; background: ${t.ground}; font-size: 11.5px; font-weight: 600; color: ${t.ink2}">
        <div></div><div></div>
        <div style="display: flex; align-items: center; gap: 4px; padding-left: 8px; color: ${t.blue}">Date${ic(I.chevDown, t.blue, 11)}</div>
        <div style="display: flex; align-items: center; padding: 0 10px">Payee</div>
        <div style="display: flex; align-items: center; padding: 0 10px">Memo</div>
        <div style="display: flex; align-items: center; padding: 0 10px">Category</div>
        <div style="display: flex; align-items: center; justify-content: flex-end; padding: 0 12px">Outflow</div>
        <div style="display: flex; align-items: center; justify-content: flex-end; padding: 0 12px">Inflow</div>
        <div style="display: flex; align-items: center; justify-content: flex-end; padding: 0 16px 0 12px">Balance</div>
      </div>
      <div style="display: grid; ${cols}; height: 36px; border-bottom: 1px solid ${t.rule2}; background: #FFFBF3; font-size: 13px">
        <div></div>
        <div style="display: flex; align-items: center; justify-content: center">${ic(I.repeat, t.gold, 12)}</div>
        <div style="display: flex; align-items: center; padding-left: 8px; font-family: ${mono}; font-size: 12.5px; color: ${t.gold}">2026.${scheduled.d}</div>
        <div style="display: flex; align-items: center; padding: 0 10px; color: ${t.ink2}">${scheduled.payee}</div>
        <div style="display: flex; align-items: center; padding: 0 10px; color: ${t.ink3}">${scheduled.memo}</div>
        <div style="display: flex; align-items: center; padding: 0 10px; color: ${t.ink3}">${scheduled.cat}</div>
        <div style="display: flex; align-items: center; justify-content: flex-end; padding: 0 12px; font-family: ${mono}; color: ${t.ink2}; border-left: 1px solid ${t.rule2}">${money(scheduled.amt, centMuted)}</div>
        <div style="border-left: 1px solid ${t.rule2}"></div>
        <div style="display: flex; align-items: center; justify-content: flex-end; padding: 0 16px 0 12px; font-family: ${mono}; color: ${t.ink3}; border-left: 1px solid ${t.rule}">${money(scheduled.bal, '')}</div>
      </div>
      <div style="display: flex; align-items: center; gap: 10px; height: 32px; padding: 0 16px; border-bottom: 1px solid ${t.rule}; background: ${t.ground}; font-size: 12px">
        ${ic(I.chevDown, t.ink2, 12)}<span style="font-weight: 600; color: ${t.ink}">September 2026</span><span style="color: ${t.ink3}">${rows.length} transactions</span>
        <span style="margin-left: auto; font-family: ${mono}; color: ${t.green}">+${whole(IN)}${cents(IN)}</span>
        <span style="font-family: ${mono}; color: ${t.ink2}; padding-right: 8px">−${whole(OUT_)}${cents(OUT_)}</span>
      </div>
      ${register.map(row).join('')}
      <div style="display: flex; align-items: center; gap: 10px; height: 32px; padding: 0 16px; border-bottom: 1px solid ${t.rule}; background: ${t.ground}; font-size: 12px">
        ${ic(I.chev, t.ink2, 12)}<span style="font-weight: 600; color: ${t.ink}">August 2026</span><span style="color: ${t.ink3}">42 transactions</span>
      </div>
    </div>
  </div>`;

  return artboard({
    title: 'Precision',
    fonts: 'family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600',
    bg: t.ground, font: sans, color: t.ink, link: t.blue,
    html: `<div style="display: flex; flex-direction: column; width: 1440px; height: 900px; overflow: hidden; background: ${t.ground}">${topbar}<div style="flex-grow: 1; display: flex; min-height: 0">${sidebar}${body}</div></div>`,
  });
}

// ---------- Midnight, round 2 ----------
// One signed amount column. The header's chart is a forecast, not a history:
// balance from today through scheduled items to the next income, so it can warn.
const TODAY = 16; // 2026.09.16, as a day index where Oct 1 = 31
const dayIdx = d => { const [m, dd] = d.split('.').map(Number); return m === 9 ? dd : 30 + dd; };
const SCENARIOS = {
  comfortable: [
    { d: '09.20', payee: 'Zaisan Residence', cat: 'Housing', amt: -180000000 },
    { d: '09.25', payee: 'Golomt Visa', cat: 'Card payment', amt: -64020000 },
    { d: '10.01', payee: 'Нарлаг цэцэрлэг', cat: 'Childcare', amt: -35000000 },
    { d: '10.10', payee: 'Altan Gadas LLC', cat: 'Salary', amt: 250000000, income: true },
  ],
  short: [
    { d: '09.20', payee: 'Zaisan Residence', cat: 'Housing', amt: -180000000 },
    { d: '09.25', payee: 'Golomt Visa', cat: 'Card payment', amt: -64020000 },
    { d: '09.30', payee: 'МУИС', cat: 'Tuition', amt: -210000000 },
    { d: '10.01', payee: 'Нарлаг цэцэрлэг', cat: 'Childcare', amt: -35000000 },
    { d: '10.10', payee: 'Altan Gadas LLC', cat: 'Salary', amt: 250000000, income: true },
  ],
};

function forecast(events) {
  let b = WORKING;
  const bills = events.filter(e => !e.income);
  const steps = [{ day: TODAY, bal: b }];
  let low = { bal: b, d: '09.16' }, firstShort = null;
  for (const e of bills) {
    b += e.amt; steps.push({ day: dayIdx(e.d), bal: b, e });
    if (b < low.bal) low = { bal: b, d: e.d };
    if (b < 0 && !firstShort) firstShort = e.d;
  }
  const payday = events.find(e => e.income);
  return { steps, low, firstShort, payday, billTotal: -bills.reduce((s, e) => s + e.amt, 0), bills };
}

function midnightTheme() {
  return {
    ground: '#060D1E', panel: '#0B1630', raised: '#10204A', rule: 'rgba(214, 224, 255, 0.07)',
    ink: '#EEF1F8', ink2: '#A3AEC6', ink3: '#66728E', blue: '#4F7BFF', gold: '#D9B878', green: '#5CCB9A', coral: '#F08A8A',
    unc: '#66728E', clr: '#A3AEC6', rec: '#D9B878',
  };
}

function forecastCard(t, scenario) {
  const f = forecast(SCENARIOS[scenario]);
  const short = f.low.bal < 0;
  const W = 440, H = 92, x0 = TODAY, x1 = dayIdx(f.payday.d);
  const hi = Math.max(...f.steps.map(s => s.bal)), lo = Math.min(0, f.low.bal);
  const X = day => ((day - x0) / (x1 - x0)) * W;
  const Y = v => 8 + (1 - (v - lo) / (hi - lo)) * (H - 16);
  // step path: balance only changes on the day a bill lands
  let p = `M0 ${Y(f.steps[0].bal).toFixed(1)}`;
  for (const s of f.steps.slice(1)) p += ` H${X(s.day).toFixed(1)} V${Y(s.bal).toFixed(1)}`;
  p += ` H${W}`;
  const zero = Y(0);
  const lineColor = short ? t.coral : t.blue;
  const svg = `<svg width="${W}" height="${H + 22}" viewBox="0 0 ${W} ${H + 22}" style="display: block; overflow: visible">
    <defs>
      <clipPath id="above"><rect x="-4" y="-4" width="${W + 8}" height="${zero + 4}"></rect></clipPath>
      <clipPath id="below"><rect x="-4" y="${zero}" width="${W + 8}" height="${H}"></rect></clipPath>
    </defs>
    <line x1="0" y1="${zero}" x2="${W}" y2="${zero}" stroke="${short ? 'rgba(240, 138, 138, 0.45)' : t.rule}" stroke-width="1" stroke-dasharray="3 4"></line>
    <text x="${W + 8}" y="${zero + 4}" font-size="11" fill="${t.ink3}">₮0</text>
    ${short ? `<path d="${p} V${zero} H0 Z" fill="${t.coral}" fill-opacity="0.16" clip-path="url(#below)"></path>` : ''}
    <path d="${p}" fill="none" stroke="${t.blue}" stroke-width="1.75" stroke-linejoin="round" clip-path="url(#above)"></path>
    <path d="${p}" fill="none" stroke="${t.coral}" stroke-width="1.75" stroke-linejoin="round" clip-path="url(#below)"></path>
    ${f.steps.slice(1).map(s => `<circle cx="${X(s.day)}" cy="${Y(s.bal)}" r="2.5" fill="${s.bal < 0 ? t.coral : t.ink2}"></circle>`).join('')}
    <circle cx="0" cy="${Y(f.steps[0].bal)}" r="3.5" fill="${t.ground}" stroke="${t.ink}" stroke-width="1.5"></circle>
    <line x1="${W}" y1="4" x2="${W}" y2="${H}" stroke="${t.green}" stroke-width="1" stroke-opacity="0.5"></line>
    <text x="0" y="${H + 18}" font-size="11" fill="${t.ink3}">Today</text>
    <text x="${W}" y="${H + 18}" font-size="11" fill="${t.green}" text-anchor="end">10.10 Salary</text>
  </svg>`;
  const headline = short
    ? `<div style="font-size: 18px; font-weight: 500; color: ${t.coral}; font-variant-numeric: tabular-nums">Runs out on ${f.firstShort} · up to ₮${whole(f.low.bal)} short</div>
       <div style="font-size: 13px; color: ${t.ink2}">${f.bills.filter(b => dayIdx(b.d) >= dayIdx(f.firstShort)).map(b => b.cat).join(' and ')} land before salary. Khan Savings could cover it.</div>`
    : `<div style="font-size: 18px; font-weight: 500; color: ${t.ink}; font-variant-numeric: tabular-nums">Lowest ₮${whole(f.low.bal)} on ${f.low.d}</div>
       <div style="font-size: 13px; color: ${t.ink3}">${f.bills.length} scheduled bills · ₮${whole(f.billTotal)} before salary</div>`;
  return `<div style="display: flex; flex-direction: column; gap: 14px; width: ${W + 24}px">
    <div style="display: flex; flex-direction: column; gap: 4px">
      <div style="font-size: 12px; color: ${t.ink3}">Until next income</div>
      ${headline}
    </div>
    ${svg}
  </div>`;
}

function balanceHeader(t, scenario) {
  const centMuted = `color: ${t.ink3}; font-size: 0.5em; letter-spacing: 0`;
  return `<div style="display: flex; align-items: stretch; gap: 40px; padding: 28px 32px 22px; border-radius: 16px; background: ${t.panel}; border: 1px solid ${t.rule}">
    <div style="flex-grow: 1; display: flex; flex-direction: column; justify-content: space-between; gap: 20px">
      <div style="display: flex; flex-direction: column; gap: 10px">
        <div style="font-size: 12px; color: ${t.ink3}">Working balance</div>
        <div style="font-size: 52px; font-weight: 500; letter-spacing: -0.03em; color: ${t.ink}; font-variant-numeric: tabular-nums; line-height: 1">${money(WORKING, centMuted)}</div>
      </div>
      <div style="display: flex; flex-direction: column; gap: 8px; font-size: 13px; font-variant-numeric: tabular-nums">
        <div style="display: flex; align-items: center; gap: 10px">
          <div style="width: 7px; height: 7px; border-radius: 50%; background: ${t.clr}"></div>
          <div style="width: 84px; color: ${t.ink3}">Cleared</div>
          <div style="width: 130px; color: ${t.ink}">₮${whole(CLEARED)}${cents(CLEARED)}</div>
          <div style="color: ${t.ink3}">Bank data through 09.15</div>
        </div>
        <div style="display: flex; align-items: center; gap: 10px">
          <div style="width: 7px; height: 7px; background: ${t.rec}; transform: rotate(45deg)"></div>
          <div style="width: 84px; color: ${t.ink3}">Reconciled</div>
          <div style="width: 130px; color: ${t.ink}">₮${whole(RECONCILED)}${cents(RECONCILED)}</div>
          <div style="color: ${t.ink3}">Statement of 09.10</div>
        </div>
      </div>
    </div>
    <div style="width: 1px; background: ${t.rule}"></div>
    ${forecastCard(t, scenario)}
  </div>`;
}

function midnightLedger() {
  const t = midnightTheme();
  const sans = "'Onest', 'Segoe UI', system-ui, sans-serif";
  const centMuted = `color: ${t.ink3}`;
  const cols = 'grid-template-columns: 24px 64px minmax(0, 1fr) 220px 170px 170px';
  const upcoming = SCENARIOS.comfortable.filter(e => !e.income);

  const amount = (m, color) => m > 0
    ? `<span style="color: ${t.green}">+₮${whole(m)}<span style="opacity: 0.6">${cents(m)}</span></span>`
    : `<span style="color: ${color || t.ink}">₮${whole(m)}<span style="${centMuted}">${cents(m)}</span></span>`;

  const row = r => {
    const sel = r.selected;
    return `<div style="display: grid; ${cols}; align-items: center; column-gap: 16px; padding: 0 20px; margin: 0 12px; height: 52px; border-radius: 10px; background: ${sel ? 'rgba(79, 123, 255, 0.12)' : 'transparent'}; box-shadow: ${sel ? 'inset 0 0 0 1px rgba(79, 123, 255, 0.35)' : 'none'}">
      <div style="display: flex; justify-content: center">${statusGlyph(r.st, t)}</div>
      <div style="font-size: 13px; color: ${t.ink3}; font-variant-numeric: tabular-nums">${r.d}</div>
      <div style="display: flex; flex-direction: column; gap: 2px; min-width: 0">
        <div style="display: flex; align-items: center; gap: 8px; font-size: 14.5px; font-weight: 500; color: ${t.ink}">${r.kind === 'transfer' ? `<span style="color: ${t.ink3}; font-weight: 400">To</span>` : ''}${r.payee}${r.kind ? ic(I[r.kind], t.ink3, 13) : ''}</div>
        <div style="font-size: 12.5px; color: ${t.ink3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${r.memo}</div>
      </div>
      <div style="display: flex">${sel
        ? `<div style="display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px 0 12px; border-radius: 8px; background: ${t.ground}; box-shadow: 0 0 0 1.5px ${t.blue}, 0 0 0 5px rgba(79, 123, 255, 0.18); font-size: 13px; color: ${t.ink}">${r.cat}${ic(I.chevDown, t.ink2, 12)}</div>`
        : r.kind
          ? `<div style="font-size: 12.5px; color: ${t.ink3}; padding: 0 10px">${r.cat}</div>`
          : `<div style="height: 26px; display: flex; align-items: center; padding: 0 10px; border-radius: 13px; background: rgba(214, 224, 255, 0.06); font-size: 12.5px; color: ${t.ink2}">${r.cat}</div>`}</div>
      <div style="text-align: right; font-size: 14.5px; font-variant-numeric: tabular-nums">${amount(r.amt)}</div>
      <div style="text-align: right; font-size: 14.5px; color: ${r.st === 'unc' ? t.ink2 : t.ink}; font-variant-numeric: tabular-nums">${money(r.bal, centMuted, { sign: true })}</div>
    </div>`;
  };

  const sidebar = `<div style="width: 240px; flex-shrink: 0; display: flex; flex-direction: column; padding: 24px 12px; border-right: 1px solid ${t.rule}">
    <div style="display: flex; align-items: center; gap: 12px; padding: 4px 12px 32px">
      <div style="width: 10px; height: 10px; background: ${t.gold}; transform: rotate(45deg)"></div>
      <div style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em; color: ${t.ink}">BetterBudget</div>
    </div>
    ${[['ledger', 'Ledger', true], ['budget', 'Budget'], ['reports', 'Reports']].map(([k, l, a]) => `<div style="display: flex; align-items: center; gap: 12px; padding: 9px 12px; border-radius: 8px; background: ${a ? t.panel : 'transparent'}; font-size: 14px; color: ${a ? t.ink : t.ink3}">${ic(I[k], a ? t.blue : t.ink3)}${l}</div>`).join('')}
    <div style="height: 28px"></div>
    ${accounts.map(g => `<div style="display: flex; flex-direction: column; gap: 2px; padding-bottom: 20px">
      <div style="font-size: 12px; color: ${t.ink3}; padding: 0 12px 8px">${g.group}</div>
      ${g.items.map(a => `<div style="display: flex; flex-direction: column; gap: 2px; padding: 9px 12px; border-radius: 8px; background: ${a.active ? t.panel : 'transparent'}; box-shadow: ${a.active ? `inset 2px 0 0 ${t.blue}` : 'none'}">
        <div style="font-size: 13.5px; color: ${a.active ? t.ink : t.ink2}">${a.name}</div>
        <div style="font-size: 12.5px; color: ${a.bal < 0 ? t.coral : t.ink3}; font-variant-numeric: tabular-nums">${a.bal < 0 ? '−' : ''}₮${whole(a.bal)}</div>
      </div>`).join('')}
    </div>`).join('')}
    <div style="margin-top: auto; padding: 16px 12px 0; border-top: 1px solid ${t.rule}; display: flex; flex-direction: column; gap: 4px">
      <div style="font-size: 12px; color: ${t.ink3}">Net worth</div>
      <div style="font-size: 18px; font-weight: 500; color: ${t.ink}; font-variant-numeric: tabular-nums">₮${whole(NET)}</div>
    </div>
  </div>`;

  const next = upcoming[0];
  const body = `<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 20px; min-width: 0; padding: 24px 28px 28px">
    <div style="display: flex; justify-content: space-between; align-items: center">
      <div style="display: flex; align-items: baseline; gap: 12px">
        <div style="font-size: 22px; font-weight: 600; letter-spacing: -0.015em; color: ${t.ink}">TDB Checking</div>
        <div style="font-size: 13px; color: ${t.ink3}">··4410</div>
      </div>
      <div style="display: flex; gap: 10px">
        <div style="display: flex; align-items: center; gap: 10px; width: 280px; height: 36px; padding: 0 12px; border-radius: 9px; background: ${t.panel}; font-size: 13px; color: ${t.ink3}; box-sizing: border-box">${ic(I.search, t.ink3, 14)}Search<span style="margin-left: auto; font-size: 11.5px; padding: 2px 6px; border-radius: 5px; background: ${t.raised}">⌘K</span></div>
        <div style="display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 14px; border-radius: 9px; background: ${t.panel}; font-size: 13px; color: ${t.ink}">${ic(I.import, t.ink2, 14)}Import</div>
        <div style="display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 14px; border-radius: 9px; background: ${t.blue}; font-size: 13px; font-weight: 500; color: #FFFFFF">${ic(I.plus, '#FFFFFF', 14)}Add</div>
      </div>
    </div>
    ${balanceHeader(t, 'comfortable')}
    <div style="flex-grow: 1; display: flex; flex-direction: column; border-radius: 16px; background: ${t.panel}; border: 1px solid ${t.rule}; overflow: hidden">
      <div style="display: flex; align-items: center; gap: 8px; padding: 12px 20px">
        ${[['All'], ['Uncleared', 2], ['Scheduled', upcoming.length]].map(([f, n], i) => `<div style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 12px; border-radius: 8px; font-size: 13px; background: ${i === 0 ? t.raised : 'transparent'}; color: ${i === 0 ? t.ink : t.ink3}">${f}${n ? `<span style="font-size: 11.5px; color: ${t.ink3}">${n}</span>` : ''}</div>`).join('')}
        <div style="margin-left: auto; display: flex; align-items: center; gap: 8px; font-size: 13px; color: ${t.ink3}">${ic(I.cal, t.ink3, 14)}Sep 2026${ic(I.filter, t.ink3, 14)}</div>
      </div>
      <div style="display: grid; ${cols}; column-gap: 16px; padding: 0 20px; margin: 0 12px; height: 28px; align-items: center; font-size: 12px; color: ${t.ink3}">
        <div></div><div>Date</div><div>Payee</div><div>Category</div><div style="text-align: right">Amount</div><div style="text-align: right">Balance</div>
      </div>
      <div style="display: grid; ${cols}; align-items: center; column-gap: 16px; padding: 0 20px; margin: 0 12px 4px; height: 46px; border-radius: 10px; border: 1px dashed rgba(217, 184, 120, 0.35)">
        <div style="display: flex; justify-content: center">${ic(I.repeat, t.gold, 13)}</div>
        <div style="font-size: 13px; color: ${t.gold}; font-variant-numeric: tabular-nums">${next.d}</div>
        <div style="font-size: 14px; color: ${t.ink2}">${next.payee} <span style="color: ${t.ink3}">· next of ${upcoming.length} scheduled</span></div>
        <div style="font-size: 12.5px; color: ${t.ink3}; padding: 0 10px">${next.cat}</div>
        <div style="text-align: right; font-size: 14.5px; color: ${t.ink2}; font-variant-numeric: tabular-nums">₮${whole(next.amt)}<span style="${centMuted}">${cents(next.amt)}</span></div>
        <div style="text-align: right; font-size: 13px; color: ${t.gold}">Confirm</div>
      </div>
      <div style="display: flex; align-items: center; gap: 12px; margin: 6px 32px 2px; height: 30px; font-size: 12.5px; font-variant-numeric: tabular-nums">
        <span style="color: ${t.ink2}; font-weight: 500">September</span>
        <span style="color: ${t.ink3}">${rows.length} transactions</span>
        <span style="margin-left: auto; color: ${t.green}">+₮${whole(IN)}</span>
        <span style="color: ${t.ink3}">₮${whole(OUT_)} out</span>
      </div>
      ${register.slice(0, 8).map(row).join('')}
    </div>
  </div>`;

  return artboard({
    title: 'Midnight ledger',
    fonts: 'family=Onest:wght@400;500;600',
    bg: t.ground, font: sans, color: t.ink, link: t.blue,
    html: `<div style="display: flex; width: 1440px; height: 900px; overflow: hidden; background: ${t.ground}">${sidebar}${body}</div>`,
  });
}

// Just the balance header, in the state the forecast exists to catch.
function midnightShortHeader() {
  const t = midnightTheme();
  return artboard({
    title: 'Midnight short',
    fonts: 'family=Onest:wght@400;500;600',
    bg: t.ground, font: "'Onest', 'Segoe UI', system-ui, sans-serif", color: t.ink, link: t.blue,
    html: `<div style="width: 1144px; padding: 28px; background: ${t.ground}">${balanceHeader(t, 'short')}</div>`,
  });
}

function artboard({ fonts, bg, font, color, link, html }) {
  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?${fonts.replaceAll("&", "&amp;")}&amp;display=swap">
  <style>
    body { margin: 0; background: ${bg}; font-family: ${font}; color: ${color}; -webkit-font-smoothing: antialiased; }
    a { color: ${link}; } a:hover { color: ${color}; }
  </style>
</helmet>
${html}
</x-dc>
</body>
</html>
`;
}

writeFileSync(join(OUT, 'Main.dc.html'), midnightLedger());
writeFileSync(join(OUT, 'ShortBeforePayday.dc.html'), midnightShortHeader());
writeFileSync(join(OUT, 'PrivateBanking.dc.html'), privateBanking());
writeFileSync(join(OUT, 'Midnight.dc.html'), midnight());
writeFileSync(join(OUT, 'Precision.dc.html'), precision());
console.log({ WORKING, CLEARED, RECONCILED, IN, OUT: OUT_, NET, projected: scheduled.bal });
