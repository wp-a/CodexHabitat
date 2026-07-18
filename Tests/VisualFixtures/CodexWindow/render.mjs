#!/usr/bin/env node

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  EXPECTED_FIXTURE_SCENE_COUNT,
  EXPECTED_SURFACE_ANNOTATIONS,
  FIXTURE_LABEL,
  FIXTURE_ROUTES,
  FIXTURE_VIEWPORTS,
  LATEST_PROFILE_SELECTORS,
  assertSceneDifferences,
  classifyFixtureRequest,
  fixtureSourceFingerprint,
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
              const artworkPixelDelta = routeName === "task" && !taskModeOff
                ? await measureArtworkPixelDelta(page, screenshotBuffer)
                : 0;
              if (routeName === "task" && !taskModeOff) {
                assert(
                  artworkPixelDelta >= 0.005,
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
  await assertCoreBounds(page, selectors, routeName);
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

  const scene = await page.locator(selectors.appShell).evaluate((node) => {
    const artwork = getComputedStyle(node, "::before");
    const overlay = getComputedStyle(node, "::after");
    const sidebar = getComputedStyle(document.querySelector("aside.app-shell-left-panel"));
    return {
      artworkBackground: artwork.backgroundImage,
      artworkOpacity: Number.parseFloat(artwork.opacity),
      artworkPosition: artwork.position,
      artworkSize: artwork.backgroundSize,
      artworkMask: artwork.maskImage || artwork.webkitMaskImage,
      overlayMask: overlay.maskImage || overlay.webkitMaskImage,
      sidebarBackdropFilter: sidebar.backdropFilter,
    };
  });
  assert(scene.artworkBackground.startsWith('url("data:image/'), "compiled artwork is not installed");
  assert(scene.artworkPosition === "fixed", `artwork position is ${scene.artworkPosition}`);
  assert(scene.artworkSize === "cover", `artwork size is ${scene.artworkSize}`);
  assert(scene.sidebarBackdropFilter === "none", "sidebar unexpectedly uses backdrop blur");
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

  return {
    styleCount,
    horizontalOverflow,
    composerHit,
    popoverInViewport: popoverBounds.inViewport,
    popoverOverlapsComposer: popoverBounds.overlapsComposer,
    surfaceAnnotationsValid: true,
    allControlsWithinViewport: true,
    semanticForegroundsValid: true,
    bannerFadeValid,
    taskCanScroll,
    finalScrollTop,
    artworkOpacity: scene.artworkOpacity,
    taskModeOff,
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
    const muted = resolveThemeColor("--habitat-muted-text");
    const checks = [
      ["nav a:not([aria-current])", text],
      [".fixture-recents h2", muted],
      [".fixture-account", text],
      [".fixture-popover", text],
    ];
    if (activeRoute === "home") {
      checks.push([".fixture-home p", muted]);
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
    const suggestionsInset = await page.locator(selectors.homeSuggestions).evaluate((node) => {
      const controls = Array.from(node.querySelectorAll("button, a, [role=button]"));
      return controls.length > 0 && controls.every((control) => {
        const rect = control.getBoundingClientRect();
        return rect.left >= 12 && rect.right <= innerWidth - 12;
      });
    });
    assert(suggestionsInset, "home suggestion controls touch or cross the viewport edge");
  }
}

async function measureArtworkPixelDelta(page, themedScreenshot) {
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
  return compareScreenshotPixels(page, themedScreenshot, withoutArtwork);
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
