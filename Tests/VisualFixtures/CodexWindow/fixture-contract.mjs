import { createHash } from "node:crypto";

export const FIXTURE_LABEL = "OFFLINE THEME FIXTURE";
export const LATEST_PROFILE_ID = "codex-26.715.31925";
export const FIXTURE_ROUTES = Object.freeze(["home", "task"]);
export const FIXTURE_VIEWPORTS = Object.freeze([
  Object.freeze({ id: "wide", width: 1512, height: 982 }),
  Object.freeze({ id: "narrow", width: 1180, height: 820 }),
  Object.freeze({ id: "compact", width: 860, height: 720 }),
]);
export const EXPECTED_THEME_COUNT = 24;
export const EXPECTED_FIXTURE_SCENE_COUNT =
  EXPECTED_THEME_COUNT * FIXTURE_ROUTES.length * FIXTURE_VIEWPORTS.length;
export const REQUIRED_STYLE_FAMILIES = Object.freeze([
  "arcade",
  "retroMessenger",
  "greenChat",
  "classicDesktop",
  "gameCinematic",
  "cozyWorld",
  "animeEnergy",
  "fantasyAdventure",
  "pixelWorld",
]);
export const REQUIRED_INTERACTION_SCENARIOS = Object.freeze([
  Object.freeze({ route: "home", viewport: "wide" }),
  Object.freeze({ route: "home", viewport: "compact" }),
  Object.freeze({ route: "task", viewport: "wide" }),
]);
export const MINIMUM_ROUTE_PHASH_DISTANCE = 12;
export const MINIMUM_CROSS_THEME_PHASH_DISTANCE = 12;
export const MINIMUM_NONBLANK_RATIO = 0.05;
export const EXPORTER_CONTRACT_MARKER = "offline-theme-fixture-payload-v1";

const commonContrastTargets = [
  { id: "sidebar-primary", kind: "normalText", selector: ".app-shell-left-panel nav a:not([aria-current]), .fixture-recents a:not(.is-selected), .fixture-account" },
  { id: "sidebar-selected", kind: "normalText", selector: ".app-shell-left-panel [aria-current]" },
  { id: "sidebar-secondary", kind: "normalText", selector: ".fixture-recents h2" },
  { id: "composer-placeholder", kind: "normalText", selector: "#fixture-composer", pseudo: "placeholder" },
  { id: "composer-submit", kind: "control", selector: ".composer-surface-chrome button" },
].map((target) => Object.freeze(target));

const routeContrastTargets = {
  home: [
    { id: "home-primary", kind: "largeText", selector: ".fixture-home h1" },
    { id: "home-secondary", kind: "normalText", selector: ".fixture-home p" },
    { id: "home-actions", kind: "normalText", selector: '.group\\/home-suggestions :where(button, [role="button"])' },
  ],
  task: [
    { id: "task-request", kind: "normalText", selector: ".fixture-message h2, .fixture-message p" },
    { id: "task-response-primary", kind: "normalText", selector: ".fixture-response h2" },
    { id: "task-response-secondary", kind: "normalText", selector: ".fixture-response > p" },
    { id: "task-code", kind: "normalText", selector: ".fixture-response pre code" },
    { id: "task-tool-primary", kind: "normalText", selector: ".fixture-tool strong" },
    { id: "task-tool-secondary", kind: "normalText", selector: ".fixture-tool p" },
    { id: "task-tool-grid", kind: "normalText", selector: ".fixture-tool-grid > div" },
  ],
};

export const FIXTURE_CONTRAST_TARGETS = Object.freeze(Object.fromEntries(
  FIXTURE_ROUTES.map((route) => [
    route,
    Object.freeze([
      ...commonContrastTargets,
      ...routeContrastTargets[route].map((target) => Object.freeze(target)),
    ]),
  ]),
));

export const CONTRAST_THRESHOLDS = Object.freeze({
  normalText: 5,
  largeText: 3,
  control: 4.5,
});
export const MAXIMUM_TASK_READING_ARTWORK_LEAK = 0.08;
export const MAXIMUM_CENTER_DELTA_PX = 1;
export const MAXIMUM_ROW_HEIGHT_DELTA_PX = 0.5;
export const MINIMUM_DENSE_SIDEBAR_ROWS = 8;
export const REQUIRED_SCENE_ARTWORK_ZONES = Object.freeze(["titlebar", "sidebar", "main"]);
const minimumSceneTransmissionPixelRatios = Object.freeze({
  titlebar: 0.02,
  sidebar: 0.02,
  main: 0.02,
});

export function summarizeContrastNodeSamples(target, nodeSamples) {
  const samples = Array.isArray(nodeSamples) ? nodeSamples : [];
  const weakest = samples.reduce(
    (current, sample) => !current || sample.ratio < current.ratio ? sample : current,
    null,
  );
  return {
    id: target.id,
    kind: target.kind,
    ratio: samples.length > 0 ? Math.min(...samples.map(({ ratio }) => ratio)) : 0,
    pixelCount: samples.reduce((total, { pixelCount }) => total + pixelCount, 0),
    evidenceCount: samples.length,
    rectCount: samples.reduce((total, { rectCount }) => total + rectCount, 0),
    weakestNodeLabel: weakest?.label ?? null,
  };
}

export function mergeContrastFrameSamples(current, incoming) {
  if (!current) return incoming;
  const weakest = incoming.ratio < current.ratio ? incoming : current;
  return {
    ...current,
    ratio: weakest.ratio,
    weakestNodeLabel: weakest.weakestNodeLabel,
    pixelCount: current.pixelCount + incoming.pixelCount,
    evidenceCount: current.evidenceCount + incoming.evidenceCount,
    rectCount: current.rectCount + incoming.rectCount,
  };
}

export function percentileLocalArtworkLeak(tileLeaks, percentile = 0.95) {
  const finiteLeaks = Array.isArray(tileLeaks)
    ? tileLeaks.filter((value) => Number.isFinite(value))
    : [];
  if (finiteLeaks.length === 0) return null;
  finiteLeaks.sort((left, right) => left - right);
  const boundedPercentile = Math.max(0, Math.min(1, percentile));
  return finiteLeaks[Math.ceil((finiteLeaks.length - 1) * boundedPercentile)];
}

export const LATEST_PROFILE_SELECTORS = Object.freeze({
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
  toolSurfaces: Object.freeze([
    '[data-content-search-unit-key] [data-testid="exec-shell-body"]',
    '[data-content-search-unit-key] [data-testid="dynamic-tool-call-group-body"]',
    '[data-content-search-unit-key] [data-testid="pending-mcp-tool-calls-body"]',
  ]),
  sidebarResizeChrome: "aside.app-shell-left-panel .sidebar-resize-handle-line",
  topFade: ".app-shell-main-content-top-fade",
  bottomFade:
    '.thread-scroll-container [data-thread-scroll-footer="true"] > [class~="pointer-events-none"]',
  composerContext: "main.main-surface [data-codex-composer-root]",
});

export const EXPECTED_SURFACE_ANNOTATIONS = Object.freeze([
  Object.freeze({ selectorKey: "appShell", surface: "app-shell" }),
  Object.freeze({ selectorKey: "sidebar", surface: "sidebar" }),
  Object.freeze({ selectorKey: "mainSurface", surface: "main-surface" }),
  Object.freeze({ selectorKey: "header", surface: "header" }),
  Object.freeze({ selectorKey: "threadScroll", surface: "task-transcript" }),
  Object.freeze({ selectorKey: "composer", surface: "composer" }),
  Object.freeze({ selectorKey: "popover", surface: "popover" }),
  Object.freeze({ selectorKey: "homeContent", surface: "home-content" }),
  Object.freeze({ selectorKey: "homeSuggestions", surface: "home-suggestions" }),
  Object.freeze({ selectorKey: "selectedNavigation", surface: "selected-navigation" }),
  Object.freeze({ selectorKey: "userMessageSurface", surface: "user-message-surface" }),
  Object.freeze({ selectorKey: "messageSurface", surface: "message-surface" }),
  Object.freeze({ selectorKey: "codeSurface", surface: "code-surface" }),
  Object.freeze({ selectorKey: "toolSurfaces", surface: "tool-surface" }),
  Object.freeze({ selectorKey: "sidebarResizeChrome", surface: "sidebar-resize-chrome" }),
  Object.freeze({ selectorKey: "topFade", surface: "top-fade" }),
  Object.freeze({ selectorKey: "bottomFade", surface: "bottom-fade" }),
  Object.freeze({ selectorKey: "composerContext", surface: "composer-context" }),
]);

export const REQUIRED_SURFACE_SELECTORS = Object.freeze([
  Object.freeze({ name: "app shell", fixtureToken: 'id="root"' }),
  Object.freeze({ name: "synthetic titlebar", fixtureToken: 'data-fixture-surface="titlebar"' }),
  Object.freeze({ name: "sidebar", fixtureToken: 'class="app-shell-left-panel"' }),
  Object.freeze({ name: "main surface", fixtureToken: 'class="main-surface"' }),
  Object.freeze({ name: "header", fixtureToken: 'class="app-header-tint"' }),
  Object.freeze({ name: "home marker", fixtureToken: 'data-testid="home-icon"' }),
  Object.freeze({ name: "home content", fixtureToken: 'data-fixture-surface="home-content"' }),
  Object.freeze({ name: "home suggestions", fixtureToken: 'class="group/home-suggestions fixture-suggestions"' }),
  Object.freeze({ name: "thread scroll", fixtureToken: 'class="thread-scroll-container"' }),
  Object.freeze({ name: "user message", fixtureToken: "data-user-message-bubble" }),
  Object.freeze({ name: "message", fixtureToken: 'data-content-search-unit-key="fixture-response"' }),
  Object.freeze({ name: "code", fixtureToken: 'data-fixture-surface="code"' }),
  Object.freeze({ name: "composer", fixtureToken: 'class="composer-surface-chrome"' }),
  Object.freeze({ name: "popover", fixtureToken: 'data-radix-popper-content-wrapper=""' }),
]);

const unsafeFixtureSourcePatterns = Object.freeze([
  /(?:src|href)\s*=\s*["']https?:\/\//i,
  /(?:src|href)\s*=\s*["']\/\//i,
  /(?:src|href)\s*=\s*["'](?:ftp|ws|wss|javascript|file|blob):/i,
  /http-equiv\s*=\s*["']refresh["']/i,
  /<script(?:\s|>)/i,
  /\son[a-z]+\s*=/i,
  /@import\b/i,
  /url\(\s*["']?(?:https?|ftp|ws|wss|javascript|file|\/\/):/i,
]);

const sha256Pattern = /^[a-f0-9]{64}$/;
const identifierPattern = /^[a-z0-9][a-z0-9-]{0,79}$/;
const backgroundDataURLPattern = /^data:image\/(?:jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/;

export function validateFixtureSource(html, css = "") {
  if (
    typeof html !== "string"
    || typeof css !== "string"
    || unsafeFixtureSourcePatterns.some((pattern) => pattern.test(html) || pattern.test(css))
  ) {
    throw new Error("unsafe fixture source");
  }
}

export function fixtureSourceFingerprint(html, css) {
  validateFixtureSource(html, css);
  return sha256(`${html}\0${css}`);
}

export function validateFixturePayload(payload, themeTemplateSource) {
  try {
    require(typeof themeTemplateSource === "string" && themeTemplateSource.length > 0);
    assertExactKeys(payload, [
      "schemaVersion",
      "profileVersion",
      "routes",
      "profile",
      "profileFingerprint",
      "templateFingerprint",
      "exporterContractFingerprint",
      "themes",
    ]);
    require(payload.schemaVersion === 1);
    require(payload.profileVersion === "26.715.31925");
    require(arrayEquals(payload.routes, FIXTURE_ROUTES));
    requireSha256(payload.profileFingerprint);
    requireSha256(payload.templateFingerprint);
    require(payload.templateFingerprint === fingerprintThemeTemplate(themeTemplateSource));
    requireSha256(payload.exporterContractFingerprint);
    require(payload.exporterContractFingerprint === fingerprintExporterContract());

    assertExactKeys(payload.profile, [
      "id",
      "minimumVersion",
      "maximumVersionExclusive",
      "selectors",
    ]);
    require(payload.profile.id === LATEST_PROFILE_ID);
    require(payload.profile.minimumVersion === "26.715.31925");
    require(payload.profile.maximumVersionExclusive === "26.715.31926");
    validateLatestSelectors(payload.profile.selectors);
    require(payload.profileFingerprint === fingerprintProfile(payload.profile));

    require(Array.isArray(payload.themes) && payload.themes.length === EXPECTED_THEME_COUNT);
    const identifiers = new Set();
    for (const theme of payload.themes) {
      assertExactKeys(theme, [
        "id",
        "name",
        "styleFamily",
        "backgroundDataURL",
        "installerExpression",
        "sourceFingerprint",
        "cssFingerprint",
        "artFingerprint",
      ]);
      require(typeof theme.id === "string" && identifierPattern.test(theme.id));
      require(!identifiers.has(theme.id));
      identifiers.add(theme.id);
      require(typeof theme.name === "string" && theme.name.length > 0 && theme.name.length <= 120);
      require(
        typeof theme.styleFamily === "string"
        && /^[A-Za-z][A-Za-z0-9-]{0,79}$/.test(theme.styleFamily),
      );
      require(
        typeof theme.backgroundDataURL === "string"
        && theme.backgroundDataURL.length <= 24 * 1024 * 1024
        && backgroundDataURLPattern.test(theme.backgroundDataURL),
      );
      require(
        typeof theme.installerExpression === "string"
        && theme.installerExpression.length > 0
        && theme.installerExpression.length <= 32 * 1024 * 1024
        && !/(?:https?:\/\/|wss?:\/\/|ftp:\/\/|\bfetch\s*\(|\bWebSocket\s*\()/i.test(
          theme.installerExpression,
        ),
      );
      requireSha256(theme.sourceFingerprint);
      requireSha256(theme.cssFingerprint);
      requireSha256(theme.artFingerprint);
      require(theme.artFingerprint === fingerprintArtDataURL(theme.backgroundDataURL));
      require(theme.sourceFingerprint === fingerprintThemeSource(theme));
    }
    return payload;
  } catch (error) {
    if (error instanceof Error && error.message.startsWith("invalid offline fixture payload")) {
      throw error;
    }
    throw new Error(`invalid offline fixture payload: ${String(error)}`);
  }
}

export function enumerateFixtureScenarios(payload, themeTemplateSource) {
  validateFixturePayload(payload, themeTemplateSource);
  return payload.themes.flatMap((theme) =>
    FIXTURE_ROUTES.flatMap((route) =>
      FIXTURE_VIEWPORTS.map((viewport) => Object.freeze({
        key: `${theme.id}-${route}-${viewport.id}`,
        theme,
        route,
        viewport,
      })),
    ),
  );
}

export function assertSceneDifferences(sceneMetrics) {
  requireMetrics(Array.isArray(sceneMetrics) && sceneMetrics.length > 0, "metrics are missing");
  assertSceneMaterialHierarchy(sceneMetrics);
  for (const metric of sceneMetrics) {
    requireMetrics(
      Number.isFinite(metric.nonblankRatio) && metric.nonblankRatio >= MINIMUM_NONBLANK_RATIO,
      `${metric.themeID}/${metric.route}/${metric.viewport} nonblank ratio is ${metric.nonblankRatio}`,
    );
    requireMetrics(
      typeof metric.perceptualHash === "string" && /^[a-f0-9]{16,}$/i.test(metric.perceptualHash),
      `${metric.themeID}/${metric.route}/${metric.viewport} perceptual hash is invalid`,
    );
  }

  const byThemeAndViewport = groupBy(sceneMetrics, (metric) => `${metric.themeID}\0${metric.viewport}`);
  for (const [key, metrics] of byThemeAndViewport) {
    const home = metrics.find(({ route }) => route === "home");
    const task = metrics.find(({ route }) => route === "task");
    if (!home || !task) continue;
    const distance = hammingDistance(home.perceptualHash, task.perceptualHash);
    requireMetrics(
      distance >= MINIMUM_ROUTE_PHASH_DISTANCE,
      `${key.replace("\0", "/")} home/task pHash distance ${distance} is below ${MINIMUM_ROUTE_PHASH_DISTANCE}`,
    );
  }

  const byRouteAndViewport = groupBy(sceneMetrics, (metric) => `${metric.route}\0${metric.viewport}`);
  for (const [key, metrics] of byRouteAndViewport) {
    for (let left = 0; left < metrics.length; left += 1) {
      for (let right = left + 1; right < metrics.length; right += 1) {
        if (metrics[left].themeID === metrics[right].themeID) continue;
        const distance = hammingDistance(
          metrics[left].perceptualHash,
          metrics[right].perceptualHash,
        );
        requireMetrics(
          distance >= MINIMUM_CROSS_THEME_PHASH_DISTANCE,
          `${key.replace("\0", "/")} cross-theme pHash distance ${distance} for `
            + `${metrics[left].themeID}/${metrics[right].themeID} is below `
            + MINIMUM_CROSS_THEME_PHASH_DISTANCE,
        );
      }
    }
  }
}

export function assertCompleteFixtureCoverage(sceneMetrics) {
  requireMetrics(Array.isArray(sceneMetrics) && sceneMetrics.length > 0, "metrics are missing");
  const themes = [...new Set(sceneMetrics.map(({ themeID }) => themeID))].sort();
  const families = [...new Set(sceneMetrics.map(({ styleFamily }) => styleFamily))].sort();
  requireMetrics(
    families.join(",") === [...REQUIRED_STYLE_FAMILIES].sort().join(","),
    `style family coverage is ${families.join(",")}`,
  );

  for (const themeID of themes) {
    const themeMetrics = sceneMetrics.filter((metric) => metric.themeID === themeID);
    for (const scenario of REQUIRED_INTERACTION_SCENARIOS) {
      const metric = themeMetrics.find(
        ({ route, viewport }) => route === scenario.route && viewport === scenario.viewport,
      );
      requireMetrics(
        metric,
        `${themeID}/${scenario.route}/${scenario.viewport} interaction coverage is missing`,
      );
      requireMetrics(
        metric.interactionStates && typeof metric.interactionStates === "object",
        `${themeID}/${scenario.route}/${scenario.viewport} interaction states are missing`,
      );
    }

    for (const metric of themeMetrics) {
      const isRequired = REQUIRED_INTERACTION_SCENARIOS.some(
        ({ route, viewport }) => route === metric.route && viewport === metric.viewport,
      );
      requireMetrics(
        isRequired || metric.interactionStates === null,
        `${themeID}/${metric.route}/${metric.viewport} has unexpected interaction states`,
      );
      requireArtworkCrop(metric.artworkCrop, `${themeID}/${metric.route}/${metric.viewport}`);
    }
  }

  for (const family of REQUIRED_STYLE_FAMILIES) {
    const compactHome = sceneMetrics.filter(
      ({ styleFamily, route, viewport }) =>
        styleFamily === family && route === "home" && viewport === "compact",
    );
    requireMetrics(
      compactHome.length > 0 && compactHome.every(({ artworkCrop }) => artworkCrop.cropsSource),
      `${family} compact home crop is missing`,
    );
  }

  requireMetrics(themes.length === EXPECTED_THEME_COUNT, `theme coverage count is ${themes.length}`);
  requireMetrics(
    sceneMetrics.length === EXPECTED_FIXTURE_SCENE_COUNT,
    `scene coverage count is ${sceneMetrics.length}`,
  );
}

export function assertSceneMaterialHierarchy(sceneMetrics) {
  requireMetrics(Array.isArray(sceneMetrics) && sceneMetrics.length > 0, "metrics are missing");
  for (const metric of sceneMetrics) {
    const context = `${metric.themeID}/${metric.route}/${metric.viewport}`;
    const requiredContrastTargets = FIXTURE_CONTRAST_TARGETS[metric.route];
    requireMetrics(
      Array.isArray(requiredContrastTargets) && Array.isArray(metric.contrastSamples),
      `${context} contrast samples are missing`,
    );
    const samplesByID = new Map();
    for (const sample of metric.contrastSamples) {
      requireMetrics(
        sample && typeof sample.id === "string" && !samplesByID.has(sample.id),
        `${context} contrast target ${sample?.id} is duplicated or invalid`,
      );
      samplesByID.set(sample.id, sample);
    }
    for (const target of requiredContrastTargets) {
      const sample = samplesByID.get(target.id);
      requireMetrics(sample, `${context} contrast target ${target.id} is missing`);
      requireMetrics(
        sample.kind === target.kind,
        `${context} contrast target ${target.id} kind is ${sample.kind}`,
      );
      requireMetrics(
        Number.isInteger(sample.pixelCount) && sample.pixelCount > 0,
        `${context} contrast target ${target.id} has no pixel evidence`,
      );
      requireMetrics(
        Number.isInteger(sample.evidenceCount) && sample.evidenceCount > 0,
        `${context} contrast target ${target.id} has no node evidence`,
      );
      requireMetrics(
        Number.isInteger(sample.rectCount) && sample.rectCount >= sample.evidenceCount,
        `${context} contrast target ${target.id} has invalid rect evidence`,
      );
      requireMetrics(
        Number.isFinite(sample.ratio) && sample.ratio >= CONTRAST_THRESHOLDS[target.kind],
        `${context} ${target.kind} contrast target ${target.id} is ${sample.ratio}`
          + ` at ${sample.weakestNodeLabel ?? "unknown node"}`,
      );
    }
    requireMetrics(
      samplesByID.size === requiredContrastTargets.length,
      `${context} contrast target count is ${samplesByID.size}`,
    );
    requireMetrics(
      Number.isFinite(metric.minimumTextContrast)
        && metric.minimumTextContrast >= CONTRAST_THRESHOLDS.normalText,
      `${context} minimum text contrast is ${metric.minimumTextContrast}`,
    );
    requireMetrics(
      Number.isFinite(metric.minimumControlContrast)
        && metric.minimumControlContrast >= CONTRAST_THRESHOLDS.control,
      `${context} minimum control contrast is ${metric.minimumControlContrast}`,
    );
    requireApproximateAlpha(
      metric.composerContextBackgroundAlpha,
      0,
      `${context} composer context background alpha`,
    );
    requireMetrics(
      Number.isFinite(metric.composerBackgroundAlpha)
        && metric.composerBackgroundAlpha >= 0.84 - 1 / 255
        && metric.composerBackgroundAlpha <= 0.90 + 1 / 255,
      `${context} composer background alpha is ${metric.composerBackgroundAlpha}`,
    );
    requireMaterialChain(
      metric.composerMaterialChain,
      ["composer", "composer-context", "main-surface"],
      [metric.composerBackgroundAlpha, metric.composerContextBackgroundAlpha, 0],
      "app-shell",
      `${context} composer material chain`,
    );
    requireCenteredGeometry(metric.layoutGeometry?.composer, `${context} composer geometry`);
    requireDenseSidebar(metric.denseSidebar, `${context} dense sidebar`);
    requireSceneContinuity(
      metric.sceneContinuity,
      metric.sceneArtworkZones,
      metric.sceneTransmissionZones,
      context,
    );
    const requiresInteraction = REQUIRED_INTERACTION_SCENARIOS.some(
      ({ route, viewport }) => route === metric.route && viewport === metric.viewport,
    );
    if (requiresInteraction) {
      requireInteractionStates(metric.interactionStates, context, metric.route);
    } else {
      requireMetrics(
        metric.interactionStates === null,
        `${context} has an unexpected interaction matrix`,
      );
    }

    if (metric.route === "task") {
      requireMetrics(
        Number.isInteger(metric.taskReadingTileCount) && metric.taskReadingTileCount > 0,
        `${context} task reading tile count is ${metric.taskReadingTileCount}`,
      );
      requireMetrics(
        Number.isFinite(metric.taskReadingArtworkLeak)
          && metric.taskReadingArtworkLeak >= 0
          && metric.taskReadingArtworkLeak <= MAXIMUM_TASK_READING_ARTWORK_LEAK,
        `${context} task reading artwork leak is ${metric.taskReadingArtworkLeak}`,
      );
    }

    if (metric.route === "home") {
      requireCenteredGeometry(metric.layoutGeometry?.home, `${context} home geometry`);
      requireApproximateAlpha(
        metric.homeContentBackgroundAlpha,
        0,
        `${context} home content background alpha`,
      );
      requireApproximateAlpha(
        metric.homeSuggestionsBackgroundAlpha,
        0,
        `${context} home suggestions background alpha`,
      );
      requireApproximateAlpha(
        metric.homeActionBackgroundAlpha,
        1,
        `${context} home action background alpha`,
      );
      requireMaterialChain(
        metric.homeMaterialChain,
        ["home-action", "home-suggestions", "home-content", "main-surface"],
        [
          metric.homeActionBackgroundAlpha,
          metric.homeSuggestionsBackgroundAlpha,
          metric.homeContentBackgroundAlpha,
          0,
        ],
        "app-shell",
        `${context} home material chain`,
      );
    } else {
      requireMetrics(metric.layoutGeometry?.home === null, `${context} task home geometry is not null`);
    }
  }
}

export function hammingDistance(left, right) {
  requireMetrics(typeof left === "string" && left.length === right.length, "pHash lengths differ");
  let distance = 0;
  for (let index = 0; index < left.length; index += 1) {
    const xor = Number.parseInt(left[index], 16) ^ Number.parseInt(right[index], 16);
    distance += POPCOUNT_NIBBLE[xor];
  }
  return distance;
}

export function classifyFixtureRequest(requestURL, fixtureDocumentURL) {
  let request;
  let document;
  try {
    request = new URL(requestURL);
    document = new URL(fixtureDocumentURL);
  } catch {
    return "block";
  }

  if (request.protocol === "file:" && document.protocol === "file:") {
    const allowed = new Set([document.href, new URL("styles.css", document).href]);
    return allowed.has(request.href) ? "allow" : "block";
  }
  if (request.protocol === "data:") {
    return /^data:image\/(?:jpeg|png|webp);base64,/i.test(requestURL) ? "allow" : "block";
  }
  if (request.protocol === "blob:") {
    return requestURL.startsWith("blob:null/") ? "allow" : "block";
  }
  if (request.href === "about:blank") {
    return "allow";
  }
  return "block";
}

export function fingerprintProfile(profile) {
  return sha256(canonicalJSONString(profile));
}

export function fingerprintThemeTemplate(source) {
  require(typeof source === "string" && source.length > 0);
  return sha256(source);
}

export function fingerprintArtDataURL(dataURL) {
  if (typeof dataURL !== "string" || !backgroundDataURLPattern.test(dataURL)) {
    throw new Error("invalid offline fixture payload");
  }
  return sha256(Buffer.from(dataURL.slice(dataURL.indexOf(",") + 1), "base64"));
}

export function fingerprintThemeSource(theme) {
  return sha256([
    theme.id,
    theme.name,
    theme.styleFamily,
    theme.cssFingerprint,
    theme.artFingerprint,
  ].join("\0"));
}

export function fingerprintExporterContract() {
  return sha256(EXPORTER_CONTRACT_MARKER);
}

function validateLatestSelectors(selectors) {
  assertExactKeys(selectors, Object.keys(LATEST_PROFILE_SELECTORS));
  for (const [key, expected] of Object.entries(LATEST_PROFILE_SELECTORS)) {
    if (Array.isArray(expected)) {
      require(arrayEquals(selectors[key], expected));
    } else {
      require(selectors[key] === expected);
    }
  }
}

function assertExactKeys(value, expectedKeys) {
  require(value !== null && typeof value === "object" && !Array.isArray(value));
  require(arrayEquals(Object.keys(value).sort(), [...expectedKeys].sort()));
}

function arrayEquals(left, right) {
  return Array.isArray(left)
    && left.length === right.length
    && left.every((value, index) => value === right[index]);
}

function require(value) {
  if (!value) throw new Error("invalid offline fixture payload");
}

function requireSha256(value) {
  require(typeof value === "string" && sha256Pattern.test(value));
}

function requireMetrics(value, message) {
  if (!value) throw new Error(message);
}

function requireApproximateAlpha(actual, expected, message) {
  requireMetrics(
    Number.isFinite(actual) && Math.abs(actual - expected) <= 1 / 255,
    `${message} is ${actual}`,
  );
}

function requireMaterialChain(
  chain,
  expectedForegroundSurfaces,
  expectedForegroundAlphas,
  expectedSceneBaseSurface,
  message,
) {
  requireMetrics(Array.isArray(chain), `${message} is missing`);
  const expectedSurfaces = [...expectedForegroundSurfaces, expectedSceneBaseSurface];
  requireMetrics(
    chain.length === expectedSurfaces.length
      && expectedSurfaces.every((surface, index) => chain[index]?.surface === surface),
    `${message} is ${JSON.stringify(chain)}`,
  );
  requireMetrics(
    expectedForegroundAlphas.length === expectedForegroundSurfaces.length,
    `${message} foreground alpha contract is invalid`,
  );
  for (let index = 0; index < expectedForegroundAlphas.length; index += 1) {
    requireApproximateAlpha(
      chain[index].backgroundAlpha,
      expectedForegroundAlphas[index],
      `${message} ${chain[index].surface} alpha`,
    );
  }
  const sceneBase = chain.at(-1);
  requireMetrics(
    Number.isFinite(sceneBase.backgroundAlpha)
      && sceneBase.backgroundAlpha >= 0
      && sceneBase.backgroundAlpha <= 1,
    `${message} sceneBase ${sceneBase.surface} alpha is ${sceneBase.backgroundAlpha}`,
  );
}

function requireCenteredGeometry(geometry, message) {
  requireMetrics(geometry && geometry.withinMain === true, `${message} is outside main`);
  for (const field of ["centerDeltaX", "marginDeltaX", "leftMargin", "rightMargin"]) {
    requireMetrics(Number.isFinite(geometry[field]), `${message} ${field} is ${geometry?.[field]}`);
  }
  requireMetrics(
    Math.abs(geometry.centerDeltaX) <= MAXIMUM_CENTER_DELTA_PX,
    `${message} center delta is ${geometry.centerDeltaX}`,
  );
  requireMetrics(
    geometry.marginDeltaX >= 0 && geometry.marginDeltaX <= MAXIMUM_CENTER_DELTA_PX,
    `${message} margin delta is ${geometry.marginDeltaX}`,
  );
  requireMetrics(
    geometry.leftMargin >= 0 && geometry.rightMargin >= 0,
    `${message} margins are ${geometry.leftMargin}/${geometry.rightMargin}`,
  );
}

function requireDenseSidebar(sidebar, message) {
  requireMetrics(sidebar && typeof sidebar === "object", `${message} is missing`);
  requireMetrics(
    Number.isInteger(sidebar.rowCount) && sidebar.rowCount >= MINIMUM_DENSE_SIDEBAR_ROWS,
    `${message} row count is ${sidebar.rowCount}`,
  );
  requireMetrics(
    Number.isFinite(sidebar.rowHeight) && Math.abs(sidebar.rowHeight - 36) <= 0.5,
    `${message} row height is ${sidebar.rowHeight}`,
  );
  requireMetrics(
    Number.isFinite(sidebar.rowHeightDelta)
      && sidebar.rowHeightDelta <= MAXIMUM_ROW_HEIGHT_DELTA_PX,
    `${message} row height delta is ${sidebar.rowHeightDelta}`,
  );
  requireMetrics(sidebar.truncatedCount >= 2, `${message} truncated count is ${sidebar.truncatedCount}`);
  for (const field of ["rowsWithinViewport", "rowsDoNotOverlap", "ellipsisContractValid"]) {
    requireMetrics(sidebar[field] === true, `${message} ${field} is ${sidebar[field]}`);
  }
  const selectedUsesStructuralShadow =
    typeof sidebar.selectedShadowGeometry === "string"
    && typeof sidebar.peerShadowGeometry === "string"
    && sidebar.selectedShadowGeometry !== "none"
    && sidebar.selectedShadowGeometry !== sidebar.peerShadowGeometry;
  const selectedUsesStructuralBorder =
    Number.isFinite(sidebar.selectedMaxBorderWidth)
    && Number.isFinite(sidebar.peerMaxBorderWidth)
    && sidebar.selectedMaxBorderWidth >= sidebar.peerMaxBorderWidth + 1;
  requireMetrics(
    Number.isFinite(sidebar.selectedFontWeight)
      && Number.isFinite(sidebar.peerFontWeight)
      && sidebar.selectedFontWeight >= 600
      && sidebar.selectedFontWeight >= sidebar.peerFontWeight + 100
      && (selectedUsesStructuralShadow || selectedUsesStructuralBorder),
    `${message} selected structural affordance is missing`,
  );
}

function requireSceneContinuity(continuity, artworkZones, transmissionZones, context) {
  requireMetrics(continuity && typeof continuity === "object", `${context} scene continuity is missing`);
  requireMetrics(
    Number.isFinite(continuity.titlebarBackgroundAlpha)
      && continuity.titlebarBackgroundAlpha >= 0
      && continuity.titlebarBackgroundAlpha <= 0.18 + 1 / 255,
    `${context} titlebar background alpha is ${continuity.titlebarBackgroundAlpha}`,
  );
  requireMetrics(
    Number.isFinite(continuity.sidebarBackgroundAlpha)
      && continuity.sidebarBackgroundAlpha >= 0.87 - 1 / 255
      && continuity.sidebarBackgroundAlpha <= 0.90 + 1 / 255,
    `${context} sidebar background alpha is ${continuity.sidebarBackgroundAlpha}`,
  );
  requireApproximateAlpha(
    continuity.mainBackgroundAlpha,
    0,
    `${context} main background alpha`,
  );
  requireMetrics(
    continuity.titlebarHasIndependentArtwork === false
      && continuity.sidebarHasIndependentArtwork === false
      && continuity.mainHasIndependentArtwork === false,
    `${context} a shell surface owns independent artwork`,
  );
  requireMetrics(
    continuity.titlebarBackdropFilter === "none",
    `${context} titlebar backdrop filter is ${continuity.titlebarBackdropFilter}`,
  );
  requireMetrics(
    Number.isFinite(continuity.sidebarBoundaryWidth)
      && continuity.sidebarBoundaryWidth > 0
      && continuity.sidebarBoundaryWidth <= 2,
    `${context} sidebar boundary width is ${continuity.sidebarBoundaryWidth}`,
  );
  requireMetrics(
    Number.isFinite(continuity.mainLeftBoundaryWidth)
      && continuity.mainLeftBoundaryWidth <= 0.5,
    `${context} main left boundary width is ${continuity.mainLeftBoundaryWidth}`,
  );

  const artworkByID = requireExactZones(artworkZones, `${context} scene artwork zones`);
  for (const id of REQUIRED_SCENE_ARTWORK_ZONES) {
    const zone = artworkByID.get(id);
    requireMetrics(
      Number.isInteger(zone.tileCount) && zone.tileCount >= 3,
      `${context} ${id} real artwork tile count is ${zone.tileCount}`,
    );
    requireMetrics(
      Number.isFinite(zone.maximumPixelDelta) && zone.maximumPixelDelta >= 1,
      `${context} ${id} real artwork maximum pixel delta is ${zone.maximumPixelDelta}`,
    );
    requireMetrics(
      Number.isFinite(zone.meanPixelDelta) && zone.meanPixelDelta >= 0.01,
      `${context} ${id} real artwork mean pixel delta is ${zone.meanPixelDelta}`,
    );
  }

  const byID = requireExactZones(transmissionZones, `${context} scene transmission zones`);
  for (const id of REQUIRED_SCENE_ARTWORK_ZONES) {
    const zone = byID.get(id);
    requireMetrics(
      Number.isInteger(zone.tileCount) && zone.tileCount >= 3,
      `${context} ${id} transmission tile count is ${zone.tileCount}`,
    );
    requireMetrics(
      Number.isFinite(zone.changedPixelRatio)
        && zone.changedPixelRatio >= 0
        && zone.changedPixelRatio >= minimumSceneTransmissionPixelRatios[id],
      `${context} ${id} transmission pixel ratio is ${zone.changedPixelRatio}`,
    );
    requireMetrics(
      Number.isInteger(zone.qualifyingTileCount) && zone.qualifyingTileCount >= 3,
      `${context} ${id} qualifying tile count is ${zone.qualifyingTileCount}`,
    );
    requireMetrics(
      Number.isFinite(zone.qualifyingTileRatio) && zone.qualifyingTileRatio >= 0.75,
      `${context} ${id} qualifying tile ratio is ${zone.qualifyingTileRatio}`,
    );
  }
}

function requireExactZones(zones, message) {
  requireMetrics(Array.isArray(zones), `${message} are missing`);
  const byID = new Map(zones.map((zone) => [zone.id, zone]));
  requireMetrics(
    zones.length === REQUIRED_SCENE_ARTWORK_ZONES.length
      && byID.size === REQUIRED_SCENE_ARTWORK_ZONES.length
      && REQUIRED_SCENE_ARTWORK_ZONES.every((id) => byID.has(id)),
    `${message} are ${zones.map((zone) => zone.id).join(",")}`,
  );
  return byID;
}

function requireArtworkCrop(crop, context) {
  requireMetrics(crop && typeof crop === "object", `${context} artwork crop is missing`);
  for (const field of ["positionXPercent", "positionYPercent"]) {
    requireMetrics(
      Number.isFinite(crop[field]) && crop[field] >= 0 && crop[field] <= 100,
      `${context} artwork crop ${field} is ${crop[field]}`,
    );
  }
  requireMetrics(
    Number.isFinite(crop.scale) && crop.scale >= 1 && crop.scale <= 1.25,
    `${context} artwork crop scale is ${crop.scale}`,
  );
  for (const field of ["effectiveBackgroundPosition", "effectiveTransformOrigin"]) {
    requireMetrics(
      typeof crop[field] === "string" && crop[field].length > 0,
      `${context} artwork crop ${field} is missing`,
    );
  }
  requireMetrics(
    typeof crop.cropsSource === "boolean",
    `${context} artwork crop source flag is invalid`,
  );
}

function requireInteractionStates(states, context, route) {
  requireMetrics(states && typeof states === "object", `${context} interaction states are missing`);
  const normal = states.normal;
  const reduced = states.reduced;
  requireMetrics(normal?.media?.finePointer === true, `${context} fine pointer media is false`);
  requireMetrics(normal?.media?.reducedMotion === false, `${context} normal media is reduced`);

  for (const [name, snapshot] of Object.entries(normal?.transitions ?? {})) {
    requireInteractionSnapshot(snapshot, `${context} normal ${name} transition`);
    requireMetrics(
      durationListHasMotion(snapshot.transitionDuration),
      `${context} normal ${name} transition is disabled`,
    );
  }
  const expectedTransitionTargets = route === "home" ? "composer,home,sidebar" : "composer,sidebar";
  requireMetrics(
    Object.keys(normal?.transitions ?? {}).sort().join(",") === expectedTransitionTargets,
    `${context} normal transition targets are incomplete`,
  );

  const home = normal?.home;
  const sidebar = normal?.sidebar;
  const composer = normal?.composer;
  const requiredSnapshots = [
    ["sidebar idle", sidebar?.idle],
    ["sidebar hover", sidebar?.hover],
    ["sidebar active", sidebar?.active],
    ["sidebar selected", sidebar?.selected],
    ["composer idle", composer?.idle],
    ["composer focus-within", composer?.focusWithin],
    ["composer input focus", composer?.inputFocus],
  ];
  if (route === "home") {
    requiredSnapshots.unshift(
      ["home idle", home?.idle],
      ["home hover", home?.hover],
      ["home active", home?.active],
      ["home focus-visible", home?.focusVisible],
    );
  } else {
    requireMetrics(home === null, `${context} task interaction includes a home state`);
  }
  for (const [name, snapshot] of requiredSnapshots) {
    requireInteractionSnapshot(snapshot, `${context} ${name}`);
  }

  if (route === "home") {
    requireStableInteractionRect(home.idle.rect, home.hover.rect, `${context} home hover`);
    requireStableInteractionRect(home.idle.rect, home.active.rect, `${context} home active`);
    requireStableInteractionRect(home.idle.rect, home.focusVisible.rect, `${context} home focus`);
  }
  requireStableInteractionRect(sidebar.idle.rect, sidebar.hover.rect, `${context} sidebar hover`);
  requireStableInteractionRect(sidebar.idle.rect, sidebar.active.rect, `${context} sidebar active`);
  requireStableInteractionRect(
    composer.idle.rect,
    composer.focusWithin.rect,
    `${context} composer focus-within`,
  );
  if (route === "home") {
    requireMetrics(home.hover.matchesHover === true, `${context} home hover did not match`);
    requireMetrics(home.active.matchesActive === true, `${context} home active did not match`);
  }
  requireMetrics(sidebar.hover.matchesHover === true, `${context} sidebar hover did not match`);
  requireMetrics(sidebar.active.matchesActive === true, `${context} sidebar active did not match`);
  if (route === "home") {
    requireMetrics(
      visualInteractionChanged(home.idle, home.hover, ["backgroundColor", "borderColor"]),
      `${context} home hover has no feedback`,
    );
    requireMetrics(
      visualInteractionChanged(
        home.hover,
        home.active,
        ["backgroundColor", "borderColor", "boxShadow"],
      ),
      `${context} home active has no feedback`,
    );
    requireMetrics(home.active.opacity === home.idle.opacity, `${context} home active dims opacity`);
  }
  requireMetrics(
    visualInteractionChanged(sidebar.idle, sidebar.hover, ["backgroundColor", "boxShadow"]),
    `${context} sidebar hover has no feedback`,
  );
  requireMetrics(
    visualInteractionChanged(sidebar.hover, sidebar.active, ["backgroundColor", "boxShadow"]),
    `${context} sidebar active has no feedback`,
  );
  requireMetrics(
    sidebar.active.opacity === sidebar.idle.opacity,
    `${context} sidebar active dims opacity`,
  );
  if (route === "home") {
    requireMetrics(
      home.focusVisible.matchesFocusVisible === true
        && Number.parseFloat(home.focusVisible.outlineWidth) >= 2
        && home.focusVisible.outlineStyle !== "none",
      `${context} keyboard focus outline is invalid`,
    );
  }
  requireMetrics(
    Number.parseInt(sidebar.selected.fontWeight, 10) >= 600
      && sidebar.selected.boxShadow !== "none",
    `${context} selected navigation lacks structure`,
  );
  requireMetrics(
    composer.focusWithin.matchesFocusWithin === true
      && composer.focusWithin.borderColor !== composer.idle.borderColor
      && composer.focusWithin.boxShadow !== composer.idle.boxShadow,
    `${context} composer focus-within lacks feedback`,
  );
  requireMetrics(
    composer.inputFocus.outlineStyle === "none"
      || Number.parseFloat(composer.inputFocus.outlineWidth) === 0,
    `${context} composer input has a duplicate outline`,
  );
  requireMetrics(
    composer.inputFocus.matchesFocusVisible === true,
    `${context} composer input is not focus-visible`,
  );

  requireMetrics(reduced?.mediaMatches === true, `${context} reduced media did not match`);
  for (const name of route === "home" ? ["home", "sidebar", "composer"] : ["sidebar", "composer"]) {
    const snapshot = reduced?.idle?.[name];
    requireInteractionSnapshot(snapshot, `${context} reduced ${name}`);
    requireMetrics(
      durationListIsZero(snapshot.transitionDuration),
      `${context} reduced ${name} transition is not zero`,
    );
    requireMetrics(
      durationListIsZero(snapshot.transitionDelay),
      `${context} reduced ${name} delay is not zero`,
    );
  }
  if (route === "home") {
    requireInteractionSnapshot(reduced?.homeHover, `${context} reduced home hover`);
  } else {
    requireMetrics(reduced?.idle?.home === null, `${context} reduced task includes a home state`);
    requireMetrics(reduced?.homeHover === null, `${context} reduced task includes home hover`);
    requireInteractionSnapshot(reduced?.sidebarHover, `${context} reduced sidebar hover`);
  }
  requireInteractionSnapshot(
    reduced?.composerFocusWithin,
    `${context} reduced composer focus-within`,
  );
  if (route === "home") {
    requireMetrics(
      reduced.homeHover.matchesHover === true
        && visualInteractionChanged(
          reduced.idle.home,
          reduced.homeHover,
          ["backgroundColor", "borderColor"],
        ),
      `${context} reduced home hover has no feedback`,
    );
  } else {
    requireMetrics(
      reduced.sidebarHover.matchesHover === true
        && visualInteractionChanged(
          reduced.idle.sidebar,
          reduced.sidebarHover,
          ["backgroundColor", "boxShadow"],
        ),
      `${context} reduced sidebar hover has no feedback`,
    );
  }
  requireMetrics(
    reduced.composerFocusWithin.matchesFocusWithin === true
      && reduced.composerFocusWithin.borderColor !== reduced.idle.composer.borderColor
      && reduced.composerFocusWithin.boxShadow !== reduced.idle.composer.boxShadow,
    `${context} reduced composer focus-within has no feedback`,
  );
  requireMetrics(
    reduced.runningAnimations === 0,
    `${context} reduced running animations are ${reduced.runningAnimations}`,
  );
}

function requireInteractionSnapshot(snapshot, message) {
  requireMetrics(snapshot && typeof snapshot === "object", `${message} is missing`);
  requireMetrics(snapshot.rect && typeof snapshot.rect === "object", `${message} rect is missing`);
  for (const field of ["x", "y", "width", "height"]) {
    requireMetrics(Number.isFinite(snapshot.rect[field]), `${message} rect ${field} is invalid`);
  }
  requireMetrics(
    snapshot.transform === "none" || snapshot.transform === "matrix(1, 0, 0, 1, 0, 0)",
    `${message} transform is ${snapshot.transform}`,
  );
}

function requireStableInteractionRect(before, after, message) {
  for (const field of ["x", "y", "width", "height"]) {
    requireMetrics(
      Math.abs(before[field] - after[field]) <= 0.25,
      `${message} changes ${field} from ${before[field]} to ${after[field]}`,
    );
  }
}

function visualInteractionChanged(before, after, fields) {
  return fields.some((field) => before[field] !== after[field]);
}

function durationListIsZero(value) {
  return String(value).split(",").every((duration) => Number.parseFloat(duration) === 0);
}

function durationListHasMotion(value) {
  return String(value).split(",").some((duration) => Number.parseFloat(duration) > 0);
}

function groupBy(values, keyForValue) {
  const result = new Map();
  for (const value of values) {
    const key = keyForValue(value);
    const bucket = result.get(key) ?? [];
    bucket.push(value);
    result.set(key, bucket);
  }
  return result;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function canonicalJSONString(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJSONString).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJSONString(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

const POPCOUNT_NIBBLE = Object.freeze([0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4]);
