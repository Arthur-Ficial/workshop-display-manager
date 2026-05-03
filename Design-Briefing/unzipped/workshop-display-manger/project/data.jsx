/* global React */

// ========== Icons (minimal originals, not SF Symbols) ==========
const Icon = ({ name, className = "ic" }) => {
  const paths = {
    crown: <path d="M2 12 L4 4 L8 8 L12 3 L16 8 L20 4 L22 12 Z M3 16 H21 V18 H3 Z" />,
    chain: <><path d="M9 12 a3 3 0 1 0 -3 -3 m9 9 a3 3 0 1 0 3 3" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M8 16 L16 8" stroke="currentColor" strokeWidth="2"/></>,
    airplay: <><path d="M5 6 H19 V14 H17 M5 14 H7 V6" fill="none" stroke="currentColor" strokeWidth="1.7"/><path d="M8 18 L12 13 L16 18 Z"/></>,
    sidecar: <rect x="4" y="3" width="16" height="14" rx="2" fill="none" stroke="currentColor" strokeWidth="1.7"/>,
    builtin: <><rect x="2" y="4" width="20" height="13" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.7"/><path d="M9 20 H15" stroke="currentColor" strokeWidth="1.7"/></>,
    external: <><rect x="3" y="3" width="18" height="14" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.7"/><path d="M8 21 H16 M12 17 V21" stroke="currentColor" strokeWidth="1.7"/></>,
    sun: <><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="1.8"/><path d="M12 2 V5 M12 19 V22 M2 12 H5 M19 12 H22 M5 5 L7 7 M17 17 L19 19 M5 19 L7 17 M17 7 L19 5" stroke="currentColor" strokeWidth="1.8"/></>,
    rotate: <path d="M4 12 a8 8 0 1 1 8 8" fill="none" stroke="currentColor" strokeWidth="1.8"/>,
    flip: <><path d="M4 4 H20 V20 H4 Z" fill="none" stroke="currentColor" strokeWidth="1.5" strokeDasharray="3 3"/><path d="M12 2 V22" stroke="currentColor" strokeWidth="1.8"/></>,
    pip: <><rect x="2" y="4" width="20" height="14" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6"/><rect x="13" y="10" width="7" height="6" rx="1" fill="currentColor"/></>,
    swap: <path d="M4 8 H17 L14 5 M20 16 H7 L10 19" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    cycle: <path d="M4 12 a8 8 0 1 1 2.5 5.8 M4 18 V13 H9" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    sleep: <path d="M12 3 a9 9 0 1 0 9 9 a7 7 0 0 1 -9 -9 Z" fill="none" stroke="currentColor" strokeWidth="1.7"/>,
    eye: <><path d="M2 12 C 4 6 8 4 12 4 C 16 4 20 6 22 12 C 20 18 16 20 12 20 C 8 20 4 18 2 12 Z" fill="none" stroke="currentColor" strokeWidth="1.6"/><circle cx="12" cy="12" r="3" fill="currentColor"/></>,
    bookmark: <path d="M6 3 H18 V21 L12 17 L6 21 Z" fill="none" stroke="currentColor" strokeWidth="1.7"/>,
    plus: <path d="M12 5 V19 M5 12 H19" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    chevron: <path d="M9 6 L15 12 L9 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    chevDown: <path d="M6 9 L12 15 L18 9" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    check: <path d="M5 12 L10 17 L19 7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>,
    x: <path d="M6 6 L18 18 M18 6 L6 18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    stethoscope: <path d="M5 3 V10 A4 4 0 0 0 13 10 V3 M9 14 V18 a3 3 0 0 0 6 0 V16" fill="none" stroke="currentColor" strokeWidth="1.7"/>,
    terminal: <><rect x="2" y="4" width="20" height="16" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6"/><path d="M6 9 L9 12 L6 15 M11 15 H16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></>,
    grid: <path d="M4 4 H10 V10 H4 Z M14 4 H20 V10 H14 Z M4 14 H10 V20 H4 Z M14 14 H20 V20 H14 Z" fill="none" stroke="currentColor" strokeWidth="1.6"/>,
    pen: <path d="M4 20 H8 L18 10 L14 6 L4 16 Z" fill="none" stroke="currentColor" strokeWidth="1.6"/>,
    bolt: <path d="M13 3 L5 13 H11 L9 21 L19 11 H13 L13 3 Z" fill="currentColor"/>,
    radio: <><circle cx="12" cy="12" r="2.5" fill="currentColor"/><path d="M7 7 a7 7 0 0 0 0 10 M17 7 a7 7 0 0 1 0 10 M4 4 a11 11 0 0 0 0 16 M20 4 a11 11 0 0 1 0 16" fill="none" stroke="currentColor" strokeWidth="1.4"/></>,
    info: <><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="1.6"/><path d="M12 11 V17 M12 7.5 V8.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/></>,
    copy: <><rect x="8" y="3" width="13" height="13" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6"/><path d="M16 16 V19 a2 2 0 0 1 -2 2 H5 a2 2 0 0 1 -2 -2 V8 a2 2 0 0 1 2 -2 H8" fill="none" stroke="currentColor" strokeWidth="1.6"/></>,
    snap: <path d="M4 12 H10 M14 12 H20 M12 4 V10 M12 14 V20" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>,
    diff: <path d="M9 4 V10 H3 M15 20 V14 H21 M3 10 L11 18 M21 14 L13 6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/>,
    detect: <><circle cx="12" cy="12" r="3" fill="currentColor"/><path d="M12 2 V5 M12 19 V22 M2 12 H5 M19 12 H22" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" strokeWidth="1.4" strokeDasharray="2 3"/></>,
    record: <><circle cx="12" cy="12" r="6" fill="currentColor"/><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="1.4"/></>,
    pause: <><rect x="7" y="5" width="3" height="14" fill="currentColor"/><rect x="14" y="5" width="3" height="14" fill="currentColor"/></>,
    stop: <rect x="6" y="6" width="12" height="12" rx="1.5" fill="currentColor"/>,
    trash: <path d="M5 7 H19 M9 7 V5 a1 1 0 0 1 1 -1 H14 a1 1 0 0 1 1 1 V7 M7 7 L8 20 a1 1 0 0 0 1 1 H15 a1 1 0 0 0 1 -1 L17 7" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"/>,
    plug: <path d="M9 2 V8 M15 2 V8 M6 8 H18 V12 a6 6 0 0 1 -12 0 V8 Z M12 18 V22" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"/>,
    aspect: <><rect x="3" y="6" width="18" height="12" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.7"/><path d="M3 14 H21" stroke="currentColor" strokeWidth="1.4" strokeDasharray="3 3"/></>,
    virtual: <><rect x="3" y="5" width="18" height="12" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6" strokeDasharray="3 3"/><path d="M9 21 H15" stroke="currentColor" strokeWidth="1.7"/></>,
    refresh: <path d="M4 12 a8 8 0 0 1 14 -5 M20 12 a8 8 0 0 1 -14 5 M16 7 H20 V3 M8 17 H4 V21" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"/>,
  };
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      {paths[name]}
    </svg>
  );
};

// ========== Display fixtures ==========
// Coords are in canvas px (we keep it simple — 1:1 with display origins divided by a factor)
const DISPLAYS_3 = [
  {
    id: 1,
    cgID: "0x4280003D",
    edid: "37D8 1A09-EFBE-4E8A-9341-3C4B7C2E1B59",
    vendor: "Apple Inc.",
    model: "MacBook Pro 14\" (M3 Pro)",
    serial: "FVH7L2X9P3",
    name: "Built-in Retina",
    alias: "podium",
    kind: "builtin",
    main: false,
    mirroredFrom: null,
    res: [1512, 982],
    refresh: 60,
    scale: 2,
    rotation: 0,
    flip: "none",
    brightness: 0.5,
    hdr: true,
    caps: { brightness: "ok", rotation: "off", flip: "off", hdr: "ok", reset: "ok", destroy: "off" },
    capReason: { rotation: "Apple Silicon built-ins don't expose IODisplayConnect", flip: "Same — use Flip Overlay", destroy: "You can't destroy the built-in panel." },
    // canvas geometry (left,top,w,h in px on the canvas surface)
    // geom is normalized: x/y/w/h in 0..1 of the canvas
    geom: { x: 0.04, y: 0.55, w: 0.20, h: 0.32 },
    color: "ink",
  },
  {
    id: 2,
    cgID: "0x4280003E",
    edid: "8E72 4D77-118A-4F22-A5DE-09B2EF6B22D1",
    vendor: "BenQ Corporation",
    model: "BenQ LU935 (4K Laser)",
    serial: "8U03H00271",
    name: "ACME Projector 4K",
    alias: "audience",
    kind: "external",
    main: true,
    mirroredFrom: null,
    res: [3840, 2160],
    refresh: 60,
    scale: 1,
    rotation: 180, // ceiling-mounted -> flipped
    flip: "none",
    brightness: null,
    hdr: false,
    caps: { brightness: "off", rotation: "ok", flip: "ok", hdr: "off", reset: "ok", destroy: "off" },
    geom: { x: 0.28, y: 0.18, w: 0.34, h: 0.50 },
    color: "slides",
  },
  {
    id: 3,
    cgID: "0x71450103",
    edid: "AIRPLAY-LG-OLED55C2",
    vendor: "LG Electronics",
    model: "OLED55C2 (AirPlay)",
    serial: "AP-2C-39-E1",
    name: "Stage Right TV",
    alias: "back-of-room",
    kind: "airplay",
    main: false,
    mirroredFrom: 2,
    res: [1920, 1080],
    refresh: 60,
    scale: 1,
    rotation: 0,
    flip: "none",
    brightness: null,
    hdr: false,
    caps: { brightness: "off", rotation: "off", flip: "off", hdr: "off", reset: "ok", destroy: "ok" },
    capReason: { flip: "AirPlay virtual displays don't expose IOKit transforms — use Flip Overlay", rotation: "AirPlay virtual displays don't expose IOKit transforms" },
    geom: { x: 0.66, y: 0.30, w: 0.20, h: 0.30 },
    color: "mirror",
  },
];

const DISPLAYS_2 = [DISPLAYS_3[0], DISPLAYS_3[1]];
const DISPLAYS_4 = [
  ...DISPLAYS_3,
  {
    id: 4, cgID: "0x52840201",
    edid: "SIDECAR-IPAD-PRO13",
    vendor: "Apple Inc.", model: "iPad Pro 13\" (Sidecar)", serial: "SC-IPD-129",
    name: "Speaker iPad", alias: "speaker-notes",
    kind: "sidecar", main: false, mirroredFrom: null,
    res: [2752, 2064], refresh: 60, scale: 2, rotation: 0, flip: "none",
    brightness: null, hdr: false,
    caps: { brightness: "off", rotation: "ok", flip: "off", hdr: "off", reset: "ok", destroy: "ok" },
    capReason: { flip: "Sidecar doesn't expose IOKit transforms" },
    geom: { x: 0.04, y: 0.30, w: 0.13, h: 0.42 },
    color: "notes",
  },
];

// available modes (sample)
const MODES = {
  1: [
    { wxh: "1512x982", hz: 60, scale: 2, current: true, supported: true, aspect: "16:10" },
    { wxh: "1728x1117", hz: 60, scale: 2, current: false, supported: true, aspect: "16:10" },
    { wxh: "1352x878", hz: 60, scale: 2, current: false, supported: true, aspect: "16:10" },
    { wxh: "1024x768", hz: 60, scale: 1, current: false, supported: true, aspect: "4:3" },
  ],
  2: [
    { wxh: "3840x2160", hz: 60, scale: 1, current: true, supported: true, aspect: "16:9" },
    { wxh: "3840x2160", hz: 30, scale: 1, current: false, supported: true, aspect: "16:9" },
    { wxh: "2560x1440", hz: 60, scale: 1, current: false, supported: true, aspect: "16:9" },
    { wxh: "1920x1080", hz: 60, scale: 1, current: false, supported: true, aspect: "16:9" },
    { wxh: "1920x1080", hz: 120, scale: 1, current: false, supported: false, reason: "EDID block reports max pixel clock 297 MHz", aspect: "16:9" },
    { wxh: "1280x720", hz: 60, scale: 1, current: false, supported: true, aspect: "16:9" },
  ],
  3: [
    { wxh: "1920x1080", hz: 60, scale: 1, current: true, supported: true, aspect: "16:9" },
    { wxh: "3840x2160", hz: 60, scale: 1, current: false, supported: false, reason: "AirPlay caps at 1080p60", aspect: "16:9" },
    { wxh: "1280x720", hz: 60, scale: 1, current: false, supported: true, aspect: "16:9" },
  ],
  4: [
    { wxh: "2752x2064", hz: 60, scale: 2, current: true, supported: true, aspect: "4:3" },
    { wxh: "2388x1668", hz: 60, scale: 2, current: false, supported: true, aspect: "4:3" },
  ],
};

// Saved profiles (mini canvases)
const PROFILES = [
  { id: "ws-a-ballroom", name: "Workshop A — Ballroom", hk: "⌘1", current: true,
    minis: [
      { x: 28, y: 50, w: 40, h: 26, main: false },
      { x: 78, y: 28, w: 70, h: 44, main: true },
      { x: 158, y: 38, w: 44, h: 26, main: false },
    ],
    det: "3 displays · projector main · 4K@60 · LG mirrored",
  },
  { id: "ws-b-breakout", name: "Workshop B — Breakout Room", hk: "⌘2",
    minis: [
      { x: 28, y: 50, w: 40, h: 26, main: false },
      { x: 78, y: 32, w: 60, h: 38, main: true },
    ],
    det: "2 displays · 1080p60",
  },
  { id: "recording", name: "Recording mode", hk: "⌘3",
    minis: [
      { x: 30, y: 30, w: 50, h: 32, main: true },
      { x: 92, y: 34, w: 44, h: 28, main: false },
      { x: 148, y: 50, w: 44, h: 28, main: false },
    ],
    det: "All extended · brightness 30% · HDR off",
  },
  { id: "single-screen", name: "Single screen — desk", hk: "⌘4",
    minis: [
      { x: 80, y: 36, w: 60, h: 38, main: true },
    ],
    det: "Built-in only",
  },
  { id: "dual-projector", name: "Dual-projector talk", hk: "⌘5",
    minis: [
      { x: 16, y: 40, w: 36, h: 24, main: false },
      { x: 60, y: 26, w: 56, h: 36, main: true },
      { x: 124, y: 30, w: 56, h: 36, main: false },
    ],
    det: "Mirror 1→2,3",
  },
  { id: "podcast", name: "Podcast — guest cam", hk: "⌘6",
    minis: [
      { x: 30, y: 36, w: 50, h: 32, main: true },
      { x: 88, y: 40, w: 38, h: 26, main: false },
    ],
    det: "Built-in main · external 1080p",
  },
];

// ========== Pseudo-screenshot panes (drawn placeholders, never live) ==========
const ScreenshotInk = () => (
  <svg viewBox="0 0 400 250" preserveAspectRatio="xMidYMid slice" style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
    <defs>
      <linearGradient id="ink-bg" x1="0" x2="1" y1="0" y2="1">
        <stop offset="0%" stopColor="#1a1d22"/>
        <stop offset="100%" stopColor="#0d0f12"/>
      </linearGradient>
      <pattern id="ink-stripes" width="8" height="8" patternUnits="userSpaceOnUse">
        <rect width="8" height="8" fill="transparent"/>
        <path d="M0 8 L8 0" stroke="rgba(255,255,255,0.025)" strokeWidth="1"/>
      </pattern>
    </defs>
    <rect width="400" height="250" fill="url(#ink-bg)"/>
    <rect width="400" height="250" fill="url(#ink-stripes)"/>
    {/* mock window chrome */}
    <rect x="40" y="60" width="220" height="140" rx="10" fill="rgba(255,255,255,0.04)" stroke="rgba(255,255,255,0.08)"/>
    <circle cx="55" cy="76" r="4" fill="rgba(255,90,90,0.6)"/>
    <circle cx="68" cy="76" r="4" fill="rgba(255,180,80,0.6)"/>
    <circle cx="81" cy="76" r="4" fill="rgba(120,210,140,0.6)"/>
    <rect x="50" y="92" width="180" height="3" rx="1.5" fill="rgba(255,255,255,0.18)"/>
    <rect x="50" y="102" width="120" height="3" rx="1.5" fill="rgba(255,255,255,0.10)"/>
    <rect x="50" y="112" width="160" height="3" rx="1.5" fill="rgba(255,255,255,0.10)"/>
    <rect x="50" y="130" width="60" height="3" rx="1.5" fill="rgba(225,160,90,0.45)"/>
    <rect x="280" y="60" width="80" height="60" rx="6" fill="rgba(225,160,90,0.10)" stroke="rgba(225,160,90,0.25)"/>
    <rect x="280" y="130" width="80" height="50" rx="6" fill="rgba(255,255,255,0.04)" stroke="rgba(255,255,255,0.08)"/>
  </svg>
);

const ScreenshotSlides = ({ rotated180 = false }) => (
  <svg viewBox="0 0 400 250" preserveAspectRatio="xMidYMid slice" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", transform: rotated180 ? "rotate(180deg)" : "none" }}>
    <defs>
      <linearGradient id="slide-bg" x1="0" x2="1" y1="0" y2="1">
        <stop offset="0%" stopColor="#2a1f15"/>
        <stop offset="100%" stopColor="#0e0a07"/>
      </linearGradient>
    </defs>
    <rect width="400" height="250" fill="url(#slide-bg)"/>
    {/* big slide title */}
    <rect x="40" y="50" width="200" height="14" rx="3" fill="rgba(225,160,90,0.85)"/>
    <rect x="40" y="74" width="280" height="6" rx="2" fill="rgba(255,255,255,0.7)"/>
    <rect x="40" y="86" width="240" height="6" rx="2" fill="rgba(255,255,255,0.4)"/>
    <rect x="40" y="120" width="320" height="3" rx="1.5" fill="rgba(255,255,255,0.18)"/>
    <rect x="40" y="132" width="290" height="3" rx="1.5" fill="rgba(255,255,255,0.18)"/>
    <rect x="40" y="144" width="260" height="3" rx="1.5" fill="rgba(255,255,255,0.12)"/>
    <rect x="40" y="156" width="300" height="3" rx="1.5" fill="rgba(255,255,255,0.12)"/>
    <rect x="40" y="190" width="60" height="3" rx="1.5" fill="rgba(225,160,90,0.7)"/>
    <rect x="290" y="190" width="60" height="3" rx="1.5" fill="rgba(255,255,255,0.4)"/>
    <text x="40" y="44" fontFamily="Geist Mono, monospace" fontSize="9" fill="rgba(225,160,90,0.6)" letterSpacing="2">SECTION 03</text>
  </svg>
);

const ScreenshotMirror = ({ rotated180 = false }) => (
  <svg viewBox="0 0 400 250" preserveAspectRatio="xMidYMid slice" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", transform: rotated180 ? "rotate(180deg)" : "none" }}>
    <defs>
      <linearGradient id="mir-bg" x1="0" x2="1" y1="0" y2="1">
        <stop offset="0%" stopColor="#221810"/>
        <stop offset="100%" stopColor="#0c0805"/>
      </linearGradient>
    </defs>
    <rect width="400" height="250" fill="url(#mir-bg)"/>
    <rect x="50" y="50" width="180" height="14" rx="3" fill="rgba(225,160,90,0.7)"/>
    <rect x="50" y="76" width="240" height="6" rx="2" fill="rgba(255,255,255,0.55)"/>
    <rect x="50" y="92" width="200" height="6" rx="2" fill="rgba(255,255,255,0.35)"/>
    <rect x="50" y="125" width="290" height="3" rx="1.5" fill="rgba(255,255,255,0.16)"/>
    <rect x="50" y="137" width="250" height="3" rx="1.5" fill="rgba(255,255,255,0.12)"/>
    <rect x="50" y="149" width="220" height="3" rx="1.5" fill="rgba(255,255,255,0.10)"/>
    {/* "mirrored" overlay */}
    <rect x="280" y="190" width="86" height="22" rx="11" fill="rgba(225,160,90,0.18)" stroke="rgba(225,160,90,0.45)"/>
    <text x="323" y="206" textAnchor="middle" fontFamily="Geist Mono, monospace" fontSize="9" fill="rgba(225,160,90,1)" letterSpacing="1.5">MIRROR · 02</text>
  </svg>
);

const ScreenshotNotes = () => (
  <svg viewBox="0 0 400 250" preserveAspectRatio="xMidYMid slice" style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
    <defs>
      <linearGradient id="notes-bg" x1="0" x2="1" y1="0" y2="1">
        <stop offset="0%" stopColor="#16191e"/>
        <stop offset="100%" stopColor="#0a0c0e"/>
      </linearGradient>
    </defs>
    <rect width="400" height="250" fill="url(#notes-bg)"/>
    <text x="40" y="50" fontFamily="Geist Mono, monospace" fontSize="11" fill="rgba(225,160,90,0.6)" letterSpacing="1.5">SPEAKER NOTES · 03/27</text>
    <rect x="40" y="64" width="320" height="3" rx="1.5" fill="rgba(255,255,255,0.45)"/>
    <rect x="40" y="74" width="290" height="3" rx="1.5" fill="rgba(255,255,255,0.4)"/>
    <rect x="40" y="84" width="280" height="3" rx="1.5" fill="rgba(255,255,255,0.35)"/>
    <rect x="40" y="94" width="240" height="3" rx="1.5" fill="rgba(255,255,255,0.3)"/>
    <rect x="40" y="116" width="40" height="20" rx="4" fill="rgba(225,160,90,0.18)"/>
    <text x="60" y="130" textAnchor="middle" fontFamily="Geist Mono, monospace" fontSize="11" fill="rgba(225,160,90,0.9)">12:34</text>
    <rect x="90" y="120" width="200" height="3" rx="1.5" fill="rgba(255,255,255,0.25)"/>
    <rect x="40" y="160" width="200" height="3" rx="1.5" fill="rgba(255,255,255,0.18)"/>
    <rect x="40" y="172" width="240" height="3" rx="1.5" fill="rgba(255,255,255,0.18)"/>
  </svg>
);

const Screenshot = ({ kind, rotation }) => {
  const rotated = rotation === 180;
  if (kind === "ink") return <ScreenshotInk/>;
  if (kind === "slides") return <ScreenshotSlides rotated180={rotated}/>;
  if (kind === "mirror") return <ScreenshotMirror rotated180={rotated}/>;
  if (kind === "notes") return <ScreenshotNotes/>;
  return null;
};

// ========== Virtual displays + PiPs (extra fixtures) ==========
// A virtual display is a CoreDisplayKit-backed "headless" framebuffer (great for recording, BlackHole-Video-style).
// A PiP is a live mirror window of a real or virtual display, hosted on the built-in.
// Both appear as first-class entities the user can manage.

const VIRTUAL_FIXTURES = [
  {
    id: 91,
    cgID: "0xVD000091",
    edid: "VIRTUAL-1080p",
    vendor: "wdm",
    model: "Virtual Display (1080p)",
    serial: "VD-091",
    name: "Recording Canvas",
    alias: "rec-canvas",
    kind: "virtual",
    main: false, mirroredFrom: null,
    res: [1920, 1080], refresh: 60, scale: 1, rotation: 0, flip: "none",
    brightness: null, hdr: false,
    caps: { brightness: "off", rotation: "ok", flip: "ok", hdr: "off", reset: "ok", destroy: "ok" },
    geom: { x: 0.04, y: 0.06, w: 0.16, h: 0.22 },
    color: "ink",
  },
];

const PIP_FIXTURES = [
  {
    id: 81,
    pipOf: 2, // mirror of ACME Projector
    name: "PiP · ACME 4K",
    alias: "pip-acme",
    kind: "pip",
    res: [1280, 720], refresh: 60,
    geom: { x: 0.78, y: 0.62, w: 0.16, h: 0.10 }, // sits on built-in
    color: "slides",
    flipH: false,
    onTop: true,
    recording: false,
  },
];

// Recording state machine — one record session per source display
// status: "idle" | "recording" | "paused" | "saved"

// ========== Detection issues (pre-canned demo state) ==========
// Used to demo "didn't detect" / "wrong ratio" / "stale EDID" recoveries.
const DETECTION_ISSUES = {
  // example keyed by display id — undefined = healthy
  // 2: { kind: "stale-edid", msg: "EDID block reports 16:9 but framebuffer is 16:10" },
  // 3: { kind: "not-detected", msg: "Plugged in but no EDID — try Force-detect" },
};

Object.assign(window, { Icon, DISPLAYS_2, DISPLAYS_3, DISPLAYS_4, MODES, PROFILES, Screenshot, VIRTUAL_FIXTURES, PIP_FIXTURES, DETECTION_ISSUES });
