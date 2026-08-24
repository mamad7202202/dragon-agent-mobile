/* Recall Lab — scores sample facts with Dragon's real formula.
   score = cosine(q, fact) × (0.55 + 0.45·importance) × (0.7 + 0.3·recency)
   recency = 1 / (1 + age_days / 14) */
window.recallLab = function (root, reduced) {
  "use strict";

  var facts = [
    { id: "a3f9", text: "Sister is called Sara",            imp: 0.9, age: 2  },
    { id: "b7c1", text: "Prefers answers in Persian",       imp: 0.7, age: 9  },
    { id: "c2d8", text: "Building Dragon Agent in Rust",    imp: 0.6, age: 30 },
    { id: "d5e0", text: "Drinks tea, no sugar",             imp: 0.3, age: 1  },
    { id: "e9a2", text: "Timezone is +3:30",                imp: 0.5, age: 45 },
    { id: "f1b4", text: "Dislikes cloud-only apps",         imp: 0.8, age: 12 }
  ];

  function tokenize(s) {
    return s.toLowerCase().split(/[^a-z0-9\u0600-\u06FF]+/)
      .filter(function (t) { return t.length > 1 && t.length < 24; });
  }

  function cosine(a, b) {
    if (!a.length || !b.length) return 0;
    var ca = {}, cb = {};
    a.forEach(function (t) { ca[t] = (ca[t] || 0) + 1; });
    b.forEach(function (t) { cb[t] = (cb[t] || 0) + 1; });
    var dot = 0, na = 0, nb = 0, t;
    for (t in ca) { dot += ca[t] * (cb[t] || 0); na += ca[t] * ca[t]; }
    for (t in cb) { nb += cb[t] * cb[t]; }
    if (!na || !nb) return 0;
    return dot / Math.sqrt(na * nb);
  }

  function score(query, f) {
    var rel = cosine(tokenize(query), tokenize(f.text));
    if (rel <= 0) return 0;
    var recency = 1 / (1 + f.age / 14);
    return rel * (0.55 + 0.45 * f.imp) * (0.7 + 0.3 * recency);
  }

  var input = root.querySelector(".lab-input input");
  var rows = root.querySelector(".lab-rows");

  function render() {
    var q = input.value || "";
    var scored = facts.map(function (f) {
      return { f: f, s: score(q, f) };
    }).sort(function (a, b) { return b.s - a.s; });

    var topCut = 0.0001;
    var hits = 0;
    rows.innerHTML = "";
    scored.forEach(function (e) {
      var isHit = e.s > topCut && hits < 3;
      if (isHit) hits++;
      var row = document.createElement("div");
      row.className = "lr" + (isHit ? " hit" : "");
      row.innerHTML =
        '<span class="fid">' + e.f.id + '</span>' +
        '<span class="ftext">' + e.f.text + '</span>' +
        '<span class="fmeta">imp ' + e.f.imp.toFixed(1) + ' · ' + e.f.age + 'd old</span>' +
        '<span class="fscore"><span class="injected">injected</span>' +
        '<span class="bar"><i style="width:' + Math.round(Math.min(1, e.s / 0.9) * 100) + '%"></i></span>' +
        '<span class="num">' + (e.s > 0 ? e.s.toFixed(2) : "0.00") + '</span></span>';
      rows.appendChild(row);
    });
  }

  input.addEventListener("input", render);
  render();
};
