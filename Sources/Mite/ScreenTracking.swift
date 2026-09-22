#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Records `name` as the current screen on the shared client when the
    /// view appears, so later bug reports carry it as `current_route`.
    /// Does nothing until `Mite.configure(_:)` has run.
    public func miteScreen(_ name: String) -> some View {
        onAppear {
            Mite.sharedIfConfigured?.recordScreen(name)
        }
    }
}
#endif
