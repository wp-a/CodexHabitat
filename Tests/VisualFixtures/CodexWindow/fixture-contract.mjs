import { createHash } from "node:crypto";

export const FIXTURE_LABEL = "OFFLINE THEME FIXTURE";
export const LATEST_PROFILE_ID = "codex-26.715.31925";
export const FIXTURE_ROUTES = Object.freeze(["home", "task"]);
export const FIXTURE_VIEWPORTS = Object.freeze([
  Object.freeze({ id: "wide", width: 1512, height: 982 }),
  Object.freeze({ id: "narrow", width: 1180, height: 820 }),
]);
export const EXPECTED_THEME_COUNT = 24;
export const EXPECTED_FIXTURE_SCENE_COUNT =
  EXPECTED_THEME_COUNT * FIXTURE_ROUTES.length * FIXTURE_VIEWPORTS.length;
export const MINIMUM_ROUTE_PHASH_DISTANCE = 12;
export const MINIMUM_CROSS_THEME_PHASH_DISTANCE = 12;
export const MINIMUM_NONBLANK_RATIO = 0.05;
export const EXPORTER_CONTRACT_MARKER = "offline-theme-fixture-payload-v1";

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
  Object.freeze({ name: "sidebar", fixtureToken: 'class="app-shell-left-panel"' }),
  Object.freeze({ name: "main surface", fixtureToken: 'class="main-surface"' }),
  Object.freeze({ name: "header", fixtureToken: 'class="app-header-tint"' }),
  Object.freeze({ name: "home marker", fixtureToken: 'data-testid="home-icon"' }),
  Object.freeze({ name: "home content", fixtureToken: 'data-fixture-surface="home-content"' }),
  Object.freeze({ name: "home suggestions", fixtureToken: 'class="group/home-suggestions fixture-suggestions"' }),
  Object.freeze({ name: "thread scroll", fixtureToken: 'class="thread-scroll-container"' }),
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
