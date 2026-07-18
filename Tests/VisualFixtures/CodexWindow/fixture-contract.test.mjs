import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

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
  ]);
  assert.ok(Object.isFrozen(FIXTURE_ROUTES));
  assert.ok(Object.isFrozen(FIXTURE_VIEWPORTS));
  assert.ok(FIXTURE_VIEWPORTS.every(Object.isFrozen));
  assert.equal(EXPECTED_FIXTURE_SCENE_COUNT, 96);
  assert.ok(MINIMUM_ROUTE_PHASH_DISTANCE >= 12);
  assert.ok(MINIMUM_CROSS_THEME_PHASH_DISTANCE >= 12);
  assert.equal(EXPORTER_CONTRACT_MARKER, "offline-theme-fixture-payload-v1");
  assert.ok(EXPECTED_SURFACE_ANNOTATIONS.length >= 17);
  assert.deepEqual(
    EXPECTED_SURFACE_ANNOTATIONS.find(({ selectorKey }) => selectorKey === "threadScroll"),
    { selectorKey: "threadScroll", surface: "task-transcript" },
  );
});

test("the exporter payload is strict, profile-owned, and expands to exactly 96 scenes", () => {
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
  }));
}

function countOccurrences(source, token) {
  return source.split(token).length - 1;
}
