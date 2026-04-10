import Foundation

struct PathConverter {
    struct ConversionContext {
        fileprivate let windowsToMacRoots: [String: String]
        fileprivate let macRules: [MacRule]
        fileprivate let sharePointRules: [SharePointRule]

        fileprivate init(windowsToMacRoots: [String: String], macRules: [MacRule], sharePointRules: [SharePointRule]) {
            self.windowsToMacRoots = windowsToMacRoots
            self.macRules = macRules
            self.sharePointRules = sharePointRules
        }
    }

    fileprivate struct MacRule {
        let macPrefixLower: String
        let windowsPrefix: String
    }

    fileprivate struct SharePointRule {
        let prefixLower: String
        let prefixOriginal: String
        let localRoot: String
    }

    static func makeContext(mappings: [PathMapping], sharePointMappings: [SharePointMapping]) -> ConversionContext {
        let normalizedDriveMappings = normalizeMappings(mappings)

        var windowsToMacRoots: [String: String] = [:]
        windowsToMacRoots.reserveCapacity(normalizedDriveMappings.count)

        var macRules: [MacRule] = []
        macRules.reserveCapacity(normalizedDriveMappings.count)

        for mapping in normalizedDriveMappings {
            windowsToMacRoots[mapping.windowsPrefix] = mapping.macPrefix
            macRules.append(
                MacRule(
                    macPrefixLower: mapping.macPrefix.lowercased(),
                    windowsPrefix: mapping.windowsPrefix
                )
            )
        }

        macRules.sort { $0.macPrefixLower.count > $1.macPrefixLower.count }

        let normalizedSharePointMappings = normalizeSharePointMappings(sharePointMappings)
        let sharePointRules = normalizedSharePointMappings
            .map {
                SharePointRule(
                    prefixLower: $0.sharePointPrefix.lowercased(),
                    prefixOriginal: $0.sharePointPrefix,
                    localRoot: $0.localRoot
                )
            }
            .sorted { $0.prefixLower.count > $1.prefixLower.count }

        return ConversionContext(
            windowsToMacRoots: windowsToMacRoots,
            macRules: macRules,
            sharePointRules: sharePointRules
        )
    }

    static func convert(_ input: String, context: ConversionContext) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if isSharePointURL(trimmed) {
            return sharePointToMac(trimmed, context: context)
        }

        if isWindowsPath(trimmed) {
            return windowsToMac(trimmed, context: context)
        }

        return macToWindows(trimmed, context: context)
    }

    static func convert(_ input: String, mappings: [PathMapping] = [], sharePointMappings: [SharePointMapping] = []) -> String {
        convert(input, context: makeContext(mappings: mappings, sharePointMappings: sharePointMappings))
    }

    static func isWindowsPath(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        
        // UNC path (\\server\share or //server/share)
        if trimmed.hasPrefix("\\\\") || trimmed.hasPrefix("//") { return true }
        
        // Drive letter (C:\, D:, etc.)
        if trimmed.count >= 2 {
            let chars = Array(trimmed)
            if chars[0].isASCII && chars[0].isLetter && chars[1] == ":" { return true }
        }
        
        // Backslash path (even forward-slash variants)
        if trimmed.contains("\\") { return true }
        
        return false
    }

    static func isSharePointURL(_ input: String) -> Bool {
        guard let url = URL(string: input),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host?.lowercased() else { return false }
        
        // Microsoft SharePoint Online
        if host.hasSuffix(".sharepoint.com") { return true }
        
        // Custom SharePoint domains can be added here if needed
        return false
    }

    private static func windowsToMac(_ input: String, context: ConversionContext) -> String {
        if let mappedDrive = mapWindowsDrive(input, context: context) {
            return mappedDrive
        }

        if input.hasPrefix("\\\\") || input.hasPrefix("//") {
            let prefixRemoved = input.hasPrefix("\\\\") ? String(input.dropFirst(2)) : String(input.dropFirst(2))
            let parts = prefixRemoved.split(separator: CharacterSet(charactersIn: "\\/"), omittingEmptySubsequences: true)
            if parts.count >= 2 {
                let server = parts[0]
                let share = parts[1]
                let rest = parts.dropFirst(2).joined(separator: "/")
                return rest.isEmpty ? "smb://\(server)/\(share)" : "smb://\(server)/\(share)/\(rest)"
            }
        }

        let slashPath = input.replacingOccurrences(of: "\\", with: "/")

        if slashPath.count >= 2 {
            let chars = Array(slashPath)
            if chars[1] == ":" {
                let drive = String(chars[0]).uppercased()
                let remainder = String(slashPath.dropFirst(2))
                let cleaned = remainder.hasPrefix("/") ? String(remainder.dropFirst(1)) : remainder
                return cleaned.isEmpty ? "/Volumes/\(drive)" : "/Volumes/\(drive)/\(cleaned)"
            }
        }

        return slashPath
    }

    private static func macToWindows(_ input: String, context: ConversionContext) -> String {
        if let mappedPrefix = mapMacPrefix(input, context: context) {
            return mappedPrefix
        }

        if input.hasPrefix("smb://") {
            let trimmed = String(input.dropFirst("smb://".count))
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            if parts.count >= 2 {
                let server = parts[0]
                let share = parts[1]
                let rest = parts.dropFirst(2).joined(separator: "\\")
                return rest.isEmpty ? "\\\\\(server)\\\(share)" : "\\\\\(server)\\\(share)\\\(rest)"
            }
        }

        if input.hasPrefix("/Volumes/") {
            let trimmed = String(input.dropFirst("/Volumes/".count))
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            if let drive = parts.first {
                let rest = parts.dropFirst().joined(separator: "\\")
                return rest.isEmpty ? "\(drive):\\" : "\(drive):\\\(rest)"
            }
        }

        if input.hasPrefix("/") {
            let remainder = String(input.dropFirst())
            let converted = remainder.replacingOccurrences(of: "/", with: "\\")
            return "C:\\\(converted)"
        }

        return input.replacingOccurrences(of: "/", with: "\\")
    }

    private static func sharePointToMac(_ input: String, context: ConversionContext) -> String {
        guard let url = URL(string: input) else { return input }
        guard let extractedPath = extractSharePointPath(from: url) else { return input }

        let decodedPath = extractedPath.removingPercentEncoding ?? extractedPath
        let lowerPath = decodedPath.lowercased()

        guard let match = context.sharePointRules.first(where: { lowerPath.hasPrefix($0.prefixLower) }) else {
            return ""
        }

        let remainder = String(decodedPath.dropFirst(match.prefixOriginal.count))
        let cleaned = remainder.hasPrefix("/") ? String(remainder.dropFirst(1)) : remainder

        return cleaned.isEmpty ? match.localRoot : match.localRoot + "/" + cleaned
    }

    private static func extractSharePointPath(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let keys = ["id", "rootfolder", "folder"]
            for key in keys {
                if let value = components.queryItems?.first(where: { $0.name.lowercased() == key })?.value,
                   let decoded = value.removingPercentEncoding {
                    return decoded
                }
            }
        }

        let path = url.path
        guard !path.isEmpty else { return nil }
        return path.removingPercentEncoding ?? path
    }

    private static func mapWindowsDrive(_ input: String, context: ConversionContext) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let chars = Array(trimmed)
        guard chars[1] == ":" else { return nil }

        let drive = String(chars[0]).uppercased()
        guard let root = context.windowsToMacRoots[drive] else { return nil }

        let remainder = String(trimmed.dropFirst(2))
        let cleaned = remainder.hasPrefix("\\") ? String(remainder.dropFirst(1)) : remainder
        let remainderPath = cleaned.replacingOccurrences(of: "\\", with: "/")

        return remainderPath.isEmpty ? root : root + "/" + remainderPath
    }

    private static func mapMacPrefix(_ input: String, context: ConversionContext) -> String? {
        let normalized = normalizeMacPath(input)
        let normalizedLower = normalized.lowercased()

        for rule in context.macRules where normalizedLower.hasPrefix(rule.macPrefixLower) {
            let remainder = String(normalized.dropFirst(rule.macPrefixLower.count))
            let cleaned = remainder.hasPrefix("/") ? String(remainder.dropFirst(1)) : remainder
            let backslashed = cleaned.replacingOccurrences(of: "/", with: "\\")
            return backslashed.isEmpty ? "\(rule.windowsPrefix):\\" : "\(rule.windowsPrefix):\\\(backslashed)"
        }

        return nil
    }

    private static func normalizeMappings(_ mappings: [PathMapping]) -> [PathMapping] {
        mappings.map { mapping in
            let windows = mapping.windowsPrefix
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\", with: "")
                .replacingOccurrences(of: ":", with: "")
                .uppercased()

            var mac = mapping.macPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            while mac.hasSuffix("/") {
                mac.removeLast()
            }

            return PathMapping(id: mapping.id, windowsPrefix: windows, macPrefix: mac)
        }
    }

    private static func normalizeMacPath(_ input: String) -> String {
        var path = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func normalizeSharePointMappings(_ mappings: [SharePointMapping]) -> [SharePointMapping] {
        mappings.map { mapping in
            let prefix = normalizeSharePointPrefix(mapping.sharePointPrefix)
            var root = mapping.localRoot.trimmingCharacters(in: .whitespacesAndNewlines)
            root = normalizeHomeRoot(root)
            while root.hasSuffix("/") {
                root.removeLast()
            }
            return SharePointMapping(id: mapping.id, sharePointPrefix: prefix, localRoot: root)
        }
    }

    private static func normalizeHomeRoot(_ root: String) -> String {
        let home = NSHomeDirectory()
        var resolved = (root as NSString).expandingTildeInPath
        resolved = resolved.replacingOccurrences(of: "$HOME", with: home)

        if resolved.hasPrefix("/Users/") {
            let parts = resolved.split(separator: "/", omittingEmptySubsequences: true)
            if parts.count >= 2, parts[0] == "Users" {
                let suffix = parts.dropFirst(2).joined(separator: "/")
                return suffix.isEmpty ? home : "\(home)/\(suffix)"
            }
        }

        return resolved
    }

    private static func normalizeSharePointPrefix(_ prefix: String) -> String {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.lowercased().hasPrefix("http"), let url = URL(string: trimmed) {
            let path = url.path.removingPercentEncoding ?? url.path
            return path.hasPrefix("/") ? path : "/" + path
        }

        let path = trimmed.removingPercentEncoding ?? trimmed
        return path.hasPrefix("/") ? path : "/" + path
    }
}
