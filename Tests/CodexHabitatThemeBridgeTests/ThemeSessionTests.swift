import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func startRequiresAuthorizationUsesLoopbackFlagsAndPersistsPrivateIdentity() throws {
    let fixture = ThemeSessionFixture()
    defer { fixture.cleanup() }

    #expect(throws: ThemeSessionError.authorizationRequired) {
        try fixture.session.start(bundleURL: fixture.bundle.bundleURL, authorized: false)
    }
    #expect(fixture.launcher.invocations.isEmpty)

    let record = try fixture.session.start(
        bundleURL: fixture.bundle.bundleURL,
        authorized: true
    )

    #expect(record.port == 55_000)
    #expect(record.process == fixture.process)
    #expect(fixture.launcher.invocations.count == 1)
    #expect(fixture.launcher.invocations[0].arguments == [
        "--remote-debugging-address=127.0.0.1",
        "--remote-debugging-port=55000",
    ])
    let attributes = try FileManager.default.attributesOfItem(
        atPath: fixture.store.recordURL.path
    )
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    let rootAttributes = try FileManager.default.attributesOfItem(atPath: fixture.root.path)
    #expect((rootAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
}

@Test
func lowPortAndUnexpectedProcessAncestryAreRejected() {
    let lowPort = ThemeSessionFixture(port: 9_222)
    defer { lowPort.cleanup() }
    #expect(throws: ThemeSessionError.portOutsideAllowedRange(9_222)) {
        try lowPort.session.start(bundleURL: lowPort.bundle.bundleURL, authorized: true)
    }
    #expect(lowPort.launcher.invocations.isEmpty)

    let unrelated = ThemeSessionFixture(isDescendant: false)
    defer { unrelated.cleanup() }
    #expect(throws: ThemeSessionError.unexpectedProcessAncestry) {
        try unrelated.session.start(bundleURL: unrelated.bundle.bundleURL, authorized: true)
    }
    #expect(unrelated.signaler.terminatedPIDs == [unrelated.process.pid])
}

@Test
func pidReuseDefenseMarksStaleAndRefusesToStopAnUnrelatedProcess() throws {
    let fixture = ThemeSessionFixture()
    defer { fixture.cleanup() }
    _ = try fixture.session.start(bundleURL: fixture.bundle.bundleURL, authorized: true)
    fixture.inspector.identities[fixture.process.pid] = ProcessIdentity(
        pid: fixture.process.pid,
        parentPID: 1,
        executableURL: URL(fileURLWithPath: "/usr/bin/unrelated"),
        startTimeMicroseconds: fixture.process.startTimeMicroseconds + 1
    )

    #expect(fixture.session.status() == .stale)
    #expect(throws: ThemeSessionError.processIdentityChanged) {
        try fixture.session.stop()
    }
    #expect(fixture.signaler.terminatedPIDs.isEmpty)
    #expect(try fixture.store.load() != nil)
}

@Test
func exactOwnedProcessCanBeStoppedAndRecordIsCleared() throws {
    let fixture = ThemeSessionFixture()
    defer { fixture.cleanup() }
    _ = try fixture.session.start(bundleURL: fixture.bundle.bundleURL, authorized: true)

    try fixture.session.stop()

    #expect(fixture.signaler.terminatedPIDs == [fixture.process.pid])
    #expect(try fixture.store.load() == nil)
    #expect(fixture.session.status() == .inactive)
}

@Test
func unsafeRecordPermissionsAreStaleAndNeverTriggerASignal() throws {
    let fixture = ThemeSessionFixture()
    defer { fixture.cleanup() }
    _ = try fixture.session.start(bundleURL: fixture.bundle.bundleURL, authorized: true)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o644],
        ofItemAtPath: fixture.store.recordURL.path
    )

    #expect(fixture.session.status() == .stale)
    #expect(throws: SessionRecordError.unsafeRecord) {
        try fixture.session.stop()
    }
    #expect(fixture.signaler.terminatedPIDs.isEmpty)
}

@Test
func processInspectorWalksAncestryAndStopsAtCycles() {
    let table: [Int32: ProcessIdentity] = [
        30: ProcessIdentity(
            pid: 30, parentPID: 20, executableURL: URL(fileURLWithPath: "/bin/child"),
            startTimeMicroseconds: 30
        ),
        20: ProcessIdentity(
            pid: 20, parentPID: 10, executableURL: URL(fileURLWithPath: "/bin/parent"),
            startTimeMicroseconds: 20
        ),
        10: ProcessIdentity(
            pid: 10, parentPID: 1, executableURL: URL(fileURLWithPath: "/bin/root"),
            startTimeMicroseconds: 10
        ),
        40: ProcessIdentity(
            pid: 40, parentPID: 41, executableURL: URL(fileURLWithPath: "/bin/a"),
            startTimeMicroseconds: 40
        ),
        41: ProcessIdentity(
            pid: 41, parentPID: 40, executableURL: URL(fileURLWithPath: "/bin/b"),
            startTimeMicroseconds: 41
        ),
    ]
    let inspector = CodexProcessInspector { table[$0] }

    #expect(inspector.isDescendant(30, of: 10))
    #expect(!inspector.isDescendant(30, of: 99))
    #expect(!inspector.isDescendant(40, of: 10))
}

private final class ThemeSessionFixture {
    let root: URL
    let bundle: VerifiedCodexBundle
    let process: ProcessIdentity
    let launcher: StubLauncher
    let inspector: StubProcessInspector
    let signaler: StubSignaler
    let store: SessionRecordStore
    let session: ThemeSession

    init(port: UInt16 = 55_000, isDescendant: Bool = true) {
        root = FileManager.default.temporaryDirectory.appending(
            path: "ThemeSessionTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let bundleURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
        let executableURL = bundleURL.appending(path: "Contents/MacOS/ChatGPT")
        bundle = VerifiedCodexBundle(
            bundleURL: bundleURL,
            executableURL: executableURL,
            bundleIdentifier: "com.openai.codex",
            teamIdentifier: "2DC432GLL2",
            version: "26.707.91948",
            architectures: [.current]
        )
        process = ProcessIdentity(
            pid: 4_321,
            parentPID: 999,
            executableURL: executableURL,
            startTimeMicroseconds: 12_345_678
        )
        launcher = StubLauncher(pid: process.pid)
        inspector = StubProcessInspector(
            identities: [process.pid: process],
            descendantResult: isDescendant
        )
        signaler = StubSignaler()
        store = SessionRecordStore(root: root)
        session = ThemeSession(
            verifier: StubBundleVerifier(bundle: bundle),
            launcher: launcher,
            processInspector: inspector,
            signaler: signaler,
            portAllocator: StubPortAllocator(port: port),
            recordStore: store,
            ownerPID: 999
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

private struct StubBundleVerifier: CodexBundleVerifying {
    let bundle: VerifiedCodexBundle

    func verify(_ bundleURL: URL) throws -> VerifiedCodexBundle { bundle }
}

private final class StubLauncher: ThemeProcessLaunching, @unchecked Sendable {
    struct Invocation: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    let pid: Int32
    var invocations: [Invocation] = []

    init(pid: Int32) { self.pid = pid }

    func launch(executableURL: URL, arguments: [String]) throws -> Int32 {
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))
        return pid
    }
}

private final class StubProcessInspector: CodexProcessInspecting, @unchecked Sendable {
    var identities: [Int32: ProcessIdentity]
    let descendantResult: Bool

    init(identities: [Int32: ProcessIdentity], descendantResult: Bool) {
        self.identities = identities
        self.descendantResult = descendantResult
    }

    func identity(for pid: Int32) -> ProcessIdentity? { identities[pid] }
    func isDescendant(_ pid: Int32, of ancestorPID: Int32) -> Bool { descendantResult }
}

private final class StubSignaler: ThemeProcessSignaling, @unchecked Sendable {
    var terminatedPIDs: [Int32] = []

    func terminate(process: ProcessIdentity) -> Bool {
        terminatedPIDs.append(process.pid)
        return true
    }
}

private struct StubPortAllocator: LoopbackPortAllocating {
    let port: UInt16
    func allocate() throws -> UInt16 { port }
}
