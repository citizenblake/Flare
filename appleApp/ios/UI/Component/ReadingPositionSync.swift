import UIKit

@MainActor
protocol ReadingPositionTarget: AnyObject {
    func scrollToReadingPosition(itemID: String, createdAt: Date)
}

/// Shares a timeline's reading position across the user's devices through iCloud
/// key-value storage. Saved whenever scrolling stops; another device's position is
/// applied only just after this app becomes active and before the user scrolls,
/// so it never moves a timeline that is being read.
@MainActor
final class ReadingPositionSync {
    private static let applyWindow: TimeInterval = 15
    private static let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""

    weak var target: ReadingPositionTarget?
    private let key: String
    private let store = NSUbiquitousKeyValueStore.default
    private var activatedAt = Date()
    private var userScrolled = false
    // A fresh launch starts at the top, so this device's own last position is restored once.
    private var restoresOwnPosition = true
    private var observers: [NSObjectProtocol] = []

    init(timelineKey: String) {
        key = "position.\(timelineKey)"
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.activatedAt = Date()
                    self?.userScrolled = false
                    self?.applyRemoteIfFresh()
                }
            },
            // iCloud often delivers the other device's position a moment after activation.
            center.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.applyRemoteIfFresh() }
            },
        ]
        store.synchronize()
    }

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func userDidScroll() {
        userScrolled = true
        restoresOwnPosition = false
    }

    func save(itemID: String, createdAt: Date) {
        store.set([
            "id": itemID,
            "createdAt": createdAt.timeIntervalSince1970,
            "device": Self.deviceID,
        ], forKey: key)
    }

    /// Called once the timeline has rows, in case the position arrived before them.
    func timelineDidLoad() {
        applyRemoteIfFresh()
    }

    private func applyRemoteIfFresh() {
        guard !userScrolled, Date().timeIntervalSince(activatedAt) < Self.applyWindow,
              let saved = store.dictionary(forKey: key),
              restoresOwnPosition || saved["device"] as? String != Self.deviceID,
              let id = saved["id"] as? String,
              let createdAt = saved["createdAt"] as? TimeInterval else { return }
        guard let target else { return }
        restoresOwnPosition = false
        target.scrollToReadingPosition(itemID: id, createdAt: Date(timeIntervalSince1970: createdAt))
    }
}
