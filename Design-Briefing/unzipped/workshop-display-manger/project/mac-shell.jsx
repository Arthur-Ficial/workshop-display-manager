/* global React, Icon */

const { useState, useEffect } = React;

/* ==========================================================
   macOS-style chrome — ONE titlebar, ONE sidebar (Connected +
   Saved), ONE inspector, ONE status bar.

   DRY rules enforced here:
     - Profile lives in sidebar only (no segment, no sheet).
     - No view-mode tabs. The canvas IS the app.
     - Recordings show as a row in the inspector + a strip
       overlay when active. No "Recordings" tab.
========================================================== */

/* ---------- Titlebar ---------- */
const Titlebar = ({ title, count, theme, onTheme, onAddVirtual, onSearch }) => {
  return (
    <div className="mac-titlebar">
      <div className="mac-traffic">
        <span className="tl tl-close"><svg viewBox="0 0 12 12" fill="none"><path d="M3.5 3.5 L8.5 8.5 M8.5 3.5 L3.5 8.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg></span>
        <span className="tl tl-min"><svg viewBox="0 0 12 12" fill="none"><path d="M3 6 H9" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg></span>
        <span className="tl tl-max"><svg viewBox="0 0 12 12" fill="none"><path d="M3.5 7 V3.5 H7 M9 6 V9 H6" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" fill="none"/></svg></span>
      </div>

      <div className="mac-title-center">
        <div className="mac-title">{title}</div>
        <div className="mac-sub">{count} surfaces</div>
      </div>

      <div className="mac-tb-actions">
        <button className="mac-tb-btn" onClick={onSearch} title="Quick action (⌘K)">
          <Icon name="snap" className="ic-sm"/>
        </button>
        <button className="mac-tb-btn" onClick={onTheme} title="Toggle appearance">
          <Icon name="sun" className="ic-sm"/>
        </button>
      </div>
    </div>
  );
};

/* ---------- Sidebar ----------
   Single source of truth for "what is connected" and
   "what arrangements are saved".

   Sections:
     - Connected   (built-ins, externals, airplay, sidecar, virtual, PiP)
     - Saved       (profiles — click row to restore)
*/
const Sidebar = ({ displays, virtuals, pips, recordings, profiles,
                   selectedId, onSelect, onAddVirtual, onApplyProfile,
                   onSaveCurrent, onDestroy, issues, currentProfileId }) => {
  // Unified connected list — flat, no duplicate sections.
  const connected = [
    ...displays.map(d => ({ ...d, _grp: "real" })),
    ...virtuals.map(d => ({ ...d, _grp: "virt" })),
    ...pips.map(d => ({ ...d, _grp: "pip" })),
  ];

  return (
    <div className="mac-sidebar">
      <SbSection title="Connected" badge={connected.length}>
        {connected.map(d => {
          const recording = !!recordings.find(r => r.sourceId === d.id);
          return (
            <SbRow key={`${d._grp}-${d.id}`}
              icon={d._grp === "virt" ? "virtual"
                : d._grp === "pip" ? "pip"
                : d.kind === "builtin" ? "builtin"
                : d.kind === "external" ? "external"
                : d.kind === "airplay" ? "airplay" : "sidecar"}
              label={d.name}
              hint={d._grp === "virt" ? "Virtual" : d._grp === "pip" ? "PiP" : (d.mirroredFrom ? `mirror of 0${d.mirroredFrom}` : null)}
              selected={selectedId === d.id}
              onClick={() => onSelect(d.id)}
              issue={issues[d.id]}
              recording={recording}
              onTrash={d._grp !== "real" ? () => onDestroy(d.id) : null}
              main={d.main}
            />
          );
        })}
        <button className="sb-cta" onClick={onAddVirtual}>
          <Icon name="plus" className="ic-sm"/>
          <span>Add virtual display</span>
        </button>
      </SbSection>

      <SbSection title="Saved arrangements" badge={profiles.length}
        action={{ icon: "plus", onClick: onSaveCurrent, tip: "Save current as profile" }}>
        {profiles.map(p => (
          <SbRow key={p.id} icon="bookmark" label={p.name}
            hint={p.id === currentProfileId ? "Applied" : null}
            selected={p.id === currentProfileId}
            onClick={() => onApplyProfile(p)}
            kbd={p.hk}
          />
        ))}
      </SbSection>
    </div>
  );
};

/* ---------- Mirror picker ----------
   Source on top (radio), targets below (multi-checkbox).
   Don't-make-me-think: source defaults to current main; targets
   default to "everything else"; one Apply button.
*/
/* ---------- Mirror targets picker ----------
   Source is implied (= currently-selected display). User just
   picks the targets and applies. Lives inside the Inspector.
*/
const MirrorTargets = ({ source, displays, excludeIds = [], onApply, onCancel }) => {
  const candidates = displays.filter(d => d.id !== source.id && !excludeIds.includes(d.id) && d.mirroredFrom == null);
  const [targets, setTargets] = useState(() => candidates.map(d => d.id));

  const toggle = (id) => setTargets(t => t.includes(id) ? t.filter(x => x !== id) : [...t, id]);

  if (candidates.length === 0) {
    return (
      <div className="mirror-picker">
        <div className="mp-empty">No other displays available to mirror to.</div>
        <div className="mp-actions">
          <button className="mp-btn ghost" onClick={onCancel}>Close</button>
        </div>
      </div>
    );
  }

  return (
    <div className="mirror-picker">
      <div className="mp-row">
        <div className="mp-label">Mirror <strong>{source.name}</strong> to</div>
        <div className="mp-targets">
          {candidates.map(d => {
            const on = targets.includes(d.id);
            return (
              <button key={d.id}
                className={`mp-target ${on ? "is-on" : ""}`}
                onClick={() => toggle(d.id)}>
                <span className={`mp-check ${on ? "is-on" : ""}`}>
                  {on && <Icon name="check" className="ic-sm"/>}
                </span>
                <span className="mp-name">{d.name}</span>
                <span className="mp-kind">{d.kind}</span>
              </button>
            );
          })}
        </div>
      </div>
      <div className="mp-actions">
        <button className="mp-btn ghost" onClick={onCancel}>Cancel</button>
        <button className="mp-btn primary"
          disabled={targets.length === 0}
          onClick={() => onApply(targets)}>
          {targets.length === 0 ? "Pick targets" : `Mirror to ${targets.length} ${targets.length === 1 ? "display" : "displays"}`}
        </button>
      </div>
    </div>
  );
};

const SbSection = ({ title, badge, action, children }) => (
  <div className="sb-section">
    <div className="sb-title">
      <span>{title}</span>
      {typeof badge === "number" && <span className="sb-badge">{badge}</span>}
      <div className="grow"/>
      {action && (
        <button className="sb-action" onClick={action.onClick} title={action.tip}>
          <Icon name={action.icon} className="ic-sm"/>
        </button>
      )}
    </div>
    <div className="sb-body">{children}</div>
  </div>
);

const SbRow = ({ icon, label, hint, selected, onClick, issue, recording, onTrash, main, kbd }) => (
  <div className={`sb-row ${selected ? "is-on" : ""} ${recording ? "is-rec" : ""}`} onClick={onClick}>
    <Icon name={icon} className="ic-sm"/>
    <div className="sb-label">
      {label}
      {main && <span className="sb-main-tag">main</span>}
      {hint && <span className="sb-hint">{hint}</span>}
    </div>
    {kbd && <span className="sb-kbd mono">{kbd}</span>}
    {issue && <span className="sb-issue" title={issue.msg}/>}
    {recording && <span className="sb-rec-dot"/>}
    {onTrash && (
      <button className="sb-trash" onClick={(e) => { e.stopPropagation(); onTrash(); }} title="Destroy">
        <Icon name="x" className="ic-sm"/>
      </button>
    )}
  </div>
);

/* ---------- Mode dropdown ---------- */
const ModeSelect = ({ open, onToggle, current, modes, onPick, scale }) => {
  return (
    <div className={`mode-select ${open ? "is-open" : ""}`}>
      <button className="mode-trigger mono" onClick={onToggle}>
        <span className="mode-current">
          {current ? `${current.wxh.replace("x", "×")} · ${current.hz}Hz` : "—"}
        </span>
        <span className="mode-scale">@{scale}x</span>
        <Icon name="chevDown" className="ic-sm"/>
      </button>
      {open && (
        <>
          <div className="mode-backdrop" onClick={onToggle}/>
          <div className="mode-menu">
            <div className="mode-menu-head">RESOLUTION · REFRESH</div>
            {modes.map((m, i) => (
              <button key={i} disabled={!m.supported}
                className={`mode-item ${m.current ? "is-current" : ""} ${!m.supported ? "is-unsupported" : ""}`}
                onClick={() => m.supported && onPick(m)}
                title={!m.supported ? m.reason : ""}>
                <span className="mode-check">{m.current && <Icon name="check" className="ic-sm"/>}</span>
                <span className="mode-res mono">{m.wxh.replace("x", "×")}</span>
                <span className="mode-hz mono">{m.hz}Hz</span>
                <span className="mode-aspect">{m.aspect}</span>
                {!m.supported && <span className="mode-warn" title={m.reason}>!</span>}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
};

/* ---------- Inspector ---------- */
const Inspector = ({ display, displays, recordings, onMutate, onPiP, onRecord, onReset, onInspect, isApp, onMirror, onUnmirror, onRename }) => {
  const [modeOpen, setModeOpen] = useState(false);
  const [mirrorOpen, setMirrorOpen] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const [draftName, setDraftName] = useState("");
  useEffect(() => { setModeOpen(false); setMirrorOpen(false); setRenaming(false); }, [display?.id]);

  if (!display) return (
    <div className="mac-inspector empty">
      <Icon name="eye" className="ic-lg"/>
      <div className="ttl">No selection</div>
      <div className="sub">Click a display in the sidebar or canvas to inspect.</div>
    </div>
  );

  const recording = recordings.find(r => r.sourceId === display.id);
  const isVirt = display.kind === "virtual";
  const isPip = display.kind === "pip";

  const modes = (window.MODES && window.MODES[display.id]) || [];
  const currentMode = modes.find(m => m.current) || modes[0];

  return (
    <div className="mac-inspector">
      <div className="ins-head">
        <div className="ins-eyebrow">
          {isPip ? "PIP WINDOW"
            : isVirt ? "VIRTUAL DISPLAY"
            : display.kind === "builtin" ? "BUILT-IN"
            : display.kind === "airplay" ? "AIRPLAY"
            : display.kind === "sidecar" ? "SIDECAR"
            : "EXTERNAL DISPLAY"}
        </div>
        {renaming ? (
          <input
            className="ins-name-input"
            autoFocus
            value={draftName}
            onChange={(e) => setDraftName(e.target.value)}
            onBlur={() => {
              const n = draftName.trim();
              if (n && n !== display.name) onRename(display.id, n);
              setRenaming(false);
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") { e.target.blur(); }
              if (e.key === "Escape") { setRenaming(false); }
            }}
          />
        ) : (
          <button
            className="ins-name"
            onClick={() => { setDraftName(display.name); setRenaming(true); }}
            title="Click to rename">
            <span>{display.name}</span>
            <Icon name="pen" className="ic-sm ins-name-edit"/>
          </button>
        )}
        <div className="ins-tags">
          {display.main && <span className="tag t-ok"><Icon name="crown" className="ic-sm"/>Main</span>}
          {display.mirroredFrom && <span className="tag t-info">Mirror of 0{display.mirroredFrom}</span>}
          {recording && <span className="tag t-rec"><span className="rec-dot"/>REC {recording.time}</span>}
          {isVirt && <span className="tag t-info">Headless</span>}
          {display.hdr && <span className="tag">HDR</span>}
        </div>
      </div>

      <div className="ins-section">
        <div className="ins-label">Mode</div>
        {modes.length > 1 ? (
          <ModeSelect
            open={modeOpen}
            onToggle={() => setModeOpen(o => !o)}
            current={currentMode}
            modes={modes}
            onPick={(m) => { setModeOpen(false); onMutate({ kind: "mode", id: display.id, mode: `${m.wxh}@${m.hz}` }); }}
            scale={display.scale}
          />
        ) : (
          <div className="ins-value mono">{display.res[0]}×{display.res[1]} · {display.refresh}Hz · @{display.scale}x</div>
        )}
      </div>

      {!isPip && (
        <div className="ins-section">
          <div className="ins-label">Geometry</div>
          <div className="ins-controls">
            <div className="ins-pill-grp" role="radiogroup">
              {[0, 90, 180, 270].map(deg => (
                <button key={deg} role="radio" aria-checked={display.rotation === deg}
                  className={`ins-pill ${display.rotation === deg ? "is-on" : ""}`}
                  onClick={() => onMutate({ kind: "rotate", id: display.id, deg })}>
                  {deg}°
                </button>
              ))}
            </div>
            <div className="ins-pill-grp">
              {[
                { k: "none", l: "—" },
                { k: "h", l: "Flip H" },
                { k: "v", l: "Flip V" },
              ].map(o => (
                <button key={o.k}
                  className={`ins-pill ${display.flip === o.k ? "is-on" : ""}`}
                  onClick={() => onMutate({ kind: "flip", id: display.id, axis: o.k })}>
                  {o.l}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Mirror state for THIS display */}
      {(() => {
        if (isPip) return null;
        const mirroringTargets = (displays || []).filter(d => d.mirroredFrom === display.id);
        const mirroredFrom = display.mirroredFrom
          ? (displays || []).find(d => d.id === display.mirroredFrom) : null;
        return (
          <div className="ins-section">
            <div className="ins-label">Mirror</div>
            {mirroredFrom && (
              <div className="ins-mirror-state">
                <Icon name="chain" className="ic-sm"/>
                <span>Mirroring <strong>{mirroredFrom.name}</strong></span>
                <button className="ins-link" onClick={() => onUnmirror(display.id)}>Stop</button>
              </div>
            )}
            {mirroringTargets.length > 0 && (
              <div className="ins-mirror-state">
                <Icon name="chain" className="ic-sm"/>
                <span>Source for {mirroringTargets.length} display{mirroringTargets.length === 1 ? "" : "s"}</span>
                <button className="ins-link" onClick={() => mirroringTargets.forEach(t => onUnmirror(t.id))}>Stop all</button>
              </div>
            )}
            {!mirroredFrom && (
              <button className={`ins-action ${mirrorOpen ? "is-on" : ""}`} onClick={() => setMirrorOpen(o => !o)}>
                <Icon name="chain" className="ic-sm"/>
                <span>{mirroringTargets.length > 0 ? "Mirror to more…" : "Mirror this display to…"}</span>
                <Icon name="chevDown" className="ic-sm" style={{ marginLeft: "auto", transform: mirrorOpen ? "rotate(180deg)" : "none", transition: "transform 160ms" }}/>
              </button>
            )}
            {mirrorOpen && !mirroredFrom && (
              <MirrorTargets
                source={display}
                displays={displays}
                excludeIds={mirroringTargets.map(t => t.id)}
                onApply={(targetIds) => { setMirrorOpen(false); onMirror(display.id, targetIds); }}
                onCancel={() => setMirrorOpen(false)}
              />
            )}
          </div>
        );
      })()}

      <div className="ins-section">
        <div className="ins-label">Actions</div>
        <div className="ins-actions">
          {!display.main && !isPip && (
            <button className="ins-action primary" onClick={() => onMutate({ kind: "main", id: display.id })}>
              <Icon name="crown" className="ic-sm"/><span>Make main</span>
            </button>
          )}
          <button className="ins-action" onClick={() => onPiP(display.id)} disabled={isPip}>
            <Icon name="pip" className="ic-sm"/><span>Open PiP window</span>
          </button>
          <button
            className={`ins-action ${recording ? "is-rec" : ""}`}
            onClick={() => onRecord(display.id)}
            disabled={isApp}
            title={isApp ? "Can't record the display wdm runs on (recursive)" : ""}>
            <Icon name={recording ? "stop" : "record"} className="ic-sm"/>
            <span>{recording ? "Stop recording" : "Record"}</span>
          </button>
          <button className="ins-action" onClick={() => onReset(display.id)}>
            <Icon name="refresh" className="ic-sm"/><span>Reset / reconnect…</span>
          </button>
          <button className="ins-action" onClick={() => onInspect(display.id)}>
            <Icon name="terminal" className="ic-sm"/><span>Open Advanced</span>
          </button>
        </div>
      </div>

      <div className="ins-section">
        <div className="ins-label">Identity</div>
        <div className="ins-kv mono">
          <span>vendor</span><span>{display.vendor}</span>
          <span>model</span><span>{display.model}</span>
          <span>serial</span><span>{display.serial}</span>
          <span>cgID</span><span>{display.cgID}</span>
          <span>alias</span><span className="alias">{display.alias}</span>
        </div>
      </div>
    </div>
  );
};

/* ---------- Status bar ----------
   Shows ambient state: daemon, current profile, last event,
   plus the Watch / Advanced toggles. Single source for "what's
   happening right now".
*/
const StatusBar = ({ counts, recordings, watchOn, onWatch, advancedOpen, onAdvanced, lastEvent, profileName }) => {
  return (
    <div className="mac-statusbar">
      <span className="sbar-pill"><span className="dot ok"/>Daemon · 2.4.1</span>
      <span className="sbar-pill"><Icon name="bookmark" className="ic-sm"/>{profileName}</span>
      <span className="sbar-pill mono">{counts.real} real · {counts.virtual} virt · {counts.pip} pip</span>
      {recordings.length > 0 && (
        <span className="sbar-pill rec">
          <span className="dot rec-dot"/>REC × {recordings.length}
        </span>
      )}
      <div className="sbar-grow"/>
      {lastEvent && (
        <span className="sbar-event mono">
          <span className="ts">{lastEvent.ts}</span>
          <span>{lastEvent.detail}</span>
        </span>
      )}
      <button className={`sbar-tgl ${watchOn ? "is-on" : ""}`} onClick={onWatch} title="Live event log">
        <Icon name="radio" className="ic-sm"/>Watch
      </button>
      <button className={`sbar-tgl ${advancedOpen ? "is-on" : ""}`} onClick={onAdvanced} title="Advanced">
        <Icon name="terminal" className="ic-sm"/>Advanced
      </button>
    </div>
  );
};

Object.assign(window, { Titlebar, Sidebar, Inspector, StatusBar });
