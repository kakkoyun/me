(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    var canvas = document.getElementById("site-graph");
    if (!canvas) return;
    fetch(canvas.dataset.graphSrc)
      .then(function (r) { return r.json(); })
      .then(function (data) { init(canvas, data); })
      .catch(function (err) { console.warn("graph: failed to load data", err); });
  });

  function readColors() {
    var cs = getComputedStyle(document.body);
    function v(name, fb) { return cs.getPropertyValue(name).trim() || fb; }
    return {
      posts: v("--graph-node-posts", "#2e7dd1"), talks: v("--graph-node-talks", "#8256d0"),
      newsletter: v("--graph-node-newsletter", "#347d39"), pages: v("--graph-node-pages", "#966600"),
      edge: v("--graph-edge", "rgba(128,128,128,0.35)"), label: v("--graph-label", "#555")
    };
  }

  function init(canvas, data) {
    var ctx = canvas.getContext("2d"), wrap = canvas.parentElement;
    var reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
    var colors = readColors(), width = 0, height = 0;
    var nodesById = {};
    var nodes = Object.keys(data.pages).map(function (id) {
      var p = data.pages[id];
      var n = { id: id, title: p.title, section: p.section, x: 0, y: 0, vx: 0, vy: 0, degree: 0 };
      nodesById[id] = n;
      return n;
    });
    var seen = {}, links = [];
    Object.keys(data.graph).forEach(function (id) {
      var src = nodesById[id];
      if (!src) return;
      (data.graph[id].out || []).forEach(function (target) {
        var tgt = nodesById[target];
        if (!tgt) return;
        var key = id < target ? id + "|" + target : target + "|" + id;
        if (seen[key]) return;
        seen[key] = true;
        links.push({ source: src, target: tgt });
      });
    });
    links.forEach(function (l) { l.source.degree++; l.target.degree++; });
    function radius(n) { return Math.min(3 + 1.5 * Math.sqrt(n.degree), 12); }

    function resize() {
      width = wrap.getBoundingClientRect().width;
      height = Math.min(window.innerHeight * 0.7, 600);
      var dpr = window.devicePixelRatio || 1;
      canvas.width = width * dpr; canvas.height = height * dpr; canvas.style.height = height + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    function place() {
      var cx = width / 2, cy = height / 2, maxR = 0.4 * Math.min(width, height);
      nodes.forEach(function (n) {
        var ang = Math.random() * Math.PI * 2, rad = Math.random() * maxR;
        n.x = cx + Math.cos(ang) * rad; n.y = cy + Math.sin(ang) * rad;
      });
    }
    resize(); place();
    var alpha = 1, hovered = null, dragged = null, rafId = null;

    function tick() {
      var cx = width / 2, cy = height / 2, i, j;
      for (i = 0; i < nodes.length; i++) {
        for (j = i + 1; j < nodes.length; j++) {
          var a = nodes[i], b = nodes[j], dx = b.x - a.x, dy = b.y - a.y;
          var d2 = dx * dx + dy * dy || 0.01, d = Math.sqrt(d2), f = (800 / d2) * alpha;
          var fx = (dx / d) * f, fy = (dy / d) * f;
          a.vx -= fx; a.vy -= fy; b.vx += fx; b.vy += fy;
        }
      }
      links.forEach(function (l) {
        var dx = l.target.x - l.source.x, dy = l.target.y - l.source.y;
        var d = Math.sqrt(dx * dx + dy * dy) || 0.01, f = (d - 80) * 0.04 * alpha;
        var fx = (dx / d) * f, fy = (dy / d) * f;
        l.source.vx += fx; l.source.vy += fy; l.target.vx -= fx; l.target.vy -= fy;
      });
      nodes.forEach(function (n) {
        if (n === dragged) return;
        n.vx += (cx - n.x) * 0.02 * alpha; n.vy += (cy - n.y) * 0.02 * alpha;
        n.vx *= 0.85; n.vy *= 0.85;
        n.x += n.vx; n.y += n.vy;
        n.x = Math.max(10, Math.min(width - 10, n.x));
        n.y = Math.max(10, Math.min(height - 10, n.y));
      });
      alpha *= 0.98;
    }

    function neighborsOf(n) {
      var set = {};
      links.forEach(function (l) {
        if (l.source === n) set[l.target.id] = true;
        else if (l.target === n) set[l.source.id] = true;
      });
      return set;
    }

    function draw() {
      ctx.clearRect(0, 0, width, height);
      var neigh = hovered ? neighborsOf(hovered) : null;
      ctx.strokeStyle = colors.edge; ctx.lineWidth = 1;
      links.forEach(function (l) {
        ctx.globalAlpha = hovered && l.source !== hovered && l.target !== hovered ? 0.25 : 1;
        ctx.beginPath(); ctx.moveTo(l.source.x, l.source.y); ctx.lineTo(l.target.x, l.target.y); ctx.stroke();
      });
      nodes.forEach(function (n) {
        var isNeighbor = n === hovered || (neigh && neigh[n.id]);
        ctx.globalAlpha = hovered && !isNeighbor ? 0.25 : 1;
        ctx.fillStyle = colors[n.section] || colors.pages;
        ctx.beginPath(); ctx.arc(n.x, n.y, radius(n), 0, Math.PI * 2); ctx.fill();
      });
      ctx.globalAlpha = 1; ctx.font = "11px system-ui, sans-serif";
      ctx.fillStyle = colors.label; ctx.textBaseline = "middle";
      nodes.forEach(function (n) {
        var isNeighbor = n === hovered || (neigh && neigh[n.id]);
        var show = hovered ? isNeighbor : n.degree >= 3;
        if (show) ctx.fillText(n.title, n.x + radius(n) + 3, n.y);
      });
    }

    function loop() {
      tick(); draw();
      rafId = alpha < 0.005 ? null : requestAnimationFrame(loop);
    }
    if (reduced) {
      for (var t = 0; t < 300 && alpha >= 0.005; t++) tick();
      draw();
    } else {
      rafId = requestAnimationFrame(loop);
    }

    function pointerPos(e) {
      var rect = canvas.getBoundingClientRect();
      return { x: e.clientX - rect.left, y: e.clientY - rect.top };
    }
    function hitTest(x, y) {
      var best = null, bestD = Infinity;
      nodes.forEach(function (n) {
        var dx = x - n.x, dy = y - n.y, d2 = dx * dx + dy * dy, r = radius(n) + 6;
        if (d2 <= r * r && d2 < bestD) { bestD = d2; best = n; }
      });
      return best;
    }

    canvas.addEventListener("mousemove", function (e) {
      if (dragged) return;
      var p = pointerPos(e), hit = hitTest(p.x, p.y);
      if (hit !== hovered) { hovered = hit; canvas.style.cursor = hit ? "pointer" : ""; draw(); }
    });
    canvas.addEventListener("click", function (e) {
      var p = pointerPos(e), hit = hitTest(p.x, p.y);
      if (hit) window.location.href = hit.id;
    });
    canvas.addEventListener("pointerdown", function (e) {
      var p = pointerPos(e), hit = hitTest(p.x, p.y);
      if (!hit) return;
      dragged = hit;
      canvas.setPointerCapture(e.pointerId);
    });
    canvas.addEventListener("pointermove", function (e) {
      if (!dragged) return;
      var p = pointerPos(e);
      dragged.x = p.x; dragged.y = p.y; dragged.vx = 0; dragged.vy = 0;
      draw();
    });
    function endDrag() {
      if (!dragged) return;
      dragged = null;
      if (reduced) return;
      alpha = Math.max(alpha, 0.3);
      if (!rafId) rafId = requestAnimationFrame(loop);
    }
    canvas.addEventListener("pointerup", endDrag);
    canvas.addEventListener("pointercancel", endDrag);

    var resizeTimer = null;
    window.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () { resize(); draw(); }, 150);
    });
    new MutationObserver(function () { colors = readColors(); draw(); })
      .observe(document.body, { attributeFilter: ["class"] });
  }
})();
