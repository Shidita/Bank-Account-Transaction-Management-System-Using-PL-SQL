(() => {
"use strict";
const $ = (s, r = document) => r.querySelector(s);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const inr = new Intl.NumberFormat("en-IN", {style:"currency", currency:"INR", minimumFractionDigits:2});
const money = v => v == null ? "—" : inr.format(v);
const MON = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const when = s => { if(!s) return "—"; const m = /^(\d{4})-(\d\d)-(\d\d)[ T](\d\d):(\d\d)/.exec(s); return m ? `${+m[3]} ${MON[+m[2]-1]} ${m[1]}, ${m[4]}:${m[5]}` : s; };
const pill = v => `<span class="pill ${esc(v)}">${esc(String(v).replace("_"," ").toLowerCase())}</span>`;

const state = { accounts: [], mode: null, log: [] };

/* ---------- API ---------- */
async function api(path, method = "GET", payload) {
  const res = await fetch("/api" + path, {
    method, headers: payload ? {"Content-Type":"application/json"} : undefined,
    body: payload ? JSON.stringify(payload) : undefined
  });
  let data; try { data = await res.json(); } catch { data = {ok:false, error:"Server did not answer. Is app.py still running?"}; }
  return {ok: res.ok, data};
}

/* ---------- console + toast ---------- */
function logEntry(call, ok, lines) {
  const t = new Date().toLocaleTimeString("en-GB");
  state.log.unshift({t, call, ok, lines});
  const el = $("#console-log");
  el.innerHTML = state.log.map(e => `<div class="entry"><div class="t">${e.t}</div>
    <div class="call">${esc(e.call)}</div>
    ${e.lines.map(l => `<div class="${e.ok ? "ok" : "er"}">${e.ok ? "✔ " : "✖ "}${esc(l)}</div>`).join("")}</div>`).join("");
  $("#console-count").textContent = state.log.length + (state.log.length === 1 ? " call" : " calls");
}
let toastTimer;
function toast(msg, err) {
  const t = $("#toast"); t.textContent = msg; t.className = "show" + (err ? " err" : "");
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = "", 3200);
}
$("#console-toggle").onclick = () => { const c = $("#console"); const o = c.classList.toggle("open"); $("#console-toggle").setAttribute("aria-expanded", o); };
$("#console-clear").onclick = () => { state.log = []; $("#console-log").innerHTML = ""; $("#console-count").textContent = "0 calls"; };

/* run an operation: POST, log in console, toast. returns {ok,data} */
async function act(path, payload, okMsg) {
  const r = await api(path, "POST", payload);
  const d = r.data;
  if (r.ok) { logEntry(d.call, true, d.output?.length ? d.output : ["PL/SQL procedure successfully completed."]); toast(okMsg || (d.output && d.output[0]) || "Done"); }
  else { logEntry(d.call || path, false, [d.ora || d.error]); toast(d.error || "Failed", true); }
  await refreshAccounts();
  return r;
}
async function refreshAccounts() { const r = await api("/accounts"); if (r.ok) state.accounts = r.data; }

/* ---------- views ---------- */
const view = $("#view");
const heading = (title, sub, actions = "") => `<div class="page-head"><div><h1>${title}</h1>${sub ? `<p>${sub}</p>` : ""}</div><div class="row">${actions}</div></div>`;
const table = (cols, rows, empty) => rows.length
  ? `<div class="tbl-wrap"><table><thead><tr>${cols.map(c => `<th class="${c.r ? "r" : ""}">${c.h}</th>`).join("")}</tr></thead><tbody>${rows.join("")}</tbody></table></div>`
  : `<div class="empty">${empty}</div>`;

const routes = {
async overview() {
  const r = await api("/summary"); if (!r.ok) return fail(r);
  const s = r.data, max = Math.max(...s.accounts_list.map(a => a.balance), 1);
  const ok = s.mismatches === 0;
  view.innerHTML = heading("Overview", "Live numbers straight from the database.") + `
  <div class="kpis">
    <div class="card kpi hero"><span>Total balance across all accounts</span><b class="num">${money(s.total_balance)}</b></div>
    <div class="card kpi"><span>Customers</span><b class="num">${s.customers}</b></div>
    <div class="card kpi"><span>Accounts (${s.active_accounts} active)</span><b class="num">${s.accounts}</b></div>
    <div class="card kpi"><span>Transactions</span><b class="num">${s.transactions}</b></div>
  </div>
  <div class="status-line ${ok ? "ok" : "bad"}"><i class="dot"></i>${ok ? "Every balance equals the sum of its transactions." : `${s.mismatches} account(s) do not match their transactions — see Reports.`}</div>
  <div class="grid2">
    <section class="card pad"><h2>Balance by account</h2>
      <div class="bars">${s.accounts_list.length ? s.accounts_list.map(a => `
        <div><div class="bar-top"><span>${esc(a.full_name)} <small>#${a.account_id} · ${a.account_type.toLowerCase()}</small></span><b class="num">${money(a.balance)}</b></div>
        <div class="track"><div class="fill ${a.account_type}" style="width:${Math.max(a.balance / max * 100, 1)}%"></div></div></div>`).join("") : `<p class="muted">No accounts yet.</p>`}</div>
    </section>
    <section class="card"><div class="pad" style="padding-bottom:6px"><h2>Latest transactions</h2></div>
      ${table([{h:"Account"},{h:"Type"},{h:"Amount",r:1}], s.recent.map(t => `<tr><td>#${t.account_id} <span class="muted">${esc(t.full_name)}</span></td><td>${pill(t.transaction_type)}</td><td class="r num ${isCredit(t) ? "cr" : "dr"}">${isCredit(t) ? "+" : "−"}${money(t.amount)}</td></tr>`), "No transactions yet.")}
    </section>
  </div>`;
},

async customers() {
  const r = await api("/customers"); if (!r.ok) return fail(r);
  view.innerHTML = heading("Customers", "People who hold accounts with the bank.", `<button class="btn primary" data-do="new-customer">New customer</button>`) +
  `<div class="card">${table([{h:"ID"},{h:"Name"},{h:"E-mail"},{h:"Phone"},{h:"City"},{h:"Accounts",r:1},{h:"Total balance",r:1},{h:""}],
    r.data.map(c => `<tr><td class="num">${c.customer_id}</td><td><b>${esc(c.full_name)}</b></td><td>${esc(c.email)}</td><td>${esc(c.phone || "—")}</td><td>${esc(c.city || "—")}</td>
      <td class="r num">${c.accounts}</td><td class="r num">${money(c.total_balance)}</td>
      <td class="act"><button class="btn sm" data-do="new-account" data-id="${c.customer_id}" data-name="${esc(c.full_name)}">Open account</button></td></tr>`),
    "No customers yet. Add the first one.")}</div>`;
},

async accounts() {
  await refreshAccounts();
  view.innerHTML = heading("Accounts", "Deposit, withdraw, transfer, or change an account's status.", `<button class="btn primary" data-do="new-account">Open account</button>`) +
  `<div class="card">${table([{h:"Account"},{h:"Holder"},{h:"Type"},{h:"Balance",r:1},{h:"Status"},{h:""}],
    state.accounts.map(a => `<tr><td class="num"><b>#${a.account_id}</b></td><td>${esc(a.full_name)}<div class="muted" style="font-size:.82rem">${esc(a.email)}</div></td>
      <td>${pill(a.account_type)}</td><td class="r num"><b>${money(a.balance)}</b></td><td>${pill(a.status)}</td>
      <td class="act"><div class="acts">
        <a class="btn sm" href="#/move?op=deposit&acc=${a.account_id}">Deposit</a>
        <a class="btn sm" href="#/move?op=withdraw&acc=${a.account_id}">Withdraw</a>
        <a class="btn sm" href="#/move?op=transfer&acc=${a.account_id}">Transfer</a>
        <a class="btn sm" href="#/transactions?acc=${a.account_id}">Statement</a>
        ${a.status === "ACTIVE" ? `<button class="btn sm" data-do="status" data-id="${a.account_id}" data-s="BLOCKED">Block</button>` : ""}
        ${a.status !== "ACTIVE" ? `<button class="btn sm" data-do="status" data-id="${a.account_id}" data-s="ACTIVE">Activate</button>` : ""}
        ${a.status !== "CLOSED" ? `<button class="btn sm danger" data-do="status" data-id="${a.account_id}" data-s="CLOSED">Close</button>` : ""}
      </div></td></tr>`), "No accounts yet. Open one for an existing customer.")}</div>`;
},

async move(q) {
  await refreshAccounts();
  const op = ["deposit","withdraw","transfer"].includes(q.get("op")) ? q.get("op") : "deposit";
  const acc = q.get("acc") || "";
  const list = `<datalist id="acc-list">${state.accounts.map(a => `<option value="${a.account_id}">${esc(a.full_name)} · ${a.account_type.toLowerCase()} · ${money(a.balance)} · ${a.status.toLowerCase()}</option>`).join("")}</datalist>`;
  const accField = (id, label, val) => `<div class="field"><label for="${id}">${label}</label><input id="${id}" name="${id}" list="acc-list" inputmode="numeric" autocomplete="off" value="${esc(val)}" placeholder="e.g. 2001"><div class="hint" data-hint="${id}"></div></div>`;
  const amount = `<div class="field"><label for="amount">Amount (₹)</label><input id="amount" name="amount" inputmode="decimal" autocomplete="off" placeholder="e.g. 2500.50"></div>`;
  const desc = `<div class="field"><label for="description">Note</label><input id="description" name="description" placeholder="${op === "withdraw" ? "Cash withdrawal" : "Cash deposit"}"></div>`;
  view.innerHTML = heading("Move money", "Each action runs the matching <code>bank_pkg</code> procedure inside a transaction.") + list + `
  <div class="move-grid">
    <section class="card pad">
      <div class="tabs" role="tablist">${["deposit","withdraw","transfer"].map(o => `<button role="tab" aria-selected="${o === op}" data-tab="${o}">${o[0].toUpperCase() + o.slice(1)}</button>`).join("")}</div>
      <form class="f" id="move-form" data-op="${op}" novalidate>
        ${op === "transfer" ? accField("from_account", "From account", acc) + accField("to_account", "To account", "") : accField("account_id", "Account", acc)}
        ${amount}${op === "transfer" ? "" : desc}
        <div class="form-err" id="f-err"></div><div class="form-ok" id="f-ok"></div>
        <div><button class="btn primary" type="submit">${op === "deposit" ? "Deposit" : op === "withdraw" ? "Withdraw" : "Transfer"}</button></div>
      </form>
    </section>
    <section class="card pad"><h2>Try the error cases</h2>
      <p class="muted" style="margin-top:4px">One click runs a call the package should reject. Watch the console for the ORA-200xx code.</p>
      <div class="viva">${VIVA.map((v, i) => `<button data-viva="${i}"><span>${v.label}</span><small>${v.code}</small></button>`).join("")}</div>
    </section>
  </div>`;
  const hint = id => {
    const el = $("#" + id), h = $(`[data-hint="${id}"]`); if (!el || !h) return;
    const a = state.accounts.find(x => String(x.account_id) === el.value.trim());
    h.textContent = !el.value.trim() ? "" : a ? `${a.full_name} · ${money(a.balance)} · ${a.status.toLowerCase()}` : "No account with this number.";
  };
  ["account_id","from_account","to_account"].forEach(id => { const el = $("#" + id); if (el) { el.addEventListener("input", () => hint(id)); hint(id); } });
},

async transactions(q) {
  await refreshAccounts();
  const acc = q.get("acc") || "";
  const r = await api("/transactions" + (acc ? "?account_id=" + encodeURIComponent(acc) : "")); if (!r.ok) return fail(r);
  view.innerHTML = heading("Transactions", acc ? `Statement for account #${esc(acc)}.` : "Every transaction, newest first.",
    `<div class="field" style="min-width:230px"><select id="tx-filter" aria-label="Filter by account"><option value="">All accounts</option>${state.accounts.map(a => `<option value="${a.account_id}" ${String(a.account_id) === acc ? "selected" : ""}>#${a.account_id} · ${esc(a.full_name)}</option>`).join("")}</select></div>`) +
  `<div class="card">${table([{h:"ID"},{h:"When"},{h:"Account"},{h:"Type"},{h:"Details"},{h:"Amount",r:1}],
    r.data.map(t => `<tr><td class="num muted">${t.transaction_id}</td><td>${when(t.transaction_date)}</td><td>#${t.account_id} <span class="muted">${esc(t.full_name)}</span></td><td>${pill(t.transaction_type)}</td><td>${esc(t.description || "—")}</td>
      <td class="r num ${isCredit(t) ? "cr" : "dr"}">${isCredit(t) ? "+" : "−"}${money(t.amount)}</td></tr>`), "Nothing here yet.")}</div>`;
  $("#tx-filter").onchange = e => location.hash = "#/transactions" + (e.target.value ? "?acc=" + e.target.value : "");
},

async reports() {
  await refreshAccounts();
  const r = await api("/reconciliation"); if (!r.ok) return fail(r);
  const bad = r.data.filter(x => x.difference !== 0).length;
  view.innerHTML = heading("Reports", "Checks that the numbers add up.") + `
  <div class="grid2" style="align-items:start">
    <section class="card"><div class="pad" style="padding-bottom:6px"><h2>Balance vs transactions</h2><p class="muted">From <code>balance_reconciliation</code>. The difference column must be zero.</p></div>
      <div class="status-line ${bad ? "bad" : "ok"}" style="margin:8px 18px 12px"><i class="dot"></i>${bad ? bad + " account(s) differ" : "All accounts reconcile"}</div>
      ${table([{h:"Account"},{h:"Balance",r:1},{h:"Transactions total",r:1},{h:"Difference",r:1}], r.data.map(x => `<tr><td class="num">#${x.account_id}</td><td class="r num">${money(x.balance)}</td><td class="r num">${money(x.ledger_total)}</td><td class="r num ${x.difference ? "dr" : "cr"}">${money(x.difference)}</td></tr>`), "No accounts.")}
    </section>
    <section class="card pad"><h2>Interest calculator</h2><p class="muted" style="margin:4px 0 14px">Simple interest for one year, via <code>bank_pkg.calculate_interest</code>.</p>
      <form class="f" id="int-form" novalidate>
        <div class="field"><label for="i-acc">Account</label><input id="i-acc" list="acc-list2" inputmode="numeric" placeholder="e.g. 2001"><datalist id="acc-list2">${state.accounts.map(a => `<option value="${a.account_id}">${esc(a.full_name)}</option>`).join("")}</datalist></div>
        <div class="field"><label for="i-rate">Yearly rate (%)</label><input id="i-rate" inputmode="decimal" value="5"></div>
        <div class="form-err" id="f-err"></div><div class="form-ok" id="f-ok"></div>
        <div><button class="btn primary" type="submit">Calculate</button></div>
      </form></section>
  </div>`;
},

async audit() {
  const r = await api("/audit"); if (!r.ok) return fail(r);
  view.innerHTML = heading("Audit log", "Written automatically by the <code>trg_account_audit</code> trigger whenever an account opens or its balance changes.") +
  `<div class="card">${table([{h:"ID"},{h:"When"},{h:"Account"},{h:"Action"},{h:"Old",r:1},{h:"New",r:1},{h:"Details"}],
    r.data.map(a => `<tr><td class="num muted">${a.audit_id}</td><td>${when(a.action_time)}</td><td class="num">#${a.account_id}</td><td>${pill(a.action_type)}</td><td class="r num">${money(a.old_balance)}</td><td class="r num">${money(a.new_balance)}</td><td>${esc(a.details || "")}</td></tr>`), "No audit entries yet.")}</div>`;
}
};
const isCredit = t => t.transaction_type === "DEPOSIT" || t.transaction_type === "TRANSFER_IN";
function fail(r) { view.innerHTML = heading("Something went wrong") + `<div class="card pad"><p>${esc(r.data?.error || "Could not load data.")}</p></div>`; }

/* ---------- viva / error scenarios (they hit the real package) ---------- */
const VIVA = [
  {label:"Withdraw more than the balance", code:"-20010", path:"/withdraw", body:{account_id:2003, amount:"999999", description:"Too much"}},
  {label:"Deposit with an empty amount", code:"-20005", path:"/deposit", body:{account_id:2001, amount:""}},
  {label:"Deposit a negative amount", code:"-20005", path:"/deposit", body:{account_id:2001, amount:"-50"}},
  {label:"Deposit 10.005 (3 decimals)", code:"-20017", path:"/deposit", body:{account_id:2001, amount:"10.005"}},
  {label:"Transfer to an unknown account", code:"-20016", path:"/transfer", body:{from_account:2001, to_account:9999, amount:"100"}},
  {label:"Transfer from an unknown account", code:"-20018", path:"/transfer", body:{from_account:9999, to_account:2001, amount:"100"}},
  {label:"Transfer to the same account", code:"-20012", path:"/transfer", body:{from_account:2001, to_account:2001, amount:"100"}},
  {label:"Duplicate e-mail (other case)", code:"-20001", path:"/customers", body:{name:"Duplicate", email:"AARAV@example.com", phone:"1", city:"X"}},
  {label:"Deposit into a blocked account", code:"-20006", steps:[
    {path:"/accounts/2003/status", body:{status:"BLOCKED"}}, {path:"/deposit", body:{account_id:2003, amount:"100"}}, {path:"/accounts/2003/status", body:{status:"ACTIVE"}}]},
  {label:"Close an account that still has money", code:"-20023", path:"/accounts/2001/status", body:{status:"CLOSED"}}
];

/* ---------- dialogs ---------- */
const dlg = $("#dlg"), dform = $("#dlg-form");
function openDialog(html, onSubmit) {
  dform.innerHTML = html + `<div class="form-err" id="d-err"></div>`;
  dform.onsubmit = async e => {
    e.preventDefault();
    const btn = dform.querySelector("[data-submit]"); btn.disabled = true;
    const ok = await onSubmit(Object.fromEntries(new FormData(dform)), msg => { const x = $("#d-err"); x.textContent = msg; x.classList.add("show"); });
    btn.disabled = false; if (ok) dlg.close();
  };
  dform.querySelector("[data-cancel]").onclick = () => dlg.close();
  dlg.showModal();
}
const actions = `<div class="dlg-actions"><button type="button" class="btn" data-cancel>Cancel</button><button class="btn primary" data-submit>Save</button></div>`;

function newCustomer() {
  openDialog(`<h2>New customer</h2><div class="f">
    <div class="field"><label for="n">Full name</label><input id="n" name="name" required autocomplete="off"></div>
    <div class="field"><label for="e">E-mail</label><input id="e" name="email" type="email" required autocomplete="off"></div>
    <div class="cols"><div class="field"><label for="p">Phone</label><input id="p" name="phone" inputmode="tel"></div>
    <div class="field"><label for="c">City</label><input id="c" name="city"></div></div>${actions}</div>`,
  async (v, err) => {
    const r = await act("/customers", v, "Customer created");
    if (!r.ok) { err(r.data.error); return false; }
    await render();
    setTimeout(() => { if (confirm("Customer created. Open an account for them now?")) newAccount(r.data.customer_id, v.name); }, 60);
    return true;
  });
}
async function newAccount(cid, name) {
  const cr = await api("/customers"); const custs = cr.ok ? cr.data : [];
  openDialog(`<h2>Open account${name ? " for " + esc(name) : ""}</h2><div class="f">
    <div class="field"><label for="cid">Customer</label><select id="cid" name="customer_id">${custs.map(c => `<option value="${c.customer_id}" ${String(c.customer_id) === String(cid) ? "selected" : ""}>#${c.customer_id} · ${esc(c.full_name)}</option>`).join("")}</select></div>
    <div class="cols"><div class="field"><label for="t">Account type</label><select id="t" name="account_type"><option>SAVINGS</option><option>CURRENT</option></select></div>
    <div class="field"><label for="d">Opening deposit (₹)</label><input id="d" name="initial_deposit" inputmode="decimal" value="0"></div></div>${actions}</div>`,
  async (v, err) => {
    const r = await act("/accounts", v, "Account opened");
    if (!r.ok) { err(r.data.error); return false; }
    await render(); return true;
  });
}

/* ---------- events ---------- */
document.addEventListener("click", async e => {
  const el = e.target.closest("[data-do],[data-tab],[data-viva]"); if (!el) return;
  if (el.dataset.do === "new-customer") return newCustomer();
  if (el.dataset.do === "new-account") return newAccount(el.dataset.id, el.dataset.name);
  if (el.dataset.do === "status") {
    const s = el.dataset.s, id = el.dataset.id;
    if (s === "CLOSED" && !confirm(`Close account #${id}? A closed account cannot be used again until it is activated.`)) return;
    await act(`/accounts/${id}/status`, {status: s}, `Account #${id} is now ${s.toLowerCase()}`); return render();
  }
  if (el.dataset.tab) { const q = new URLSearchParams(location.hash.split("?")[1] || ""); q.set("op", el.dataset.tab); location.hash = "#/move?" + q; return; }
  if (el.dataset.viva !== undefined) {
    const v = VIVA[+el.dataset.viva];
    $("#console").classList.add("open");
    for (const s of (v.steps || [{path:v.path, body:v.body}])) await act(s.path, s.body);
    return;
  }
});

document.addEventListener("submit", async e => {
  const f = e.target;
  if (f.id === "move-form") {
    e.preventDefault();
    const op = f.dataset.op, v = Object.fromEntries(new FormData(f));
    const r = await act("/" + op, v, op === "deposit" ? "Deposit successful" : op === "withdraw" ? "Withdrawal successful" : "Transfer successful");
    const err = $("#f-err"), ok = $("#f-ok");
    err.classList.toggle("show", !r.ok); ok.classList.toggle("show", r.ok);
    if (r.ok) { ok.textContent = r.data.output?.[0] || "Done"; f.querySelector("#amount").value = ""; f.querySelector("#amount").focus();
      f.querySelectorAll("input[list]").forEach(i => i.dispatchEvent(new Event("input"))); }
    else err.textContent = r.data.error + (r.data.code ? `  (${r.data.ora?.startsWith("ORA") ? r.data.ora.split(":")[0] : "ORA" + r.data.code})` : "");
  }
  if (f.id === "int-form") {
    e.preventDefault();
    const q = new URLSearchParams({account_id: $("#i-acc").value, rate: $("#i-rate").value});
    const r = await api("/interest?" + q), err = $("#f-err"), ok = $("#f-ok"), d = r.data;
    logEntry("SELECT " + d.call + " FROM dual;", r.ok, [r.ok ? String(d.interest) : (d.ora || d.error)]);
    err.classList.toggle("show", !r.ok); ok.classList.toggle("show", r.ok);
    if (r.ok) ok.textContent = `Interest for one year on ${money(d.balance)}: ${money(d.interest)}`; else err.textContent = d.error;
  }
});

/* ---------- router ---------- */
async function render() {
  const [path, qs] = (location.hash.slice(2) || "overview").split("?");
  const name = routes[path] ? path : "overview";
  document.querySelectorAll("#nav a").forEach(a => a.classList.toggle("on", a.dataset.r === name));
  try { await routes[name](new URLSearchParams(qs || "")); } catch (err) { view.innerHTML = heading("Something went wrong") + `<div class="card pad">${esc(err.message)}</div>`; }
}
window.addEventListener("hashchange", () => { render(); window.scrollTo(0, 0); });

(async () => {
  const m = await api("/mode"); state.mode = m.data;
  $("#mode-label").textContent = m.data.label || "";
  if (m.data.mode === "demo") {
    $("#side-foot").innerHTML = `Demo data lives in memory.<button class="btn sm" id="reset">Reset demo data</button>`;
    $("#reset").onclick = async () => { if (confirm("Restore the original 3 customers and clear everything you added?")) { const r = await api("/reset", "POST"); logEntry(r.data.call, true, r.data.output); toast("Demo data restored"); render(); } };
  }
  await refreshAccounts(); render();
})();
})();
