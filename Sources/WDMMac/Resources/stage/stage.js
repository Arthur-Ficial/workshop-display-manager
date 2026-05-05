/* wdm Stage — embedded WebKit monitor arrangement.
 * Vanilla modern JS (Pointer Events, requestAnimationFrame, ResizeObserver).
 * Bridges to Swift via window.webkit.messageHandlers.wdm.postMessage(...).
 *
 * Public API — Swift calls these via evaluateJavaScript:
 *   window.wdm.setState({ tiles, selectedID, zoom })
 *
 * Bridge messages from JS → Swift:
 *   { type: "ready" }
 *   { type: "select", id }
 *   { type: "drag", phase: "end", id, originX, originY }
 *   { type: "zoom", value }
 */

(() => {
  "use strict";

  /** @typedef {{
   *    id: number, name: string, isMain: boolean,
   *    widthPx: number, heightPx: number,
   *    originX: number, originY: number,
   *    refreshHz: number,
   * }} Tile */

  const $canvas = document.getElementById("canvas");
  const $content = document.getElementById("content");
  const $guides = document.getElementById("guides");
  const ZOOM_MIN = 0.4, ZOOM_MAX = 4.0;
  // "Strong magnet": tile edges/centres within this many display-pixels
  // get pulled in. ~64px is roughly the macOS Settings ▸ Displays feel —
  // edges bond from ~5cm of cursor distance at typical zoom.
  const SNAP_TOLERANCE_PX = 64;
  const TILE_PADDING = 60;             // visual breathing room (canvas px)

  /** Current state mirror. */
  let state = { tiles: [], selectedID: null, zoom: 1.0 };
  /** Per-tile DOM nodes, keyed by id. */
  const nodes = new Map();
  /** Per-tile pending origin during drag (display px). */
  const pending = new Map();
  /** Current display→canvas pixel scale (set on each render). */
  let pxToCanvas = 1, bbMinX = 0, bbMinY = 0, bbW = 1, bbH = 1;
  /** Latched layout frame — updated only on canvas resize, zoom change,
   *  or an explicit refit (zoom-reset / first paint). NOT recomputed on
   *  every state update, because that would re-centre the whole canvas
   *  every time the user drags a tile or selects one. Stability wins. */
  let layoutFrameDirty = true;

  /** Send a message to the Swift host. No-op outside WKWebView. */
  function bridge(msg) {
    const h = window.webkit?.messageHandlers?.wdm;
    if (h) { h.postMessage(msg); }
  }

  // ─── State setter (Swift → JS) ─────────────────────────────────────
  // Zoom is JS-owned — Swift never overrides it, so the user's chosen
  // zoom level survives selection / arrangement updates. Pending drag
  // overlays are cleared because fresh Swift state already reflects any
  // committed move; leaving stale pending around makes tiles jump.
  window.wdm = window.wdm || {};
  window.wdm.setState = (next) => {
    if (next.tiles !== undefined) state.tiles = next.tiles;
    if (next.selectedID !== undefined) state.selectedID = next.selectedID;
    pending.clear();
    render();
  };

  // ─── Layout ────────────────────────────────────────────────────────
  // The layout frame (bbMinX, bbMinY, bbW, bbH, pxToCanvas) is computed
  // at the **natural** fit-to-canvas scale (zoom=1) and stays fixed
  // unless the canvas resizes or the displays' on-disk arrangement
  // changes. Zoom does NOT recompute the frame — it's applied as a
  // pure CSS transform on `#content` + `#guides` so clicking + only
  // zooms; the canvas centre and tile-relative-to-canvas anchors stay
  // exactly where they were.
  function computeLayout() {
    const w = $canvas.clientWidth;
    const h = $canvas.clientHeight;
    applyZoom();                       // always re-apply, cheap
    if (!layoutFrameDirty) return { canvasW: w, canvasH: h };
    if (state.tiles.length === 0) {
      pxToCanvas = 1; bbMinX = 0; bbMinY = 0; bbW = 1; bbH = 1;
      return { canvasW: w, canvasH: h };
    }
    const xs = state.tiles.map(t => t.originX);
    const ys = state.tiles.map(t => t.originY);
    const xRights = state.tiles.map(t => t.originX + t.widthPx);
    const yBottoms = state.tiles.map(t => t.originY + t.heightPx);
    bbMinX = Math.min(...xs);
    bbMinY = Math.min(...ys);
    bbW = Math.max(...xRights) - bbMinX;
    bbH = Math.max(...yBottoms) - bbMinY;
    const innerW = Math.max(w - TILE_PADDING * 2, 1);
    const innerH = Math.max(h - TILE_PADDING * 2, 1);
    pxToCanvas = Math.min(innerW / bbW, innerH / bbH);   // no zoom factor
    layoutFrameDirty = false;
    return { canvasW: w, canvasH: h };
  }

  /** Apply zoom as a CSS transform on the visible content layers.
   *  Anchored at the canvas centre so + grows the view symmetrically. */
  function applyZoom() {
    const t = `scale(${state.zoom})`;
    $content.style.transform = t;
    $content.style.transformOrigin = "50% 50%";
    $guides.style.transform = t;
    $guides.style.transformOrigin = "50% 50%";
  }

  function tileToCanvas(t) {
    const canvasW = $canvas.clientWidth, canvasH = $canvas.clientHeight;
    const scaledW = bbW * pxToCanvas;
    const scaledH = bbH * pxToCanvas;
    const dx = (canvasW - scaledW) / 2;
    const dy = (canvasH - scaledH) / 2;
    const ox = pending.get(t.id)?.x ?? t.originX;
    const oy = pending.get(t.id)?.y ?? t.originY;
    return {
      x: (ox - bbMinX) * pxToCanvas + dx,
      y: (oy - bbMinY) * pxToCanvas + dy,
      w: t.widthPx  * pxToCanvas,
      h: t.heightPx * pxToCanvas,
    };
  }

  // ─── Render ────────────────────────────────────────────────────────
  function render() {
    computeLayout();
    const seen = new Set();
    for (const t of state.tiles) {
      seen.add(t.id);
      let node = nodes.get(t.id);
      if (!node) { node = createTile(t); nodes.set(t.id, node); $content.appendChild(node); }
      updateTile(node, t);
    }
    for (const [id, node] of nodes) {
      if (!seen.has(id)) { node.remove(); nodes.delete(id); }
    }
    document.getElementById("zoom-reset").textContent =
      Math.round(state.zoom * 100) + "%";
  }

  function createTile(t) {
    const el = document.createElement("div");
    el.className = "tile";
    el.dataset.id = String(t.id);
    el.setAttribute("role", "button");
    el.setAttribute("aria-label", t.name);
    // remoteID literal mirrors the SwiftUI accessibilityIdentifier so
    // headed e2e tests can still find it via the AccessibilityWalker.
    el.dataset.remoteId = "stage.tile." + t.id;
    el.innerHTML =
      '<div class="webcam"></div>' +
      '<div class="screen">' +
        '<div class="badge"></div>' +
        '<div class="main-tag" hidden>MAIN</div>' +
        '<div class="name"></div>' +
        '<div class="res"></div>' +
      '</div>';
    attachDrag(el);
    el.addEventListener("click", (e) => {
      if (el.dataset.dragMoved === "1") {
        // suppress click after drag-move
        delete el.dataset.dragMoved;
        return;
      }
      bridge({ type: "select", id: t.id });
    });
    return el;
  }

  function updateTile(el, t) {
    const r = tileToCanvas(t);
    el.style.transform = `translate3d(${r.x}px, ${r.y}px, 0)`;
    el.style.width = r.w + "px";
    el.style.height = r.h + "px";
    el.classList.toggle("is-main", t.isMain);
    el.classList.toggle("is-selected", state.selectedID === t.id);
    el.querySelector(".badge").textContent = String(t.id).padStart(2, "0");
    el.querySelector(".name").textContent = t.name;
    el.querySelector(".res").textContent =
      t.widthPx + "×" + t.heightPx + " @ " + (t.refreshHz | 0) + "Hz";
    // Progressive label degradation — drop details that won't fit the
    // tile's current rendered size. Each density tier hides one more
    // field: tiny → only the number badge; small → +name; medium → +res;
    // large → +MAIN tag. Prevents text overflow at any zoom.
    const tier =
      r.w < 80  || r.h < 50 ? "tiny"   :
      r.w < 130 || r.h < 70 ? "small"  :
      r.w < 200 || r.h < 100 ? "medium" : "large";
    el.dataset.tier = tier;
    const showName = tier !== "tiny";
    const showRes  = tier === "medium" || tier === "large";
    const showMain = tier === "large" && t.isMain;
    el.querySelector(".name").hidden = !showName;
    el.querySelector(".res").hidden = !showRes;
    el.querySelector(".main-tag").hidden = !showMain;
  }

  // ─── Drag with snap guidelines ─────────────────────────────────────
  function attachDrag(el) {
    /** @type {{startX:number,startY:number,startOriginX:number,startOriginY:number,id:number}|null} */
    let drag = null;
    el.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      const id = Number(el.dataset.id);
      const t = state.tiles.find(x => x.id === id);
      if (!t) return;
      el.setPointerCapture(e.pointerId);
      el.classList.add("is-dragging");
      drag = {
        startX: e.clientX, startY: e.clientY,
        startOriginX: t.originX, startOriginY: t.originY,
        id,
      };
    });
    el.addEventListener("pointermove", (e) => {
      if (!drag) return;
      // Zoom is applied as a CSS transform on the parent, so the screen
      // delta in display-pixels is divided by (pxToCanvas * zoom).
      const visualPxToCanvas = pxToCanvas * state.zoom;
      const dx = (e.clientX - drag.startX) / visualPxToCanvas;
      const dy = (e.clientY - drag.startY) / visualPxToCanvas;
      const proposed = {
        x: Math.round(drag.startOriginX + dx),
        y: Math.round(drag.startOriginY + dy),
      };
      const t = state.tiles.find(x => x.id === drag.id);
      const snapped = applySnap(proposed, t);
      pending.set(drag.id, snapped.origin);
      el.dataset.dragMoved = "1";
      updateTile(el, t);
      drawGuides(snapped.lines);
    });
    el.addEventListener("pointerup", () => endDrag(el));
    el.addEventListener("pointercancel", () => endDrag(el));

    function endDrag(el) {
      if (!drag) return;
      const final = pending.get(drag.id);
      const id = drag.id;
      drag = null;
      el.classList.remove("is-dragging");
      // Hold the snap guidelines for a beat after release so the user
      // can confirm visually which edges aligned, then fade them out.
      // Pure CSS opacity — no further state churn.
      $guides.classList.add("guides-hold");
      setTimeout(() => { $guides.classList.add("guides-fade"); }, 320);
      setTimeout(() => {
        $guides.classList.remove("guides-hold", "guides-fade");
        drawGuides([]);
      }, 720);
      if (final) {
        bridge({ type: "drag", phase: "end",
                 id, originX: final.x, originY: final.y });
      }
      // keep pending until Swift sends a fresh state, so we don't blink
    }
  }

  /** Snap-line computation: for the proposed rect, look for edges /
   *  centres of every other tile within tolerance. Then push out of
   *  any sibling rectangle that would otherwise overlap — physical
   *  monitors don't intersect, neither do their tiles. Returns the
   *  snapped origin and the active guide lines (display-pixel coords). */
  function applySnap(proposed, tile) {
    const tol = SNAP_TOLERANCE_PX;
    const rect = { x: proposed.x, y: proposed.y, w: tile.widthPx, h: tile.heightPx };
    const others = state.tiles.filter(t => t.id !== tile.id);
    const lines = [];
    let snappedX = proposed.x, snappedY = proposed.y;
    const myX = [rect.x, rect.x + rect.w / 2, rect.x + rect.w];
    const myY = [rect.y, rect.y + rect.h / 2, rect.y + rect.h];
    for (const o of others) {
      const oX = [o.originX, o.originX + o.widthPx / 2, o.originX + o.widthPx];
      const oY = [o.originY, o.originY + o.heightPx / 2, o.originY + o.heightPx];
      for (let i = 0; i < 3; i++) {
        for (const tx of oX) {
          if (Math.abs(myX[i] - tx) <= tol) {
            const offset = [0, rect.w / 2, rect.w][i];
            snappedX = Math.round(tx - offset);
            lines.push({ axis: "v", at: tx, span: [
              Math.min(rect.y, o.originY), Math.max(rect.y + rect.h, o.originY + o.heightPx)] });
          }
        }
        for (const ty of oY) {
          if (Math.abs(myY[i] - ty) <= tol) {
            const offset = [0, rect.h / 2, rect.h][i];
            snappedY = Math.round(ty - offset);
            lines.push({ axis: "h", at: ty, span: [
              Math.min(rect.x, o.originX), Math.max(rect.x + rect.w, o.originX + o.widthPx)] });
          }
        }
      }
      // size match: same width or height as another → emit guide
      if (Math.abs(rect.w - o.widthPx) <= tol) {
        lines.push({ axis: "size-w", a: rect.x, b: rect.x + rect.w, atY: rect.y - 14 });
      }
      if (Math.abs(rect.h - o.heightPx) <= tol) {
        lines.push({ axis: "size-h", a: rect.y, b: rect.y + rect.h, atX: rect.x - 14 });
      }
    }
    // Overlap prevention — push the dragged tile out of any sibling
    // it would intersect, towards the closest non-overlapping side.
    const final = pushOutOfOverlap(
      { x: snappedX, y: snappedY, w: rect.w, h: rect.h },
      others
    );
    return { origin: { x: final.x, y: final.y }, lines };
  }

  /** Move `r` so it doesn't overlap any sibling rect. Picks the cheapest
   *  axis-aligned displacement (left/right/up/down) per overlapping
   *  sibling, in iteration order; converges quickly because real
   *  monitor counts are small (rarely more than 4–6). */
  function pushOutOfOverlap(r, others) {
    let { x, y, w, h } = r;
    for (let pass = 0; pass < 4; pass++) {
      let moved = false;
      for (const o of others) {
        const ox = o.originX, oy = o.originY, ow = o.widthPx, oh = o.heightPx;
        const overlapX = Math.min(x + w, ox + ow) - Math.max(x, ox);
        const overlapY = Math.min(y + h, oy + oh) - Math.max(y, oy);
        if (overlapX <= 0 || overlapY <= 0) continue;       // not overlapping
        // Cheapest of: push left, push right, push up, push down.
        const pushLeft  = (x + w) - ox;        // amount to move left
        const pushRight = (ox + ow) - x;       // amount to move right
        const pushUp    = (y + h) - oy;        // amount to move up
        const pushDown  = (oy + oh) - y;       // amount to move down
        const min = Math.min(pushLeft, pushRight, pushUp, pushDown);
        if (min === pushLeft)  { x -= pushLeft; }
        else if (min === pushRight) { x += pushRight; }
        else if (min === pushUp)    { y -= pushUp; }
        else                        { y += pushDown; }
        moved = true;
      }
      if (!moved) break;
    }
    return { x: Math.round(x), y: Math.round(y) };
  }

  /** Per-line lifecycle. Each guide is keyed by axis+position; on every
   *  draw we (a) refresh `lastSeen` for guides still proposed, (b) add
   *  brand-new ones, (c) remove only those whose `lastSeen` is older
   *  than GUIDES_LINGER_MS. So a vertical line doesn't vanish just
   *  because a horizontal one appeared on the next frame. */
  const liveGuides = new Map();         // key → { element, lastSeen }
  const GUIDES_LINGER_MS = 320;
  function drawGuides(lines) {
    const now = performance.now();
    const canvasW = $canvas.clientWidth;
    const canvasH = $canvas.clientHeight;
    const NS = "http://www.w3.org/2000/svg";
    // Refresh / add proposed lines.
    const proposedKeys = new Set();
    for (const line of lines) {
      const key = line.axis + ":" + line.at;
      if (proposedKeys.has(key)) continue;
      proposedKeys.add(key);
      const existing = liveGuides.get(key);
      if (existing) {
        existing.lastSeen = now;
        existing.element.setAttribute("data-active", "1");
        continue;
      }
      const el = document.createElementNS(NS, "line");
      el.setAttribute("data-active", "1");
      if (line.axis === "v") {
        const cx = (line.at - bbMinX) * pxToCanvas + canvasOffset().dx;
        el.setAttribute("x1", cx); el.setAttribute("y1", 0);
        el.setAttribute("x2", cx); el.setAttribute("y2", canvasH);
      } else if (line.axis === "h") {
        const cy = (line.at - bbMinY) * pxToCanvas + canvasOffset().dy;
        el.setAttribute("x1", 0);       el.setAttribute("y1", cy);
        el.setAttribute("x2", canvasW); el.setAttribute("y2", cy);
      } else { continue; }
      $guides.appendChild(el);
      liveGuides.set(key, { element: el, lastSeen: now });
    }
    // Mark guides not proposed this frame as inactive (dimmed); expire
    // them only after the linger window — so the user can still see
    // *which* line they were aligned to, just at lower opacity.
    for (const [key, entry] of liveGuides) {
      if (proposedKeys.has(key)) continue;
      entry.element.setAttribute("data-active", "0");
      if (now - entry.lastSeen >= GUIDES_LINGER_MS) {
        entry.element.remove();
        liveGuides.delete(key);
      }
    }
  }
  /** Force-clear all guides (used by endDrag's fade timer). */
  function clearAllGuides() {
    for (const [, entry] of liveGuides) entry.element.remove();
    liveGuides.clear();
  }

  function canvasOffset() {
    const w = $canvas.clientWidth, h = $canvas.clientHeight;
    return {
      dx: (w - bbW * pxToCanvas) / 2,
      dy: (h - bbH * pxToCanvas) / 2,
    };
  }

  // ─── Zoom ──────────────────────────────────────────────────────────
  // 1% per click, accelerating while the button is held. Tick interval
  // halves every 8 ticks (down to 18ms) so a long press sweeps the
  // range; a single click is precisely +/- 1%.
  function setZoom(z) {
    state.zoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, z));
    // Don't dirty the layout frame — zoom is a pure CSS transform now.
    applyZoom();
    document.getElementById("zoom-reset").textContent =
      Math.round(state.zoom * 100) + "%";
    bridge({ type: "zoom", value: state.zoom });
  }
  function nudgeZoom(direction) {
    setZoom(state.zoom + direction * 0.01);
  }
  function attachHoldRepeat(el, direction) {
    let timer = null;
    let interval = 140;
    let ticks = 0;
    const stop = () => {
      if (timer) { clearTimeout(timer); timer = null; }
      ticks = 0; interval = 140;
    };
    const tick = () => {
      nudgeZoom(direction);
      ticks++;
      if (ticks % 8 === 0) interval = Math.max(18, interval * 0.6);
      timer = setTimeout(tick, interval);
    };
    el.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      el.setPointerCapture(e.pointerId);
      nudgeZoom(direction);                      // immediate 1% on press
      timer = setTimeout(tick, 380);             // 380ms hold → repeat
    });
    el.addEventListener("pointerup", stop);
    el.addEventListener("pointercancel", stop);
    el.addEventListener("pointerleave", stop);
  }
  attachHoldRepeat(document.getElementById("zoom-in"), +1);
  attachHoldRepeat(document.getElementById("zoom-out"), -1);
  document.getElementById("zoom-reset").addEventListener("click",
    () => setZoom(1.0));

  // Trackpad pinch (Safari sends gesturestart/change/end with .scale)
  let pinchStart = 1.0;
  $canvas.addEventListener("gesturestart", (e) => {
    e.preventDefault(); pinchStart = state.zoom;
  });
  $canvas.addEventListener("gesturechange", (e) => {
    e.preventDefault(); setZoom(pinchStart * e.scale);
  });
  $canvas.addEventListener("gestureend", (e) => e.preventDefault());

  // ⌘ +/-/0. Held key repeats at 1%/event via the OS key-repeat rate.
  document.addEventListener("keydown", (e) => {
    if (!e.metaKey) return;
    if (e.key === "=" || e.key === "+") { e.preventDefault(); nudgeZoom(+1); }
    else if (e.key === "-")              { e.preventDefault(); nudgeZoom(-1); }
    else if (e.key === "0")              { e.preventDefault(); setZoom(1.0); }
  });

  // Re-render on resize — and refit the layout frame, since a wider
  // canvas wants a different scale.
  new ResizeObserver(() => { layoutFrameDirty = true; render(); }).observe($canvas);

  // Tell Swift we're ready to receive state
  bridge({ type: "ready" });
})();
