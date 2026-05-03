/* global React, ReactDOM, useTweaks, TweaksPanel, TweakSection, TweakRadio, TweakSelect,
   Icon, DISPLAYS_2, DISPLAYS_3, DISPLAYS_4, MODES, PROFILES, VIRTUAL_FIXTURES,
   DisplayTile, Titlebar, Sidebar, Inspector, StatusBar, SafeTx, AdvancedDrawer, Toast,
   ResetSheet, VirtualSheet */

const { useState, useEffect, useMemo, useRef } = React;

const App = () => {
  const [tweaks, setTweak] = useTweaks(/*EDITMODE-BEGIN*/{
    "theme": "dark",
    "displayCount": 3,
    "scenario": "default"
  }/*EDITMODE-END*/);

  const baseFixture = tweaks.displayCount === 2 ? DISPLAYS_2 : tweaks.displayCount === 4 ? DISPLAYS_4 : DISPLAYS_3;
  const [displays, setDisplays] = useState(baseFixture.map(d => ({ ...d, geom: { ...d.geom } })));
  const [virtuals, setVirtuals] = useState([]);
  const [pips, setPips] = useState([]);
  const [issues, setIssues] = useState({});
  const [recordings, setRecordings] = useState([]);
  const [currentProfileId, setCurrentProfileId] = useState(PROFILES.find(p => p.current)?.id || PROFILES[0].id);
  const APP_DISPLAY_ID = 1;

  useEffect(() => {
    const fresh = baseFixture.map(d => ({ ...d, geom: { ...d.geom } }));
    setDisplays(fresh);
    setVirtuals([]); setPips([]); setIssues({}); setRecordings([]);
    setSelected(fresh.find(d => d.id === 2)?.id || fresh[0].id);
  }, [tweaks.displayCount]);

  const [selected, setSelected] = useState(2);
  const [draggingId, setDraggingId] = useState(null);
  const [snapLines, setSnapLines] = useState([]);
  const [advOpen, setAdvOpen] = useState(false);
  const [resetSheet, setResetSheet] = useState(null);
  const [virtualOpen, setVirtualOpen] = useState(false);
  const [tx, setTx] = useState(null);
  const [cli, setCli] = useState({ args: ["get", "2"], flags: ["--json"] });
  const [toast, setToast] = useState(null);
  const [watchOn, setWatchOn] = useState(false);
  const [events, setEvents] = useState([
    { ts: "12:04:09", kind: "added", detail: "ACME Projector 4K connected" },
    { ts: "12:04:11", kind: "main", detail: "main → ACME 4K" },
    { ts: "12:04:11", kind: "mode", detail: "ACME 4K · 3840×2160@60" },
    { ts: "12:04:23", kind: "added", detail: "LG OLED55C2 (AirPlay)" },
    { ts: "12:04:24", kind: "mode", detail: "mirror ACME → LG" },
  ]);

  useEffect(() => { document.documentElement.setAttribute("data-theme", tweaks.theme); }, [tweaks.theme]);

  useEffect(() => {
    if (!recordings.length) return;
    const tick = setInterval(() => {
      setRecordings((rs) => rs.map(r => ({ ...r, time: fmtDuration(Date.now() - r.startedAt) })));
    }, 500);
    return () => clearInterval(tick);
  }, [recordings.length]);

  useEffect(() => {
    if (tweaks.scenario === "safetx") {
      setTx({
        headline: "Switched main to ACME Projector 4K",
        copy: "Looks right? Press Space to keep — anything else reverts.",
        diff: [{ field: "main", pre: "Built-in", post: "ACME 4K" }, { field: "mode", pre: "1280×720", post: "3840×2160" }],
      });
    } else if (tweaks.scenario === "advanced") setAdvOpen(true);
    else if (tweaks.scenario === "issues") {
      setIssues({ 2: { kind: "wrong-aspect", msg: "EDID reports 16:9 but framebuffer outputs 16:10 — projector mismatch." } });
    } else if (tweaks.scenario === "virtual") {
      setVirtuals([VIRTUAL_FIXTURES[0]]);
      setSelected(91);
    } else if (tweaks.scenario === "recording") {
      setRecordings([{ id: "rec-1", sourceId: 2, sourceKind: "external", name: "ACME Projector 4K", time: "00:42", startedAt: Date.now() - 42_000 }]);
      setPips([{ ...require_pip(2), id: 81 }]);
    } else if (tweaks.scenario === "pip") {
      setPips([{ id: 81, pipOf: 2, name: "PiP · ACME 4K", kind: "pip", res: [1280, 720], refresh: 60, geom: { x: 0.78, y: 0.62, w: 0.16, h: 0.10 }, color: "slides", flipH: false, onTop: true }]);
    }
  }, [tweaks.scenario]);

  const canvasRef = useRef(null);
  const [canvasSize, setCanvasSize] = useState({ w: 800, h: 500 });
  useEffect(() => {
    const measure = () => {
      if (!canvasRef.current) return;
      const r = canvasRef.current.getBoundingClientRect();
      setCanvasSize({ w: r.width, h: r.height });
    };
    measure();
    const ro = new ResizeObserver(measure);
    if (canvasRef.current) ro.observe(canvasRef.current);
    window.addEventListener("resize", measure);
    return () => { ro.disconnect(); window.removeEventListener("resize", measure); };
  }, []);

  const allEntities = useMemo(() => {
    const realOnes = displays.map(d => ({ ...d, _entityKind: "display" }));
    const virtOnes = virtuals.map(d => ({ ...d, _entityKind: "virtual" }));
    const pipOnes = pips.map(p => {
      const src = [...displays, ...virtuals].find(d => d.id === p.pipOf);
      return {
        ...p, _entityKind: "pip",
        rotation: 0, flip: "none",
        main: false, mirroredFrom: null,
        color: src ? src.color : "ink",
        kind: "pip",
        cgID: `0xPIP${p.id}`,
        alias: p.alias || `pip-${p.id}`,
        vendor: "wdm", model: "PiP window", serial: `pip-${p.id}`,
      };
    });
    return [...realOnes, ...virtOnes, ...pipOnes];
  }, [displays, virtuals, pips]);

  const onSelect = (id) => {
    setSelected(id);
    setCli({ args: ["get", String(id)], flags: ["--json"] });
  };

  const onDrag = (id, phase, pos, isClick) => {
    if (phase === "start") { setDraggingId(id); setSnapLines([]); }
    else if (phase === "move") {
      const SNAP = 0.015;
      const me = allEntities.find(d => d.id === id);
      if (!me) return;
      let nx = pos.x, ny = pos.y;
      const others = allEntities.filter(d => d.id !== id);
      const lines = [];
      for (const o of others) {
        const myRight = nx + me.geom.w; const myBottom = ny + me.geom.h;
        if (Math.abs(nx - (o.geom.x + o.geom.w)) < SNAP) { nx = o.geom.x + o.geom.w; lines.push({ kind: "v", x: nx * canvasSize.w }); }
        if (Math.abs(myRight - o.geom.x) < SNAP) { nx = o.geom.x - me.geom.w; lines.push({ kind: "v", x: o.geom.x * canvasSize.w }); }
        if (Math.abs(ny - o.geom.y) < SNAP) { ny = o.geom.y; lines.push({ kind: "h", y: ny * canvasSize.h }); }
        if (Math.abs(myBottom - (o.geom.y + o.geom.h)) < SNAP) { ny = (o.geom.y + o.geom.h) - me.geom.h; lines.push({ kind: "h", y: (o.geom.y + o.geom.h) * canvasSize.h }); }
      }
      setSnapLines(lines);
      const updater = (arr) => arr.map(d => d.id === id ? { ...d, geom: { ...d.geom, x: Math.max(0.01, nx), y: Math.max(0.01, ny) } } : d);
      setDisplays(updater); setVirtuals(updater); setPips(updater);
    } else if (phase === "end") {
      setDraggingId(null); setSnapLines([]);
      if (!isClick) {
        setTx({ headline: "Arrangement updated", copy: "Origins moved. Space to keep.", diff: [{ field: "origin", pre: "previous", post: "new" }] });
        const md = allEntities.find(d => d.id === id);
        if (md) setCli({ args: ["move", String(id), String(Math.round(md.geom.x * 4000)), String(Math.round(md.geom.y * 2000))], flags: ["--confirm"] });
      }
    }
  };

  const onMutate = (m) => {
    if (m.kind === "main") {
      const target = displays.find(d => d.id === m.id); if (!target) return;
      setDisplays(displays.map(d => ({ ...d, main: d.id === m.id })));
      setTx({ headline: `Set main to ${target.name}`, copy: "Space keeps. Auto-revert in 15s.", diff: [{ field: "main", pre: displays.find(d=>d.main)?.name || "—", post: target.name }] });
      setCli({ args: ["main", String(m.id)], flags: ["--confirm"] });
    } else if (m.kind === "mode") {
      setTx({ headline: `Set mode ${m.mode}`, copy: "Space keeps.", diff: [{ field: "mode", pre: "current", post: m.mode }] });
      setCli({ args: ["mode", String(m.id), m.mode], flags: ["--confirm"] });
    } else if (m.kind === "rotate") {
      setDisplays(displays.map(d => d.id === m.id ? { ...d, rotation: m.deg } : d));
      setCli({ args: ["rotate", String(m.id), String(m.deg)], flags: ["--confirm"] });
    } else if (m.kind === "flip") {
      setDisplays(displays.map(d => d.id === m.id ? { ...d, flip: m.axis } : d));
      setCli({ args: ["flip", String(m.id), m.axis], flags: ["--confirm"] });
    } else if (m.kind === "mirror") {
      setTx({ headline: `Mirror ${displays.find(d=>d.id===m.src)?.name} → ${displays.find(d=>d.id===m.id)?.name}`, copy: "Space keeps.", diff: [{ field: "mirror", pre: "extended", post: `mirror of 0${m.src}` }] });
      setCli({ args: ["mirror", String(m.src), String(m.id)], flags: ["--confirm"] });
    } else if (m.kind === "extend") {
      setDisplays(displays.map(d => d.id === m.id ? { ...d, mirroredFrom: null } : d));
      setCli({ args: ["unmirror", String(m.id)], flags: ["--confirm"] });
    }
  };

  const onResetClick = (id) => setResetSheet(id);

  const onRename = (id, name) => {
    setDisplays(ds => ds.map(d => d.id === id ? { ...d, name } : d));
    setVirtuals(vs => vs.map(v => v.id === id ? { ...v, name } : v));
    setPips(ps => ps.map(p => p.id === id ? { ...p, name } : p));
    pushEvent({ kind: "mode", detail: `rename 0${id} → "${name}"` });
    setCli({ args: ["rename", String(id), JSON.stringify(name)], flags: [] });
  };

  const applyReset = (id, level) => {
    setResetSheet(null);
    const d = allEntities.find(x => x.id === id);
    if (!d) return;
    pushEvent({ kind: "mode", detail: `reset ${level} → ${d.name}` });
    if (level === "soft") pushToast({ icon: "refresh", title: "Soft refresh", sub: `Re-read EDID + redrove framebuffer for ${d.name}.` });
    else if (level === "force-edid") { setIssues((I) => { const n = { ...I }; delete n[id]; return n; }); pushToast({ icon: "detect", title: "Force-detected", sub: `EDID re-handshaked. ${d.name} reports clean modes now.` }); }
    else if (level === "force-aspect") { setIssues((I) => { const n = { ...I }; delete n[id]; return n; }); pushToast({ icon: "aspect", title: "Aspect ratio pinned", sub: `Override saved. ${d.name} → 16:9 forced.` }); }
    else if (level === "hpm-cycle") { setIssues((I) => { const n = { ...I }; delete n[id]; return n; }); pushToast({ icon: "plug", title: "Bus cycled", sub: `AppleHPM port-power cycled. ${d.name} re-enumerated.` }); }
    setCli({ args: ["reset", String(id), `--level=${level}`], flags: [] });
  };

  const onAddVirtual = (preset) => {
    setVirtualOpen(false);
    const newId = 90 + virtuals.length + 1;
    const v = {
      id: newId, cgID: `0xVD0000${newId}`, edid: `VIRTUAL-${preset.res[0]}p`,
      vendor: "wdm", model: `Virtual Display (${preset.res[1]}p)`, serial: `VD-${newId}`,
      name: preset.name, alias: preset.id, kind: "virtual",
      main: false, mirroredFrom: null,
      res: preset.res, refresh: preset.hz, scale: 1, rotation: 0, flip: "none",
      brightness: null, hdr: false,
      caps: { brightness: "off", rotation: "ok", flip: "ok", hdr: "off", reset: "ok", destroy: "ok" },
      geom: { x: 0.04 + (virtuals.length * 0.04), y: 0.06 + (virtuals.length * 0.04), w: 0.18, h: 0.22 },
      color: "ink",
    };
    setVirtuals([...virtuals, v]);
    setSelected(newId);
    pushEvent({ kind: "added", detail: `+ virtual: ${v.name}` });
    pushToast({ icon: "virtual", title: "Virtual display created", sub: `${v.name} · ${preset.res[0]}×${preset.res[1]}@${preset.hz}Hz` });
    setCli({ args: ["virtual", "create", `--res=${preset.res[0]}x${preset.res[1]}`, `--hz=${preset.hz}`], flags: [] });
  };

  const onDestroy = (id) => {
    const v = virtuals.find(d => d.id === id);
    const p = pips.find(d => d.id === id);
    if (v) {
      setVirtuals(virtuals.filter(d => d.id !== id));
      pushEvent({ kind: "removed", detail: `- virtual: ${v.name}` });
      pushToast({ icon: "trash", title: "Virtual destroyed", sub: `${v.name} torn down.` });
      if (selected === id) setSelected(displays[0]?.id);
    } else if (p) {
      setPips(pips.filter(d => d.id !== id));
      pushEvent({ kind: "removed", detail: `- pip: ${p.name}` });
      pushToast({ icon: "trash", title: "PiP closed", sub: `${p.name} closed.` });
      if (selected === id) setSelected(displays[0]?.id);
    }
  };

  const onRecord = (id) => {
    if (id === APP_DISPLAY_ID) return;
    const existing = recordings.find(r => r.sourceId === id);
    if (existing) {
      setRecordings(recordings.filter(r => r.id !== existing.id));
      pushToast({ icon: "stop", title: "Recording saved", sub: `${existing.name} · ${existing.time} · ~/Movies/wdm/${existing.id}.mov` });
      pushEvent({ kind: "removed", detail: `rec stop: ${existing.name}` });
      setCli({ args: ["record", "stop", String(id)], flags: [] });
      return;
    }
    const src = allEntities.find(d => d.id === id);
    if (!src) return;
    const recId = `rec-${Date.now()}`;
    setRecordings([...recordings, { id: recId, sourceId: id, sourceKind: src.kind, name: src.name, time: "00:00", startedAt: Date.now() }]);
    if (!pips.find(p => p.pipOf === id)) setPips([...pips, require_pip(id, src)]);
    pushEvent({ kind: "added", detail: `rec start: ${src.name}` });
    pushToast({ icon: "record", title: "Recording started", sub: `${src.name} · ScreenCaptureKit · 60fps.` });
    setCli({ args: ["record", "start", String(id), "--codec=h264", "--fps=60"], flags: [] });
  };

  const onPiP = (id) => {
    if (pips.find(p => p.pipOf === id)) { pushToast({ icon: "pip", title: "PiP already open" }); return; }
    const src = allEntities.find(d => d.id === id);
    if (!src) return;
    setPips([...pips, require_pip(id, src)]);
    setCli({ args: ["pip", String(id), "--size", "1280x720"], flags: [] });
    pushToast({ icon: "pip", title: "PiP mirror started", sub: `Live mirror of ${src.name}.` });
    pushEvent({ kind: "added", detail: `+ pip of ${src.name}` });
  };

  const onKeep = () => { if (!tx) return; pushEvent({ kind: "main", detail: tx.headline }); pushToast({ icon: "check", title: "Kept.", sub: "Snapshot in last.json." }); setTx(null); };
  const onRevert = () => { pushToast({ icon: "x", title: "Reverted." }); setTx(null); };

  const onMirror = (srcId, targetIds) => {
    const src = displays.find(d => d.id === srcId);
    if (!src) return;
    setDisplays(displays.map(d => targetIds.includes(d.id) ? { ...d, mirroredFrom: srcId, main: false } : d));
    setTx({
      headline: `Mirror ${src.name} → ${targetIds.length} display${targetIds.length === 1 ? "" : "s"}`,
      copy: "Space keeps. Auto-revert in 15s.",
      diff: targetIds.map(id => ({ field: `0${id}`, pre: "extended", post: `mirror of 0${srcId}` })),
    });
    setCli({ args: ["mirror", String(srcId), ...targetIds.map(String)], flags: ["--confirm"] });
    pushEvent({ kind: "mode", detail: `mirror ${src.name} → ${targetIds.length}` });
  };
  const onUnmirror = (id) => {
    setDisplays(displays.map(d => d.id === id ? { ...d, mirroredFrom: null } : d));
    setCli({ args: ["unmirror", String(id)], flags: ["--confirm"] });
    pushToast({ icon: "chain", title: "Unmirrored", sub: `0${id} is extended again.` });
  };

  const onApplyProfile = (p) => {
    setCurrentProfileId(p.id);
    setTx({ headline: `Restore "${p.name}"`, copy: "Space keeps. Auto-revert in 15s.", diff: [{ field: "profile", pre: "current", post: p.name }] });
    setCli({ args: ["restore", p.id], flags: ["--confirm"] });
  };
  const onSaveCurrent = () => {
    pushToast({ icon: "bookmark", title: "Saved current arrangement", sub: "Added to Saved arrangements." });
    setCli({ args: ["save", `desk-${Date.now().toString(36).slice(-4)}`], flags: [] });
  };

  function pushToast(t) { setToast(t); setTimeout(() => setToast(curr => curr === t ? null : curr), 3500); }
  function pushEvent(e) { setEvents(es => [{ ts: now(), ...e }, ...es]); }

  const display = allEntities.find(d => d.id === selected) || null;
  const profile = PROFILES.find(p => p.id === currentProfileId) || PROFILES[0];
  const lastEvent = events[0];

  return (
    <div className="shell">
      <Titlebar
        title="wdm"
        count={displays.length + virtuals.length + pips.length}
        theme={tweaks.theme}
        onTheme={() => setTweak("theme", tweaks.theme === "dark" ? "light" : "dark")}
        onSearch={() => pushToast({ icon: "snap", title: "⌘K palette", sub: "Quick action menu." })}
      />

      <Sidebar
        displays={displays}
        virtuals={virtuals}
        pips={pips}
        recordings={recordings}
        profiles={PROFILES}
        currentProfileId={currentProfileId}
        selectedId={selected}
        onSelect={onSelect}
        onAddVirtual={() => setVirtualOpen(true)}
        onApplyProfile={onApplyProfile}
        onSaveCurrent={onSaveCurrent}
        onDestroy={onDestroy}
        issues={issues}
      />

      <div className="mac-canvas-wrap">
        <div className="mac-canvas" ref={canvasRef}>
          {snapLines.map((l, i) => l.kind === "v"
            ? <div key={i} className="snap-line" style={{ left: l.x, top: 0, bottom: 0, width: 1 }}/>
            : <div key={i} className="snap-line" style={{ top: l.y, left: 0, right: 0, height: 1 }}/>
          )}
          {allEntities.map((d) => (
            <DisplayTile key={d.id} d={d}
              selected={selected === d.id}
              dragging={draggingId === d.id}
              onSelect={onSelect}
              onDrag={onDrag}
              canvasSize={canvasSize}
              primaryAction={null}
              issue={issues[d.id]}
              recording={!!recordings.find(r => r.sourceId === d.id)}
              isApp={d.id === APP_DISPLAY_ID}
              onRecordToggle={onRecord}
              onReset={onResetClick}
              onInspect={(id) => { setSelected(id); setAdvOpen(true); }}
              onDestroy={onDestroy}
            />
          ))}
        </div>
      </div>

      <Inspector
        display={display}
        displays={displays}
        recordings={recordings}
        onMutate={onMutate}
        onPiP={onPiP}
        onRecord={onRecord}
        onReset={onResetClick}
        onInspect={() => setAdvOpen(true)}
        isApp={display?.id === APP_DISPLAY_ID}
        onMirror={onMirror}
        onUnmirror={onUnmirror}
        onRename={onRename}
      />

      <StatusBar
        counts={{ real: displays.length, virtual: virtuals.length, pip: pips.length }}
        recordings={recordings}
        watchOn={watchOn}
        onWatch={() => setWatchOn(w => !w)}
        advancedOpen={advOpen}
        onAdvanced={() => setAdvOpen(o => !o)}
        lastEvent={lastEvent}
        profileName={profile.name}
      />

      <AdvancedDrawer
        open={advOpen}
        onClose={() => setAdvOpen(false)}
        display={display && display._entityKind === "display" ? display : displays.find(d => d.id === 2)}
        onMutate={onMutate}
        onPiP={onPiP}
        onDoctor={() => setAdvOpen(true)}
        displays={displays}
        cli={cli}
      />

      <Toast toast={toast}/>
      <ResetSheet open={!!resetSheet} display={resetSheet ? allEntities.find(d => d.id === resetSheet) : null} onClose={() => setResetSheet(null)} onApply={applyReset}/>
      <VirtualSheet open={virtualOpen} onClose={() => setVirtualOpen(false)} onCreate={onAddVirtual}/>
      <SafeTx tx={tx} onKeep={onKeep} onRevert={onRevert}/>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Theme">
          <TweakRadio value={tweaks.theme} onChange={(v) => setTweak("theme", v)}
            options={[{ label: "Dark", value: "dark" }, { label: "Light", value: "light" }]}/>
        </TweakSection>
        <TweakSection title="Real displays">
          <TweakRadio value={String(tweaks.displayCount)} onChange={(v) => setTweak("displayCount", Number(v))}
            options={[{ label: "2", value: "2" }, { label: "3", value: "3" }, { label: "4", value: "4" }]}/>
        </TweakSection>
        <TweakSection title="Scenario">
          <TweakSelect value={tweaks.scenario} onChange={(v) => setTweak("scenario", v)}
            options={[
              { label: "Default", value: "default" },
              { label: "Detection issue (wrong aspect)", value: "issues" },
              { label: "Virtual display added", value: "virtual" },
              { label: "PiP window open", value: "pip" },
              { label: "Recording in progress", value: "recording" },
              { label: "Safe-tx countdown", value: "safetx" },
              { label: "Advanced drawer", value: "advanced" },
            ]}/>
        </TweakSection>
      </TweaksPanel>
    </div>
  );
};

const now = () => { const d = new Date(); return [d.getHours(), d.getMinutes(), d.getSeconds()].map(n => String(n).padStart(2, "0")).join(":"); };
const fmtDuration = (ms) => { const s = Math.floor(ms / 1000); const m = Math.floor(s / 60); return `${String(m).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`; };
const require_pip = (sourceId, src) => ({
  id: 80 + sourceId, pipOf: sourceId, name: `PiP · ${src ? src.name : "?"}`,
  alias: `pip-${sourceId}`, kind: "pip",
  res: [1280, 720], refresh: 60,
  geom: { x: 0.78 - ((sourceId % 4) * 0.02), y: 0.62 - ((sourceId % 3) * 0.02), w: 0.16, h: 0.10 },
  color: src ? src.color : "ink", flipH: false, onTop: true,
});

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
