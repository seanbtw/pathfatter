import Foundation

struct PathMapping: Identifiable, Hashable {
    var id: UUID
    var windowsPrefix: String
    var macPrefix: String
}

struct SharePointMapping: Identifiable, Hashable {
    var id: UUID
    var sharePointPrefix: String
    var localRoot: String
}

struct HistoryItem: Identifiable, Hashable, Codable {
    var id: UUID
    var input: String
    var output: String
    var timestamp: Date
    var canOpen: Bool
}

final class PathMappingStore: ObservableObject {
    @Published var mappings: [PathMapping] {
        didSet { scheduleSave() }
    }

    @Published var sharePointMappings: [SharePointMapping] {
        didSet { scheduleSharePointSave() }
    }

    @Published var browserIntegrationEnabled: Bool {
        didSet { saveBrowserIntegration() }
    }

    @Published var browserAutoOpenFinder: Bool {
        didSet { saveBrowserAutoOpenFinder() }
    }

    @Published var browserAutoCopyConvertedPath: Bool {
        didSet { saveBrowserAutoCopyConvertedPath() }
    }

    @Published var incomingSharePointURL: String?
    @Published var browserIntegrationLastEvent: String?
    @Published var history: [HistoryItem] {
        didSet { scheduleHistorySave() }
    }

    @Published var pinnedHistoryIds: Set<UUID> {
        didSet { schedulePinnedSave() }
    }

    private var incomingBrowserOpenFinderOverride: Bool?
    private var incomingBrowserCopyOverride: Bool?
    private var pinnedSaveWorkItem: DispatchWorkItem?

    // Debounced save work items
    private var saveWorkItem: DispatchWorkItem?
    private var sharePointSaveWorkItem: DispatchWorkItem?
    private var historySaveWorkItem: DispatchWorkItem?

    private static let storageKey = "PathFatter.PathMappings"
    private static let legacyStorageKey = "PathFlip.PathMappings"
    private static let sharePointStorageKey = "PathFatter.SharePointMappings"
    private static let browserIntegrationKey = "PathFatter.BrowserIntegrationEnabled"
    private static let browserAutoOpenFinderKey = "PathFatter.BrowserAutoOpenFinder"
    private static let browserAutoCopyPathKey = "PathFatter.BrowserAutoCopyConvertedPath"
    private static let historyStorageKey = "PathFatter.History"
    private static let pinnedStorageKey = "PathFatter.PinnedHistory"

    init() {
        self.mappings = Self.load()
        self.sharePointMappings = Self.loadSharePoint()
        self.browserIntegrationEnabled = Self.loadBrowserIntegration()
        self.browserAutoOpenFinder = Self.loadBrowserAutoOpenFinder()
        self.browserAutoCopyConvertedPath = Self.loadBrowserAutoCopyConvertedPath()
        self.history = Self.loadHistory()
        self.pinnedHistoryIds = Self.loadPinnedHistory()
    }

    // MARK: - Debounced Saves (Thread-Safe)

    private func scheduleSave() {
        saveWorkItem?.cancel()
        
        // Snapshot the data to avoid race conditions
        let mappingsSnapshot = mappings
        
        let work = DispatchWorkItem { [mappingsSnapshot] in
            self.performSave(with: mappingsSnapshot)
        }
        
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func performSave(with mappingsSnapshot: [PathMapping]) {
        let dto = mappingsSnapshot.map { PathMappingDTO(windowsPrefix: $0.windowsPrefix, macPrefix: $0.macPrefix) }
        guard let data = try? JSONEncoder().encode(dto) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func scheduleSharePointSave() {
        sharePointSaveWorkItem?.cancel()
        
        let sharePointSnapshot = sharePointMappings
        
        let work = DispatchWorkItem { [sharePointSnapshot] in
            self.performSharePointSave(with: sharePointSnapshot)
        }
        
        sharePointSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func performSharePointSave(with sharePointSnapshot: [SharePointMapping]) {
        let dto = sharePointSnapshot.map { SharePointMappingDTO(sharePointPrefix: $0.sharePointPrefix, localRoot: $0.localRoot) }
        guard let data = try? JSONEncoder().encode(dto) else { return }
        UserDefaults.standard.set(data, forKey: Self.sharePointStorageKey)
    }

    private func scheduleHistorySave() {
        historySaveWorkItem?.cancel()
        
        let historySnapshot = history
        
        let work = DispatchWorkItem { [historySnapshot] in
            self.performHistorySave(with: historySnapshot)
        }
        
        historySaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func performHistorySave(with historySnapshot: [HistoryItem]) {
        guard let data = try? JSONEncoder().encode(historySnapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyStorageKey)
    }

    private func schedulePinnedSave() {
        pinnedSaveWorkItem?.cancel()

        let pinnedSnapshot = pinnedHistoryIds

        let work = DispatchWorkItem { [pinnedSnapshot] in
            self.performPinnedSave(with: pinnedSnapshot)
        }

        pinnedSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func performPinnedSave(with pinnedSnapshot: Set<UUID>) {
        guard let data = try? JSONEncoder().encode(Array(pinnedSnapshot)) else { return }
        UserDefaults.standard.set(data, forKey: Self.pinnedStorageKey)
    }

    private static func loadPinnedHistory() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: pinnedStorageKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    func togglePinned(_ itemId: UUID) {
        if pinnedHistoryIds.contains(itemId) {
            pinnedHistoryIds.remove(itemId)
        } else {
            pinnedHistoryIds.insert(itemId)
        }
    }

    var pinnedHistory: [HistoryItem] {
        history.filter { pinnedHistoryIds.contains($0.id) }
    }

    // MARK: - Browser Integration Saves (immediate, low frequency)

    private func saveBrowserIntegration() {
        UserDefaults.standard.set(browserIntegrationEnabled, forKey: Self.browserIntegrationKey)
    }

    private static func loadBrowserIntegration() -> Bool {
        UserDefaults.standard.bool(forKey: browserIntegrationKey)
    }

    private func saveBrowserAutoOpenFinder() {
        UserDefaults.standard.set(browserAutoOpenFinder, forKey: Self.browserAutoOpenFinderKey)
    }

    private static func loadBrowserAutoOpenFinder() -> Bool {
        if UserDefaults.standard.object(forKey: browserAutoOpenFinderKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: browserAutoOpenFinderKey)
    }

    private func saveBrowserAutoCopyConvertedPath() {
        UserDefaults.standard.set(browserAutoCopyConvertedPath, forKey: Self.browserAutoCopyPathKey)
    }

    private static func loadBrowserAutoCopyConvertedPath() -> Bool {
        UserDefaults.standard.bool(forKey: browserAutoCopyPathKey)
    }

    // MARK: - Load Methods

    private static func load() -> [PathMapping] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let dto = try? JSONDecoder().decode([PathMappingDTO].self, from: data) {
            return dto.map { PathMapping(id: UUID(), windowsPrefix: $0.windowsPrefix, macPrefix: $0.macPrefix) }
        }

        if let legacy = UserDefaults.standard.data(forKey: legacyStorageKey),
           let dto = try? JSONDecoder().decode([PathMappingDTO].self, from: legacy) {
            let mappings = dto.map { PathMapping(id: UUID(), windowsPrefix: $0.windowsPrefix, macPrefix: $0.macPrefix) }
            if let encoded = try? JSONEncoder().encode(dto) {
                UserDefaults.standard.set(encoded, forKey: storageKey)
            }
            return mappings
        }

        return defaultMappings()
    }

    private static func loadSharePoint() -> [SharePointMapping] {
        if let data = UserDefaults.standard.data(forKey: sharePointStorageKey),
           let dto = try? JSONDecoder().decode([SharePointMappingDTO].self, from: data) {
            return dto.map { SharePointMapping(id: UUID(), sharePointPrefix: $0.sharePointPrefix, localRoot: $0.localRoot) }
        }

        return defaultSharePointMappings()
    }

    private static func loadHistory() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey) else { return [] }
        return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }

    // MARK: - History Management

    func recordHistory(input: String, output: String) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return }

        // Normalize both input and output for deduplication
        let normalizedOutput = trimmedOutput.lowercased()
        history.removeAll { 
            $0.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedOutput 
        }

        let canOpen = trimmedOutput.hasPrefix("/") || trimmedOutput.lowercased().hasPrefix("smb://")
        let item = HistoryItem(
            id: UUID(),
            input: trimmedInput,
            output: trimmedOutput,
            timestamp: Date(),
            canOpen: canOpen
        )
        history.insert(item, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
    }

    // MARK: - URL Handling

    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "pathfatter" else { return }

        guard browserIntegrationEnabled else {
            browserIntegrationLastEvent = "Received link, but integration is disabled."
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            browserIntegrationLastEvent = "Received malformed link."
            return
        }

        let queryItems = components.queryItems ?? []
        let action = resolvedAction(for: url, components: components)
        let allowedActions: Set<String> = ["open", "convert", "receive"]
        if let action, !action.isEmpty, !allowedActions.contains(action) {
            browserIntegrationLastEvent = "Unsupported browser action: \(action)."
            return
        }

        let sourceValue =
            queryValue(in: queryItems, keys: ["sharepoint", "url", "u", "target"])
            ?? sourceValueFromPath(components.path, action: action)

        guard let sourceValue else {
            browserIntegrationLastEvent = "No SharePoint URL found in link."
            return
        }

        let decoded = sourceValue.removingPercentEncoding ?? sourceValue
        guard PathConverter.isSharePointURL(decoded) else {
            browserIntegrationLastEvent = "Received link, but URL is not a SharePoint page."
            return
        }

        incomingBrowserOpenFinderOverride = boolValue(in: queryItems, keys: ["open", "finder"])
        incomingBrowserCopyOverride = boolValue(in: queryItems, keys: ["copy"])

        incomingSharePointURL = decoded
        browserIntegrationLastEvent = "Received SharePoint link from browser."
    }

    func consumeIncomingBrowserPreferences() -> (openFinder: Bool, copyPath: Bool) {
        let openFinder = incomingBrowserOpenFinderOverride ?? browserAutoOpenFinder
        let copyPath = incomingBrowserCopyOverride ?? browserAutoCopyConvertedPath

        incomingBrowserOpenFinderOverride = nil
        incomingBrowserCopyOverride = nil

        return (openFinder, copyPath)
    }

    private func resolvedAction(for url: URL, components: URLComponents) -> String? {
        if let host = url.host, !host.isEmpty {
            return host.lowercased()
        }

        let parts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        return parts.first?.lowercased()
    }

    private func sourceValueFromPath(_ path: String, action: String?) -> String? {
        let parts = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard !parts.isEmpty else { return nil }

        if let action, parts.first?.lowercased() == action {
            let remainder = parts.dropFirst().joined(separator: "/")
            return remainder.isEmpty ? nil : remainder
        }

        return parts.joined(separator: "/")
    }

    private func queryValue(in queryItems: [URLQueryItem], keys: [String]) -> String? {
        for key in keys {
            if let value = queryItems.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value,
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func boolValue(in queryItems: [URLQueryItem], keys: [String]) -> Bool? {
        guard let rawValue = queryValue(in: queryItems, keys: keys) else { return nil }
        return Self.parseBool(rawValue)
    }

    private static func parseBool(_ raw: String) -> Bool? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }

    // MARK: - Default Mappings (Generic, not workplace-specific)

    static func defaultMappings() -> [PathMapping] {
        // Start with empty mappings - users configure their own
        []
    }

    static func defaultSharePointMappings() -> [SharePointMapping] {
        // Try to detect OneDrive automatically
        let home = NSHomeDirectory()
        let possibleOneDrivePaths = [
            "\(home)/Library/CloudStorage/OneDrive-Personal",
            "\(home)/Library/CloudStorage/OneDrive-*",
            "\(home)/OneDrive",
        ]
        
        for path in possibleOneDrivePaths {
            // Handle wildcard
            if path.contains("*") {
                let prefix = path.replacingOccurrences(of: "/*", with: "")
                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: prefix), includingPropertiesForKeys: [.isDirectoryKey]) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.hasDirectoryPath && fileURL.lastPathComponent.contains("OneDrive") {
                            return [
                                SharePointMapping(
                                    id: UUID(),
                                    sharePointPrefix: "/sites/YourTeam/Shared Documents",
                                    localRoot: fileURL.path
                                )
                            ]
                        }
                    }
                }
            } else if FileManager.default.fileExists(atPath: path) {
                return [
                    SharePointMapping(
                        id: UUID(),
                        sharePointPrefix: "/sites/YourTeam/Shared Documents",
                        localRoot: path
                    )
                ]
            }
        }
        
        // No OneDrive found - start empty
        return []
    }

    // MARK: - Import/Export

    func importFromURL(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode([PathMappingDTO].self, from: data)
        self.mappings = dto.map { PathMapping(id: UUID(), windowsPrefix: $0.windowsPrefix, macPrefix: $0.macPrefix) }
    }

    func exportToURL(_ url: URL) throws {
        let dto = mappings.map { PathMappingDTO(windowsPrefix: $0.windowsPrefix, macPrefix: $0.macPrefix) }
        let data = try JSONEncoder().encode(dto)
        try data.write(to: url, options: [.atomic])
    }
    
    // MARK: - Validation Helpers
    
    static func isValidWindowsPrefix(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        return trimmed.count == 1 && trimmed.first?.isASCII == true && trimmed.first?.isLetter == true
    }
    
    static func isValidMacPrefix(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("/") || trimmed.hasPrefix("smb://")
    }
    
    static func isValidSharePointPrefix(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("/sites/") || trimmed.hasPrefix("/teams/") || trimmed.hasPrefix("/")
    }
}

private struct PathMappingDTO: Codable {
    var windowsPrefix: String
    var macPrefix: String
}

private struct SharePointMappingDTO: Codable {
    var sharePointPrefix: String
    var localRoot: String
}
