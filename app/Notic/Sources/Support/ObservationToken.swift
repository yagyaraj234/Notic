import Foundation
import Observation

/// Re-arms `withObservationTracking` so AppKit code can react to `@Observable`
/// changes the way SwiftUI views do. Release the token to stop observing.
final class ObservationToken {
    private var rearm: (() -> Void)?

    private init() {}

    /// Calls `onChange` with the current value immediately and again whenever
    /// any observable state read inside `read` changes.
    static func track<Value>(_ read: @escaping () -> Value, onChange: @escaping (Value) -> Void) -> ObservationToken {
        let token = ObservationToken()
        token.rearm = { [weak token] in
            guard let token else { return }
            let value = withObservationTracking {
                read()
            } onChange: { [weak token] in
                Task { @MainActor in
                    token?.rearm?()
                }
            }
            onChange(value)
        }
        token.rearm?()
        return token
    }
}
