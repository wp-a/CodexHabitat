import Foundation
import Testing
@testable import HabitatCore

@Test
func narrowViewportFocusYMovesTheArtworkCropByNonzeroPixels() {
    let lowFocus = HabitatThemeArtworkCrop(
        focus: HabitatThemeFocalPoint(x: 0.5, y: 0.25),
        scale: 1.08
    )
    let highFocus = HabitatThemeArtworkCrop(
        focus: HabitatThemeFocalPoint(x: 0.5, y: 0.75),
        scale: 1.08
    )
    let imageSize = HabitatThemeArtworkCrop.Size(width: 1_600, height: 1_000)
    let viewportSize = HabitatThemeArtworkCrop.Size(width: 1_180, height: 820)

    let lowRect = lowFocus.drawRect(imageSize: imageSize, viewportSize: viewportSize)
    let highRect = highFocus.drawRect(imageSize: imageSize, viewportSize: viewportSize)

    #expect(lowRect.width == highRect.width)
    #expect(lowRect.height == highRect.height)
    #expect(abs(lowRect.x - highRect.x) < 0.001)
    #expect(abs(lowRect.y - -16.4) < 0.001)
    #expect(abs(highRect.y - -49.2) < 0.001)
    #expect(abs(abs(lowRect.y - highRect.y) - 32.8) < 0.001)
}

@Test
func artworkCropRejectsInvalidImageOrViewportSizes() {
    let crop = HabitatThemeArtworkCrop(
        focus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
        scale: 1.08
    )

    #expect(crop.drawRect(
        imageSize: HabitatThemeArtworkCrop.Size(width: 0, height: 1_000),
        viewportSize: HabitatThemeArtworkCrop.Size(width: 1_180, height: 820)
    ) == .zero)
    #expect(crop.drawRect(
        imageSize: HabitatThemeArtworkCrop.Size(width: 1_600, height: 1_000),
        viewportSize: HabitatThemeArtworkCrop.Size(width: .infinity, height: 820)
    ) == .zero)
}
