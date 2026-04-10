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

    private var incomingBrowserOpenFinderOverride: Bool?
    private var incomingBrowserCopyOverride: Bool?

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

    init() {
        self.mappings = Self.load()
        self.sharePointMappings = Self.loadSharePoint()
        self.browserIntegrationEnabled = Self.loadBrowserIntegration()
        self.browserAutoOpenFinder = Self.loadBrowserAutoOpenFinder()
        self.browserAutoCopyConvertedPath = Self.loadBrowserAutoCopyConvertedPath()
        self.history = Self.loadHistory()
    }

    // MARK: - Debounced Saves

    private func scheduleSave() {
        saveWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performSave()
        }

        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func performSave() {
        let dto = mappings.map { PathMappingDTO(windowsPrefix: $0.windowsPrefix, macPrefix: $0.macPrefix) }
        guard let data = try? JSONEncoder().encode(dto) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func scheduleSharePointSave() {
        sharePointSaveWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performSharePointSave()
        }

        sharePointSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func performSharePointSave() {
        let dto = sharePointMappings.map { SharePointMappingDTO(sharePointPrefix: $0.sharePointPrefix, localRoot: $0.localRoot) }
        guard let data = try? JSONEncoder().encode(dto) else { return }
        UserDefaults.standard.set(data, forKey: Self.sharePointStorageKey)
    }

    private func scheduleHistorySave() {
        historySaveWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performHistorySave()
        }

        historySaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func performHistorySave() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyStorageKey)
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
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return }

        let normalized = trimmedOutput.lowercased()
        history.removeAll { $0.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }

        let canOpen = trimmedOutput.hasPrefix("/") || trimmedOutput.lowercased().hasPrefix("smb://")
        let item = HistoryItem(
            id: UUID(),
            input: input.trimmingCharacters(in: .whitespacesAndNewlines),
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

    // MARK: - Default Mappings

    static func defaultMappings() -> [PathMapping] {
        [
            PathMapping(id: UUID(), windowsPrefix: "A:\\", macPrefix: "smb://10.20.1.10/LON_WFG_VDI_Data/Data"),
            PathMapping(id: UUID(), windowsPrefix: "G:\\", macPrefix: "smb://10.20.1.10/LON_WFG_VDI_Data/Graphics"),
            PathMapping(id: UUID(), windowsPrefix: "K:\\", macPrefix: "smb://10.20.1.10/LON_WFG_VDI_Data/Modus Jobs"),
            PathMapping(id: UUID(), windowsPrefix: "L:\\", macPrefix: "smb://10.20.1.10/LON_WFG_VDI_Data_Archive"),
            PathMapping(id: UUID(), windowsPrefix: "M:\\", macPrefix: "smb://10.20.1.10/LON_WFG_VDI_Data/MYTR"),
            PathMapping(id: UUID(), windowsPrefix: "V:\\", macPrefix: "smb://10.20.1.10/LON_WFG_RenderData")
        ]
    }

    static func defaultSharePointMappings() -> [SharePointMapping] {
        let home = NSHomeDirectory()
        let localRoot = "\(home)/Library/CloudStorage/OneDrive-WorkplaceFuturesGroupLimited/Mytr Team - Documents"
        return [
            SharePointMapping(
                id: UUID(),
                sharePointPrefix: "/sites/MytrTeam2/Shared Documents",
                localRoot: localRoot
            )
        ]
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
}

private struct PathMappingDTO: Codable {
    var windowsPrefix: String
    var macPrefix: String
}

private struct SharePointMappingDTO: Codable {
    var sharePointPrefix: String
    var localRoot: String
}
