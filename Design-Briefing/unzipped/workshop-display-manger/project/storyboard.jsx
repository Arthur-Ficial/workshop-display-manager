/* global React, Icon */

const Storyboard = ({ onExit }) => {
  const frames = [
    {
      step: "T+0s",
      ttl: "Cable plugged in",
      desc: "wdm daemon detects HDMI hot-plug. Native banner appears top-right.",
      render: () => (
        <>
          <Mini d={{ x: 30, y: 80, w: 90, h: 60 }} main/>
          <Mini d={{ x: 140, y: 50, w: 130, h: 80 }} fresh/>
          <Pulse x={205} y={90}/>
        </>
      ),
    },
    {
      step: "T+1s",
      ttl: "Banner: Set as main?",
      desc: "wdm offers the obvious next move. One click — no dialog cascade.",
      render: () => (
        <>
          <Mini d={{ x: 30, y: 80, w: 90, h: 60 }} main/>
          <Mini d={{ x: 140, y: 50, w: 130, h: 80 }}/>
          <FrameToast/>
        </>
      ),
    },
    {
      step: "T+12s",
      ttl: "Safe-tx countdown",
      desc: "Auto-revert ring at 15s. SPACE keeps. Anything else reverts.",
      render: () => (
        <>
          <Mini d={{ x: 30, y: 80, w: 90, h: 60 }}/>
          <Mini d={{ x: 140, y: 50, w: 130, h: 80 }} main/>
          <Ring/>
        </>
      ),
    },
    {
      step: "T+27s",
      ttl: "Applied — slides land",
      desc: "Audience sees the deck. Profile auto-saved as 'acme-room'.",
      render: () => (
        <>
          <Mini d={{ x: 30, y: 80, w: 90, h: 60 }}/>
          <Mini d={{ x: 140, y: 50, w: 130, h: 80 }} main slides/>
          <FrameDone/>
        </>
      ),
    },
  ];

  return (
    <div style={S.wrap}>
      <div style={S.toolbar}>
        <button style={S.closeBtn} onClick={onExit}>
          <Icon name="x" className="ic-sm"/>
          <span>Back to Stage</span>
        </button>
        <div style={S.title}>
          <div style={S.eyebrow}>60-SECOND WALKTHROUGH · 4 FRAMES</div>
          <h1 style={S.h1}>Cable plugged in → audience sees slides</h1>
          <p style={S.lead}>
            No wizard. No onboarding modal. The fastest path from "the projector is plugged in"
            to "I am presenting" — with the safety net visible the whole way.
          </p>
        </div>
      </div>

      <div style={S.frames}>
        {frames.map((f, i) => (
          <div key={i} style={S.frame}>
            <div style={S.stepRow}>
              <span style={S.stepNum}>{String(i + 1).padStart(2, "0")}</span>
              <span style={S.stepTime}>{f.step}</span>
            </div>
            <div style={S.stage}>{f.render()}</div>
            <div style={S.ttl}>{f.ttl}</div>
            <div style={S.desc}>{f.desc}</div>
          </div>
        ))}
      </div>

      <div style={S.cliBlock}>
        <div style={S.cliHead}>EQUIVALENT CLI · WHAT THE GUI ACTUALLY RAN</div>
        <div style={S.cliBody}>
          <div style={S.cliLine}>
            <span style={S.cliPr}>$</span>
            <span> wdm watch </span>
            <span style={S.cliFlag}>--json</span>
            <span style={S.cliCmt}>  # daemon already running</span>
          </div>
          <div style={S.cliLine}>
            <span style={S.cliPr}>$</span>
            <span> wdm switch </span>
            <span style={S.cliFlag}>--confirm</span>
            <span style={S.cliCmt}>  # main → 0x4280003E (ACME 4K)</span>
          </div>
          <div style={S.cliLine}>
            <span style={S.cliOk}>✓ kept</span>
            <span style={S.cliCmt}>   last.json snapshotted at /Users/franz/.config/wdm/profiles/last.json</span>
          </div>
          <div style={S.cliLine}>
            <span style={S.cliPr}>$</span>
            <span> wdm save acme-room  </span>
            <span style={S.cliCmt}># auto-saved by GUI</span>
          </div>
        </div>
      </div>
    </div>
  );
};

const S = {
  wrap: {
    position: "absolute", inset: 0, zIndex: 40,
    background: "var(--bg)",
    overflowY: "auto",
    padding: "32px 48px 60px",
  },
  toolbar: {
    display: "flex", alignItems: "flex-start", gap: 24,
    marginBottom: 32, maxWidth: 1200, margin: "0 auto 32px",
  },
  closeBtn: {
    display: "inline-flex", alignItems: "center", gap: 8,
    height: 32, padding: "0 12px",
    borderRadius: 8,
    background: "var(--surf)",
    border: "1px solid var(--hair)",
    color: "var(--fg-2)",
    fontSize: 12, fontWeight: 500,
    flexShrink: 0,
  },
  title: { flex: 1, minWidth: 0 },
  eyebrow: {
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: 10.5, letterSpacing: "0.14em",
    color: "var(--fg-4)", marginBottom: 8,
  },
  h1: {
    margin: 0, fontSize: 28, fontWeight: 700,
    letterSpacing: "-0.02em", lineHeight: 1.15,
  },
  lead: {
    margin: "10px 0 0",
    fontSize: 13.5, lineHeight: 1.55,
    color: "var(--fg-3)", maxWidth: 720,
  },
  frames: {
    display: "grid",
    gridTemplateColumns: "repeat(4, 1fr)",
    gap: 16,
    maxWidth: 1200, margin: "0 auto 32px",
  },
  frame: {
    display: "flex", flexDirection: "column", gap: 10,
    padding: 16,
    borderRadius: 14,
    background: "var(--surf)",
    border: "1px solid var(--hair)",
    minHeight: 280,
  },
  stepRow: { display: "flex", alignItems: "baseline", gap: 10 },
  stepNum: {
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: 11, fontWeight: 700, color: "var(--accent)",
    letterSpacing: "0.08em",
  },
  stepTime: {
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: 10.5, color: "var(--fg-4)",
    letterSpacing: "0.1em",
  },
  stage: {
    position: "relative",
    height: 170, borderRadius: 10,
    background: "linear-gradient(180deg, oklch(from var(--bg) calc(l - 0.02) c h), var(--bg))",
    border: "1px solid var(--hair)",
    overflow: "hidden",
  },
  ttl: { fontSize: 13.5, fontWeight: 600, letterSpacing: "-0.01em" },
  desc: { fontSize: 11.5, lineHeight: 1.5, color: "var(--fg-3)" },

  cliBlock: { maxWidth: 1200, margin: "0 auto" },
  cliHead: {
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: 10.5, color: "var(--fg-4)",
    letterSpacing: "0.12em", marginBottom: 10,
  },
  cliBody: {
    borderRadius: 12,
    padding: "16px 20px",
    background: "var(--surf)",
    border: "1px solid var(--hair)",
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: 12.5, lineHeight: 2,
  },
  cliLine: { whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" },
  cliPr: { color: "var(--accent)" },
  cliFlag: { color: "var(--info)" },
  cliCmt: { color: "var(--fg-4)" },
  cliOk: { color: "var(--accent)" },
};

const Mini = ({ d, main, fresh, slides }) => (
  <div style={{
    position: "absolute",
    left: d.x, top: d.y, width: d.w, height: d.h,
    borderRadius: 6,
    border: `1px solid ${main ? "oklch(from var(--accent) l c h / 0.7)" : "var(--hair-2)"}`,
    background: main
      ? "linear-gradient(135deg, oklch(from var(--accent) l c h / 0.5), oklch(from var(--accent) calc(l - 0.15) c h / 0.7))"
      : fresh
      ? "linear-gradient(135deg, oklch(0.30 0.04 60), oklch(0.18 0.04 60))"
      : "linear-gradient(135deg, oklch(0.32 0.02 60), oklch(0.20 0.02 60))",
    boxShadow: main
      ? "0 0 0 2px oklch(from var(--accent) l c h / 0.3), 0 8px 18px -6px oklch(0 0 0 / 0.5)"
      : "0 6px 14px -6px oklch(0 0 0 / 0.45)",
  }}>
    {slides && (
      <div style={{
        position: "absolute", inset: 8, borderRadius: 3,
        background: "linear-gradient(135deg, oklch(0.95 0.02 80), oklch(0.85 0.04 70))",
      }}>
        <div style={{ position: "absolute", left: 6, top: 8, width: "60%", height: 4, borderRadius: 2, background: "oklch(0.20 0.02 80)" }}/>
        <div style={{ position: "absolute", left: 6, top: 18, width: "85%", height: 2, borderRadius: 1, background: "oklch(0.40 0.02 80)" }}/>
        <div style={{ position: "absolute", left: 6, top: 24, width: "75%", height: 2, borderRadius: 1, background: "oklch(0.40 0.02 80)" }}/>
      </div>
    )}
    {main && (
      <div style={{ position: "absolute", top: 4, right: 6, color: "oklch(0.96 0.02 80)", fontSize: 10 }}>★</div>
    )}
  </div>
);

const Pulse = ({ x, y }) => (
  <div style={{
    position: "absolute", left: x, top: y, width: 14, height: 14,
    borderRadius: 999,
    background: "var(--accent)",
    boxShadow: "0 0 16px var(--accent)",
    animation: "pulse 1.6s ease-in-out infinite",
  }}/>
);

const FrameToast = () => (
  <div style={{
    position: "absolute", top: 10, right: 10,
    padding: "9px 11px", borderRadius: 9,
    background: "var(--surf-2)",
    border: "1px solid var(--hair-2)",
    backdropFilter: "blur(20px)",
    fontSize: 10.5, color: "var(--fg)",
    width: 165, lineHeight: 1.35,
  }}>
    <div style={{ fontWeight: 600 }}>New display: ACME 4K</div>
    <div style={{ color: "var(--fg-3)", fontSize: 10 }}>3840×2160 @ 60Hz</div>
    <div style={{ display: "flex", gap: 4, marginTop: 6 }}>
      <span style={{ flex: 1, textAlign: "center", padding: "3px 0", borderRadius: 5, background: "var(--accent)", color: "var(--accent-ink)", fontSize: 9.5, fontWeight: 600 }}>Set as main</span>
      <span style={{ flex: 1, textAlign: "center", padding: "3px 0", borderRadius: 5, background: "var(--hair)", fontSize: 9.5 }}>Mirror</span>
    </div>
  </div>
);

const Ring = () => (
  <div style={{ position: "absolute", top: 55, right: 22, width: 60, height: 60 }}>
    <svg width="60" height="60" viewBox="0 0 60 60">
      <circle cx="30" cy="30" r="26" fill="oklch(0 0 0 / 0.6)" stroke="var(--hair)" strokeWidth="3"/>
      <circle cx="30" cy="30" r="26" fill="none" stroke="var(--accent)" strokeWidth="3"
        strokeDasharray={2 * Math.PI * 26}
        strokeDashoffset={2 * Math.PI * 26 * 0.55}
        transform="rotate(-90 30 30)" strokeLinecap="round"
        style={{ filter: "drop-shadow(0 0 4px var(--accent))" }}/>
      <text x="30" y="34" textAnchor="middle"
        fontFamily="JetBrains Mono, monospace" fontSize="14" fontWeight="600" fill="var(--fg)">7</text>
    </svg>
  </div>
);

const FrameDone = () => (
  <div style={{
    position: "absolute", bottom: 10, left: 10,
    padding: "5px 9px", borderRadius: 7,
    background: "oklch(from var(--accent) l c h / 0.18)",
    border: "1px solid oklch(from var(--accent) l c h / 0.4)",
    color: "var(--accent)",
    fontSize: 10.5,
    fontFamily: "JetBrains Mono, monospace",
    letterSpacing: "0.06em",
  }}>
    ✓ KEPT · acme-room saved
  </div>
);

Object.assign(window, { Storyboard });
