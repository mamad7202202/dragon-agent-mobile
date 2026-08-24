/* Live telemetry — real numbers from the GitHub releases API. */
(function () {
  "use strict";

  var REPO = "mamad7202202/dragon-agent-mobile";
  var CACHE_KEY = "dg-telemetry-v1";
  var FRESH_MS = 10 * 60 * 1000;

  var totalEl = document.getElementById("t-total");
  var relEl = document.getElementById("t-releases");
  var verEl = document.getElementById("t-latest");
  var chartEl = document.getElementById("t-chart");
  if (!chartEl) return;

  function fmt(n) {
    if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k";
    return String(n);
  }

  function render(data) {
    totalEl.textContent = fmt(data.total);
    relEl.textContent = String(data.releases);
    verEl.textContent = data.latest;

    // bar chart: downloads per release, oldest → newest
    var rows = data.perRelease.slice(-10);
    var max = 1;
    rows.forEach(function (r) { if (r.dl > max) max = r.dl; });

    chartEl.innerHTML = "";
    rows.forEach(function (r) {
      var col = document.createElement("div");
      col.className = "tbar" + (r.latest ? " latest" : "");
      var h = Math.max(6, Math.round((r.dl / max) * 100));
      col.innerHTML =
        '<span class="v">' + (r.dl > 0 ? fmt(r.dl) : "") + "</span>" +
        '<span class="bar"><i style="height:' + h + '%"></i></span>' +
        '<span class="t" title="' + r.tag + " · " + r.dl + ' downloads">' + r.tag.replace(/^v/, "") + "</span>";
      col.title = r.tag + " — " + r.dl + " downloads";
      chartEl.appendChild(col);
    });

    var stamp = document.getElementById("t-stamp");
    if (stamp) stamp.textContent = "live · api.github.com · " + data.releases + " releases";
  }

  function showError(msg) {
    chartEl.innerHTML = '<div class="tel-empty">' + msg + "</div>";
  }

  function parse(releases) {
    var total = 0;
    var perRelease = [];
    releases.forEach(function (r) {
      var dl = 0;
      (r.assets || []).forEach(function (a) { dl += a.download_count || 0; });
      if (dl === 0 && !r.assets.length) return; // releases without assets
      total += dl;
      perRelease.push({
        tag: r.tag_name,
        dl: dl,
        date: r.published_at || "",
        latest: !!r.assets.length && perRelease.length === 0 ? false : false
      });
    });
    // newest first by published date; mark the most recent with assets
    perRelease.sort(function (a, b) { return a.date < b.date ? -1 : 1; });
    if (perRelease.length) perRelease[perRelease.length - 1].latest = true;
    return {
      total: total,
      releases: perRelease.length,
      latest: perRelease.length ? perRelease[perRelease.length - 1].tag : "—",
      perRelease: perRelease
    };
  }

  function load(cachedOnly) {
    var cached = null;
    try {
      cached = JSON.parse(localStorage.getItem(CACHE_KEY) || "null");
    } catch (e) {}

    if (cached && cached.data) {
      render(cached.data);
      if (cachedOnly || Date.now() - cached.t < FRESH_MS) return;
    }

    fetch("https://api.github.com/repos/" + REPO + "/releases?per_page=100", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (releases) {
        var data = parse(releases);
        try {
          localStorage.setItem(CACHE_KEY, JSON.stringify({ t: Date.now(), data: data }));
        } catch (e) {}
        render(data);
      })
      .catch(function () {
        if (!cached) showError("github api unreachable — try again shortly");
      });
  }

  load(false);
})();
