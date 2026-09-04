import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum PlatformIdentity {
    static var hostDisplayName: String {
        #if os(macOS)
        Host.current().localizedName ?? "Mac"
        #elseif os(tvOS)
        UIDevice.current.name
        #else
        "Host"
        #endif
    }

    static var controllerDisplayName: String {
        #if os(iOS)
        UIDevice.current.name
        #else
        "Controller"
        #endif
    }
}
