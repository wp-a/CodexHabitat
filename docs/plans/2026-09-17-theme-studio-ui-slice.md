# Theme Studio UI Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a clear image drop/import first screen and progressive disclosure for advanced Theme Studio controls on macOS and Windows.

**Architecture:** Keep the existing macOS `ThemeStudioModel` and Windows typed `ThemeDraft`/`ThemeImageValidator` as the behavior boundaries. Add platform-native presentation only: SwiftUI drop-zone and disclosure state on macOS, and WinUI page/expander presentation on the Windows worktree. Do not add a web layer or duplicate image validation.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, Swift Testing, C# 14, .NET 10, WinUI 3, Windows App SDK 2.4, MSTest.

---

### Task 1: macOS source-contract tests for the new presentation

**Files:**
- Modify: `Tests/CodexHabitatAppTests/ThemeStudioHistoryTests.swift`
- Test: `Tests/CodexHabitatAppTests/ThemeStudioHistoryTests.swift`

**Step 1: Write the failing tests**

Add focused source-contract assertions that `ThemeStudioView.swift` contains a
file URL drop handler, the drop-zone accessibility identifier, and an initial
inspector state that does not include Scene.

**Step 2: Run the focused test**

Run: `swift test --filter ThemeStudioHistoryTests`

Expected: FAIL because the view has no drop handler/identifier and still opens
Scene by default.

**Step 3: Commit the failing test**

```bash
git add Tests/CodexHabitatAppTests/ThemeStudioHistoryTests.swift
git commit -m "test: specify theme studio import and disclosure hierarchy"
```

### Task 2: macOS drop zone and progressive disclosure

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioView.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift` if new keys are added to its required-key list

**Step 1: Implement the minimal drop-zone behavior**

Add an `isDropTargeted` state, a button-based empty artwork surface, and an
`onDrop(of: [UTType.fileURL.identifier])` handler. Resolve Finder providers to
their original local `NSURL`, filter PNG/JPEG/WebP extensions, and call
`model.selectImage(url)` on the main actor. Keep the existing file chooser as
the button action and disable both paths while selecting/saving.

**Step 2: Implement the disclosure hierarchy**

Initialize the expanded set with Metadata and Artwork only. On a successful
image state change, insert Palette. Keep the existing section IDs and
validation scroll behavior. Add a single Advanced expander if it keeps the
existing source contract simple; otherwise keep the existing section rows
collapsed by default and preserve their individual controls.

**Step 3: Add localized copy and identifiers**

Add concise English and Simplified Chinese strings for the drop hint, accepted
formats, and advanced inspector label. Keep visible text short enough for the
900-point minimum window.

**Step 4: Run the focused tests**

Run: `swift test --filter ThemeStudioHistoryTests`

Expected: PASS.

**Step 5: Commit the macOS slice**

```bash
git add Sources/CodexHabitatApp/Settings/ThemeStudioView.swift Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings Tests/CodexHabitatAppTests/ThemeStudioHistoryTests.swift Tests/CodexHabitatAppTests/LocalizationTests.swift
git commit -m "feat: make theme studio import surface primary"
```

### Task 3: Windows core presentation seam

**Files:**
- Modify: `Windows/src/CodexHabitat.Windows.Resources/Themes/ThemeImageValidator.cs` only if a small typed intake state is required
- Create or modify: `Windows/src/CodexHabitat.Windows.App/Settings/ThemeStudioPage.xaml`
- Create or modify: `Windows/src/CodexHabitat.Windows.App/Settings/ThemeStudioPage.xaml.cs`
- Modify: `Windows/src/CodexHabitat.Windows.App/Settings/ThemesPage.xaml`
- Modify: `Windows/src/CodexHabitat.Windows.App/Settings/ThemesPage.xaml.cs`
- Modify: `Windows/src/CodexHabitat.Windows.App/Navigation/SectionPageRouter.cs` only if routing is needed
- Test: `Windows/tests/CodexHabitat.Windows.Resources.Tests/Themes/ThemeImageValidatorTests.cs` or a new focused page-model test

**Step 1: Write the failing Windows behavior test**

Cover the typed draft intake contract used by the page: a new draft starts
without an image, accepted image extensions are limited to PNG/JPEG/WebP, and
mutating metadata marks the draft dirty.

**Step 2: Run the portable Windows test**

Run from `Windows/`: `dotnet test tests/CodexHabitat.Windows.Resources.Tests/CodexHabitat.Windows.Resources.Tests.csproj -c Release`

Expected: the new assertion fails until the page-facing state is wired.

**Step 3: Add the WinUI Theme Studio page**

Create a native two-column page with a large empty drop zone, click-to-browse
button, accepted-format hint, route preview area, and right-side Metadata,
Artwork, and collapsed Advanced expanders. Use `FileOpenPicker`/WinUI drag/drop
and send the selected bytes through `ThemeImageValidator`.

**Step 4: Add the Themes page entry**

Add a `Create theme` command button and navigate to/open the studio while
preserving the current selection behavior for built-in themes.

**Step 5: Build portable Windows projects**

Run from `Windows/`: `dotnet build CodexHabitat.Windows.sln -c Release -p:Platform=x64`

Expected: portable projects compile on macOS; WinUI application build may be
skipped or reported separately if the SDK rejects Windows-only UI compilation.

**Step 6: Commit the Windows slice without touching unrelated worktree files**

Stage only the Theme Studio files and tests. Leave the existing untracked
`HabitatThemeSurfaceRecipe` files untouched.

### Task 4: Cross-platform verification and review

**Files:**
- No new production files unless verification exposes a defect.

**Step 1: Run macOS full tests**

Run: `swift test`

Expected: all existing suites pass.

**Step 2: Run Windows portable tests**

Run from `Windows/`: `dotnet test tests/CodexHabitat.Windows.Resources.Tests/CodexHabitat.Windows.Resources.Tests.csproj -c Release`

Expected: all resource tests pass.

**Step 3: Review visual QA surfaces**

Use the existing macOS visual-QA launch option for Theme Studio and inspect the
wide and narrow screenshots. On this macOS host, verify the Windows page source,
build output, and XAML hierarchy; record that a native Windows screenshot needs
a Windows host if one is unavailable.

**Step 4: Inspect both worktree diffs**

Run `git diff --check` and confirm no unrelated files or user changes were
modified.
