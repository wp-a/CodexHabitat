# Theme Asset Provenance

Generated: 2026-07-17

Prototype refresh: 2026-07-18

All twenty-four built-in backgrounds were generated with the project-approved `imagegen` CLI fallback using `gpt-image-2` through the user-configured image endpoint `https://api.wpironman.top/v1`. Each job requested `1600 x 1008`, medium quality, JPEG output, and a separate rights-safe prompt. The endpoint returned `1586 x 992`; project assets were normalized with macOS `sips` to `1600 x 1000` JPEG and `800 x 500` PNG preview files.

The user-provided messenger screenshot was inspected locally for era, hierarchy, and spacing only. It was not supplied to the image model, edited, copied, or bundled. No third-party artwork or downloaded image is present in these theme directories.

On 2026-07-18, `workbench`, `retro-messenger`, `arcade-signal`, and
`quiet-garden` were regenerated as the approved polished prototypes. These four
jobs used the same user-configured OpenAI-compatible endpoint class with
`gpt-image-2`, high quality, and a requested `2560 x 1440` JPEG output. The
endpoint returned `1672 x 941`; Pillow `ImageOps.fit` performed an aspect-fill
normalization to `2560 x 1440` without stretching, then derived an `800 x 500`
preview. No Dream Skin image, QQ screenshot, or other image input was sent to
the model.

On 2026-07-18, five original, text-free built-ins were deterministically mirrored
horizontally with macOS `sips` so the library includes honest trailing content
safe areas instead of declaring a safe side that overlaps the artwork. The
derived assets are `retro-messenger`, `grand-ocean-crew`,
`hero-training-campus`, `spirit-lantern-town`, and `block-frontier`; their source
prompts and raw generated files are unchanged. Background and preview hashes
below describe the packaged mirrored derivatives.

Manual review checked every contact-sheet image plus original-resolution high-risk nostalgia, anime-energy, classic-desktop, and block-world outputs. Review criteria: no text, logos, people, faces, characters, creatures, mascots, trademarked symbols, proprietary interface icons, screenshots, copied compositions, or recognizable franchise designs; calm leading safe side; distinct trailing focal region. `block-frontier` draft 1 was rejected because its grass blocks, square clouds, and wooden outpost were too close to familiar cubic-sandbox conventions. Only the independently generated polygonal v2 is packaged.

## Cathedral Foundry (`workbench`) — refreshed prototype

- Source: 2026-07-18; `gpt-image-2`; OpenAI-compatible CLI fallback through `https://api.wpironman.top/v1`; high quality; requested `2560 x 1440`; raw output `output/imagegen/theme-prototypes/workbench-source.jpeg` (temporary, not packaged); actual `1672 x 941`; `208555` bytes; SHA-256 `a0139f041758f19fb3291dbb06a4be1290059792b49f072af3534544b52c2850`.
- Background: `Sources/CodexHabitatApp/Resources/Themes/workbench/background.jpg`; `2560 x 1440`; `419678` bytes; SHA-256 `4bb92d4a6808b17443ee3ce7cae1cfae8150df1427045db1180563f10b213800`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/workbench/preview.png`; `800 x 500`; `394723` bytes; SHA-256 `f8ad6270bb5e9f32c7bd053ef642f2f32619560c9ff6ee23c3bd8604381e361b`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: full-window desktop theme background. Primary request: an original cathedral-scale industrial foundry interior built from charcoal iron beams, aged brass rails, dark stone floor plates, and restrained amber furnace light; environment only. Composition/framing: 16:9 landscape, preserve the left 42 percent as calm low-detail iron shadow for readable native controls, place the strongest architectural depth, brass machinery, and warm light on the right; continuous environment that remains useful under wide cover crops. Style/medium: polished cinematic environment concept art with tactile metal and stone, sophisticated rather than illustrative. Lighting/mood: controlled warm work light against deep charcoal, high contrast without crushed detail. Constraints: pure background artwork, no text, letters, numbers, logos, trademarks, people, faces, bodies, characters, creatures, mascots, screens, interface panels, copied UI, watermark, weapons, heraldry, religious symbols, recognizable franchise motifs, or copied composition. Avoid: orange-dominated palette, bokeh blobs, floating decorative orbs, excessive smoke, clutter in the left safe area.
```

## Neon Night Shift (`night-shift`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/night-shift-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/night-shift/background.jpg`; `1600 x 1000`; `288473` bytes; SHA-256 `da033301de3b8158d1d967625ecf0869dae39368ef42e8df72a1bea1b31b4133`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/night-shift/preview.png`; `800 x 500`; `438366` bytes; SHA-256 `5c3308ca42628be6ce4ee04a93a15a42d66a3f380d2461cc0abac177e3c0d40b`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original midnight operations room with deep indigo walls, violet instrument housings, cyan edge lights, and a glass observation window. Subject: luminous control machinery concentrated on the right side. Style/medium: cinematic game environment painting with rich material detail. Composition/framing: 16:10 landscape, quiet dark negative space on the left 40 percent for native app headings, saturated focal region on the right. Lighting/mood: nocturnal violet and cyan, calm but energetic. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: empty gradient-only background, bokeh blobs, protected symbols, and visual noise in the safe side.
```

## Arcade Signal (`arcade-signal`) — refreshed prototype

- Source: 2026-07-18; `gpt-image-2`; OpenAI-compatible CLI fallback through `https://api.wpironman.top/v1`; high quality; requested `2560 x 1440`; raw output `output/imagegen/theme-prototypes/arcade-signal-source.jpeg` (temporary, not packaged); actual `1672 x 941`; `158185` bytes; SHA-256 `f81db2871918c5c3a9a434e8d674acc213368754f59369f78d8bc2c597085050`.
- Background: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/background.jpg`; `2560 x 1440`; `302173` bytes; SHA-256 `82ce85a8eafd5579ef111c13bbfd56a6d397405b4d861575b915dd22d9ed9771`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/preview.png`; `800 x 500`; `338447` bytes; SHA-256 `6962d157d926b13529c640049d4e80f191bd17ebfb6f60edc27e684b602f8d4f`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: full-window desktop theme background. Primary request: an original after-hours arcade-inspired environment made from abstract geometric light machines, navy structural bays, crisp magenta and cyan signal rails, and restrained yellow attention lights; no recognizable cabinets and environment only. Composition/framing: 16:9 landscape, preserve the left 42 percent as calm low-detail navy space for readable native controls, place luminous machine geometry and energetic perspective on the right, keep the scene continuous under wide cover crops. Style/medium: premium graphic game-environment concept art with sharp edges, tactile dark materials, and disciplined saturation. Lighting/mood: electric magenta-cyan contrast with precise yellow cues, deep navy shadows, energetic but organized. Constraints: no text, letters, numbers, scores, marquees, logos, trademarks, people, faces, bodies, characters, creatures, mascots, recognizable arcade cabinets, screens, game UI, copied interface, watermark, protected symbols, recognizable franchise motifs, or copied composition. Avoid: bokeh blobs, neon signs, cyberpunk city clichés, purple-only palette, visual noise in the left safe area.
```

## Quiet Garden (`quiet-garden`) — refreshed prototype

- Source: 2026-07-18; `gpt-image-2`; OpenAI-compatible CLI fallback through `https://api.wpironman.top/v1`; high quality; requested `2560 x 1440`; raw output `output/imagegen/theme-prototypes/quiet-garden-source.jpeg` (temporary, not packaged); actual `1672 x 941`; `297860` bytes; SHA-256 `42c24794c32e1e458b1f42c69f4777675555990a4359c72e40e9cdf73a33870d`.
- Background: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/background.jpg`; `2560 x 1440`; `566265` bytes; SHA-256 `cf09ab799889c8ae58eb1a7046e42e72cee60b0c788294c16147dcb30ccc14ef`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/preview.png`; `800 x 500`; `535341` bytes; SHA-256 `50f56e3c3c1f3ee1b26dd52ccac2d4218b8609ceb8c5d980f4023a64fcaab490`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: full-window desktop theme background. Primary request: an original morning conservatory with elegant greenhouse ribs, frosted glass partitions, living green foliage, pale stone paths, and soft white-green daylight; environment only. Composition/framing: 16:9 landscape, preserve the left 42 percent as calm airy pale glass and low-detail daylight for readable native controls, place the greenhouse structure, layered leaves, and sunlit focal depth on the right, keep the scene continuous under wide cover crops. Style/medium: refined natural environment painting with realistic materials and quiet editorial polish, not storybook illustration. Lighting/mood: fresh morning light, balanced greens, clean whites, subtle natural shadow, serene and focused. Constraints: no text, letters, numbers, signs, logos, trademarks, people, faces, bodies, characters, creatures, animals, mascots, branded objects, cottage-game replicas, screens, copied UI, watermark, recognizable franchise motifs, or copied composition. Avoid: beige-dominated palette, fantasy cottages, decorative bokeh orbs, excessive flowers, visual clutter in the left safe area.
```

## Retro Messenger 2007 (`retro-messenger`) — refreshed prototype

- Source: 2026-07-18; `gpt-image-2`; OpenAI-compatible CLI fallback through `https://api.wpironman.top/v1`; high quality; requested `2560 x 1440`; raw output `output/imagegen/theme-prototypes/retro-messenger-source.jpeg` (temporary, not packaged); actual `1672 x 941`; `173668` bytes; SHA-256 `d902ef61b93d188e25df83688213e42751c2cd6a2f5a9f2a716ea2d4775cc8c2`.
- Background: `Sources/CodexHabitatApp/Resources/Themes/retro-messenger/background.jpg`; `2560 x 1440`; `405071` bytes; SHA-256 `0ae022878cfbd7ca0c56902bb1ddcd039732ab71be0472a971aeac166d7f572c`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/retro-messenger/preview.png`; `800 x 500`; `409729` bytes; SHA-256 `5847def443974ae53c20312b504a9a2f67d6712fc0d04173dfc908af5f056a1f`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; mirrored trailing safe side and leading focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: full-window desktop theme background. Primary request: an original early-2000s blue-glass communication workspace expressed only through architecture and materials: layered cobalt translucent glass frames, pale aqua light wells, brushed silver rails, compact beveled structures, and a bright airy central depth; environment only. Composition/framing: 16:9 landscape, preserve the left 42 percent as calm low-detail deep-blue glass and soft pale light for readable native controls, cluster the most luminous glass architecture on the right, maintain a continuous scene under wide cover crops. Style/medium: polished retro-futurist environment rendering with restrained one-pixel-like highlights and authentic 2007-era material rhythm, not an interface mockup. Lighting/mood: clear cool daylight, cobalt and aqua glass with small silver highlights. Constraints: no text, letters, numbers, logos, trademarks, messenger brands, proprietary icons, contacts, portraits, people, faces, bodies, characters, creatures, mascots, computer screens, application windows, chat bubbles, copied UI, watermark, or copied composition. Avoid: recognizable messaging software layouts, logos, desktop screenshots, one-note blue wash, bokeh blobs, clutter in the left safe area.
```

## Green Chat Desktop (`green-chat-desk`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/green-chat-desk-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/green-chat-desk/background.jpg`; `1600 x 1000`; `257575` bytes; SHA-256 `f00435a52f802992ecf1af1af660a778cf43cf170ca8a17d04a06dba1d0987db`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/green-chat-desk/preview.png`; `800 x 500`; `398688` bytes; SHA-256 `8bfca45a09d9c335cce2861ee49e2a08bf9500fe975c423382fa39f0bb810ac3`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original green desktop chat-era environment built from a deep forest contact rail, mint message panes, beveled section dividers, subtle leaf-shaped window reflections, and a thin calm status baseline; abstract architecture only, not a readable interface screenshot. Subject: rich emerald rail and mint panel depth on the right. Style/medium: polished nostalgic desktop concept art. Composition/framing: 16:10 landscape, calm light mint negative space on the left 40 percent for native controls, dark green focal chrome on the right. Lighting/mood: fresh daylight green with clear layered panels. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: any messenger branding, proprietary icons, profile portraits, chat bubbles with writing, or copied composition.
```

## Cyber Cafe Neon (`cyber-cafe`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/cyber-cafe-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/cyber-cafe/background.jpg`; `1600 x 1000`; `250605` bytes; SHA-256 `0df085fd2050a2b85174049e5a3aa3756f5cc8cc3abe89b1e3a6e76478714dd6`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/cyber-cafe/preview.png`; `800 x 500`; `407568` bytes; SHA-256 `c92447cff93d7081dce4d51666b1248c747f5f266c51934461ba6d26872d368f`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original late-night cyber cafe workstation wall with magenta and cyan terminal glow, translucent glass dividers, cable silhouettes, and a dark counter rhythm; no readable screens and no literal UI. Subject: vivid cyan-magenta lighting clustered on the right. Style/medium: polished neon environmental concept art. Composition/framing: 16:10 landscape, low-detail deep purple negative space on the left 40 percent for controls, sharp neon focal architecture on the right. Lighting/mood: energetic after-hours glow, crisp colored reflections. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: cyberpunk brand marks, proprietary icons, profile portraits, and bokeh blobs.
```

## Candy Combo (`candy-combo`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/candy-combo-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/candy-combo/background.jpg`; `1600 x 1000`; `309912` bytes; SHA-256 `a1747358e3f2ec11f595945d11d8d244afc53c230cb3a1836136160eb428b914`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/candy-combo/preview.png`; `800 x 500`; `434027` bytes; SHA-256 `7ccfd325cf446f284a53a7fb67d6fb64a2828f40916ad36d56bf38eb0e15fd37`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original glossy candy game environment with translucent color tiles, curved lane rails, polished syrup-like material, and playful geometric lighting; no text and no characters. Subject: pink, aqua, and yellow combo-like light structures on the right. Style/medium: vivid polished game environment illustration. Composition/framing: 16:10 landscape, calm darker plum negative space on the left 40 percent for native UI, saturated candy architecture on the right. Lighting/mood: bright confectionery gloss, energetic but orderly. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: empty gradient-only background, bokeh blobs, protected symbols, and visual noise in the safe side.
```

## Crimson Mecha (`crimson-mecha`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/crimson-mecha-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/crimson-mecha/background.jpg`; `1600 x 1000`; `268132` bytes; SHA-256 `e88bd3a78229169b427f33c86d3de39025da6ed899c1d7a81d8eb0f3ea0621d3`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/crimson-mecha/preview.png`; `800 x 500`; `409230` bytes; SHA-256 `953fb250dfe08fb02af8fbd4833edeb422bccb4f486cdcbe95a0f55aa9756c05`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original crimson industrial hangar with angular armored bay doors, service gantries, warning lamps, and matte metal floor panels. Subject: red mechanical structures and teal maintenance light concentrated on the right, with no vehicle or character. Style/medium: cinematic game environment concept art. Composition/framing: 16:10 landscape, quiet charcoal negative space on the left 40 percent for controls, dramatic detailed hangar on the right. Lighting/mood: warning red with clear warm highlights and cool balance. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: recognizable robots, weapons, emblems, and protected designs.
```

## Win95 Workbench (`win95-workbench`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/win95-workbench-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/win95-workbench/background.jpg`; `1600 x 1000`; `377324` bytes; SHA-256 `44913195ae7af55fb79e59b3e3c687fb387843369cc6943a12d7f12081b9c36a`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/win95-workbench/preview.png`; `800 x 500`; `487299` bytes; SHA-256 `0ec2c43ba31b1dedae74e290ff64aeed223f50f706029f7063229b77fd749508`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original classic gray desktop workbench made of raised and sunken rectangular control surfaces, pixel-sharp bevels, teal inset panels, blue accent bars, and a small workshop lamp; abstract material study, not a real operating-system screenshot. Subject: crisp gray geometry and blue-teal control depth on the right. Style/medium: nostalgic low-resolution-inspired environment painting with precise edges. Composition/framing: 16:10 landscape, quiet light gray negative space on the left 40 percent for native controls, focused raised-panel geometry on the right. Lighting/mood: bright neutral office light, clear separation. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: operating-system names, proprietary icons, menus, cursors, and copied chrome.
```

## Gold Rush (`gold-rush`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/gold-rush-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/gold-rush/background.jpg`; `1600 x 1000`; `418957` bytes; SHA-256 `3297053447889fd5dee90c6c7a0d545c836061c5a50e637343a16c2975f42659`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/gold-rush/preview.png`; `800 x 500`; `581969` bytes; SHA-256 `116fca02464c0a5446dc741702b87d3fda365afa255a47d7ba26ef1f558e7787`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original sunlit machinery vault with brass rails, amber mineral facets, dark wood supports, and a broad polished worktable. Subject: warm gold machinery and turquoise reflected light clustered on the right. Style/medium: rich adventure game environment concept art. Composition/framing: 16:10 landscape, calm deep brown negative space on the left 40 percent for native controls, treasure-like focal detail on the right. Lighting/mood: golden afternoon shafts, high saturation, tactile materials. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: literal treasure maps, franchise props, bokeh blobs, and visual noise in the safe side.
```

## Aqua Pulse (`aqua-pulse`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/aqua-pulse-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/aqua-pulse/background.jpg`; `1600 x 1000`; `449220` bytes; SHA-256 `6af215a2d96e4e98d2c510bf5812cb53aafe20d523cd178e156340860febf35d`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/aqua-pulse/preview.png`; `800 x 500`; `613582` bytes; SHA-256 `b11187609568156a2761170d4ef47c58c19c49a7bba74ab85ae218f4707ff4b8`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original underwater research gallery with glass channels, aqua circuit-like conduits, coral-shaped abstract architecture, and deep blue structural ribs; no creatures and no text. Subject: bright aqua and lime pulse structures on the right. Style/medium: polished aquatic game environment art. Composition/framing: 16:10 landscape, calm deep teal negative space on the left 40 percent for native headings, lively detailed water-light focal area on the right. Lighting/mood: clear submerged caustic light, crisp saturated color. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: bokeh-only effects, protected symbols, and visual noise in the safe side.
```

## Harvest Homestead (`harvest-homestead`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/harvest-homestead-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/harvest-homestead/background.jpg`; `1600 x 1000`; `435667` bytes; SHA-256 `0c88a24d541816008f79c669a0cf03492ef1b7437863d429bab3df56847f60a7`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/harvest-homestead/preview.png`; `800 x 500`; `581943` bytes; SHA-256 `ec378353d9ae4caa9092888536ada1795af40e3740249a6d3635985f52e6594a`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original social-farm-inspired homestead with orchard rows, wooden trellis, crop beds, warm soil, a small windmill silhouette, and morning haze; environment only, no people or animals. Subject: colorful orchard and golden crops on the right. Style/medium: cozy polished game environment illustration. Composition/framing: 16:10 landscape, calm pale sky and low-detail field on the left 40 percent for native controls, warm detailed homestead on the right. Lighting/mood: cheerful early morning, saturated greens and amber. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: recognizable game UI, mascots, and copied farm layouts.
```

## Solar Ki Arena (`solar-ki-arena`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/solar-ki-arena-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/solar-ki-arena/background.jpg`; `1600 x 1000`; `375380` bytes; SHA-256 `5eb30d2ef7c3650f2455a38529ae123a67bab43c16cfa5e768f81de41fbbf3ef`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/solar-ki-arena/preview.png`; `800 x 500`; `550451` bytes; SHA-256 `2c3a147799ff61e70c7ebb4fd1a22ae79a63b9882f1a1c6960cc52574f3f6d01`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original rocky training arena under a huge bright sun, layered stone terraces, dust trails, cobalt banners without marks, and angular energy rings with no writing. Subject: orange sunlight and cobalt-blue energy geometry on the right, no characters. Style/medium: bold high-energy game environment concept art. Composition/framing: 16:10 landscape, calm warm sky negative space on the left 40 percent for controls, dramatic arena focal point on the right. Lighting/mood: hot solar glow, crisp primary color contrast. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: martial-arts characters, signature costumes, emblems, and protected visual motifs.
```

## Moonlit Shinobi (`moonlit-shinobi`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/moonlit-shinobi-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/moonlit-shinobi/background.jpg`; `1600 x 1000`; `271295` bytes; SHA-256 `dc42b31df43e7c6d67d25dbbd662d224897c4c957c21fa0555484889ce270363`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/moonlit-shinobi/preview.png`; `800 x 500`; `435933` bytes; SHA-256 `ea67ec314ab42f83edc2fa7a0f361d95ce6b6f3546b3e2388e99813553ba337b`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original indigo rooftop village at night with tiled roofs, quiet paper lanterns, narrow bridges, misty mountain layers, and a large moon; no people or figures. Subject: crimson signal lanterns and blue rooftops on the right. Style/medium: atmospheric painted adventure environment. Composition/framing: 16:10 landscape, calm deep indigo negative space on the left 40 percent for controls, detailed rooftop focal region on the right. Lighting/mood: cool moonlight with controlled crimson accents. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: ninja silhouettes, signature costumes, franchise symbols, and copied compositions.
```

## Grand Ocean Crew (`grand-ocean-crew`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/grand-ocean-crew-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/grand-ocean-crew/background.jpg`; `1600 x 1000`; `356976` bytes; SHA-256 `88d3ebc966ec2c7546843e079bc7d25cd04e52737b4e1b7afe6e1145577ba0fc`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/grand-ocean-crew/preview.png`; `800 x 500`; `602936` bytes; SHA-256 `f263a7466db2f90c5476d6d4aceb93eb83b387dd8a320e269a154a84bb7989ff`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; mirrored trailing safe side and leading focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original open ocean chart-like environment with layered turquoise waves, a wooden sailing deck, tall blank sails, rope, brass fittings, and a distant sunrise horizon; no people and no readable chart marks. Subject: bright sails and treasure-colored deck details on the right. Style/medium: sunlit adventure game environment painting. Composition/framing: 16:10 landscape, calm open sky negative space on the left 40 percent for controls, detailed deck and sail focal area on the right. Lighting/mood: optimistic ocean daylight, vivid cyan and amber. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: pirate emblems, signature props, flags with marks, and copied compositions.
```

## Elemental Companions (`elemental-companions`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/elemental-companions-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/elemental-companions/background.jpg`; `1600 x 1000`; `467211` bytes; SHA-256 `6f159eacafd6eeddcf402369e09eac829d2923e0e7b6dbc71910985fe41bd59f`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/elemental-companions/preview.png`; `800 x 500`; `688351` bytes; SHA-256 `c487d5480e989861e2980b032faf73e4c5a7129933621d340095ae8025659fd4`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original set of friendly elemental habitats with stone, water, moss, crystal, and small glowing pools, arranged like a collectible adventure garden; no creatures or characters. Subject: green, aqua, and gold habitat forms on the right. Style/medium: warm stylized game environment illustration. Composition/framing: 16:10 landscape, calm leafy negative space on the left 40 percent for controls, layered habitat focal area on the right. Lighting/mood: soft daylight with jewel-like saturated accents. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: creature silhouettes, monster designs, collectible icons, and protected motifs.
```

## Walled Vanguard (`walled-vanguard`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/walled-vanguard-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/walled-vanguard/background.jpg`; `1600 x 1000`; `358210` bytes; SHA-256 `86f8e13d206a9df6193e543ef161431ab5fea7f80a07c9345d59e884d0fa0d35`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/walled-vanguard/preview.png`; `800 x 500`; `512301` bytes; SHA-256 `d4cdd5c4037ec250d552d2c943c383513a369d1da9d525be96ff5675d20f06d6`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original monumental stone rampart at dawn with layered walls, watch platforms, banners made of plain color fields, distant haze, and geometric military planning tables without marks. Subject: terracotta walls and blue-green signal structures on the right, no people. Style/medium: cinematic environment concept art. Composition/framing: 16:10 landscape, quiet dawn haze negative space on the left 40 percent for controls, strong architectural focal point on the right. Lighting/mood: disciplined sunrise, warm stone and cool shadow contrast. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: uniforms, emblems, signature weapons, and copied cinematic compositions.
```

## Arcane Academy (`arcane-academy`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/arcane-academy-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/arcane-academy/background.jpg`; `1600 x 1000`; `399802` bytes; SHA-256 `d1bc82fd5fe6d36828b4b96e8bc273808d60f8ea12e6ca5634ce81a57a2e7f21`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/arcane-academy/preview.png`; `800 x 500`; `550206` bytes; SHA-256 `f3b17f68142852f5da23a13b554b996883f92de643d3d48cc1d369c7b3420b5d`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original enchanted academy library with tall bookshelves whose spines are blank color blocks, jewel-toned stained glass, brass ladders, constellation-like ceiling lights, and a polished reading desk; no readable text or people. Subject: violet, teal, and gold magical architecture on the right. Style/medium: richly painted fantasy environment concept art. Composition/framing: 16:10 landscape, calm dark library negative space on the left 40 percent for controls, glowing bookshelf focal region on the right. Lighting/mood: jewel-tone candlelight and cool star glow. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: recognizable school crests, wands, spell marks, franchise props, and copied compositions.
```

## Hero Training Campus (`hero-training-campus`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/hero-training-campus-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/hero-training-campus/background.jpg`; `1600 x 1000`; `280585` bytes; SHA-256 `68df5fb32a675bd707ef540aeddb2a3b7ea2ebf34fc9d49a08b58a82215a2703`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/hero-training-campus/preview.png`; `800 x 500`; `472509` bytes; SHA-256 `e54d40b31b02a9a856fd6d0b305ec570b4e965ff11541655ffcbfe008d839a8d`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; mirrored trailing safe side and leading focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original graphic training campus with bold primary-color practice lanes, modular towers, painted safety blocks, banners with no marks, and a clear sky; no people or figures. Subject: blue, red, and yellow training structures on the right. Style/medium: energetic graphic game environment illustration. Composition/framing: 16:10 landscape, calm pale sky negative space on the left 40 percent for controls, strong campus focal geometry on the right. Lighting/mood: crisp daylight, primary-color action energy. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: superhero silhouettes, costumes, insignias, signature props, and protected visual motifs.
```

## Nebula Vanguard (`nebula-vanguard`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/nebula-vanguard-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/nebula-vanguard/background.jpg`; `1600 x 1000`; `389517` bytes; SHA-256 `1670afabd498832bea096da1aedd8c58d8e284e3881299ec4fea040832f83050`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/nebula-vanguard/preview.png`; `800 x 500`; `559694` bytes; SHA-256 `e1d5f537f26cfc080a4262fd6dd6fb2ac144bff6941b9bbcf88be4cc892bdef6`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original deep-space command deck with broad observation glass, red and blue navigation glow, layered structural ribs, distant nebula clouds, and abstract control consoles with no displays or writing. Subject: red-blue command architecture on the right. Style/medium: cinematic space-opera environment concept art. Composition/framing: 16:10 landscape, calm dark star field negative space on the left 40 percent for controls, detailed command deck on the right. Lighting/mood: high contrast red and blue, controlled atmospheric depth. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: recognizable spacecraft, alien forms, franchise symbols, and copied compositions.
```

## Spirit Lantern Town (`spirit-lantern-town`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/spirit-lantern-town-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/spirit-lantern-town/background.jpg`; `1600 x 1000`; `334978` bytes; SHA-256 `caec06131fefbec6ead5939f2bd689566df6d8e6b839092dbd57a3b7100b568b`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/spirit-lantern-town/preview.png`; `800 x 500`; `572526` bytes; SHA-256 `011167a73d48a8f245d88f63fdd23bf127dbb2f47f1a22408635b9888c8ccbc6`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; mirrored trailing safe side and leading focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original storybook hillside town at evening with warm paper lanterns, wooden footbridges, tiled roofs, mossy walls, and a quiet bathhouse-like communal building with no signs; no people or spirits. Subject: orange lantern warmth and green rooftops on the right. Style/medium: hand-painted storybook environment, textured brushwork. Composition/framing: 16:10 landscape, calm dusky negative space on the left 40 percent for controls, lantern-lit town focal area on the right. Lighting/mood: gentle amber twilight, welcoming and calm. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: recognizable animated-film compositions, creatures, named landmarks, and copied architecture.
```

## Block Frontier (`block-frontier`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/block-frontier-v2.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/block-frontier/background.jpg`; `1600 x 1000`; `278985` bytes; SHA-256 `b1b698f2c35d3c229b2f050703db66fa667fb79f4f38f197e1b51218609f7515`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/block-frontier/preview.png`; `800 x 500`; `505939` bytes; SHA-256 `063b2949fb1ede3e987b20c48849b73a3627a4e3562f8dcb2fb62c2c9fc824ec`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; mirrored trailing safe side and leading focal region verified.
- Selection note: v2 passed after draft 1 was rejected and excluded from packaging.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original geometric frontier valley built from large beveled polygonal terraces, smooth ceramic land plates, slanted basalt prisms, cyan water channels, and a small abstract outpost made from triangular beams; landscape geometry should feel modular and game-like but must not use cube blocks. Subject: green, cobalt, and amber faceted terrain concentrated on the right. Style/medium: distinctive low-poly game environment illustration with clean painted surfaces, not pixel art and not voxel blocks. Composition/framing: 16:10 landscape, calm open sky and low-detail mist on the left 40 percent for native controls, detailed polygonal frontier on the right. Lighting/mood: clear afternoon, saturated green and cobalt. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: grass-and-dirt cubes, square clouds, cubic trees, wooden block houses, inventory motifs, recognizable sandbox-game textures, or copied terrain compositions.
```

## Turbo Striker (`turbo-striker`)

- Source: `gpt-image-2`, CLI fallback, medium quality, requested `1600 x 1008`, raw output `output/imagegen/habitat-themes/turbo-striker-source.jpeg` (temporary, not packaged).
- Background: `Sources/CodexHabitatApp/Resources/Themes/turbo-striker/background.jpg`; `1600 x 1000`; `300671` bytes; SHA-256 `05463249cc810a798abb0f663ed0d68df01eca60f32cfe6f727dc1ae16f215c4`.
- Preview: `Sources/CodexHabitatApp/Resources/Themes/turbo-striker/preview.png`; `800 x 500`; `484867` bytes; SHA-256 `1e2801d996d89649119342e77688470949b46d5895b82527ad53840d5df90ad3`.
- Manual rights and content review: Pass. Original environment composition; no text or identifiable protected content; leading safe side and trailing focal region verified.
- Final prompt:

```text
Use case: stylized-concept. Asset type: desktop theme background. Scene/backdrop: an original floodlit stadium tunnel opening toward a bright field, cyan lane markings without text, lime safety rails, abstract speed streaks, and layered grandstand geometry; no people or logos. Subject: cyan and lime stadium architecture on the right. Style/medium: energetic sports game environment concept art. Composition/framing: 16:10 landscape, calm dark tunnel negative space on the left 40 percent for controls, bright field focal region on the right. Lighting/mood: crisp night floodlights, kinetic but legible. Constraints: no text, letters, numbers, logos, trademarks, people, faces, characters, creatures, mascots, flags, copied interface, screenshot, watermark, or recognizable franchise design. Avoid: team marks, player silhouettes, branded balls, and copied sports game compositions.
```
