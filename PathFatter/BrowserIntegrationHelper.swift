import Foundation
import SafariServices

enum BrowserExtensionStatus {
    case unknown
    case enabled
    case disabled
    case unavailable
    case error(String)

    var message: String {
        switch self {
        case .unknown:
            return "Click 'Check Status' to verify."
        case .enabled:
            return "✓ Extension is active and ready."
        case .disabled:
            return "⚠️ Extension is disabled. Enable it in Safari settings."
        case .unavailable:
            return "❌ Extension not found. Build and run PathFatterSafariWebExtension."
        case .error(let text):
            return "Error: \(text)"
        }
    }
    
    var actionHint: String {
        switch self {
        case .disabled:
            return "Open Safari Preferences → Extensions"
        case .unavailable:
            return "Build the Safari extension scheme in Xcode"
        default:
            return ""
        }
    }
}

enum BrowserIntegrationHelper {
    static let extensionBundleIdentifier = "com.sean.pathfatter.webextension"

    static func checkSafariExtensionStatus(completion: @escaping (BrowserExtensionStatus) -> Void) {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { state, error in
            DispatchQueue.main.async {
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == SFErrorDomain,
                       nsError.code == 1 {
                        completion(.unavailable)
                        return
                    }

                    completion(.error("Unable to check extension status."))
                    return
                }

                guard let state else {
                    completion(.unknown)
                    return
                }

                completion(state.isEnabled ? .enabled : .disabled)
            }
        }
    }

    static func openSafariExtensionPreferences(completion: @escaping (BrowserExtensionStatus) -> Void) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(.error("Could not open Safari extension settings."))
                    return
                }

                completion(.unknown)
            }
        }
    }
}
