/* global React, Icon, Screenshot */

const { useState, useRef, useEffect } = React;

/* ==========================================================
   Display Tile — handles real / virtual / PiP variants.
   Adds:
     - bottom action rail (Record, Reset, Inspect)
     - top-left detection issue chip when display is unhealthy
     - dashed border + "VIRTUAL" badge for virtual displays
     - "● REC" overlay when this tile is being recorded
========================================================== */

const DisplayTile = ({
  d, selected, dragging,
  onSelect, onDrag, canvasSize,
  primaryAction, // (display) => { primary, secondaries }
  issue,         // { kind, msg } | null
  recording,     // boolean — this display is being captured
  onRecordToggle, onReset, onInspect, onDestroy,
  isApp,         // true if this is the display the wdm app is on (record disabled)
}) => {
  const startPos = useRef(null);
  const cw = canvasSize?.w || 1000;
  const ch = canvasSize?.h || 600;
  const px = { x: d.geom.x * cw, y: d.geom.y * ch, w: d.geom.w * cw, h: d.geom.h * ch };

  const onPointerDown = (e) => {
    if (e.button !== 0) return;
    onSelect(d.id);
    startPos.current = { x: e.clientX, y: e.clientY, gx: d.geom.x, gy: d.geom.y, moved: false };
    onDrag(d.id, "start");
    const move = (ev) => {
      const dx = (ev.clientX - startPos.current.x) / cw;
      const dy = (ev.clientY - startPos.current.y) / ch;
      if (Math.abs(dx) + Math.abs(dy) > 0.005) startPos.current.moved = true;
      onDrag(d.id, "move", { x: startPos.current.gx + dx, y: startPos.current.gy + dy });
    };
    const up = () => {
      onDrag(d.id, "end", null, !startPos.current.moved);
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
  };

  const transform = d.rotation ? `rotate(${d.rotation}deg)` : "none";

  // chassis form: laptop (built-in), external monitor, airplay/sidecar (tablet/floating), virtual/pip (no chrome)
  const chassis =
    d.kind === "builtin" ? "laptop" :
    d.kind === "external" ? "monitor" :
    d.kind === "airplay" ? "tablet" :
    d.kind === "sidecar" ? "tablet" :
    "flat";

  const cls = [
    "tile",
    `tile--${chassis}`,
    selected && "is-selected",
    d.main && "is-main",
    dragging && "dragging",
    d.kind === "virtual" && "is-virtual",
    d.kind === "pip" && "is-pip",
    issue && "is-issue",
    recording && "is-recording",
  ].filter(Boolean).join(" ");

  return (
    <div className={cls} style={{ left: px.x, top: px.y, width: px.w, height: px.h }} onPointerDown={onPointerDown}>
      <div className="tile-monitor">
        {/* webcam dot for laptop / tablet / monitor */}
        {chassis !== "flat" && <div className="mon-cam" aria-hidden="true"/>}

        <div className="tile-pane">
          <div className="tile-screenshot" style={{ transform }}>
            <Screenshot kind={d.color} rotation={d.rotation}/>
          </div>

        {/* Top-right detection-issue chip — actionable, only lives here */}
        {issue && <IssueChip issue={issue} onReset={() => onReset(d.id, issue.kind)}/>}

        {/* Recording state dot — corner of monitor, not text */}
        {recording && <div className="tile-rec-dot" aria-label="Recording"/>}
        </div>

        {/* Stand / hinge — outside the screen pane so it doesn't crop screen content */}
        {chassis === "monitor" && (
          <div className="mon-stand" aria-hidden="true">
            <div className="mon-neck"/>
            <div className="mon-base"/>
          </div>
        )}
        {chassis === "laptop" && <div className="mon-hinge" aria-hidden="true"/>}
      </div>

      {/* Display name label — always visible below every tile so the
          user can identify each surface without selecting it. */}
      <div className="tile-nameplate">
        <span className="tile-num mono">0{d.id}</span>
        <span className="tile-name">{d.name}</span>
        {d.main && <span className="tile-main-tag">main</span>}
      </div>

      {/* No floating tile rail. Selection sets the right Inspector — single source of truth.
          Hover-only "drag handle" hint gives the user permission to move the tile. */}
      {selected && !dragging && (
        <div className="tile-hint" onPointerDown={(e) => e.stopPropagation()}>
          <Icon name="grid" className="ic-sm"/>
          <span>Drag to move · Inspector →</span>
        </div>
      )}
    </div>
  );
};

/* ==========================================================
   Detection-issue chip — quick "click to fix" inline.
========================================================== */

const ISSUE_LABEL = {
  "not-detected": "Not detected",
  "stale-edid":   "EDID stale",
  "wrong-aspect": "Wrong aspect",
  "frozen":       "Frozen",
};

const IssueChip = ({ issue, onReset }) => (
  <button className="tile-issue" onClick={(e) => { e.stopPropagation(); onReset(); }}
    onPointerDown={(e) => e.stopPropagation()}
    title={issue.msg}>
    <span className="issue-dot"/>
    <span>{ISSUE_LABEL[issue.kind] || "Needs attention"}</span>
    <span className="issue-cta"><Icon name="refresh" className="ic-sm"/> Fix</span>
  </button>
);

/* ==========================================================
   Tile floating actions — the contextual primary verb.
========================================================== */

const TileActions = ({ display, primaryAction }) => {
  const { primary, secondaries = [] } = primaryAction(display) || {};
  if (!primary) return null;
  return (
    <div className="tile-actions" onPointerDown={(e) => e.stopPropagation()}>
      <button className="ta-btn primary" onClick={primary.onClick}>
        <Icon name={primary.icon} className="ic-sm"/>
        {primary.label}
      </button>
      {secondaries.length > 0 && <span className="ta-sep"/>}
      {secondaries.map((s, i) => (
        <button key={i} className="ta-btn" onClick={s.onClick} title={s.tooltip || ""}>
          <Icon name={s.icon} className="ic-sm"/>
          {s.label}
        </button>
      ))}
    </div>
  );
};

Object.assign(window, { DisplayTile, TileActions, IssueChip });
