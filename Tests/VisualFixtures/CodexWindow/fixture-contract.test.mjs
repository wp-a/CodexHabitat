import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import * as fixtureContract from "./fixture-contract.mjs";

import {
  EXPECTED_FIXTURE_SCENE_COUNT,
  EXPECTED_SURFACE_ANNOTATIONS,
  EXPORTER_CONTRACT_MARKER,
  FIXTURE_LABEL,
  FIXTURE_ROUTES,
  FIXTURE_VIEWPORTS,
  LATEST_PROFILE_ID,
  MINIMUM_CROSS_THEME_PHASH_DISTANCE,
  MINIMUM_ROUTE_PHASH_DISTANCE,
  REQUIRED_SURFACE_SELECTORS,
  assertSceneMaterialHierarchy,
  assertSceneDifferences,
  classifyFixtureRequest,
  enumerateFixtureScenarios,
  fixtureSourceFingerprint,
  fingerprintArtDataURL,
  fingerprintExporterContract,
  fingerprintProfile,
  fingerprintThemeTemplate,
  fingerprintThemeSource,
  validateFixturePayload,
  validateFixtureSource,
} from "./fixture-contract.mjs";

const fixtureRoot = new URL("./", import.meta.url);
const representativeTemplate = "/* representative Codex theme template */\n";

test("the representative DOM is fixed and explicitly marked as offline", async () => {
  const html = await readFile(new URL("index.html", fixtureRoot), "utf8");
  const css = await readFile(new URL("styles.css", fixtureRoot), "utf8");

  assert.equal(FIXTURE_LABEL, "OFFLINE THEME FIXTURE");
  assert.equal(countOccurrences(html, FIXTURE_LABEL), 1);
  assert.match(html, /data-offline-theme-fixture="true"/);
  assert.equal(countOccurrences(html, "data-fixture-dense-sidebar"), 1);
  assert.ok(countOccurrences(html, "data-fixture-sidebar-row") >= 8);
  assert.match(html, /[\u3400-\u9fff]/u);
  assert.doesNotMatch(html, /data-radix-popper-content-wrapper="" hidden/);
  assert.doesNotThrow(() => validateFixtureSource(html, css));
  assert.match(fixtureSourceFingerprint(html, css), /^[a-f0-9]{64}$/);

  for (const selector of REQUIRED_SURFACE_SELECTORS) {
    assert.equal(
      countOccurrences(html, selector.fixtureToken),
      1,
      `${selector.name} must have one stable representative node`,
    );
  }
});

test("the fixture contract rejects remote or executable document content", () => {
  for (const unsafeSource of [
    '<script src="https://example.test/remote.js"></script>',
    '<img src="//example.test/tracker.png">',
    '<a href="ftp://example.test/archive">archive</a>',
    '<meta http-equiv="refresh" content="0;url=https://example.test">',
    '<script>document.body.textContent = "mutable"</script>',
    '<button onclick="alert(1)">unsafe</button>',
  ]) {
    assert.throws(() => validateFixtureSource(unsafeSource, ""), /unsafe fixture source/);
  }
  assert.throws(
    () => validateFixtureSource("<main></main>", '@import "https://example.test/theme.css";'),
    /unsafe fixture source/,
  );
});

test("all network protocols are blocked while bounded local resources remain usable", () => {
  const fixtureDocument = "file:///tmp/codex-window/index.html";
  const decisions = new Map([
    ["file:///tmp/codex-window/index.html", "allow"],
    ["file:///tmp/codex-window/styles.css", "allow"],
    ["file:///tmp/codex-window/render.mjs", "block"],
    ["file:///tmp/codex-window-escape/secret.css", "block"],
    ["data:image/png;base64,AA==", "allow"],
    ["data:text/html;base64,PHNjcmlwdD4=", "block"],
    ["blob:null/local-art", "allow"],
    ["about:blank", "allow"],
    ["https://example.test/theme.css", "block"],
    ["http://127.0.0.1:8080/payload", "block"],
    ["ws://127.0.0.1:8080/session", "block"],
    ["wss://example.test/session", "block"],
    ["ftp://example.test/archive", "block"],
    ["javascript:alert(1)", "block"],
  ]);

  for (const [url, expected] of decisions) {
    assert.equal(classifyFixtureRequest(url, fixtureDocument), expected, url);
  }
});

test("routes and viewports are deterministic and release-independent", () => {
  assert.deepEqual(FIXTURE_ROUTES, ["home", "task"]);
  assert.deepEqual(FIXTURE_VIEWPORTS, [
    { id: "wide", width: 1512, height: 982 },
    { id: "narrow", width: 1180, height: 820 },
    { id: "compact", width: 860, height: 720 },
  ]);
  assert.ok(Object.isFrozen(FIXTURE_ROUTES));
  assert.ok(Object.isFrozen(FIXTURE_VIEWPORTS));
  assert.ok(FIXTURE_VIEWPORTS.every(Object.isFrozen));
  assert.equal(EXPECTED_FIXTURE_SCENE_COUNT, 144);
  assert.ok(MINIMUM_ROUTE_PHASH_DISTANCE >= 12);
  assert.ok(MINIMUM_CROSS_THEME_PHASH_DISTANCE >= 12);
  assert.equal(EXPORTER_CONTRACT_MARKER, "offline-theme-fixture-payload-v1");
  assert.ok(EXPECTED_SURFACE_ANNOTATIONS.length >= 17);
  assert.deepEqual(
    EXPECTED_SURFACE_ANNOTATIONS.find(({ selectorKey }) => selectorKey === "threadScroll"),
    { selectorKey: "threadScroll", surface: "task-transcript" },
  );
});

test("the exporter payload is strict, profile-owned, and expands to exactly 144 scenes", () => {
  const payload = representativePayload();

  assert.doesNotThrow(() => validateFixturePayload(payload, representativeTemplate));
  assert.equal(payload.profile.id, LATEST_PROFILE_ID);
  const scenarios = enumerateFixtureScenarios(payload, representativeTemplate);
  assert.equal(scenarios.length, EXPECTED_FIXTURE_SCENE_COUNT);
  assert.equal(new Set(scenarios.map(({ key }) => key)).size, EXPECTED_FIXTURE_SCENE_COUNT);
  assert.deepEqual(
    [...new Set(scenarios.map(({ route }) => route))],
    ["home", "task"],
  );

  for (const mutate of [
    (value) => { value.schemaVersion = 2; },
    (value) => { value.routes = ["task", "home"]; },
    (value) => { value.profile.id = "legacy-profile"; },
    (value) => { value.profile.selectors.composer = ""; },
    (value) => { value.themes.pop(); },
    (value) => { value.themes[1].id = value.themes[0].id; },
    (value) => { value.themes[0].backgroundDataURL = "https://example.test/art.jpg"; },
    (value) => { value.themes[0].installerExpression = ""; },
    (value) => { value.themes[0].sourceFingerprint = "not-sha256"; },
    (value) => { value.profileFingerprint = "d".repeat(64); },
    (value) => { value.templateFingerprint = "d".repeat(64); },
    (value) => { value.exporterContractFingerprint = "d".repeat(64); },
    (value) => { value.themes[0].artFingerprint = "d".repeat(64); },
    (value) => { value.themes[0].sourceFingerprint = "d".repeat(64); },
  ]) {
    const invalid = structuredClone(payload);
    mutate(invalid);
    assert.throws(
      () => validateFixturePayload(invalid, representativeTemplate),
      /invalid offline fixture payload/,
    );
  }
  assert.throws(
    () => validateFixturePayload(payload, "/* different template */\n"),
    /invalid offline fixture payload/,
  );
});

test("scene difference checks reject blank or visually identical captures", () => {
  assert.ok(MINIMUM_ROUTE_PHASH_DISTANCE > 0);
  assert.ok(MINIMUM_CROSS_THEME_PHASH_DISTANCE > 0);
  const healthy = representativeMetrics();
  assert.doesNotThrow(() => assertSceneDifferences(healthy));

  const blank = structuredClone(healthy);
  blank[0].nonblankRatio = 0;
  assert.throws(() => assertSceneDifferences(blank), /nonblank/);

  const identicalRoute = structuredClone(healthy);
  identicalRoute[1].perceptualHash = identicalRoute[0].perceptualHash;
  assert.throws(() => assertSceneDifferences(identicalRoute), /home\/task pHash distance/);

  const identicalTheme = structuredClone(healthy);
  identicalTheme[2].perceptualHash = identicalTheme[0].perceptualHash;
  assert.throws(() => assertSceneDifferences(identicalTheme), /cross-theme pHash distance/);
});

test("scene material checks enforce one computed background layer on real DOM paths", () => {
  const healthy = representativeMetrics();
  assert.doesNotThrow(() => assertSceneMaterialHierarchy(healthy));

  for (const [field, value, expected] of [
    ["minimumTextContrast", 4.49, /minimum text contrast/],
    ["minimumControlContrast", 2.99, /minimum control contrast/],
    ["homeContentBackgroundAlpha", 0.2, /home content background alpha/],
    ["homeSuggestionsBackgroundAlpha", 0.2, /home suggestions background alpha/],
    ["homeActionBackgroundAlpha", 0.7, /home action background alpha/],
    ["composerContextBackgroundAlpha", 0.2, /composer context background alpha/],
    ["composerBackgroundAlpha", 0.5, /composer background alpha/],
  ]) {
    const invalid = structuredClone(healthy);
    invalid.find(({ route }) => route === "home")[field] = value;
    assert.throws(() => assertSceneMaterialHierarchy(invalid), expected);
  }

  const missingContrastTarget = structuredClone(healthy);
  missingContrastTarget[0].contrastSamples.pop();
  assert.throws(
    () => assertSceneMaterialHierarchy(missingContrastTarget),
    /contrast target .* is missing/,
  );

  for (const [kind, ratio, expected] of [
    ["normalText", 4.49, /normalText contrast/],
    ["largeText", 2.99, /largeText contrast/],
    ["control", 2.99, /control contrast/],
  ]) {
    const lowContrast = structuredClone(healthy);
    const sample = lowContrast
      .flatMap(({ contrastSamples }) => contrastSamples)
      .find((candidate) => candidate.kind === kind);
    assert.ok(sample, `${kind} representative sample is missing`);
    sample.ratio = ratio;
    assert.throws(() => assertSceneMaterialHierarchy(lowContrast), expected);
  }

  const emptyPixelEvidence = structuredClone(healthy);
  emptyPixelEvidence[0].contrastSamples[0].pixelCount = 0;
  assert.throws(
    () => assertSceneMaterialHierarchy(emptyPixelEvidence),
    /pixel evidence/,
  );

  const missingNodeEvidence = structuredClone(healthy);
  missingNodeEvidence[0].contrastSamples[0].evidenceCount = 0;
  assert.throws(
    () => assertSceneMaterialHierarchy(missingNodeEvidence),
    /node evidence/,
  );

  const excessiveTaskArtworkLeak = structuredClone(healthy);
  excessiveTaskArtworkLeak.find(({ route }) => route === "task").taskReadingArtworkLeak = 0.081;
  assert.throws(
    () => assertSceneMaterialHierarchy(excessiveTaskArtworkLeak),
    /task reading artwork leak/,
  );

  const missingTaskTiles = structuredClone(healthy);
  missingTaskTiles.find(({ route }) => route === "task").taskReadingTileCount = 0;
  assert.throws(
    () => assertSceneMaterialHierarchy(missingTaskTiles),
    /task reading tile count/,
  );

  const missingAncestor = structuredClone(healthy);
  missingAncestor[0].homeMaterialChain = missingAncestor[0].homeMaterialChain.filter(
    ({ surface }) => surface !== "home-suggestions",
  );
  assert.throws(() => assertSceneMaterialHierarchy(missingAncestor), /home material chain/);

  for (const [metricIndex, chainField, surface, expected] of [
    [0, "homeMaterialChain", "main-surface", /home material chain main-surface alpha/],
    [1, "composerMaterialChain", "main-surface", /composer material chain main-surface alpha/],
  ]) {
    const opaqueAncestor = structuredClone(healthy);
    opaqueAncestor[metricIndex][chainField].find(
      (entry) => entry.surface === surface,
    ).backgroundAlpha = 0.2;
    assert.throws(() => assertSceneMaterialHierarchy(opaqueAncestor), expected);
  }

  for (const [mutate, expected] of [
    [(metric) => { metric.layoutGeometry.composer.centerDeltaX = 1.01; }, /composer geometry center delta/],
    [(metric) => { metric.layoutGeometry.home.marginDeltaX = 1.01; }, /home geometry margin delta/],
    [(metric) => { metric.layoutGeometry.home.marginDeltaX = -1; }, /home geometry margin delta/],
    [(metric) => { metric.denseSidebar.rowCount = 7; }, /dense sidebar row count/],
    [(metric) => { metric.denseSidebar.rowHeightDelta = 0.51; }, /row height delta/],
    [(metric) => { metric.denseSidebar.truncatedCount = 1; }, /truncated count/],
    [(metric) => { metric.denseSidebar.rowsWithinViewport = false; }, /rowsWithinViewport/],
    [(metric) => { metric.denseSidebar.rowsDoNotOverlap = false; }, /rowsDoNotOverlap/],
    [(metric) => { metric.denseSidebar.ellipsisContractValid = false; }, /ellipsisContractValid/],
    [(metric) => { metric.denseSidebar.selectedFontWeight = 500; }, /selected structural affordance/],
    [(metric) => {
      metric.denseSidebar.selectedShadowGeometry = metric.denseSidebar.peerShadowGeometry;
    }, /selected structural affordance/],
    [(metric) => { metric.sceneContinuity.titlebarBackgroundAlpha = 0.3; }, /titlebar background alpha/],
    [(metric) => { metric.sceneContinuity.titlebarHasIndependentArtwork = true; }, /owns independent artwork/],
    [(metric) => { metric.sceneContinuity.titlebarBackdropFilter = "blur(8px)"; }, /backdrop filter/],
    [(metric) => { metric.sceneContinuity.mainLeftBoundaryWidth = 1; }, /main left boundary width/],
    [(metric) => { metric.sceneArtworkZones.find(({ id }) => id === "titlebar").maximumPixelDelta = 0; }, /titlebar real artwork maximum pixel delta/],
    [(metric) => { metric.sceneArtworkZones.find(({ id }) => id === "sidebar").meanPixelDelta = 0; }, /sidebar real artwork mean pixel delta/],
    [(metric) => { metric.sceneTransmissionZones.find(({ id }) => id === "titlebar").tileCount = 0; }, /titlebar transmission tile count/],
    [(metric) => { metric.sceneTransmissionZones.find(({ id }) => id === "sidebar").changedPixelRatio = 0.019; }, /sidebar transmission pixel ratio/],
    [(metric) => { metric.sceneTransmissionZones.find(({ id }) => id === "main").qualifyingTileCount = 2; }, /main qualifying tile count/],
    [(metric) => { metric.sceneTransmissionZones.find(({ id }) => id === "main").qualifyingTileRatio = 0.74; }, /main qualifying tile ratio/],
    [(metric) => {
      metric.sceneTransmissionZones[1] = structuredClone(metric.sceneTransmissionZones[0]);
    }, /scene transmission zones/],
    [(metric) => { metric.interactionStates.normal.sidebar.active = null; }, /sidebar active is missing/],
    [(metric) => { metric.interactionStates.normal.home.hover.rect.x = 0.26; }, /home hover changes x/],
    [(metric) => {
      metric.interactionStates.reduced.idle.home.transitionDuration = "140ms";
    }, /reduced home transition is not zero/],
  ]) {
    const invalid = structuredClone(healthy);
    mutate(invalid[0]);
    assert.throws(() => assertSceneMaterialHierarchy(invalid), expected);
  }
});

test("pixel summaries preserve the weakest node and strongest local artwork leak", () => {
  assert.equal(typeof fixtureContract.summarizeContrastNodeSamples, "function");
  assert.equal(typeof fixtureContract.percentileLocalArtworkLeak, "function");
  const summary = fixtureContract.summarizeContrastNodeSamples(
    { id: "multi-node", kind: "normalText" },
    [
      { label: "first", ratio: 8.4, pixelCount: 120, rectCount: 3 },
      { label: "second", ratio: 3.2, pixelCount: 12, rectCount: 1 },
    ],
  );
  assert.equal(summary.ratio, 3.2);
  assert.equal(summary.pixelCount, 132);
  assert.equal(summary.evidenceCount, 2);
  assert.equal(summary.rectCount, 4);
  assert.equal(summary.weakestNodeLabel, "second");
  assert.equal(typeof fixtureContract.mergeContrastFrameSamples, "function");
  const merged = fixtureContract.mergeContrastFrameSamples(
    { ratio: 6.2, weakestNodeLabel: "top", pixelCount: 20, evidenceCount: 1, rectCount: 1 },
    { ratio: 4.7, weakestNodeLabel: "bottom", pixelCount: 12, evidenceCount: 1, rectCount: 2 },
  );
  assert.equal(merged.ratio, 4.7);
  assert.equal(merged.weakestNodeLabel, "bottom");
  assert.equal(merged.pixelCount, 32);
  assert.equal(merged.evidenceCount, 2);
  assert.equal(merged.rectCount, 3);
  assert.equal(
    fixtureContract.percentileLocalArtworkLeak([0.01, 0.02, 0.03, 0.04, 0.12], 0.75),
    0.04,
  );
});

function representativePayload() {
  const themes = Array.from({ length: 24 }, (_, index) => ({
    id: `fixture-theme-${String(index + 1).padStart(2, "0")}`,
    name: `Fixture Theme ${index + 1}`,
    styleFamily: `fixture-family-${index + 1}`,
    backgroundDataURL: "data:image/jpeg;base64,/9j/2Q==",
    installerExpression: "(() => ({ installed: true }))()",
    sourceFingerprint: "",
    cssFingerprint: "b".repeat(64),
    artFingerprint: "",
  }));
  for (const theme of themes) {
    theme.artFingerprint = fingerprintArtDataURL(theme.backgroundDataURL);
    theme.sourceFingerprint = fingerprintThemeSource(theme);
  }
  const profile = {
    id: LATEST_PROFILE_ID,
    minimumVersion: "26.715.31925",
    maximumVersionExclusive: "26.715.31926",
    selectors: {
      sidebar: "aside.app-shell-left-panel",
      mainSurface: "main.main-surface",
      composer: ".composer-surface-chrome",
      threadScroll: ".thread-scroll-container",
      popover: "[data-radix-popper-content-wrapper]",
      header: "main.main-surface > header.app-header-tint",
      homeMarker: '[data-testid="home-icon"]',
      appShell: "#root",
      homeContent: 'main.main-surface [role="main"]',
      homeSuggestions: '[class~="group/home-suggestions"]',
      selectedNavigation: "aside.app-shell-left-panel [aria-current]",
      taskTranscript: ".thread-scroll-container",
      userMessageSurface: "[data-user-message-bubble]",
      messageSurface: "[data-content-search-unit-key]",
      codeSurface: "[data-content-search-unit-key] pre",
      toolSurfaces: [
        '[data-content-search-unit-key] [data-testid="exec-shell-body"]',
        '[data-content-search-unit-key] [data-testid="dynamic-tool-call-group-body"]',
        '[data-content-search-unit-key] [data-testid="pending-mcp-tool-calls-body"]',
      ],
      sidebarResizeChrome: "aside.app-shell-left-panel .sidebar-resize-handle-line",
      topFade: ".app-shell-main-content-top-fade",
      bottomFade: '.thread-scroll-container [data-thread-scroll-footer="true"] > [class~="pointer-events-none"]',
      composerContext: "main.main-surface [data-codex-composer-root]",
    },
  };
  return {
    schemaVersion: 1,
    profileVersion: "26.715.31925",
    routes: ["home", "task"],
    profile,
    profileFingerprint: fingerprintProfile(profile),
    templateFingerprint: fingerprintThemeTemplate(representativeTemplate),
    exporterContractFingerprint: fingerprintExporterContract(),
    themes,
  };
}

function representativeMetrics() {
  const hashes = [
    "0000000000000000",
    "000000000000ffff",
    "ffffffff00000000",
    "ffffffffffffffff",
  ];
  return hashes.map((perceptualHash, index) => ({
    themeID: index < 2 ? "theme-a" : "theme-b",
    route: index % 2 === 0 ? "home" : "task",
    viewport: "wide",
    perceptualHash,
    nonblankRatio: 0.8,
    minimumTextContrast: 5,
    minimumControlContrast: 3.5,
    contrastSamples: representativeContrastSamples(index % 2 === 0 ? "home" : "task"),
    taskReadingArtworkLeak: index % 2 === 0 ? null : 0.04,
    taskReadingTileCount: index % 2 === 0 ? null : 12,
    homeContentBackgroundAlpha: index % 2 === 0 ? 0 : null,
    homeSuggestionsBackgroundAlpha: index % 2 === 0 ? 0 : null,
    homeActionBackgroundAlpha: index % 2 === 0 ? 0.82 : null,
    composerContextBackgroundAlpha: 0,
    composerBackgroundAlpha: 0.86,
    layoutGeometry: {
      home: index % 2 === 0 ? {
        centerDeltaX: 0,
        marginDeltaX: 0,
        leftMargin: 120,
        rightMargin: 120,
        withinMain: true,
      } : null,
      composer: {
        centerDeltaX: 0,
        marginDeltaX: 0,
        leftMargin: 80,
        rightMargin: 80,
        withinMain: true,
      },
    },
    denseSidebar: {
      rowCount: 8,
      rowHeight: 36,
      rowHeightDelta: 0,
      truncatedCount: 3,
      rowsWithinViewport: true,
      rowsDoNotOverlap: true,
      ellipsisContractValid: true,
      selectedFontWeight: 600,
      peerFontWeight: 400,
      selectedShadowGeometry: "inset 3px 0px 0px 0px",
      peerShadowGeometry: "none",
      selectedMaxBorderWidth: 1,
      peerMaxBorderWidth: 1,
    },
    sceneContinuity: {
      titlebarBackgroundAlpha: 0.16,
      sidebarBackgroundAlpha: 0,
      mainBackgroundAlpha: 0,
      titlebarHasIndependentArtwork: false,
      sidebarHasIndependentArtwork: false,
      mainHasIndependentArtwork: false,
      titlebarBackdropFilter: "none",
      sidebarBoundaryWidth: 1,
      mainLeftBoundaryWidth: 0,
    },
    sceneTransmissionZones: ["titlebar", "sidebar", "main"].map((id) => ({
      id,
      tileCount: 12,
      changedPixelRatio: 0.2,
      qualifyingTileCount: 10,
      qualifyingTileRatio: 0.9,
    })),
    sceneArtworkZones: ["titlebar", "sidebar", "main"].map((id) => ({
      id,
      tileCount: 12,
      changedPixelRatio: 0.2,
      qualifyingTileCount: 10,
      qualifyingTileRatio: 0.9,
      maximumPixelDelta: 96,
      meanPixelDelta: 12,
    })),
    interactionStates: index % 2 === 0 ? representativeInteractionStates() : null,
    homeMaterialChain: index % 2 === 0 ? [
      { surface: "home-action", backgroundAlpha: 0.82 },
      { surface: "home-suggestions", backgroundAlpha: 0 },
      { surface: "home-content", backgroundAlpha: 0 },
      { surface: "main-surface", backgroundAlpha: 0 },
      { surface: "app-shell", backgroundAlpha: 1 },
    ] : null,
    composerMaterialChain: [
      { surface: "composer", backgroundAlpha: 0.86 },
      { surface: "composer-context", backgroundAlpha: 0 },
      { surface: "main-surface", backgroundAlpha: 0 },
      { surface: "app-shell", backgroundAlpha: 1 },
    ],
  }));
}

function representativeInteractionStates() {
  const snapshot = (overrides = {}) => ({
    rect: { x: 0, y: 0, width: 180, height: 44 },
    backgroundColor: "rgba(30, 40, 50, 0.82)",
    borderColor: "rgba(120, 140, 160, 0.28)",
    boxShadow: "rgba(255, 255, 255, 0.1) 0px 1px 0px 0px inset",
    opacity: "1",
    transform: "none",
    outlineColor: "rgb(120, 180, 240)",
    outlineOffset: "0px",
    outlineStyle: "none",
    outlineWidth: "0px",
    fontWeight: "400",
    transitionDuration: "0.14s, 0.14s",
    transitionDelay: "0s",
    animationName: "none",
    animationDuration: "0s",
    matchesHover: false,
    matchesActive: false,
    matchesFocusVisible: false,
    matchesFocusWithin: false,
    ...overrides,
  });
  const homeIdle = snapshot();
  const sidebarIdle = snapshot({ rect: { x: 0, y: 0, width: 220, height: 36 } });
  const composerIdle = snapshot({ rect: { x: 0, y: 0, width: 620, height: 116 } });
  return {
    normal: {
      media: { finePointer: true, reducedMotion: false },
      transitions: { home: homeIdle, sidebar: sidebarIdle, composer: composerIdle },
      home: {
        idle: homeIdle,
        hover: snapshot({ backgroundColor: "rgba(34, 44, 54, 0.9)", matchesHover: true }),
        active: snapshot({
          backgroundColor: "rgba(38, 48, 58, 0.94)",
          boxShadow: "rgba(120, 180, 240, 0.54) 0px 0px 0px 1px inset",
          matchesHover: true,
          matchesActive: true,
        }),
        focusVisible: snapshot({
          outlineOffset: "2px",
          outlineStyle: "solid",
          outlineWidth: "2px",
          matchesFocusVisible: true,
        }),
      },
      sidebar: {
        idle: sidebarIdle,
        hover: snapshot({
          rect: sidebarIdle.rect,
          backgroundColor: "rgba(34, 44, 54, 0.54)",
          matchesHover: true,
        }),
        active: snapshot({
          rect: sidebarIdle.rect,
          backgroundColor: "rgba(38, 48, 58, 0.68)",
          boxShadow: "rgb(120, 180, 240) 3px 0px 0px 0px inset",
          matchesHover: true,
          matchesActive: true,
        }),
        selected: snapshot({
          rect: sidebarIdle.rect,
          boxShadow: "rgb(120, 180, 240) 3px 0px 0px 0px inset",
          fontWeight: "600",
        }),
      },
      composer: {
        idle: composerIdle,
        focusWithin: snapshot({
          rect: composerIdle.rect,
          borderColor: "rgb(120, 180, 240)",
          boxShadow: "rgba(120, 180, 240, 0.58) 0px 0px 0px 2px",
          matchesFocusWithin: true,
        }),
        inputFocus: snapshot({ matchesFocusVisible: true }),
      },
    },
    reduced: {
      mediaMatches: true,
      idle: {
        home: snapshot({ transitionDuration: "0s" }),
        sidebar: snapshot({ transitionDuration: "0s" }),
        composer: snapshot({ transitionDuration: "0s" }),
      },
      homeHover: snapshot({
        backgroundColor: "rgba(34, 44, 54, 0.9)",
        transitionDuration: "0s",
        matchesHover: true,
      }),
      composerFocusWithin: snapshot({
        borderColor: "rgb(120, 180, 240)",
        boxShadow: "rgba(120, 180, 240, 0.58) 0px 0px 0px 2px",
        transitionDuration: "0s",
        matchesFocusWithin: true,
      }),
      runningAnimations: 0,
    },
  };
}

function representativeContrastSamples(route) {
  const common = [
    ["sidebar-primary", "normalText", 5],
    ["sidebar-selected", "normalText", 5],
    ["sidebar-secondary", "normalText", 5],
    ["composer-placeholder", "normalText", 5],
    ["composer-submit", "control", 3.5],
  ];
  const routeSpecific = route === "home"
    ? [
      ["home-primary", "largeText", 3.5],
      ["home-secondary", "normalText", 5],
      ["home-actions", "normalText", 5],
    ]
    : [
      ["task-request", "normalText", 5],
      ["task-response-primary", "normalText", 5],
      ["task-response-secondary", "normalText", 5],
      ["task-code", "normalText", 5],
      ["task-tool-primary", "normalText", 5],
      ["task-tool-secondary", "normalText", 5],
      ["task-tool-grid", "normalText", 5],
    ];
  return [...common, ...routeSpecific].map(([id, kind, ratio]) => ({
    id,
    kind,
    ratio,
    pixelCount: 24,
    evidenceCount: 1,
    rectCount: 1,
  }));
}

function countOccurrences(source, token) {
  return source.split(token).length - 1;
}
