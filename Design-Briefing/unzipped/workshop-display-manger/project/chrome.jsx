/* global React, Icon, PROFILES, MODES */

const { useState, useEffect, useMemo } = React;

// ========== Header ==========
const Header = ({ profile, onProfileClick, onTheme, theme, onToggleAdvanced, advancedOpen, onWatch, watchOn, onAddVirtual }) => {
  return (
    <div className="hdr">
      <div className="brand">
        <span className="mark"/>
        <span>wdm</span>
        <span className="v">2.4</span>
      </div>
      <button className="profile-pill" onClick={onProfileClick}>
        <span className="lbl">Profile</span>
        <span className="nm">{profile.name}</span>
        <span className="chip"><span className="dot"/>APPLIED</span>
        <Icon name="chevDown" className="ic-sm"/>
      </button>
      <div className="hdr-actions">
        {onAddVirtual && (
          <button className="icon-btn" onClick={onAddVirtual} title="Add a virtual display">
            <Icon name="virtual" className="ic"/>
          </button>
        )}
        <button className={`icon-btn ${watchOn ? "is-on" : ""}`} onClick={onWatch} title="Live event log">
          <Icon name="radio" className="ic"/>
        </button>
        <button className={`icon-btn ${advancedOpen ? "is-on" : ""}`} onClick={onToggleAdvanced} title="Advanced">
          <Icon name="terminal" className="ic"/>
        </button>
        <button className="icon-btn" onClick={onTheme} title="Toggle theme">
          <Icon name="sun" className="ic"/>
        </button>
      </div>
    </div>
  );
};

// ========== Bottom dock — THE 80% ==========
const Dock = ({ primary, onSwitch, onCycle, onSave, onSleep, advancedOpen, onAdvanced, onAddVirtual }) => {
  return (
    <div className="dock">
      <button className="primary-card" onClick={primary.onClick}>
        <span className="ic-wrap"><Icon name={primary.icon} className="ic-lg"/></span>
        <span className="body">
          <div className="ttl">{primary.title}</div>
          <div className="sub">{primary.sub}</div>
        </span>
        <span className="go">
          <span className="kbd">↵</span>
        </span>
      </button>

      <div className="dock-actions">
        <button className="dock-btn" onClick={onSwitch} title="Swap main between screens">
          <Icon name="swap" className="ic"/>
          <span className="lbl">Switch</span>
        </button>
        <button className="dock-btn" onClick={onCycle} title="Cycle main forward">
          <Icon name="cycle" className="ic"/>
          <span className="lbl">Cycle</span>
        </button>
        <button className="dock-btn" onClick={onSave} title="Save current arrangement as profile">
          <Icon name="bookmark" className="ic"/>
          <span className="lbl">Save</span>
        </button>
        {onAddVirtual && (
          <button className="dock-btn" onClick={onAddVirtual} title="Add a virtual display">
            <Icon name="virtual" className="ic"/>
            <span className="lbl">+ Virtual</span>
          </button>
        )}
        <button className="dock-btn is-warn" onClick={onSleep} title="Drain AppleHPM, safe to unplug">
          <Icon name="sleep" className="ic"/>
          <span className="lbl">Sleep</span>
        </button>
      </div>

      <div className="dock-sep"/>

      <button className={`dock-advanced ${advancedOpen ? "is-on" : ""}`} onClick={onAdvanced}>
        <Icon name="terminal" className="ic-sm"/>
        Advanced
        <Icon name="chevron" className="ic-sm" style={{ transform: advancedOpen ? "rotate(180deg)" : "none", transition: "transform 200ms" }}/>
      </button>
    </div>
  );
};

// ========== Profile sheet ==========
const ProfileSheet = ({ open, onClose, current, onApply, onSaveCurrent }) => {
  if (!open) return null;
  return (
    <>
      <div className="sheet-bg" onClick={onClose}/>
      <div className="sheet">
        <div className="sheet-head">
          <div>
            <h3>Restore an arrangement</h3>
            <div className="sub">Pick a saved layout. The room will diff and ask before keeping.</div>
          </div>
          <div className="grow"/>
          <button className="btn" onClick={onSaveCurrent}><Icon name="plus" className="ic-sm"/>Save current</button>
          <button className="btn ghost" onClick={onClose}><Icon name="x" className="ic-sm"/></button>
        </div>
        <div className="sheet-grid">
          {PROFILES.map((p) => (
            <div key={p.id}
              className={`pf-card ${p.id === current ? "is-current" : ""}`}
              onClick={() => onApply(p)}
            >
              <div className="pf-mini">
                {p.minis.map((m, i) => (
                  <div key={i} className={`mini-disp ${m.main ? "main" : ""}`}
                    style={{ left: m.x, top: m.y, width: m.w, height: m.h }}/>
                ))}
              </div>
              <div>
                <div className="nm">{p.name}</div>
                <div className="det">{p.det}</div>
              </div>
              <div className="foot">
                <span className="status">{p.id === current ? "● Applied" : "○ Ready"}</span>
                <span className="hk">{p.hk}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </>
  );
};

// ========== Safe-tx (simpler, fewer words) ==========
const SafeTx = ({ tx, onKeep, onRevert }) => {
  const [t, setT] = useState(15);
  useEffect(() => {
    if (!tx) return;
    setT(15);
    const i = setInterval(() => setT((x) => Math.max(0, x - 0.1)), 100);
    return () => clearInterval(i);
  }, [tx]);
  useEffect(() => { if (t <= 0 && tx) onRevert(); }, [t]);
  useEffect(() => {
    if (!tx) return;
    const onKey = (e) => {
      if (e.code === "Space") { e.preventDefault(); onKeep(); }
      else if (e.key === "Escape") onRevert();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [tx]);
  if (!tx) return null;
  const pct = t / 15;
  const C = 2 * Math.PI * 46;
  return (
    <div className="safetx">
      <div className="safetx-card">
        <div className="ring">
          <svg width="110" height="110" viewBox="0 0 110 110">
            <circle cx="55" cy="55" r="46" fill="none" stroke="var(--hair)" strokeWidth="5"/>
            <circle cx="55" cy="55" r="46" fill="none" stroke="var(--accent)" strokeWidth="5"
              strokeDasharray={C} strokeDashoffset={C * (1 - pct)}
              strokeLinecap="round" transform="rotate(-90 55 55)"
              style={{ transition: "stroke-dashoffset 100ms linear", filter: "drop-shadow(0 0 8px var(--accent))" }}/>
          </svg>
          <div className="ring-text">
            <span className="num">{Math.ceil(t)}</span>
            <span className="lbl">Auto-revert</span>
          </div>
        </div>
        <h3>{tx.headline}</h3>
        <p>{tx.copy}</p>
        <div className="diff">
          {tx.diff.map((line, i) => (
            <div key={i} className="diff-line">
              <span className="lbl">{line.field || "diff"}</span>
              <span className="pre">{line.pre}</span>
              <span className="arrow">→</span>
              <span className="post">{line.post}</span>
            </div>
          ))}
        </div>
        <div className="safetx-actions">
          <button className="btn" onClick={onRevert}>Revert</button>
          <button className="btn primary" onClick={onKeep}>Keep · Space</button>
        </div>
      </div>
    </div>
  );
};

// ========== Advanced drawer (the 20%) ==========
const AdvancedDrawer = ({ open, onClose, display, onMutate, onPiP, onDoctor, displays, cli }) => {
  const [tab, setTab] = useState("doctor");

  if (!display) {
    return (
      <div className={`drawer ${open ? "is-open" : ""}`}>
        <div className="drawer-head">
          <div>
            <h3>Advanced</h3>
            <div className="sub">Select a display to inspect</div>
          </div>
          <button className="icon-btn" onClick={onClose}><Icon name="x" className="ic-sm"/></button>
        </div>
      </div>
    );
  }

  return (
    <div className={`drawer ${open ? "is-open" : ""}`}>
      <div className="drawer-head">
        <div>
          <h3>{display.name}</h3>
          <div className="sub mono">0{display.id} · {display.cgID} · {display.kind}</div>
        </div>
        <button className="icon-btn" onClick={onClose}><Icon name="x" className="ic-sm"/></button>
      </div>
      <div className="drawer-tabs">
        <button className={`dt-tab ${tab === "doctor" ? "is-on" : ""}`} onClick={() => setTab("doctor")}>Doctor</button>
        <button className={`dt-tab ${tab === "cli" ? "is-on" : ""}`} onClick={() => setTab("cli")}>CLI</button>
      </div>
      <div className="drawer-body">
        {tab === "doctor" && <TabDoctor display={display}/>}
        {tab === "cli" && <TabCli cli={cli} display={display}/>}
        <div className="drawer-hint mono">
          Knobs (mode, role, rotation, flip) live in the Inspector →<br/>
          This drawer is only for diagnosis & CLI.
        </div>
      </div>
    </div>
  );
};

const TabDisplay = ({ display, onMutate, onPiP }) => {
  const role = display.main ? "main" : display.mirroredFrom ? "mirror" : "extended";
  return (
    <>
      <div className="adv-section">
        <div className="adv-title">Identity</div>
        <div className="adv-row"><span className="lbl">Vendor</span><span className="val">{display.vendor.split(" ")[0]}</span></div>
        <div className="adv-row"><span className="lbl">Model</span><span className="val" style={{maxWidth:200, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap"}}>{display.model}</span></div>
        <div className="adv-row"><span className="lbl">Serial</span><span className="val">{display.serial}</span></div>
        <div className="adv-row"><span className="lbl">Alias</span><span className="val">"{display.alias}"</span></div>
      </div>

      <div className="adv-section">
        <div className="adv-title">Role</div>
        <div className="seg">
          <button className={`seg-btn ${role === "main" ? "is-on" : ""}`} onClick={() => onMutate({ kind: "main", id: display.id })}>
            <Icon name="crown" className="ic-sm"/>Main
          </button>
          <button className={`seg-btn ${role === "extended" ? "is-on" : ""}`} onClick={() => onMutate({ kind: "extend", id: display.id })}>Extend</button>
          <button className={`seg-btn ${role === "mirror" ? "is-on" : ""}`} onClick={() => onMutate({ kind: "mirror", id: display.id, src: 1 })}>
            <Icon name="chain" className="ic-sm"/>Mirror
          </button>
        </div>
      </div>

      <div className="adv-section">
        <div className="adv-title">Rotation</div>
        {display.caps.rotation === "off" ? (
          <div className="note warn">
            Rotation unsupported — {display.capReason?.rotation || "OS doesn't expose IODisplayConnect"}.
          </div>
        ) : (
          <div className="seg">
            {[0, 90, 180, 270].map((deg) => (
              <button key={deg} className={`seg-btn ${display.rotation === deg ? "is-on" : ""}`}
                onClick={() => onMutate({ kind: "rotate", id: display.id, deg })}>{deg}°</button>
            ))}
          </div>
        )}
      </div>

      <div className="adv-section">
        <div className="adv-title">Flip</div>
        {display.caps.flip === "off" ? (
          <>
            <div className="note warn" style={{marginBottom: 8}}>
              IOKit flip unsupported on {display.kind} — software overlay only.
            </div>
            <button className="btn block" onClick={() => onMutate({ kind: "flip-overlay", id: display.id, axis: "horizontal" })}>
              <Icon name="flip" className="ic-sm"/> Use Flip Overlay
            </button>
          </>
        ) : (
          <div className="seg">
            {["none", "h", "v", "hv"].map((ax) => (
              <button key={ax} className={`seg-btn ${display.flip === ax ? "is-on" : ""}`}
                onClick={() => onMutate({ kind: "flip", id: display.id, axis: ax })}>
                {ax === "none" ? "None" : ax.toUpperCase()}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="adv-section">
        <div className="adv-title">Brightness</div>
        {display.caps.brightness === "ok" ? (
          <div className="adv-row">
            <span className="lbl">Level</span>
            <span className="val">{Math.round(display.brightness * 100)}%</span>
          </div>
        ) : (
          <div className="note">Use the monitor's OSD — macOS doesn't expose DDC/CI brightness for {display.kind}.</div>
        )}
      </div>

      <div className="adv-section">
        <div className="adv-title">Picture-in-picture</div>
        <button className="btn block" onClick={() => onPiP(display.id)}>
          <Icon name="pip" className="ic-sm"/> Mirror this in a PiP window
        </button>
      </div>
    </>
  );
};

const TabModes = ({ display, onMutate }) => {
  const modes = MODES[display.id] || [];
  return (
    <div className="adv-section">
      <div className="adv-title">Available modes</div>
      <div className="mode-list">
        {modes.map((m, i) => (
          <div key={i}
            className={`mode-row ${m.current ? "is-on" : ""} ${!m.supported ? "is-off" : ""}`}
            onClick={() => m.supported && onMutate({ kind: "mode", id: display.id, mode: `${m.wxh}@${m.hz}` })}
            title={!m.supported ? m.reason : ""}
          >
            <span>{m.wxh}@{m.hz}{m.scale > 1 ? ` · @${m.scale}x` : ""}</span>
            {m.current ? <Icon name="check" className="ic-sm"/> :
              !m.supported ? <span className="reason">unsupported</span> : null}
          </div>
        ))}
      </div>
      <div className="note" style={{marginTop: 10}}>
        Unsupported rows show <em>why</em> — usually EDID-reported pixel-clock or AirPlay/Sidecar virtual caps.
      </div>
    </div>
  );
};

const DOCTOR_ROWS = (d) => [
  { field: "main", req: d.main ? "true" : "false", got: d.main ? "true" : "false", level: "green" },
  { field: "mode", req: `${d.res[0]}x${d.res[1]}@${d.refresh}`, got: `${d.res[0]}x${d.res[1]}@${d.refresh}`, level: "green" },
  { field: "rotation", req: `${d.rotation}°`, got: d.caps.rotation === "off" ? "n/a" : `${d.rotation}°`, level: d.caps.rotation === "off" ? "amber" : "green" },
  { field: "flip", req: d.flip, got: d.caps.flip === "off" ? "overlay" : d.flip, level: d.caps.flip === "off" ? "amber" : "green" },
  { field: "brightness", req: d.brightness != null ? d.brightness.toFixed(2) : "n/a", got: d.caps.brightness === "off" ? "no DDC/CI" : d.brightness.toFixed(2), level: d.caps.brightness === "off" ? "amber" : "green" },
  { field: "mirror", req: d.mirroredFrom ?? "—", got: d.mirroredFrom ?? "—", level: "green" },
  { field: "hdr", req: d.hdr ? "on" : "off", got: d.hdr ? "on" : "off", level: "green" },
];

const TabDoctor = ({ display }) => {
  const rows = DOCTOR_ROWS(display);
  return (
    <div className="adv-section">
      <div className="adv-title">Doctor probe</div>
      <div className="doc">
        {rows.map((r, i) => (
          <div key={i} className={`doc-row ${r.level}`}>
            <span className="field">{r.field}</span>
            <span className="got">→ {r.got}</span>
            <span className="dot"/>
          </div>
        ))}
      </div>
      <div className="note" style={{marginTop: 10}}>
        Amber = OS doesn't support this knob. Red = the OS returned a different value than wdm requested (an actual bug).
      </div>
    </div>
  );
};

const TabCli = ({ cli, display }) => {
  return (
    <>
      <div className="adv-section">
        <div className="adv-title">Last action — CLI equivalent</div>
        <div className="cli">
          <span className="pr">$</span>
          <span className="cmd">wdm</span>
          <span>{cli.args.join(" ")}</span>
          {cli.flags.map((f, i) => <span key={i} className="fl">{f}</span>)}
          <span className="copy" title="Copy"><Icon name="copy" className="ic-sm"/></span>
        </div>
      </div>
      <div className="adv-section">
        <div className="adv-title">Aliases for scripts</div>
        <div className="cli">
          <span className="pr">$</span>
          <span className="cmd">wdm</span>
          <span>main</span>
          <span className="fl">"{display.alias}"</span>
        </div>
        <div className="cli" style={{marginTop: 8}}>
          <span className="pr">$</span>
          <span className="cmd">wdm</span>
          <span>doctor probe</span>
          <span className="fl">"{display.alias}"</span>
          <span className="fl">--json</span>
        </div>
      </div>
    </>
  );
};

// ========== Watch rail card ==========
const WatchCard = ({ events }) => {
  return (
    <div className="rail-card">
      <div className="rail-head">
        <span style={{ width: 6, height: 6, borderRadius: 999, background: "var(--accent)", boxShadow: "0 0 6px var(--accent)" }}/>
        wdm watch
      </div>
      <div className="watch-list">
        {events.slice(0, 6).map((e, i) => (
          <div key={i} className="we">
            <span className="ts">{e.ts}</span>
            <span className={`k ${e.kind}`}>{e.kind}</span>
            <span style={{overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap"}}>{e.detail}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

// ========== Toast ==========
const Toast = ({ toast }) => {
  if (!toast) return null;
  return (
    <div className="rail-card" style={{ position: "absolute", left: 28, bottom: 130, width: 320, zIndex: 26 }}>
      <div className="rail-head"><Icon name={toast.icon || "info"} className="ic-sm"/>Status</div>
      <div className="ttl">{toast.title}</div>
      <div className="sub">{toast.sub}</div>
      {toast.actions && (
        <div className="rail-actions">
          {toast.actions.map((a, i) => (
            <button key={i} className={`btn sm ${a.primary ? "primary" : ""}`} onClick={a.onClick}>{a.label}</button>
          ))}
        </div>
      )}
    </div>
  );
};

/* ==========================================================
   Reset / reconnect sheet — three escalating levels.
   Solves "didn't detect" / "wrong ratio" / "frozen" without
   resetting EVERYTHING.
========================================================== */

const ResetSheet = ({ open, display, onClose, onApply }) => {
  if (!open || !display) return null;

  const levels = [
    {
      id: "soft",
      label: "Soft refresh",
      sub: "Re-read EDID and redrive the framebuffer. Other displays stay frozen-stable.",
      detail: "CGSConfigureDisplayMode + CGRestorePermanentDisplayConfiguration on this display only.",
      time: "~0.4s",
      risk: "low",
    },
    {
      id: "force-edid",
      label: "Force-detect (re-handshake)",
      sub: "Re-pull EDID over DDC. Fixes wrong aspect / stale resolution after KVM or projector swap.",
      detail: "ioctl(IODisplayConnect, force_detect=1). Display flickers once. Other displays untouched.",
      time: "~1.2s",
      risk: "low",
    },
    {
      id: "force-aspect",
      label: "Override aspect ratio",
      sub: "Pin a specific aspect when EDID lies — e.g. 16:10 panel reporting 16:9.",
      detail: "Sets DisplayProductOverride.plist; no driver reset. Persistent until you remove it.",
      time: "instant",
      risk: "low",
    },
    {
      id: "hpm-cycle",
      label: "Bus cycle (last resort)",
      sub: "AppleHPM port-power cycle. Use when the display is plugged in but completely invisible.",
      detail: "Drains AppleHPM, waits 600ms, re-enumerates. ONLY this port — Thunderbolt sibling stays up.",
      time: "~2.5s",
      risk: "med",
    },
  ];

  return (
    <>
      <div className="sheet-bg" onClick={onClose}/>
      <div className="sheet" style={{ width: 620 }}>
        <div className="sheet-head">
          <div>
            <h3>Reset {display.name}</h3>
            <div className="sub">Other displays stay running. We never reset the whole arrangement.</div>
          </div>
          <div className="grow"/>
          <button className="btn ghost" onClick={onClose}><Icon name="x" className="ic-sm"/></button>
        </div>
        <div style={{ padding: "16px 24px 22px", display: "flex", flexDirection: "column", gap: 10 }}>
          {levels.map((lv) => (
            <button key={lv.id} className="reset-card" onClick={() => onApply(display.id, lv.id)}>
              <div className="rc-head">
                <Icon name={lv.id === "force-edid" ? "detect" : lv.id === "force-aspect" ? "aspect" : lv.id === "hpm-cycle" ? "plug" : "refresh"} className="ic"/>
                <div className="rc-title">{lv.label}</div>
                <div className={`rc-risk risk-${lv.risk}`}>{lv.risk === "low" ? "low risk" : "use carefully"}</div>
                <div className="rc-time mono">{lv.time}</div>
              </div>
              <div className="rc-sub">{lv.sub}</div>
              <div className="rc-detail mono">{lv.detail}</div>
            </button>
          ))}
        </div>
      </div>
    </>
  );
};

/* ==========================================================
   Virtual-display creator
========================================================== */

const VIRTUAL_PRESETS = [
  { id: "rec-1080", name: "Recording — 1080p", res: [1920, 1080], hz: 60, why: "Standard YouTube/Loom output" },
  { id: "rec-4k",   name: "Recording — 4K",     res: [3840, 2160], hz: 60, why: "High-res screencaps" },
  { id: "ipad-mir", name: "iPad mirror canvas", res: [2388, 1668], hz: 60, why: "AirPlay-ready aspect" },
  { id: "headless", name: "Headless 1440p",     res: [2560, 1440], hz: 60, why: "Background CI / off-screen rendering" },
];

const VirtualSheet = ({ open, onClose, onCreate }) => {
  if (!open) return null;
  return (
    <>
      <div className="sheet-bg" onClick={onClose}/>
      <div className="sheet" style={{ width: 620 }}>
        <div className="sheet-head">
          <div>
            <h3>Add a virtual display</h3>
            <div className="sub">A headless framebuffer macOS treats as a real display. Pick a preset.</div>
          </div>
          <div className="grow"/>
          <button className="btn ghost" onClick={onClose}><Icon name="x" className="ic-sm"/></button>
        </div>
        <div style={{ padding: "16px 24px 22px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {VIRTUAL_PRESETS.map((p) => (
            <button key={p.id} className="virt-card" onClick={() => onCreate(p)}>
              <div className="vc-head">
                <Icon name="virtual" className="ic"/>
                <div className="vc-title">{p.name}</div>
              </div>
              <div className="vc-res mono">{p.res[0]}×{p.res[1]} · {p.hz}Hz</div>
              <div className="vc-why">{p.why}</div>
            </button>
          ))}
        </div>
        <div style={{ padding: "0 24px 22px", fontSize: 11, color: "var(--fg-3)", lineHeight: 1.5 }}>
          Backed by CoreDisplayKit. Apps see them like any monitor — drag windows in, record them, mirror them, destroy them. The wdm app's own display can't be recorded (would recurse).
        </div>
      </div>
    </>
  );
};

/* ==========================================================
   Recording bar — global, shows active recordings
========================================================== */

const RecordingBar = ({ recordings, onStop, onPause, onPipShow }) => {
  if (!recordings.length) return null;
  return (
    <div className="rec-bar">
      <div className="rec-bar-head">
        <span className="rec-dot"/>
        <span>Recording</span>
        <span className="rec-count">{recordings.length}</span>
      </div>
      {recordings.map((r) => (
        <div key={r.id} className="rec-row">
          <div className="rec-name">{r.name}</div>
          <div className="rec-time mono">{r.time}</div>
          <div className="rec-actions">
            <button className="icon-btn-sm" onClick={() => onPipShow(r.sourceId)} title="Show as PiP">
              <Icon name="pip" className="ic-sm"/>
            </button>
            <button className="icon-btn-sm" onClick={() => onPause(r.id)} title="Pause">
              <Icon name="pause" className="ic-sm"/>
            </button>
            <button className="icon-btn-sm danger" onClick={() => onStop(r.id)} title="Stop & save">
              <Icon name="stop" className="ic-sm"/>
            </button>
          </div>
        </div>
      ))}
    </div>
  );
};

Object.assign(window, { Header, Dock, ProfileSheet, SafeTx, AdvancedDrawer, WatchCard, Toast, DOCTOR_ROWS, ResetSheet, VirtualSheet, VIRTUAL_PRESETS, RecordingBar });
