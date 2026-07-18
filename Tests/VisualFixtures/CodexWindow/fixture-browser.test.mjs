import assert from "node:assert/strict";
import test from "node:test";

import { EXPECTED_FIXTURE_SCENE_COUNT } from "./fixture-contract.mjs";
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
          taskModeOff ? artworkOpacity === 0 : artworkOpacity > 0),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "home")
        .every(({ artworkPixelDelta }) => artworkPixelDelta >= 0.02),
    );
    assert.ok(
      result.scenes
        .filter(({ route, taskModeOff }) => route === "task" && !taskModeOff)
        .every(({ artworkPixelDelta }) => artworkPixelDelta >= 0.04),
    );
    assert.ok(
      result.scenes
        .filter(({ route, taskModeOff }) => route === "task" && taskModeOff)
        .every(({ artworkPixelDelta }) => artworkPixelDelta === 0),
    );
    assert.ok(
      result.scenes
        .filter(({ route }) => route === "task")
        .every(({ taskCanScroll, finalScrollTop }) => taskCanScroll && finalScrollTop === 0),
    );
  },
);
