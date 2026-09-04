#if os(macOS) || os(tvOS)
import Foundation
import Darwin

enum LocalLinkAddresses {
    static func ipv4() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var pointer = ifaddr
        while let interface = pointer?.pointee {
            defer { pointer = interface.ifa_next }
            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            let name = String(cString: interface.ifa_name)
            if name.hasPrefix("utun") || name.hasPrefix("awdl") || name.hasPrefix("llw") {
                continue
            }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            let ip = String(cString: hostname)
            if ip.hasPrefix("169.254") { continue }
            if !addresses.contains(ip) {
                addresses.append(ip)
            }
        }
        return addresses
    }
}
#endif
