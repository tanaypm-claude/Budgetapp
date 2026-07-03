const INR = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", minimumFractionDigits: 2 });
const storeKey = "kosha.web.v1";
const legacyStoreKey = "lakshmi.web.v1";
const tabs = [
  ["dashboard", "Today"],
  ["ledger", "Ledger"],
  ["inbox", "Import Desk"],
  ["categories", "Categories"],
  ["reports", "Patterns"],
  ["rules", "Rule Loom"],
  ["more", "Studio"]
];

function makeSeed() {
  return {
    categories: [
      { id: crypto.randomUUID(), name: "Meals", budget: 22000, color: "#750609", symbol: "Meals" },
      { id: crypto.randomUUID(), name: "Moving Around", budget: 12000, color: "#0e0b09", symbol: "Moving Around" },
      { id: crypto.randomUUID(), name: "Home Base", budget: 60000, color: "#750609", symbol: "Home Base" },
      { id: crypto.randomUUID(), name: "Bills", budget: 8000, color: "#0e0b09", symbol: "Bills" }
    ],
    transactions: [],
    drafts: [],
    rules: [],
    visibleTabs: tabs.map(([id]) => id),
    active: "dashboard"
  };
}

let state = load();

function load() {
  const stored = JSON.parse(localStorage.getItem(storeKey) || localStorage.getItem(legacyStoreKey) || "null");
  return normalizeState(stored || makeSeed());
}

function normalizeState(next) {
  const defaults = makeSeed();
  const tabIds = tabs.map(([id]) => id);
  const visibleTabs = [...new Set(next.visibleTabs || defaults.visibleTabs)].filter(id => tabIds.includes(id));
  if (!visibleTabs.includes("more")) visibleTabs.push("more");
  return {
    ...defaults,
    ...next,
    categories: next.categories || defaults.categories,
    transactions: next.transactions || [],
    drafts: next.drafts || [],
    rules: next.rules || [],
    visibleTabs,
    active: visibleTabs.includes(next.active) ? next.active : visibleTabs[0]
  };
}

function save() {
  localStorage.setItem(storeKey, JSON.stringify(state));
}

function money(value) {
  return INR.format(Number(value || 0));
}

function currentMonthRows(rows = state.transactions) {
  const now = new Date();
  return rows.filter(row => {
    const date = new Date(row.date);
    return date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear();
  });
}

function overview() {
  const rows = currentMonthRows();
  const budget = state.categories.reduce((sum, category) => sum + Number(category.budget || 0), 0);
  const spent = rows.filter(row => row.type === "expense").reduce((sum, row) => sum + Number(row.amount), 0);
  const income = rows.filter(row => row.type === "income").reduce((sum, row) => sum + Number(row.amount), 0);
  return { budget, spent, income, remaining: budget - spent };
}

function categorySpend(category) {
  return currentMonthRows()
    .filter(row => row.categoryId === category.id && row.type === "expense")
    .reduce((sum, row) => sum + Number(row.amount), 0);
}

function nav() {
  document.querySelector("#nav").innerHTML = state.visibleTabs.map(id => [id, tabLabel(id)]).map(([id, label]) =>
    `<button class="nav-button ${state.active === id ? "active" : ""}" data-tab="${id}">${label}</button>`
  ).join("");
}

function render() {
  nav();
  document.querySelector("#month").textContent = new Date().toLocaleDateString("en-IN", { month: "long", year: "numeric" });
  document.querySelector("#title").textContent = tabLabel(state.active);
  const view = document.querySelector("#view");
  view.innerHTML = views[state.active]();
  wireView();
}

const tile = (title, value, tone = "") => `<div class="tile ${tone}"><span>${title}</span><strong>${value}</strong></div>`;
const row = (title, meta, amount, type = "expense") => `
  <div class="row">
    <div><strong>${title}</strong><br><small>${meta}</small></div>
    <div class="amount ${type}">${amount}</div>
  </div>`;

const views = {
  dashboard() {
    const o = overview();
    const recent = state.transactions.slice(-6).reverse();
    return `
      <section class="grid">
        ${tile("Room today", money(Math.max(0, o.remaining)), o.remaining < 0 ? "expense" : "income")}
        ${tile("Out this month", money(o.spent))}
        ${tile("In this month", money(o.income), "income")}
        ${tile("To sort", state.drafts.length)}
      </section>
      <section class="panel">
        <h2>Latest Moves</h2>
        ${recent.length ? recent.map(t => row(t.merchant, `${t.date} · ${categoryName(t.categoryId)}`, money(t.amount), t.type)).join("") : `<p class="muted">Your first entry lands here.</p>`}
      </section>`;
  },
  ledger() {
    return `
      <section class="panel">
        <div class="toolbar"><button class="primary" data-action="add">New Entry</button></div>
        ${state.transactions.slice().reverse().map(t => row(t.merchant, `${t.date} · ${categoryName(t.categoryId)}`, money(t.amount), t.type)).join("") || `<p class="muted">Nothing written yet.</p>`}
      </section>`;
  },
  inbox() {
    return `
      <section class="panel">
        <h2>Statement Drop</h2>
        <div class="toolbar">
          <label>CSV file <input id="csvFile" type="file" accept=".csv,.txt,.tsv"></label>
        </div>
      </section>
      <section class="panel">
        <h2>Sorting Table</h2>
        ${state.drafts.length ? state.drafts.map(draftRow).join("") : `<p class="muted">Nothing to sort.</p>`}
      </section>`;
  },
  categories() {
    const o = overview();
    return `
      <section class="grid">
        ${tile("Monthly plan", money(o.budget))}
        ${tile("Used", money(o.spent))}
        ${tile("Still open", money(Math.max(0, o.remaining)), o.remaining < 0 ? "expense" : "income")}
        ${tile("Buckets", state.categories.length)}
      </section>
      <section class="panel">
        <h2>Category Map</h2>
        ${state.categories.map(categoryRow).join("")}
      </section>
      <section class="panel">
        <h2>Category Workshop</h2>
        ${state.categories.map(categoryEditRow).join("")}
        <div class="form-grid">
          <label>Name <input id="catName"></label>
          <label>Monthly shape <input id="catBudget" type="number" step="0.01"></label>
          <label>Tone <select id="catColor">${toneOptions("#750609")}</select></label>
          <button class="primary" data-action="addCategory">Create</button>
        </div>
      </section>`;
  },
  reports() {
    const o = overview();
    const rows = state.categories.map(c => ({ ...c, spent: categorySpend(c) })).sort((a, b) => b.spent - a.spent);
    return `
      <section class="grid">
        ${tile("Came in", money(o.income), "income")}
        ${tile("Went out", money(o.spent), "expense")}
        ${tile("Net flow", money(o.income - o.spent), o.income >= o.spent ? "income" : "expense")}
        ${tile("Plan used", `${Math.round((o.spent / Math.max(1, o.budget)) * 100)}%`)}
      </section>
      <section class="panel">
        <h2>Monthly Pattern</h2>
        ${rows.map(categoryRow).join("")}
      </section>`;
  },
  rules() {
    return `
      <section class="panel">
        <h2>Rule Loom</h2>
        <div class="form-grid">
          <label>When merchant says <input id="ruleMatch"></label>
          <label>Category <select id="ruleCategory">${categoryOptions()}</select></label>
          <button class="primary" data-action="addRule">Weave Rule</button>
        </div>
        ${state.rules.map(rule => `<div class="row"><div><strong>${rule.match}</strong><br><small>${categoryName(rule.categoryId)}</small></div><button data-delete-rule="${rule.id}">Remove</button></div>`).join("") || `<p class="muted">No rules woven yet.</p>`}
      </section>`;
  },
  more() {
    return `
      <section class="panel">
        <h2>Dock</h2>
        ${tabs.map(tabControl).join("")}
        <div class="toolbar">
          <button data-action="resetNav">Reset Dock</button>
        </div>
      </section>
      <section class="panel">
        <h2>Archive</h2>
        <div class="toolbar">
          <button data-action="export">Export JSON Backup</button>
          <button data-action="clear">Clear Browser Data</button>
        </div>
      </section>`;
  }
};

function tabLabel(id) {
  return tabs.find(([tabId]) => tabId === id)?.[1] || "Today";
}

function tabControl([id, label]) {
  const checked = state.visibleTabs.includes(id) ? "checked" : "";
  const locked = id === "more" ? "disabled" : "";
  const index = state.visibleTabs.indexOf(id);
  const moveButtons = index >= 0 ? `
    <button data-tab-up="${id}" ${index <= 0 ? "disabled" : ""}>Up</button>
    <button data-tab-down="${id}" ${index === state.visibleTabs.length - 1 ? "disabled" : ""}>Down</button>
  ` : "";
  return `<div class="row">
    <label class="inline"><input type="checkbox" data-visible-tab="${id}" ${checked} ${locked}> ${label}</label>
    <div class="toolbar">${moveButtons}</div>
  </div>`;
}

function categoryRow(category) {
  const spent = categorySpend(category);
  const pct = Math.round((spent / Math.max(1, Number(category.budget))) * 100);
  const color = categoryDisplayColor(category);
  return `<div class="row">
    <div>
      <strong style="color:${color}">${category.name}</strong>
      <div class="bar"><i style="--w:${Math.min(125, pct)}%;--c:${color}"></i></div>
      <small>${pct}% · ${money(Number(category.budget) - spent)} left</small>
    </div>
    <div class="amount">${money(spent)}</div>
  </div>`;
}

function categoryDisplayColor(category) {
  const redNames = ["meals", "home base", "rent", "fun"];
  return redNames.includes(String(category.name).toLowerCase()) ? "#750609" : "#0e0b09";
}

function toneOptions(selected = "#0e0b09") {
  return [
    ["#0e0b09", "Black"],
    ["#750609", "Deep red"],
    ["#fbf6ec", "Off white"]
  ].map(([value, label]) => `<option value="${value}" ${value.toLowerCase() === String(selected).toLowerCase() ? "selected" : ""}>${label}</option>`).join("");
}

function categoryEditRow(category) {
  return `<div class="row">
    <div class="form-grid compact">
      <label>Name <input data-cat-name="${category.id}" value="${escapeHtml(category.name)}"></label>
      <label>Monthly shape <input data-cat-budget="${category.id}" type="number" step="0.01" value="${Number(category.budget || 0)}"></label>
      <label>Tone <select data-cat-color="${category.id}">${toneOptions(category.color)}</select></label>
    </div>
    <div class="toolbar">
      <button class="primary" data-save-cat="${category.id}">Save</button>
      <button data-delete-cat="${category.id}">Remove</button>
    </div>
  </div>`;
}

function draftRow(draft) {
  return `<div class="row">
    <div><strong>${draft.merchant}</strong><br><small>${draft.date} · ${money(draft.amount)}</small></div>
    <div class="toolbar">
      <select data-draft-cat="${draft.id}">${categoryOptions(draft.categoryId)}</select>
      <button class="primary" data-approve="${draft.id}">Keep</button>
      <button data-dismiss="${draft.id}">Skip</button>
    </div>
  </div>`;
}

function categoryOptions(selected = "") {
  return `<option value="">No category</option>` + state.categories
    .map(c => `<option value="${c.id}" ${c.id === selected ? "selected" : ""}>${c.name}</option>`)
    .join("");
}

function categoryName(id) {
  return state.categories.find(c => c.id === id)?.name || "No category";
}

function wireView() {
  document.querySelectorAll("[data-tab]").forEach(button => button.addEventListener("click", () => {
    state.active = button.dataset.tab;
    save();
    render();
  }));
  document.querySelectorAll("[data-action='add']").forEach(button => button.addEventListener("click", openTransactionDialog));
  document.querySelector("[data-action='addCategory']")?.addEventListener("click", addCategory);
  document.querySelector("[data-action='addRule']")?.addEventListener("click", addRule);
  document.querySelector("[data-action='export']")?.addEventListener("click", exportData);
  document.querySelector("[data-action='clear']")?.addEventListener("click", clearData);
  document.querySelector("[data-action='resetNav']")?.addEventListener("click", resetNavigation);
  document.querySelector("#csvFile")?.addEventListener("change", importCSV);
  document.querySelectorAll("[data-visible-tab]").forEach(input => input.addEventListener("change", () => setTabVisibility(input.dataset.visibleTab, input.checked)));
  document.querySelectorAll("[data-tab-up]").forEach(button => button.addEventListener("click", () => moveTab(button.dataset.tabUp, -1)));
  document.querySelectorAll("[data-tab-down]").forEach(button => button.addEventListener("click", () => moveTab(button.dataset.tabDown, 1)));
  document.querySelectorAll("[data-save-cat]").forEach(button => button.addEventListener("click", () => saveCategory(button.dataset.saveCat)));
  document.querySelectorAll("[data-delete-cat]").forEach(button => button.addEventListener("click", () => deleteCategory(button.dataset.deleteCat)));
  document.querySelectorAll("[data-draft-cat]").forEach(select => select.addEventListener("change", event => {
    state.drafts.find(d => d.id === select.dataset.draftCat).categoryId = event.target.value;
    save();
  }));
  document.querySelectorAll("[data-approve]").forEach(button => button.addEventListener("click", () => approveDraft(button.dataset.approve)));
  document.querySelectorAll("[data-dismiss]").forEach(button => button.addEventListener("click", () => dismissDraft(button.dataset.dismiss)));
  document.querySelectorAll("[data-delete-rule]").forEach(button => button.addEventListener("click", () => {
    state.rules = state.rules.filter(rule => rule.id !== button.dataset.deleteRule);
    save();
    render();
  }));
}

function setTabVisibility(tabId, isVisible) {
  if (tabId === "more") return;
  if (isVisible && !state.visibleTabs.includes(tabId)) {
    state.visibleTabs.splice(Math.max(0, state.visibleTabs.length - 1), 0, tabId);
  }
  if (!isVisible) {
    state.visibleTabs = state.visibleTabs.filter(id => id !== tabId);
    if (state.active === tabId) state.active = state.visibleTabs[0] || "dashboard";
  }
  save();
  render();
}

function moveTab(tabId, offset) {
  const index = state.visibleTabs.indexOf(tabId);
  const nextIndex = index + offset;
  if (index < 0 || nextIndex < 0 || nextIndex >= state.visibleTabs.length) return;
  const [tab] = state.visibleTabs.splice(index, 1);
  state.visibleTabs.splice(nextIndex, 0, tab);
  save();
  render();
}

function resetNavigation() {
  state.visibleTabs = tabs.map(([id]) => id);
  if (!state.visibleTabs.includes(state.active)) state.active = "dashboard";
  save();
  render();
}

function openTransactionDialog() {
  const dialog = document.querySelector("#transactionDialog");
  const form = document.querySelector("#transactionForm");
  document.querySelector("#transactionCategory").innerHTML = categoryOptions();
  form.date.valueAsDate = new Date();
  dialog.showModal();
}

document.querySelector("#quickAdd").addEventListener("click", openTransactionDialog);
document.querySelector("#transactionForm").addEventListener("submit", event => {
  if (event.submitter.value !== "save") return;
  const data = new FormData(event.currentTarget);
  state.transactions.push({
    id: crypto.randomUUID(),
    date: data.get("date"),
    merchant: data.get("merchant"),
    amount: Number(data.get("amount")),
    type: data.get("type"),
    categoryId: data.get("categoryId")
  });
  save();
  render();
});

function addCategory() {
  const name = document.querySelector("#catName").value.trim();
  if (!name) return;
  state.categories.push({
    id: crypto.randomUUID(),
    name,
    budget: Number(document.querySelector("#catBudget").value || 0),
    color: document.querySelector("#catColor").value,
    symbol: name
  });
  save();
  render();
}

function saveCategory(id) {
  const category = state.categories.find(row => row.id === id);
  if (!category) return;
  const name = document.querySelector(`[data-cat-name="${id}"]`).value.trim();
  if (!name) return;
  category.name = name;
  category.symbol = name;
  category.budget = Number(document.querySelector(`[data-cat-budget="${id}"]`).value || 0);
  category.color = document.querySelector(`[data-cat-color="${id}"]`).value;
  save();
  render();
}

function deleteCategory(id) {
  if (!confirm("Remove this category? Existing web entries will become uncategorized.")) return;
  state.categories = state.categories.filter(category => category.id !== id);
  state.transactions.forEach(row => {
    if (row.categoryId === id) row.categoryId = "";
  });
  state.drafts.forEach(row => {
    if (row.categoryId === id) row.categoryId = "";
  });
  state.rules = state.rules.filter(rule => rule.categoryId !== id);
  save();
  render();
}

function addRule() {
  const match = document.querySelector("#ruleMatch").value.trim();
  const categoryId = document.querySelector("#ruleCategory").value;
  if (!match || !categoryId) return;
  state.rules.push({ id: crypto.randomUUID(), match, categoryId });
  save();
  render();
}

function importCSV(event) {
  const file = event.target.files[0];
  if (!file) return;
  file.text().then(text => {
    const lines = parseCSVRows(text.trim());
    const headers = lines.shift().map(header => header.toLowerCase());
    const idx = name => headers.findIndex(header => header.includes(name));
    const dateIndex = idx("date");
    const descIndex = Math.max(idx("description"), idx("merchant"), idx("narration"));
    const debitIndex = idx("debit");
    const creditIndex = idx("credit");
    const amountIndex = idx("amount");
    state.drafts.push(...lines.map(row => {
      const credit = Number((row[creditIndex] || "").replace(/,/g, ""));
      const debit = Number((row[debitIndex] || "").replace(/,/g, ""));
      const rawAmount = Number((row[amountIndex] || "").replace(/,/g, ""));
      const amount = debit || credit || Math.abs(rawAmount);
      const type = credit || rawAmount > 0 ? "income" : "expense";
      const merchant = row[descIndex] || "Imported transaction";
      const rule = state.rules.find(rule => merchant.toLowerCase().includes(rule.match.toLowerCase()));
      return { id: crypto.randomUUID(), date: row[dateIndex], merchant, amount, type, categoryId: rule?.categoryId || "" };
    }).filter(row => row.date && row.amount));
    save();
    render();
  });
}

function approveDraft(id) {
  const draft = state.drafts.find(row => row.id === id);
  if (!draft) return;
  state.transactions.push({ ...draft, id: crypto.randomUUID() });
  if (draft.categoryId && !state.rules.some(rule => draft.merchant.toLowerCase().includes(rule.match.toLowerCase()))) {
    state.rules.push({ id: crypto.randomUUID(), match: draft.merchant.split(/\s+/).slice(0, 3).join(" "), categoryId: draft.categoryId });
  }
  dismissDraft(id);
}

function dismissDraft(id) {
  state.drafts = state.drafts.filter(row => row.id !== id);
  save();
  render();
}

function exportData() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = Object.assign(document.createElement("a"), { href: url, download: "kosha-web-backup.json" });
  link.click();
  URL.revokeObjectURL(url);
}

function clearData() {
  if (!confirm("Clear Kosha browser data?")) return;
  localStorage.removeItem(storeKey);
  state = load();
  render();
}

function parseCSVRows(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (char === '"' && quoted && next === '"') {
      cell += '"';
      index += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      row.push(cell.trim());
      cell = "";
    } else if ((char === "\n" || char === "\r") && !quoted) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(cell.trim());
      if (row.some(value => value.length)) rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += char;
    }
  }

  row.push(cell.trim());
  if (row.some(value => value.length)) rows.push(row);
  return rows;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

render();
