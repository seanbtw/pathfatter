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
            return "Not checked yet."
        case .enabled:
            return "Safari extension is enabled."
        case .disabled:
            return "Safari extension is installed but disabled."
        case .unavailable:
            return "Safari extension was not found."
        case .error(let text):
            return text
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
