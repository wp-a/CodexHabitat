#!/usr/bin/env node

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  EXPECTED_FIXTURE_SCENE_COUNT,
  EXPECTED_SURFACE_ANNOTATIONS,
  FIXTURE_CONTRAST_TARGETS,
  FIXTURE_LABEL,
  FIXTURE_ROUTES,
  FIXTURE_VIEWPORTS,
  LATEST_PROFILE_SELECTORS,
  assertSceneDifferences,
  classifyFixtureRequest,
  fixtureSourceFingerprint,
  mergeContrastFrameSamples,
  percentileLocalArtworkLeak,
  summarizeContrastNodeSamples,
  validateFixturePayload,
  validateFixtureSource,
} from "./fixture-contract.mjs";

const fixtureRoot = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(fixtureRoot, "../../..");
const documentPath = path.join(fixtureRoot, "index.html");
const documentURL = pathToFileURL(documentPath).href;
const themeTemplatePath = path.join(
  repositoryRoot,
  "Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css",
);
const focusYProbeConfiguration = Object.freeze({
  themeID: "workbench",
  viewport: "narrow",
  scale: 1.08,
  firstFocusY: 0.25,
  secondFocusY: 0.75,
});
const primaryThemeIDs = new Set([
  "retro-messenger",
  "green-chat-desk",
  "cyber-cafe",
  "win95-workbench",
]);
const GLYPH_CORE_SENTINEL_DELTA = 224;

export async function readOfflineFixturePayload(payloadPath) {
  if (
    typeof payloadPath !== "string"
    || payloadPath.length === 0
    || /^[a-z][a-z0-9+.-]*:\/\//i.test(payloadPath)
  ) {
    throw new Error("offline fixture payload path is required");
  }
  const absolutePath = path.resolve(payloadPath);
  let payload;
  try {
    const [payloadSource, themeTemplateSource] = await Promise.all([
      readFile(absolutePath, "utf8"),
      readFile(themeTemplatePath, "utf8"),
    ]);
    payload = validateFixturePayload(JSON.parse(payloadSource), themeTemplateSource);
  } catch (error) {
    throw new Error(`unable to read offline fixture payload: ${String(error)}`);
  }
  return payload;
}

export async function runOfflineFixture({ payloadPath, outputDirectory = null } = {}) {
  const payload = await readOfflineFixturePayload(payloadPath);
  const [fixtureHTML, fixtureCSS, rendererSource, contractSource, playwrightMetadata] =
    await Promise.all([
      readFile(documentPath, "utf8"),
      readFile(path.join(fixtureRoot, "styles.css"), "utf8"),
      readFile(fileURLToPath(import.meta.url), "utf8"),
      readFile(path.join(fixtureRoot, "fixture-contract.mjs"), "utf8"),
      readFile(path.join(fixtureRoot, "node_modules/playwright/package.json"), "utf8"),
    ]);
  validateFixtureSource(fixtureHTML, fixtureCSS);
  const actualFixtureFingerprint = fixtureSourceFingerprint(fixtureHTML, fixtureCSS);
  const resolvedOutputDirectory = outputDirectory ? path.resolve(outputDirectory) : null;
  if (resolvedOutputDirectory) await mkdir(resolvedOutputDirectory, { recursive: true, mode: 0o700 });

  const { chromium } = await import("playwright");
  const browser = await chromium.launch({ headless: true });
  const browserVersion = browser.version();
  const externalRequests = [];
  const scenes = [];
  let focusYProbe;

  try {
    focusYProbe = await measureNarrowFocusYProbe(browser, payload);
    for (const viewport of FIXTURE_VIEWPORTS) {
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        deviceScaleFactor: 1,
        locale: "en-US",
        reducedMotion: "reduce",
        serviceWorkers: "block",
      });
      await context.route("**/*", async (route) => {
        const url = route.request().url();
        if (classifyFixtureRequest(url, documentURL) === "allow") {
          await route.continue();
        } else {
          externalRequests.push(url);
          await route.abort("blockedbyclient");
        }
      });

      try {
        for (const theme of payload.themes) {
          const page = await context.newPage();
          const consoleErrors = [];
          const pageErrors = [];
          page.on("console", (message) => {
            if (message.type() === "error") consoleErrors.push(message.text());
          });
          page.on("pageerror", (error) => pageErrors.push(error.message));

          try {
            await page.goto(documentURL, { waitUntil: "load" });
            await page.emulateMedia({ reducedMotion: "reduce" });
            const art = await decodeArtwork(page, theme.backgroundDataURL);
            assert(art.decoded, `${theme.id} artwork did not decode`);
            assert(art.decodeMS <= 5_000, `${theme.id} artwork decode exceeded 5000ms`);

            await page.evaluate(theme.installerExpression);
            await page.waitForFunction(
              () => document.documentElement.dataset.codexHabitatTheme === "1",
            );
            const installedCSS = await page.locator("#codex-habitat-theme-style").textContent();
            assert(installedCSS !== null, `${theme.id} installer did not create the theme style`);
            assert(
              sha256(installedCSS) === theme.cssFingerprint,
              `${theme.id} installed CSS fingerprint differs from the Swift exporter`,
            );
            const taskModeOff = installedCSS.includes("habitat-task-mode: off");
            const taskModeBanner = installedCSS.includes("habitat-task-mode: banner");

            const warmupTransition = await selectFixtureRoute(
              page,
              "task",
              payload.profile.selectors.homeMarker,
            );
            assert(warmupTransition.mutationObserved, `${theme.id} task warmup bypassed observer`);

            for (const routeName of FIXTURE_ROUTES) {
              const routeTransition = await selectFixtureRoute(
                page,
                routeName,
                payload.profile.selectors.homeMarker,
              );
              const routeLatencyMS = routeTransition.latencyMS;
              assert(
                routeTransition.mutationObserved,
                `${theme.id}/${routeName}/${viewport.id} bypassed the route observer`,
              );
              assert(
                routeLatencyMS <= 120,
                `${theme.id}/${routeName}/${viewport.id} route latency `
                  + `${routeLatencyMS.toFixed(2)}ms exceeded 120ms`,
              );
              const pageChecks = await inspectFixturePage(
                page,
                payload.profile.selectors,
                routeName,
                consoleErrors,
                pageErrors,
                taskModeOff,
                taskModeBanner,
              );
              assert(
                externalRequests.length === 0,
                `external request attempted: ${externalRequests.join(", ")}`,
              );

              const screenshotBuffer = await page.screenshot({
                animations: "disabled",
                fullPage: false,
                type: "png",
              });
              const contrast = await measureFinalPixelContrast(
                page,
                screenshotBuffer,
                routeName,
              );
              const artworkPixelDelta = routeName === "home" || !taskModeOff
                ? await measureArtworkPixelDelta(page, screenshotBuffer)
                : 0;
              if (routeName === "home") {
                assert(
                  artworkPixelDelta >= 0.02,
                  `${theme.id}/${viewport.id} home artwork pixel delta ${artworkPixelDelta} is too low`,
                );
              } else {
                assert(
                  !taskModeOff,
                  `${theme.id}/${viewport.id} built-in task scene disables artwork`,
                );
                assert(
                  artworkPixelDelta >= 0.08,
                  `${theme.id}/${viewport.id} task artwork pixel delta ${artworkPixelDelta} is too low`,
                );
              }
              const pixels = await analyzeScreenshot(page, screenshotBuffer);
              let screenshotPath = null;
              if (resolvedOutputDirectory) {
                const sceneDirectory = path.join(resolvedOutputDirectory, "scenes", theme.id);
                await mkdir(sceneDirectory, { recursive: true, mode: 0o700 });
                screenshotPath = path.join(sceneDirectory, `${routeName}-${viewport.id}.png`);
                await writeFile(screenshotPath, screenshotBuffer, { mode: 0o600 });
                if (viewport.id === "wide" && primaryThemeIDs.has(theme.id)) {
                  const primaryDirectory = path.join(resolvedOutputDirectory, "primary");
                  await mkdir(primaryDirectory, { recursive: true, mode: 0o700 });
                  await writeFile(
                    path.join(primaryDirectory, `${theme.id}-${routeName}.png`),
                    screenshotBuffer,
                    { mode: 0o600 },
                  );
                }
              }

              scenes.push({
                key: `${theme.id}-${routeName}-${viewport.id}`,
                themeID: theme.id,
                themeName: theme.name,
                styleFamily: theme.styleFamily,
                route: routeName,
                viewport: viewport.id,
                viewportWidth: viewport.width,
                viewportHeight: viewport.height,
                routeLatencyMS,
                routeMutationObserved: routeTransition.mutationObserved,
                artDecoded: art.decoded,
                artWidth: art.width,
                artHeight: art.height,
                artDecodeMS: art.decodeMS,
                artworkPixelDelta,
                screenshotPath,
                screenshotFingerprint: sha256(screenshotBuffer),
                sourceFingerprint: theme.sourceFingerprint,
                cssFingerprint: theme.cssFingerprint,
                artFingerprint: theme.artFingerprint,
                ...pageChecks,
                ...contrast,
                ...pixels,
              });
            }
          } finally {
            await page.close();
          }
        }
      } finally {
        await context.close();
      }
    }
  } finally {
    await browser.close();
  }

  assert(scenes.length === EXPECTED_FIXTURE_SCENE_COUNT, `expected 96 scenes, found ${scenes.length}`);
  assertSceneDifferences(scenes);
  const metadata = JSON.parse(playwrightMetadata);
  const metrics = {
    schemaVersion: 1,
    fixtureLabel: FIXTURE_LABEL,
    offlineOnly: true,
    commit: currentCommit(),
    profileVersion: payload.profileVersion,
    profileID: payload.profile.id,
    profileFingerprint: payload.profileFingerprint,
    templateFingerprint: payload.templateFingerprint,
    exporterContractFingerprint: payload.exporterContractFingerprint,
    fixtureSourceFingerprint: actualFixtureFingerprint,
    rendererFingerprint: sha256(`${rendererSource}\0${contractSource}`),
    playwrightVersion: metadata.version,
    chromiumVersion: browserVersion,
    externalRequests,
    focusYProbe,
    scenes,
    contactSheets: [],
  };

  if (resolvedOutputDirectory) {
    metrics.contactSheets = await renderContactSheets(resolvedOutputDirectory, scenes);
    await writeFile(
      path.join(resolvedOutputDirectory, "metrics.json"),
      `${JSON.stringify(metrics, null, 2)}\n`,
      { mode: 0o600 },
    );
  }
  return { scenes, metrics };
}

async function measureNarrowFocusYProbe(browser, payload) {
  const configuration = focusYProbeConfiguration;
  const viewport = FIXTURE_VIEWPORTS.find(({ id }) => id === configuration.viewport);
  const theme = payload.themes.find(({ id }) => id === configuration.themeID);
  assert(viewport, `focus y probe viewport ${configuration.viewport} is missing`);
  assert(theme, `focus y probe theme ${configuration.themeID} is missing`);

  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    locale: "en-US",
    reducedMotion: "reduce",
    serviceWorkers: "block",
  });
  const blockedRequests = [];
  await context.route("**/*", async (route) => {
    const url = route.request().url();
    if (classifyFixtureRequest(url, documentURL) === "allow") {
      await route.continue();
    } else {
      blockedRequests.push(url);
      await route.abort("blockedbyclient");
    }
  });

  try {
    const page = await context.newPage();
    await page.goto(documentURL, { waitUntil: "load" });
    await page.emulateMedia({ reducedMotion: "reduce" });
    const art = await decodeArtwork(page, theme.backgroundDataURL);
    assert(art.decoded, `${theme.id} focus y probe artwork did not decode`);
    assert(
      art.width / art.height > viewport.width / viewport.height,
      `${theme.id} focus y probe requires artwork wider than the narrow viewport`,
    );
    await page.evaluate(theme.installerExpression);
    await page.waitForFunction(
      () => document.documentElement.dataset.codexHabitatTheme === "1",
    );
    await page.addStyleTag({
      content: `
        .offline-fixture-label,
        #root > * {
          visibility: hidden !important;
        }
        html,
        body,
        html[data-codex-habitat-theme="1"] #root {
          background: transparent !important;
        }
        html[data-codex-habitat-theme="1"] #root::before {
          filter: none !important;
          opacity: 1 !important;
          transition: none !important;
        }
        html[data-codex-habitat-theme="1"] #root::after {
          content: none !important;
        }
      `,
    });

    const captureAtFocusY = async (focusY) => {
      await page.evaluate(({ scale, y }) => {
        document.documentElement.style.setProperty("--habitat-home-art-scale", String(scale));
        document.documentElement.style.setProperty(
          "--habitat-home-art-position",
          `50% ${y * 100}%`,
        );
      }, { scale: configuration.scale, y: focusY });
      await page.evaluate(() => new Promise((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(resolve));
      }));
      return page.locator(LATEST_PROFILE_SELECTORS.appShell).screenshot({
        animations: "disabled",
        type: "png",
      });
    };

    const firstScreenshot = await captureAtFocusY(configuration.firstFocusY);
    const secondScreenshot = await captureAtFocusY(configuration.secondFocusY);
    const pixelDelta = await compareScreenshotPixels(page, firstScreenshot, secondScreenshot);
    assert(blockedRequests.length === 0, `focus y probe request blocked: ${blockedRequests.join(", ")}`);
    assert(
      pixelDelta > 0,
      `${theme.id}/${viewport.id} focus y pixel delta ${pixelDelta} is not greater than zero`,
    );
    return {
      ...configuration,
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      artWidth: art.width,
      artHeight: art.height,
      firstScreenshotFingerprint: sha256(firstScreenshot),
      secondScreenshotFingerprint: sha256(secondScreenshot),
      pixelDelta,
    };
  } finally {
    await context.close();
  }
}

async function selectFixtureRoute(page, routeName, homeMarkerSelector) {
  return page.evaluate(
    async ({ selectedRoute, markerSelector }) => {
      const startedAt = performance.now();
      const previousRoute = document.documentElement.dataset.codexHabitatRoute;
      const home = document.querySelector('[data-fixture-route="home"]');
      const task = document.querySelector('[data-fixture-route="task"]');
      if (!(home instanceof HTMLElement) || !(task instanceof HTMLElement)) {
        throw new Error("fixture route surfaces are missing");
      }
      home.hidden = selectedRoute !== "home";
      task.hidden = selectedRoute !== "task";

      let marker = document.querySelector(markerSelector);
      if (selectedRoute === "home" && !marker) {
        marker = document.createElement("div");
        marker.setAttribute("data-testid", "home-icon");
        marker.setAttribute("aria-hidden", "true");
        marker.textContent = "◇";
        home.prepend(marker);
      } else if (selectedRoute === "task" && marker) {
        marker.remove();
      }

      if (document.documentElement.dataset.codexHabitatRoute === selectedRoute) {
        return { latencyMS: performance.now() - startedAt, mutationObserved: false };
      }
      return new Promise((resolve, reject) => {
        const observer = new MutationObserver(() => {
          if (document.documentElement.dataset.codexHabitatRoute === selectedRoute) {
            observer.disconnect();
            clearTimeout(timeout);
            resolve({
              latencyMS: performance.now() - startedAt,
              mutationObserved: previousRoute !== selectedRoute,
            });
          }
        });
        observer.observe(document.documentElement, {
          attributes: true,
          attributeFilter: ["data-codex-habitat-route"],
        });
        const timeout = setTimeout(() => {
          observer.disconnect();
          reject(new Error(`route did not become ${selectedRoute}`));
        }, 500);
      });
    },
    { selectedRoute: routeName, markerSelector: homeMarkerSelector },
  );
}

async function inspectFixturePage(
  page,
  selectors,
  routeName,
  consoleErrors,
  pageErrors,
  taskModeOff,
  taskModeBanner,
) {
  assert(await page.locator('[data-offline-theme-fixture="true"]').count() === 1, "offline marker missing");
  assert(await page.getByText(FIXTURE_LABEL, { exact: true }).count() === 1, "offline label missing");
  await assertProfileSelectorCardinality(page, selectors, routeName);
  await assertSurfaceAnnotations(page, selectors);

  const activeRoute = await page.locator("html").getAttribute("data-codex-habitat-route");
  assert(activeRoute === routeName, `expected ${routeName} route, found ${activeRoute}`);
  const styleCount = await page.locator("#codex-habitat-theme-style").count();
  assert(styleCount === 1, `expected one installed style, found ${styleCount}`);
  assert(consoleErrors.length === 0, `console error: ${consoleErrors.join("; ")}`);
  assert(pageErrors.length === 0, `page error: ${pageErrors.join("; ")}`);

  const horizontalOverflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  assert(horizontalOverflow <= 0, `horizontal overflow: ${horizontalOverflow}px`);

  const composerHit = await page.locator("#fixture-composer").evaluate((node) => {
    const rect = node.getBoundingClientRect();
    return document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2) === node;
  });
  assert(composerHit, "composer does not receive pointer hit testing");
  const popoverBounds = await page.evaluate((popoverSelector) => {
    const popover = document.querySelector(popoverSelector);
    const composer = document.querySelector(".composer-surface-chrome");
    if (!(popover instanceof HTMLElement) || !(composer instanceof HTMLElement)) {
      return { inViewport: false, overlapsComposer: true };
    }
    const popoverRect = popover.getBoundingClientRect();
    const composerRect = composer.getBoundingClientRect();
    const overlapsComposer = !(
      popoverRect.right <= composerRect.left
      || popoverRect.left >= composerRect.right
      || popoverRect.bottom <= composerRect.top
      || popoverRect.top >= composerRect.bottom
    );
    return {
      inViewport:
        popoverRect.width > 0
        && popoverRect.height > 0
        && popoverRect.left >= 0
        && popoverRect.top >= 0
        && popoverRect.right <= innerWidth
        && popoverRect.bottom <= innerHeight,
      overlapsComposer,
    };
  }, selectors.popover);
  assert(popoverBounds.inViewport, "popover is outside the viewport");
  assert(!popoverBounds.overlapsComposer, "popover overlaps the composer");
  const coreBounds = await assertCoreBounds(page, selectors, routeName);
  await assertSemanticTextColors(page, routeName);

  let taskCanScroll = false;
  let finalScrollTop = 0;
  if (routeName === "task") {
    const scroll = await page.locator(selectors.threadScroll).evaluate((node) => {
      const before = node.scrollTop;
      node.scrollTop = node.scrollHeight;
      const maximum = node.scrollTop;
      const canScroll = node.scrollHeight > node.clientHeight && maximum > before;
      node.scrollTop = before;
      return { canScroll, finalScrollTop: node.scrollTop };
    });
    taskCanScroll = scroll.canScroll;
    finalScrollTop = scroll.finalScrollTop;
    assert(taskCanScroll, "task transcript is not scrollable");
    assert(finalScrollTop === 0, `task transcript did not restore scrollTop: ${finalScrollTop}`);
  }

  const scene = await page.locator(selectors.appShell).evaluate((node, transcriptSelector) => {
    const artwork = getComputedStyle(node, "::before");
    const overlay = getComputedStyle(node, "::after");
    const sidebar = getComputedStyle(document.querySelector("aside.app-shell-left-panel"));
    const transcript = getComputedStyle(document.querySelector(transcriptSelector));
    return {
      artworkBackground: artwork.backgroundImage,
      artworkOpacity: Number.parseFloat(artwork.opacity),
      artworkPosition: artwork.position,
      artworkSize: artwork.backgroundSize,
      artworkMask: artwork.maskImage || artwork.webkitMaskImage,
      overlayBackgroundImage: overlay.backgroundImage,
      overlayMask: overlay.maskImage || overlay.webkitMaskImage,
      sidebarBackdropFilter: sidebar.backdropFilter,
      transcriptBackgroundImage: transcript.backgroundImage,
    };
  }, selectors.threadScroll);
  assert(scene.artworkBackground.startsWith('url("data:image/'), "compiled artwork is not installed");
  assert(scene.artworkPosition === "fixed", `artwork position is ${scene.artworkPosition}`);
  assert(scene.artworkSize === "cover", `artwork size is ${scene.artworkSize}`);
  assert(scene.sidebarBackdropFilter === "none", "sidebar unexpectedly uses backdrop blur");
  const sceneOverlayLayerCount = (scene.overlayBackgroundImage.match(/gradient\(/g) ?? []).length;
  assert(sceneOverlayLayerCount >= 2, `scene overlay has only ${sceneOverlayLayerCount} gradient layer(s)`);
  if (routeName === "home") {
    assert(scene.artworkOpacity > 0, "home artwork is not visible");
  } else if (taskModeOff) {
    assert(scene.artworkOpacity === 0, "taskMode off still shows artwork");
  } else {
    assert(scene.artworkOpacity > 0, "task artwork is not visible");
  }
  const bannerFadeValid = routeName !== "task" || !taskModeBanner || (
    scene.artworkMask.includes("linear-gradient")
    && scene.overlayMask.includes("linear-gradient")
  );
  assert(bannerFadeValid, "task banner artwork does not fade into the transcript");
  const taskReadingScrimValid = routeName !== "task" || (
    taskModeOff
      ? scene.transcriptBackgroundImage === "none"
      : scene.transcriptBackgroundImage.includes("gradient")
  );
  assert(taskReadingScrimValid, "task reading scrim is not active on the transcript owner");
  const taskReadingLayerCount = routeName === "task"
    ? (scene.transcriptBackgroundImage.match(/gradient\(/g) ?? []).length
    : null;
  if (routeName === "task") {
    assert(
      taskReadingLayerCount >= 2,
      `task reading surface has only ${taskReadingLayerCount} gradient layer(s)`,
    );
  }
  const messageCardOpacity = routeName === "task"
    ? await page.locator('[data-fixture-surface="message"]').evaluate((node) => {
      const color = getComputedStyle(node).backgroundColor;
      const slashAlpha = color.match(/\/\s*([0-9.]+)\s*\)$/);
      if (slashAlpha) return Number.parseFloat(slashAlpha[1]);
      const legacyAlpha = color.match(/^rgba\([^,]+,[^,]+,[^,]+,\s*([0-9.]+)\)$/);
      if (legacyAlpha) return Number.parseFloat(legacyAlpha[1]);
      return color === "transparent" ? 0 : null;
    })
    : null;
  if (routeName === "task") {
    assert(
      messageCardOpacity !== null && Math.abs(messageCardOpacity - 0.88) <= 0.001,
      `task message card opacity is ${messageCardOpacity}`,
    );
  }
  const materialHierarchy = await page.evaluate(({ profileSelectors, activeRoute }) => {
    const appShell = document.querySelector(profileSelectors.appShell);
    const mainSurface = document.querySelector(profileSelectors.mainSurface);
    const composer = document.querySelector(profileSelectors.composer);
    const composerContext = document.querySelector(profileSelectors.composerContext);
    if (
      !(appShell instanceof HTMLElement)
      || !(mainSurface instanceof HTMLElement)
      || !(composer instanceof HTMLElement)
      || !(composerContext instanceof HTMLElement)
    ) {
      throw new Error("composer material path is missing");
    }

    const canvas = document.createElement("canvas");
    canvas.width = 1;
    canvas.height = 1;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    if (!context) throw new Error("unable to inspect computed background alpha");
    const computedBackground = (node) => {
      const color = getComputedStyle(node).backgroundColor;
      context.clearRect(0, 0, 1, 1);
      context.fillStyle = "#ff00ff";
      context.fillStyle = color;
      context.fillRect(0, 0, 1, 1);
      return {
        computedBackgroundColor: color,
        backgroundAlpha: context.getImageData(0, 0, 1, 1).data[3] / 255,
      };
    };
    const ancestorChain = (node, surfaceForNode) => {
      const chain = [];
      for (let current = node; current instanceof HTMLElement; current = current.parentElement) {
        const surface = surfaceForNode(current) ?? `dom:${current.tagName.toLowerCase()}`;
        chain.push({ surface, ...computedBackground(current) });
        if (current === appShell) break;
      }
      return chain;
    };
    const composerMaterialChain = ancestorChain(composer, (node) => {
      if (node === composer) return "composer";
      if (node === composerContext) return "composer-context";
      if (node === mainSurface) return "main-surface";
      if (node === appShell) return "app-shell";
      return null;
    });

    let homeMaterialChain = null;
    if (activeRoute === "home") {
      const homeContent = document.querySelector(profileSelectors.homeContent);
      const homeSuggestions = document.querySelector(profileSelectors.homeSuggestions);
      const homeAction = homeSuggestions?.querySelector(":scope > :where(button, [role=button])");
      if (
        !(homeContent instanceof HTMLElement)
        || !(homeSuggestions instanceof HTMLElement)
        || !(homeAction instanceof HTMLElement)
      ) {
        throw new Error("home material path is missing");
      }
      homeMaterialChain = ancestorChain(homeAction, (node) => {
        if (node === homeAction) return "home-action";
        if (node === homeSuggestions) return "home-suggestions";
        if (node === homeContent) return "home-content";
        if (node === mainSurface) return "main-surface";
        if (node === appShell) return "app-shell";
        return null;
      });
    }

    const alphaFor = (chain, surface) =>
      chain?.find((entry) => entry.surface === surface)?.backgroundAlpha ?? null;
    return {
      homeContentBackgroundAlpha: alphaFor(homeMaterialChain, "home-content"),
      homeSuggestionsBackgroundAlpha: alphaFor(homeMaterialChain, "home-suggestions"),
      homeActionBackgroundAlpha: alphaFor(homeMaterialChain, "home-action"),
      composerContextBackgroundAlpha: alphaFor(composerMaterialChain, "composer-context"),
      composerBackgroundAlpha: alphaFor(composerMaterialChain, "composer"),
      homeMaterialChain,
      composerMaterialChain,
    };
  }, { profileSelectors: selectors, activeRoute: routeName });
  const alphaTolerance = 1 / 255;
  assert(
    Number.isFinite(materialHierarchy.composerContextBackgroundAlpha)
      && materialHierarchy.composerContextBackgroundAlpha <= alphaTolerance,
    `composer context background alpha is ${materialHierarchy.composerContextBackgroundAlpha}`,
  );
  assert(
    Number.isFinite(materialHierarchy.composerBackgroundAlpha)
      && materialHierarchy.composerBackgroundAlpha >= 0.84 - alphaTolerance
      && materialHierarchy.composerBackgroundAlpha <= 0.90 + alphaTolerance,
    `composer background alpha is ${materialHierarchy.composerBackgroundAlpha}`,
  );
  if (routeName === "home") {
    assert(
      Number.isFinite(materialHierarchy.homeContentBackgroundAlpha)
        && materialHierarchy.homeContentBackgroundAlpha <= alphaTolerance,
      `home content background alpha is ${materialHierarchy.homeContentBackgroundAlpha}`,
    );
    assert(
      Number.isFinite(materialHierarchy.homeSuggestionsBackgroundAlpha)
        && materialHierarchy.homeSuggestionsBackgroundAlpha <= alphaTolerance,
      `home suggestions background alpha is ${materialHierarchy.homeSuggestionsBackgroundAlpha}`,
    );
    assert(
      Number.isFinite(materialHierarchy.homeActionBackgroundAlpha)
        && Math.abs(materialHierarchy.homeActionBackgroundAlpha - 0.82) <= alphaTolerance,
      `home action background alpha is ${materialHierarchy.homeActionBackgroundAlpha}`,
    );
  }

  return {
    styleCount,
    horizontalOverflow,
    composerHit,
    popoverInViewport: popoverBounds.inViewport,
    popoverOverlapsComposer: popoverBounds.overlapsComposer,
    surfaceAnnotationsValid: true,
    allControlsWithinViewport: true,
    homeSuggestionMinimumViewportInset: coreBounds.homeSuggestionMinimumViewportInset,
    semanticForegroundsValid: true,
    bannerFadeValid,
    taskReadingScrimValid,
    sceneOverlayLayerCount,
    taskReadingLayerCount,
    messageCardOpacity,
    taskCanScroll,
    finalScrollTop,
    artworkOpacity: scene.artworkOpacity,
    taskModeOff,
    ...materialHierarchy,
  };
}

async function assertSemanticTextColors(page, routeName) {
  const failures = await page.evaluate((activeRoute) => {
    const root = document.querySelector("#root");
    if (!(root instanceof HTMLElement)) return ["root is missing"];
    const resolveThemeColor = (name) => {
      const probe = document.createElement("span");
      probe.style.color = `var(${name})`;
      root.appendChild(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    };
    const text = resolveThemeColor("--habitat-text");
    const muted = resolveThemeColor("--habitat-readable-muted");
    const checks = [
      ["nav a:not([aria-current])", text],
      [".fixture-recents h2", muted],
      [".fixture-account", text],
      [".fixture-popover", text],
    ];
    if (activeRoute === "home") {
      checks.push([".fixture-home p", muted]);
      checks.push(['[class~="group/home-suggestions"] :where(button, [role="button"])', text]);
    } else {
      checks.push(
        [".fixture-message h2", text],
        [".fixture-message p", text],
        [".fixture-tool strong", text],
        [".fixture-tool p", text],
        [".fixture-tool-grid > div", text],
      );
    }
    return checks.flatMap(([selector, expected]) => {
      const nodes = [...document.querySelectorAll(selector)].filter((node) =>
        node instanceof HTMLElement && !node.closest("[hidden]"));
      if (nodes.length === 0) return [`${selector} is missing`];
      return nodes.flatMap((node) => {
        const actual = getComputedStyle(node).color;
        return actual === expected ? [] : [`${selector}: ${actual}, expected ${expected}`];
      });
    });
  }, routeName);
  assert(failures.length === 0, `semantic text color mismatch: ${failures.join("; ")}`);
}

async function measureFinalPixelContrast(page, screenshotBuffer, routeName) {
  const targets = FIXTURE_CONTRAST_TARGETS[routeName];
  const frames = [await measureContrastFrame(page, screenshotBuffer, targets, routeName)];
  let originalScrollTop = 0;

  if (routeName === "task") {
    const scroll = await page.locator(".thread-scroll-container").evaluate((node) => {
      const original = node.scrollTop;
      node.scrollTop = node.scrollHeight;
      return { original, maximum: node.scrollTop };
    });
    originalScrollTop = scroll.original;
    if (scroll.maximum > originalScrollTop) {
      await settleRenderedFrame(page);
      const bottomScreenshot = await page.screenshot({
        animations: "disabled",
        fullPage: false,
        type: "png",
      });
      frames.push(await measureContrastFrame(page, bottomScreenshot, targets, routeName));
    }
    await page.locator(".thread-scroll-container").evaluate(
      (node, scrollTop) => { node.scrollTop = scrollTop; },
      originalScrollTop,
    );
    await settleRenderedFrame(page);
  }

  const byTarget = new Map();
  for (const frame of frames) {
    for (const sample of frame.contrastSamples) {
      if (sample.evidenceCount <= 0) continue;
      const existing = byTarget.get(sample.id);
      byTarget.set(sample.id, mergeContrastFrameSamples(existing, sample));
    }
  }
  const contrastSamples = [...byTarget.values()];
  const textRatios = contrastSamples
    .filter(({ kind }) => kind === "normalText")
    .map(({ ratio }) => ratio);
  const controlRatios = contrastSamples
    .filter(({ kind }) => kind === "control")
    .map(({ ratio }) => ratio);
  const leakSamples = frames
    .map(({ taskReadingArtworkLeak }) => taskReadingArtworkLeak)
    .filter((value) => Number.isFinite(value));
  const taskReadingTileCount = frames.reduce(
    (total, frame) => total + frame.taskReadingTileCount,
    0,
  );
  return {
    contrastSamples,
    minimumTextContrast: textRatios.length > 0 ? Math.min(...textRatios) : 0,
    minimumControlContrast: controlRatios.length > 0 ? Math.min(...controlRatios) : 0,
    taskReadingArtworkLeak: routeName === "task" && leakSamples.length > 0
      ? Math.max(...leakSamples)
      : null,
    taskReadingTileCount: routeName === "task" ? taskReadingTileCount : null,
  };
}

async function measureContrastFrame(page, finalScreenshot, targets, routeName) {
  const geometry = await page.evaluate(({ contrastTargets, activeRoute }) => {
    const viewport = { left: 0, top: 0, right: innerWidth, bottom: innerHeight };
    const intersect = (left, right) => {
      const result = {
        left: Math.max(left.left, right.left),
        top: Math.max(left.top, right.top),
        right: Math.min(left.right, right.right),
        bottom: Math.min(left.bottom, right.bottom),
      };
      return result.right > result.left && result.bottom > result.top ? result : null;
    };
    const asPlainRect = (rect) => ({
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
    });
    const visibleClip = (node) => {
      if (!(node instanceof HTMLElement) || node.closest("[hidden]")) return null;
      for (let current = node; current instanceof HTMLElement; current = current.parentElement) {
        const style = getComputedStyle(current);
        if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) {
          return null;
        }
      }
      const scroll = node.closest(".thread-scroll-container");
      const clip = scroll ? intersect(viewport, asPlainRect(scroll.getBoundingClientRect())) : viewport;
      return clip && intersect(asPlainRect(node.getBoundingClientRect()), clip) ? clip : null;
    };
    const clippedRect = (rect, clip) => intersect(asPlainRect(rect), clip);
    const textRects = (node, clip) => {
      const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
      const rects = [];
      for (let text = walker.nextNode(); text; text = walker.nextNode()) {
        if (!text.textContent?.trim()) continue;
        const range = document.createRange();
        range.selectNodeContents(text);
        for (const rect of range.getClientRects()) {
          const clipped = clippedRect(rect, clip);
          if (clipped && clipped.right - clipped.left >= 1 && clipped.bottom - clipped.top >= 1) {
            rects.push(clipped);
          }
        }
      }
      return rects;
    };
    const placeholderRect = (node, clip) => {
      const rect = node.getBoundingClientRect();
      return clippedRect({
        left: rect.left + 8,
        top: rect.top + 6,
        right: rect.right - 8,
        bottom: rect.bottom - 6,
      }, clip);
    };
    const collectedTargets = contrastTargets.map((target) => {
      const nodes = [];
      for (const node of document.querySelectorAll(target.selector)) {
        const clip = visibleClip(node);
        if (!clip) continue;
        const rects = [];
        if (target.pseudo === "placeholder") {
          const rect = placeholderRect(node, clip);
          if (rect) rects.push(rect);
        } else {
          rects.push(...textRects(node, clip));
        }
        const text = node.getAttribute("aria-label") ?? node.textContent ?? "";
        const label = `${node.tagName.toLowerCase()}:${text.trim().replace(/\s+/g, " ").slice(0, 80)}`;
        nodes.push({ label, rects });
      }
      return { id: target.id, kind: target.kind, nodes };
    });

    const taskReadingRects = [];
    if (activeRoute === "task") {
      const response = document.querySelector("[data-content-search-unit-key]");
      const scroll = response?.closest(".thread-scroll-container");
      if (response instanceof HTMLElement && scroll instanceof HTMLElement) {
        const scrollClip = intersect(viewport, asPlainRect(scroll.getBoundingClientRect()));
        const visibleResponse = scrollClip
          ? intersect(asPlainRect(response.getBoundingClientRect()), scrollClip)
          : null;
        if (visibleResponse) {
          const protectedRects = [...response.querySelectorAll(
            '[data-fixture-surface="code"], [data-fixture-surface="tool"], .fixture-tool-grid',
          )].map((node) => asPlainRect(node.getBoundingClientRect()));
          const readingBounds = {
            left: visibleResponse.left + 10,
            top: visibleResponse.top + 10,
            right: visibleResponse.right - 10,
            bottom: visibleResponse.bottom - 10,
          };
          const tileSize = 64;
          for (let top = readingBounds.top; top < readingBounds.bottom; top += tileSize) {
            for (let left = readingBounds.left; left < readingBounds.right; left += tileSize) {
              const tile = {
                left,
                top,
                right: Math.min(left + tileSize, readingBounds.right),
                bottom: Math.min(top + tileSize, readingBounds.bottom),
              };
              if (tile.right - tile.left < 24 || tile.bottom - tile.top < 24) continue;
              if (protectedRects.some((rect) => intersect(tile, rect))) continue;
              taskReadingRects.push(tile);
            }
          }
        }
      }
    }
    return {
      targets: collectedTargets,
      taskReadingRects,
      viewportWidth: innerWidth,
      viewportHeight: innerHeight,
    };
  }, { contrastTargets: targets, activeRoute: routeName });

  const foregroundRules = (color, textShadow) => targets.map((target) => {
    const selector = target.pseudo === "placeholder"
      ? `${target.selector}::placeholder`
      : target.selector;
    return `${selector} { color: ${color} !important; -webkit-text-fill-color: ${color} !important; ${textShadow} caret-color: transparent !important; }`;
  }).join("\n");
  const sentinelForegrounds = await page.addStyleTag({
    content: foregroundRules("#000000", "text-shadow: none !important;"),
  });
  let blackSentinelScreenshot;
  let whiteSentinelScreenshot;
  try {
    await settleRenderedFrame(page);
    blackSentinelScreenshot = await page.screenshot({
      animations: "disabled",
      fullPage: false,
      type: "png",
    });
    await sentinelForegrounds.evaluate((node, content) => { node.textContent = content; },
      foregroundRules("#ffffff", "text-shadow: none !important;"));
    await settleRenderedFrame(page);
    whiteSentinelScreenshot = await page.screenshot({
      animations: "disabled",
      fullPage: false,
      type: "png",
    });
  } finally {
    await sentinelForegrounds.evaluate((node) => node.remove());
  }

  const hiddenForegrounds = await page.addStyleTag({
    content: foregroundRules("transparent", ""),
  });
  let backgroundScreenshot;
  let backgroundWithoutArtwork = null;
  try {
    await settleRenderedFrame(page);
    backgroundScreenshot = await page.screenshot({
      animations: "disabled",
      fullPage: false,
      type: "png",
    });
    if (geometry.taskReadingRects.length > 0) {
      const hiddenArtwork = await page.addStyleTag({
        content: 'html[data-codex-habitat-theme="1"] #root::before { opacity: 0 !important; }',
      });
      try {
        await settleRenderedFrame(page);
        backgroundWithoutArtwork = await page.screenshot({
          animations: "disabled",
          fullPage: false,
          type: "png",
        });
      } finally {
        await hiddenArtwork.evaluate((node) => node.remove());
      }
    }
  } finally {
    await hiddenForegrounds.evaluate((node) => node.remove());
    await settleRenderedFrame(page);
  }

  const pixelEvidence = await page.evaluate(async ({
    finalBase64,
    backgroundBase64,
    blackSentinelBase64,
    whiteSentinelBase64,
    noArtworkBase64,
    frameGeometry,
    glyphCoreSentinelDelta,
  }) => {
    const decode = async (base64) => {
      const image = new Image();
      image.src = `data:image/png;base64,${base64}`;
      await image.decode();
      const canvas = document.createElement("canvas");
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      const context = canvas.getContext("2d", { willReadFrequently: true });
      if (!context) throw new Error("unable to create screenshot contrast canvas");
      context.drawImage(image, 0, 0);
      return {
        width: canvas.width,
        height: canvas.height,
        pixels: context.getImageData(0, 0, canvas.width, canvas.height).data,
      };
    };
    const [finalImage, backgroundImage, blackSentinelImage, whiteSentinelImage, noArtworkImage] = await Promise.all([
      decode(finalBase64),
      decode(backgroundBase64),
      decode(blackSentinelBase64),
      decode(whiteSentinelBase64),
      noArtworkBase64 ? decode(noArtworkBase64) : null,
    ]);
    if (
      finalImage.width !== backgroundImage.width
      || finalImage.height !== backgroundImage.height
      || blackSentinelImage.width !== finalImage.width
      || blackSentinelImage.height !== finalImage.height
      || whiteSentinelImage.width !== finalImage.width
      || whiteSentinelImage.height !== finalImage.height
      || (noArtworkImage && (
        noArtworkImage.width !== finalImage.width
        || noArtworkImage.height !== finalImage.height
      ))
    ) {
      throw new Error("contrast screenshots have mismatched dimensions");
    }
    const scaleX = finalImage.width / frameGeometry.viewportWidth;
    const scaleY = finalImage.height / frameGeometry.viewportHeight;
    const linearChannel = (value) => {
      const normalized = value / 255;
      return normalized <= 0.04045
        ? normalized / 12.92
        : ((normalized + 0.055) / 1.055) ** 2.4;
    };
    const luminanceRGB = (channels) => (
      0.2126 * linearChannel(channels[0])
      + 0.7152 * linearChannel(channels[1])
      + 0.0722 * linearChannel(channels[2])
    );
    const foregroundContrastAt = (offset, coverage) => {
      const background = [
        backgroundImage.pixels[offset],
        backgroundImage.pixels[offset + 1],
        backgroundImage.pixels[offset + 2],
      ];
      const foreground = background.map((channel, index) => Math.max(0, Math.min(255,
        (finalImage.pixels[offset + index] - channel * (1 - coverage)) / coverage,
      )));
      const foregroundLuminance = luminanceRGB(foreground);
      const backgroundLuminance = luminanceRGB(background);
      return (Math.max(foregroundLuminance, backgroundLuminance) + 0.05)
        / (Math.min(foregroundLuminance, backgroundLuminance) + 0.05);
    };
    const pixelBounds = (rect) => ({
      left: Math.max(0, Math.floor(rect.left * scaleX)),
      top: Math.max(0, Math.floor(rect.top * scaleY)),
      right: Math.min(finalImage.width, Math.ceil(rect.right * scaleX)),
      bottom: Math.min(finalImage.height, Math.ceil(rect.bottom * scaleY)),
    });
    const sampleNode = (node) => {
      const corePixels = [];
      const visited = new Set();
      for (const rect of node.rects) {
        const bounds = pixelBounds(rect);
        for (let y = bounds.top; y < bounds.bottom; y += 1) {
          for (let x = bounds.left; x < bounds.right; x += 1) {
            const pixelIndex = y * finalImage.width + x;
            if (visited.has(pixelIndex)) continue;
            visited.add(pixelIndex);
            const offset = pixelIndex * 4;
            const sentinelDelta = Math.max(
              Math.abs(blackSentinelImage.pixels[offset] - whiteSentinelImage.pixels[offset]),
              Math.abs(blackSentinelImage.pixels[offset + 1] - whiteSentinelImage.pixels[offset + 1]),
              Math.abs(blackSentinelImage.pixels[offset + 2] - whiteSentinelImage.pixels[offset + 2]),
            );
            if (sentinelDelta >= glyphCoreSentinelDelta) {
              corePixels.push({ offset, coverage: sentinelDelta / 255 });
            }
          }
        }
      }
      if (corePixels.length === 0) {
        return { label: node.label, ratio: 0, pixelCount: 0, rectCount: node.rects.length };
      }
      const ratios = corePixels
        .map(({ offset, coverage }) => foregroundContrastAt(offset, coverage))
        .sort((left, right) => left - right);
      const lowPercentileIndex = Math.floor((ratios.length - 1) * 0.05);
      return {
        label: node.label,
        ratio: ratios[lowPercentileIndex],
        pixelCount: ratios.length,
        rectCount: node.rects.length,
      };
    };
    const contrastTargets = frameGeometry.targets.map((target) => ({
      id: target.id,
      kind: target.kind,
      nodeSamples: target.nodes.map(sampleNode),
    }));

    const taskReadingTileLeaks = [];
    if (frameGeometry.taskReadingRects.length > 0 && noArtworkImage) {
      for (const rect of frameGeometry.taskReadingRects) {
        const bounds = pixelBounds(rect);
        let totalDelta = 0;
        let pixelCount = 0;
        for (let y = bounds.top; y < bounds.bottom; y += 2) {
          for (let x = bounds.left; x < bounds.right; x += 2) {
            const offset = (y * finalImage.width + x) * 4;
            totalDelta += Math.max(
              Math.abs(backgroundImage.pixels[offset] - noArtworkImage.pixels[offset]),
              Math.abs(backgroundImage.pixels[offset + 1] - noArtworkImage.pixels[offset + 1]),
              Math.abs(backgroundImage.pixels[offset + 2] - noArtworkImage.pixels[offset + 2]),
            ) / 255;
            pixelCount += 1;
          }
        }
        if (pixelCount > 0) taskReadingTileLeaks.push(totalDelta / pixelCount);
      }
    }
    return { contrastTargets, taskReadingTileLeaks };
  }, {
    finalBase64: finalScreenshot.toString("base64"),
    backgroundBase64: backgroundScreenshot.toString("base64"),
    blackSentinelBase64: blackSentinelScreenshot.toString("base64"),
    whiteSentinelBase64: whiteSentinelScreenshot.toString("base64"),
    noArtworkBase64: backgroundWithoutArtwork?.toString("base64") ?? null,
    frameGeometry: geometry,
    glyphCoreSentinelDelta: GLYPH_CORE_SENTINEL_DELTA,
  });
  return {
    contrastSamples: pixelEvidence.contrastTargets.map((target) =>
      summarizeContrastNodeSamples(target, target.nodeSamples)),
    taskReadingArtworkLeak: percentileLocalArtworkLeak(pixelEvidence.taskReadingTileLeaks),
    taskReadingTileCount: pixelEvidence.taskReadingTileLeaks.length,
  };
}

async function settleRenderedFrame(page) {
  await page.evaluate(() => new Promise((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(resolve));
  }));
}

async function assertProfileSelectorCardinality(page, selectors, routeName) {
  for (const [name, selectorOrSelectors] of Object.entries(selectors)) {
    const values = Array.isArray(selectorOrSelectors) ? selectorOrSelectors : [selectorOrSelectors];
    for (const selector of values) {
      const expected = name === "homeMarker" && routeName === "task" ? 0 : 1;
      const count = await page.locator(selector).count();
      assert(count === expected, `${name} selector cardinality changed: ${count}, expected ${expected}`);
    }
  }
}

async function assertSurfaceAnnotations(page, selectors) {
  for (const { selectorKey, surface } of EXPECTED_SURFACE_ANNOTATIONS) {
    const selectorOrSelectors = selectors[selectorKey];
    const values = Array.isArray(selectorOrSelectors) ? selectorOrSelectors : [selectorOrSelectors];
    for (const selector of values) {
      const annotations = await page.locator(selector).evaluateAll((nodes) =>
        nodes.map((node) => node.getAttribute("data-codex-habitat-surface")));
      assert(
        annotations.length > 0 && annotations.every((value) => value === surface),
        `${selectorKey} annotation expected ${surface}, found ${annotations.join(",")}`,
      );
    }
  }
}

async function assertCoreBounds(page, selectors, routeName) {
  const selectorKeys = routeName === "home"
    ? ["sidebar", "mainSurface", "header", "homeSuggestions", "selectedNavigation", "composer"]
    : ["sidebar", "mainSurface", "header", "threadScroll", "selectedNavigation", "composer"];
  for (const selectorKey of selectorKeys) {
    const inViewport = await page.locator(selectors[selectorKey]).evaluate((node) => {
      const rect = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return style.display !== "none"
        && style.visibility !== "hidden"
        && rect.width > 0
        && rect.height > 0
        && rect.left >= 0
        && rect.top >= 0
        && rect.right <= innerWidth
        && rect.bottom <= innerHeight;
    });
    assert(inViewport, `${selectorKey} is clipped or outside the viewport`);
  }
  if (routeName === "home") {
    const minimumInset = await page.locator(selectors.homeSuggestions).evaluate((node) => {
      const controls = Array.from(node.querySelectorAll("button, a, [role=button]"));
      if (controls.length === 0) return null;
      return Math.min(...controls.flatMap((control) => {
        const rect = control.getBoundingClientRect();
        return [rect.left, innerWidth - rect.right];
      }));
    });
    assert(
      minimumInset !== null && minimumInset >= 12,
      `home suggestion controls have only ${String(minimumInset)}px viewport inset`,
    );
    return { homeSuggestionMinimumViewportInset: minimumInset };
  }
  return { homeSuggestionMinimumViewportInset: null };
}

async function measureArtworkPixelDelta(page, themedScreenshot) {
  const revealRects = await page.evaluate(() => {
    const route = document.documentElement.dataset.codexHabitatRoute;
    const main = document.querySelector(".main-surface");
    const header = document.querySelector(".app-header-tint");
    const composer = document.querySelector(".composer-surface-chrome");
    if (!(main instanceof HTMLElement) || !(header instanceof HTMLElement) || !(composer instanceof HTMLElement)) {
      return [];
    }
    const asRect = (node) => {
      const rect = node.getBoundingClientRect();
      return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom };
    };
    const stage = asRect(main);
    stage.top = Math.max(stage.top, header.getBoundingClientRect().bottom + 8);
    stage.bottom = Math.min(stage.bottom, composer.getBoundingClientRect().top - 8);
    const protectedSelector = route === "home"
      ? ".fixture-home, .fixture-popover"
      : ".fixture-message, .fixture-response, .fixture-popover";
    const protectedRects = [...document.querySelectorAll(protectedSelector)].map(asRect);
    const overlaps = (left, right) => !(
      right.right <= left.left
      || right.left >= left.right
      || right.bottom <= left.top
      || right.top >= left.bottom
    );
    const regions = [];
    const tileSize = 32;
    for (let top = stage.top; top < stage.bottom; top += tileSize) {
      for (let left = stage.left; left < stage.right; left += tileSize) {
        const tile = {
          left,
          top,
          right: Math.min(left + tileSize, stage.right),
          bottom: Math.min(top + tileSize, stage.bottom),
        };
        if (tile.right - tile.left < 20 || tile.bottom - tile.top < 20) continue;
        if (protectedRects.some((rect) => overlaps(tile, rect))) continue;
        regions.push(tile);
      }
    }
    return regions;
  });
  const override = await page.addStyleTag({
    content: 'html[data-codex-habitat-theme="1"] #root::before { opacity: 0 !important; }',
  });
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => resolve())));
  const withoutArtwork = await page.screenshot({
    animations: "disabled",
    fullPage: false,
    type: "png",
  });
  await override.evaluate((node) => node.remove());
  return compareScreenshotRegionPixels(page, themedScreenshot, withoutArtwork, revealRects);
}

async function compareScreenshotRegionPixels(page, left, right, regions) {
  return page.evaluate(async ({ leftBase64, rightBase64, sampleRegions }) => {
    if (!Array.isArray(sampleRegions) || sampleRegions.length === 0) return 0;
    const decode = async (base64) => {
      const image = new Image();
      image.src = `data:image/png;base64,${base64}`;
      await image.decode();
      const canvas = document.createElement("canvas");
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      const context = canvas.getContext("2d", { willReadFrequently: true });
      if (!context) throw new Error("unable to create artwork comparison canvas");
      context.drawImage(image, 0, 0);
      return { width: canvas.width, height: canvas.height, pixels: context.getImageData(0, 0, canvas.width, canvas.height).data };
    };
    const [leftImage, rightImage] = await Promise.all([
      decode(leftBase64),
      decode(rightBase64),
    ]);
    if (leftImage.width !== rightImage.width || leftImage.height !== rightImage.height) {
      throw new Error("artwork comparison screenshots have mismatched dimensions");
    }
    const scaleX = leftImage.width / innerWidth;
    const scaleY = leftImage.height / innerHeight;
    let changed = 0;
    let total = 0;
    for (const region of sampleRegions) {
      const left = Math.max(0, Math.floor(region.left * scaleX));
      const top = Math.max(0, Math.floor(region.top * scaleY));
      const right = Math.min(leftImage.width, Math.ceil(region.right * scaleX));
      const bottom = Math.min(leftImage.height, Math.ceil(region.bottom * scaleY));
      for (let y = top; y < bottom; y += 2) {
        for (let x = left; x < right; x += 2) {
          const offset = (y * leftImage.width + x) * 4;
          if (Math.max(
            Math.abs(leftImage.pixels[offset] - rightImage.pixels[offset]),
            Math.abs(leftImage.pixels[offset + 1] - rightImage.pixels[offset + 1]),
            Math.abs(leftImage.pixels[offset + 2] - rightImage.pixels[offset + 2]),
          ) >= 6) changed += 1;
          total += 1;
        }
      }
    }
    return total > 0 ? changed / total : 0;
  }, {
    leftBase64: left.toString("base64"),
    rightBase64: right.toString("base64"),
    sampleRegions: regions,
  });
}

async function compareScreenshotPixels(page, left, right) {
  return page.evaluate(async ({ leftBase64, rightBase64 }) => {
    const decode = async (base64) => {
      const image = new Image();
      image.src = `data:image/png;base64,${base64}`;
      await image.decode();
      const canvas = document.createElement("canvas");
      canvas.width = 64;
      canvas.height = 64;
      const context = canvas.getContext("2d", { willReadFrequently: true });
      context.drawImage(image, 0, 0, 64, 64);
      return context.getImageData(0, 0, 64, 64).data;
    };
    const [leftPixels, rightPixels] = await Promise.all([
      decode(leftBase64),
      decode(rightBase64),
    ]);
    let changed = 0;
    for (let index = 0; index < leftPixels.length; index += 4) {
      if (Math.max(
        Math.abs(leftPixels[index] - rightPixels[index]),
        Math.abs(leftPixels[index + 1] - rightPixels[index + 1]),
        Math.abs(leftPixels[index + 2] - rightPixels[index + 2]),
      ) >= 6) changed += 1;
    }
    return changed / (leftPixels.length / 4);
  }, {
    leftBase64: left.toString("base64"),
    rightBase64: right.toString("base64"),
  });
}

async function decodeArtwork(page, dataURL) {
  return page.evaluate(async (source) => {
    const image = new Image();
    const startedAt = performance.now();
    image.src = source;
    try {
      await Promise.race([
        image.decode(),
        new Promise((_, reject) => setTimeout(() => reject(new Error("decode timeout")), 5_000)),
      ]);
      return {
        decoded: image.naturalWidth > 0 && image.naturalHeight > 0,
        width: image.naturalWidth,
        height: image.naturalHeight,
        decodeMS: performance.now() - startedAt,
      };
    } catch {
      return { decoded: false, width: 0, height: 0, decodeMS: performance.now() - startedAt };
    }
  }, dataURL);
}

async function analyzeScreenshot(page, screenshotBuffer) {
  const encoded = screenshotBuffer.toString("base64");
  return page.evaluate(async (base64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${base64}`;
    await image.decode();
    const size = 32;
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    context.drawImage(image, 0, 0, size, size);
    const data = context.getImageData(0, 0, size, size).data;
    const luminance = [];
    const redChannel = [];
    const greenChannel = [];
    const blueChannel = [];
    const first = [data[0], data[1], data[2]];
    let changedPixels = 0;
    let red = 0;
    let green = 0;
    let blue = 0;
    for (let index = 0; index < data.length; index += 4) {
      const r = data[index];
      const g = data[index + 1];
      const b = data[index + 2];
      red += r;
      green += g;
      blue += b;
      redChannel.push(r);
      greenChannel.push(g);
      blueChannel.push(b);
      luminance.push(0.299 * r + 0.587 * g + 0.114 * b);
      if (Math.max(Math.abs(r - first[0]), Math.abs(g - first[1]), Math.abs(b - first[2])) >= 8) {
        changedPixels += 1;
      }
    }
    const dctHash = (samples) => {
      const coefficients = [];
      for (let u = 0; u < 8; u += 1) {
        for (let v = 0; v < 8; v += 1) {
          let sum = 0;
          for (let x = 0; x < size; x += 1) {
            for (let y = 0; y < size; y += 1) {
              sum += samples[y * size + x]
                * Math.cos(((2 * x + 1) * u * Math.PI) / (2 * size))
                * Math.cos(((2 * y + 1) * v * Math.PI) / (2 * size));
            }
          }
          coefficients.push(sum);
        }
      }
      const sorted = coefficients.slice(1).sort((left, right) => left - right);
      const median = sorted[Math.floor(sorted.length / 2)];
      const bits = coefficients.map((coefficient, index) => index === 0 || coefficient >= median);
      let result = "";
      for (let index = 0; index < bits.length; index += 4) {
        let nibble = 0;
        for (let bit = 0; bit < 4; bit += 1) {
          nibble = (nibble << 1) | Number(bits[index + bit]);
        }
        result += nibble.toString(16);
      }
      return result;
    };
    const luminancePerceptualHash = dctHash(luminance);
    const colorPerceptualHash = [redChannel, greenChannel, blueChannel]
      .map(dctHash)
      .join("");
    const pixelCount = size * size;
    const average = luminance.reduce((sum, value) => sum + value, 0) / pixelCount;
    const variance = luminance.reduce((sum, value) => sum + (value - average) ** 2, 0) / pixelCount;
    const averageRGB = [red / pixelCount, green / pixelCount, blue / pixelCount];
    const colorSignature = averageRGB
      .map((value) => Math.round(value).toString(16).padStart(2, "0"))
      .join("");
    return {
      perceptualHash: luminancePerceptualHash + colorPerceptualHash + colorSignature,
      luminancePerceptualHash,
      colorPerceptualHash,
      colorSignature,
      nonblankRatio: changedPixels / pixelCount,
      luminanceMean: average,
      luminanceStandardDeviation: Math.sqrt(variance),
      averageRGB,
      decodedScreenshotWidth: image.naturalWidth,
      decodedScreenshotHeight: image.naturalHeight,
    };
  }, encoded);
}

async function renderContactSheets(outputDirectory, scenes) {
  const { chromium } = await import("playwright");
  const browser = await chromium.launch({ headless: true });
  const outputs = [];
  try {
    for (const route of FIXTURE_ROUTES) {
      for (const viewport of FIXTURE_VIEWPORTS) {
        const members = scenes.filter(
          (scene) => scene.route === route && scene.viewport === viewport.id,
        );
        const cards = await Promise.all(members.map(async (scene) => {
          const image = await readFile(scene.screenshotPath);
          return `<figure><img src="data:image/png;base64,${image.toString("base64")}" alt=""><figcaption>${escapeHTML(scene.themeName)}</figcaption></figure>`;
        }));
        const context = await browser.newContext({
          viewport: { width: 1800, height: 2500 },
          deviceScaleFactor: 1,
          locale: "en-US",
          reducedMotion: "reduce",
          serviceWorkers: "block",
        });
        const blocked = [];
        await context.route("**/*", async (requestRoute) => {
          const url = requestRoute.request().url();
          if (/^(?:about:blank|data:image\/png;base64,)/i.test(url)) {
            await requestRoute.continue();
          } else {
            blocked.push(url);
            await requestRoute.abort("blockedbyclient");
          }
        });
        try {
          const page = await context.newPage();
          await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>
            *{box-sizing:border-box}html,body{margin:0;background:#111315;color:#f5f7f8;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}body{padding:72px 28px 28px}.label{position:fixed;z-index:5;top:14px;right:18px;border:1px solid #f5c542;background:#111315;color:#f5c542;padding:7px 10px;font:700 13px ui-monospace,monospace}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px}figure{margin:0;border:1px solid #42464a;background:#1a1d20}img{display:block;width:100%;aspect-ratio:${viewport.width}/${viewport.height};object-fit:cover}figcaption{padding:10px 12px;font-size:14px}
          </style></head><body><div class="label">${FIXTURE_LABEL}</div><div class="grid">${cards.join("")}</div></body></html>`, { waitUntil: "load" });
          await page.waitForFunction(() => [...document.images].every((image) => image.complete));
          assert(blocked.length === 0, `contact sheet external request attempted: ${blocked.join(", ")}`);
          const contactDirectory = path.join(outputDirectory, "contact-sheets");
          await mkdir(contactDirectory, { recursive: true, mode: 0o700 });
          const outputPath = path.join(contactDirectory, `${route}-${viewport.id}.png`);
          await page.screenshot({ path: outputPath, fullPage: true, animations: "disabled" });
          outputs.push({ route, viewport: viewport.id, path: outputPath });
          await page.close();
        } finally {
          await context.close();
        }
      }
    }
  } finally {
    await browser.close();
  }
  return outputs;
}

function currentCommit() {
  return execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: repositoryRoot,
    encoding: "utf8",
  }).trim();
}

function escapeHTML(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function main() {
  const [mode = "--check", payloadPath, outputPath] = process.argv.slice(2);
  if (mode !== "--check" && mode !== "--write") {
    throw new Error("usage: node render.mjs --check PAYLOAD | --write PAYLOAD OUTPUT_DIRECTORY");
  }
  if (!payloadPath) throw new Error("offline fixture payload path is required");
  if (mode === "--write" && !outputPath) throw new Error("--write requires an output directory");
  const result = await runOfflineFixture({
    payloadPath,
    outputDirectory: mode === "--write" ? outputPath : null,
  });
  process.stdout.write(
    `offline fixture: PASS (${result.scenes.length} theme/route/viewport checks)\n`,
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
