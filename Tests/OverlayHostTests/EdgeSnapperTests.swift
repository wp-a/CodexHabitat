import Foundation
import Testing
@testable import OverlayHost

@Test(arguments: [
    (CGPoint(x: 8, y: 300), CGPoint(x: 0, y: 300)),
    (CGPoint(x: 812, y: 300), CGPoint(x: 820, y: 300)),
    (CGPoint(x: 300, y: 48), CGPoint(x: 300, y: 40)),
    (CGPoint(x: 300, y: 652), CGPoint(x: 300, y: 660)),
])
func snapsToEveryVisibleEdge(input: CGPoint, expected: CGPoint) {
    let snapper = EdgeSnapper(threshold: 12)
    let visibleFrame = CGRect(x: 0, y: 40, width: 1_000, height: 820)

    let result = snapper.snappedOrigin(
        input,
        panelSize: CGSize(width: 180, height: 200),
        visibleFrame: visibleFrame
    )

    #expect(result == expected)
}

@Test
func distantOriginsClampButDoNotSnapPastTheVisibleFrame() {
    let snapper = EdgeSnapper(threshold: 12)
    let visibleFrame = CGRect(x: 100, y: 80, width: 900, height: 700)

    let result = snapper.snappedOrigin(
        CGPoint(x: -500, y: 900),
        panelSize: CGSize(width: 200, height: 180),
        visibleFrame: visibleFrame
    )

    #expect(result == CGPoint(x: 100, y: 600))
}
