import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects a flat string map that describes the device. Keys follow the
/// React Native SDK where the platforms overlap.
enum DeviceInfo {
    static func collect() -> [String: String] {
        var info: [String: String] = [
            "brand": "Apple",
            "manufacturer": "Apple",
            "modelId": hardwareModelIdentifier(),
            "totalMemory": String(ProcessInfo.processInfo.physicalMemory),
            "supportedCpuArchitectures": cpuArchitecture(),
        ]

        #if targetEnvironment(simulator)
        info["isDevice"] = "false"
        #else
        info["isDevice"] = "true"
        #endif

        #if canImport(UIKit)
        let device = UIDevice.current
        info["modelName"] = device.model
        info["deviceName"] = device.name
        info["osName"] = device.systemName
        info["osVersion"] = device.systemVersion
        info["deviceType"] = deviceType(for: device.userInterfaceIdiom)
        #else
        let process = ProcessInfo.processInfo
        info["osName"] = "macOS"
        info["osVersion"] = process.operatingSystemVersionString
        info["deviceType"] = "DESKTOP"
        #endif

        return info
    }

    /// The raw hardware identifier, for example `iPhone14,2`.
    private static func hardwareModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            let data = Data(buffer.prefix(while: { $0 != 0 }))
            return String(data: data, encoding: .utf8) ?? "unknown"
        }
    }

    private static func cpuArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    #if canImport(UIKit)
    private static func deviceType(for idiom: UIUserInterfaceIdiom) -> String {
        switch idiom {
        case .phone: return "PHONE"
        case .pad: return "TABLET"
        case .tv: return "TV"
        case .mac: return "DESKTOP"
        default: return "UNKNOWN"
        }
    }
    #endif
}
