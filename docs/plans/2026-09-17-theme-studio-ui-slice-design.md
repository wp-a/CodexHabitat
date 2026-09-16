# Theme Studio Cross-Platform UI Slice Design

**Date:** 2026-09-17  
**Status:** Approved by the user

## Goal

Make Theme Studio start with an obvious image import action and make advanced
controls discoverable without overwhelming the first screen on both macOS and
Windows.

## macOS design

The existing live preview remains the primary canvas after an image is loaded.
Before import, the canvas becomes a single large drop target with a photo icon,
short format guidance, and a prominent `Choose Image` action. Finder drops are
accepted only as local file URLs with PNG, JPEG, or WebP extensions and reuse
the existing `ThemeStudioModel.selectImage(URL)` validation path. A targeted
drop changes the border and surface tint but does not add a new visual effect.

The inspector opens with Metadata and Artwork only. Palette, Scene, Material,
Pet Pairing, and Package stay collapsed until the user asks for advanced
controls. Once an image is successfully loaded, Palette opens automatically so
the generated starting colors are visible. Existing validation scrolling,
undo/redo, save, export, and accessibility identifiers remain intact.

## Windows design

The Windows branch currently contains the typed `ThemeDraft`, image validator,
and history model but no Theme Studio page. Add a native WinUI page reached from
the Themes page's Create Theme command. The page uses a two-column layout: a
large preview/import drop zone on the left and an `Expander` inspector on the
right. Metadata and Artwork are initially open; Palette, Scene, Material,
Pairing, and Package are grouped under a collapsed Advanced expander. File
selection and drag/drop feed the existing validator, and the page keeps draft
editing local until the existing resource save/export path is invoked.

The Windows implementation uses Mica, Segoe UI Variable, Fluent icons, keyboard
focus visuals, text scaling, and high-contrast resources. It mirrors the
information hierarchy of macOS without sharing SwiftUI view code.

## Verification

Add source-contract assertions for the macOS drop zone and initial inspector
state. Add Windows core tests for the draft/image-intake state used by the page
and build the portable Windows projects on this host; the WinUI application
build remains a Windows-host verification step because the current machine is
macOS.
