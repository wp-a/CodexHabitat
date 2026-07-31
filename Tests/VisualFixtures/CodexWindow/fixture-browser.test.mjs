import assert from "node:assert/strict";
import test from "node:test";

import {
  EXPECTED_FIXTURE_SCENE_COUNT,
  EXPECTED_THEME_COUNT,
  REQUIRED_INTERACTION_SCENARIOS,
  REQUIRED_STYLE_FAMILIES,
  assertCompleteFixtureCoverage,
} from "./fixture-contract.mjs";
import { runOfflineFixture } from "./render.mjs";

test("the renderer fails closed when no Swift exporter payload is provided", async () => {
  await assert.rejects(() => runOfflineFixture(), /payload path is required/);
});

const payloadPath = process.env.HABITAT_OFFLINE_FIXTURE_PAYLOAD;

test(
  "the pinned browser validates all exported themes, routes, and viewports",
  { skip: payloadPath ? false : "set by render-codex-theme-fixtures.sh" },
  async () => {
    const result = await runOfflineFixture({ payloadPath });

    assert.equal(result.scenes.length, EXPECTED_FIXTURE_SCENE_COUNT);
    assert.equal(result.metrics.scenes.length, EXPECTED_FIXTURE_SCENE_COUNT);
    assert.equal(result.metrics.externalRequests.length, 0);
    assert.doesNotThrow(() => assertCompleteFixtureCoverage(result.scenes));
    assert.equal(
      result.scenes.filter(({ interactionStates }) => interactionStates !== null).length,
      EXPECTED_THEME_COUNT * REQUIRED_INTERACTION_SCENARIOS.length,
    );
    assert.deepEqual(
      [...new Set(result.scenes.map(({ styleFamily }) => styleFamily))].sort(),
      [...REQUIRED_STYLE_FAMILIES].sort(),
    );
    assert.ok(
      result.scenes
        .filter(({ route, viewport }) => route === "home" && viewport === "compact")
        .every(({ artworkCrop }) => artworkCrop.cropsSource),
    );
    assert.ok(
      result.scenes
        .filter(({ route, viewport }) => route === "task" && viewport === "wide")
        .every(({ interactionStates }) =>
          interactionStates.normal.home === null
          && interactionStates.normal.composer.inputFocus.matchesFocusVisible),
    );
    assert.deepEqual(
      {
        viewport: result.metrics.focusYProbe.viewport,
        scale: result.metrics.focusYProbe.scale,
        firstFocusY: result.metrics.focusYProbe.firstFocusY,
        secondFocusY: result.metrics.focusYProbe.secondFocusY,
      },
      {
        viewport: "narrow",
        scale: 1.08,
        firstFocusY: 0.25,
        secondFocusY: 0.75,
      },
    );
    assert.ok(result.metrics.focusYProbe.pixelDelta > 0);
    assert.ok(result.scenes.every(({ routeLatencyMS }) => routeLatencyMS <= 120));
    assert.ok(result.scenes.every(({ styleCount }) => styleCount === 1));
    assert.ok(result.scenes.every(({ artDecoded }) => artDecoded));
    assert.ok(result.scenes.every(({ composerHit }) => composerHit));
    assert.ok(result.scenes.every(({ popoverInViewport }) => popoverInViewport));
    assert.ok(result.scenes.every(({ popoverOverlapsComposer }) => !popoverOverlapsComposer));
    assert.ok(result.scenes.every(({ surfaceAnnotationsValid }) => surfaceAnnotationsValid));
    assert.ok(result.scenes.every(({ allControlsWithinViewport }) => allControlsWithinViewport));
    assert.ok(result.scenes.every(({ routeMutationObserved }) => routeMutationObserved));
    assert.ok(result.scenes.every(({ semanticForegroundsValid }) => semanticForegroundsValid));
    assert.ok(result.scenes.every(({ bannerFadeValid }) => bannerFadeValid));
    assert.ok(result.scenes.every(({ taskReadingScrimValid }) => taskReadingScrimValid));
    assert.ok(result.scenes.every(({ sceneOverlayLayerCount }) => sceneOverlayLayerCount >= 2));
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({ taskReadingLayerCount }) => taskReadingLayerCount >= 2),
    );
    assert.ok(result.scenes.every(({ horizontalOverflow }) => horizontalOverflow <= 0));
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "home")
        .every(({ homeSuggestionMinimumViewportInset }) =>
          homeSuggestionMinimumViewportInset >= 12),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({ homeSuggestionMinimumViewportInset }) =>
          homeSuggestionMinimumViewportInset === null),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({ taskModeOff, artworkOpacity }) =>
          !taskModeOff && artworkOpacity > 0),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "home")
        .every(({ artworkPixelDelta }) => artworkPixelDelta >= 0.02),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({ artworkPixelDelta }) => artworkPixelDelta >= 0.08),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({ taskCanScroll, finalScrollTop }) => taskCanScroll && finalScrollTop === 0),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({
          messageCardOpacity,
          responseSurfaceOpacity,
          codeSurfaceOpacity,
          toolSurfaceOpacity,
        }) =>
          Math.abs(messageCardOpacity - 1) <= 0.001
          && Math.abs(responseSurfaceOpacity) <= 0.001
          && Math.abs(codeSurfaceOpacity - 1) <= 0.001
          && Math.abs(toolSurfaceOpacity - 1) <= 0.001),
    );
  },
);
