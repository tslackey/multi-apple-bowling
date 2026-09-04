import SwiftUI

struct RootView: View {
    var body: some View {
        #if os(iOS)
        ControllerView()
        #elseif os(macOS) || os(tvOS)
        HostView()
        #else
        Text("This platform is not supported.")
        #endif
    }
}

#Preview {
    RootView()
}
