/* Dragon Agent docs — transcript typing + recall lab */
(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- hero transcript ---------- */
  var body = document.querySelector(".term-body");
  if (body) {
    var lines = [
      { cls: "you",    html: "remember my sister&rsquo;s name is Sara" },
      { cls: "dragon", html: '<span class="tag">save_memory</span>{ "text": "Sister is called Sara", "importance": 0.9 }' },
      { cls: "dragon", html: '<span class="tag ok">stored</span>id <span class="dim">a3f9</span> &middot; hybrid memory' },
      { cls: "dragon", html: "Got it &mdash; Sara. I&rsquo;ll keep that." },
      { cls: "you",    html: "new phone, same question: what do you know about me?" },
      { cls: "dragon", html: '<span class="tag recall">recall</span>1 fact &middot; score <span class="dim">0.71</span>' },
      { cls: "dragon", html: "Your sister is called Sara. Everything else stayed on-device." }
    ];
    var caret = document.createElement("span");
    caret.className = "caret";

    function renderLine(li) {
      var d = document.createElement("div");
      d.className = "tl " + lines[li].cls;
      var who = document.createElement("span");
      who.className = "who";
      who.textContent = lines[li].cls === "you" ? "you" : "dragon";
      var txt = document.createElement("span");
      txt.className = "txt";
      txt.innerHTML = lines[li].html;
      d.appendChild(who);
      d.appendChild(txt);
      body.appendChild(d);
      return d;
    }

    if (reduced) {
      lines.forEach(function (l, i) { renderLine(i).classList.add("on"); });
    } else {
      var li = 0;
      function nextLine() {
        if (li >= lines.length) return;
        var el = renderLine(li);
        el.classList.add("on");
        var txt = el.querySelector(".txt");
        var full = txt.innerHTML;
        txt.innerHTML = "";
        txt.appendChild(caret);
        var shown = 0;
        var plain = full;
        // type by revealing characters of the plain string, then restore html
        var plainText = full.replace(/<[^>]*>/g, "");
        var timer = setInterval(function () {
          shown += 3;
          if (shown >= plainText.length) {
            clearInterval(timer);
            txt.innerHTML = full;
            li++;
            setTimeout(nextLine, li === lines.length ? 0 : 420);
          } else {
            caret.before(document.createTextNode(plainText.slice(shown - 3, shown)));
          }
        }, 16);
      }
      nextLine();
      body.addEventListener("click", function () {
        body.innerHTML = "";
        lines.forEach(function (l) {
          var d = renderLine(lines.indexOf(l));
          d.classList.add("on");
        });
      });
    }
  }

  /* ---------- recall lab ---------- */
  var lab = document.getElementById("lab");
  if (lab && window.recallLab) window.recallLab(lab, reduced);
})();
