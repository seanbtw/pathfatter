import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var mappingStore: PathMappingStore
    @Environment(\.colorScheme) var colorScheme

    @State private var selection: SettingsPane? = .driveMappings
    @State private var errorMessage: String?
    @State private var didCopyBookmarklet = false
    @State private var extensionStatus: BrowserExtensionStatus = .unknown
    @State private var isCheckingExtensionStatus = false

    private var activePane: SettingsPane {
        selection ?? .driveMappings
    }

    // MARK: - Color Scheme Aware Colors

    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.035) : Color.primary.opacity(0.06)
    }

    var cardBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.08) : Color.primary.opacity(0.15)
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.secondary : Color(white: 0.45)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selection) {
                Section("Mappings") {
                    ForEach(SettingsPane.mappingPanes, id: \.self) { pane in
                        sidebarItem(for: pane)
                    }
                }

                Section("Integration") {
                    ForEach(SettingsPane.integrationPanes, id: \.self) { pane in
                        sidebarItem(for: pane)
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    pageHeader(for: activePane)
                    content(for: activePane)

                    if let errorMessage {
                        InlineIssueMessage(message: errorMessage)
                    }
                }
                .padding(28)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, idealWidth: 1040, minHeight: 620, idealHeight: 700)
        .onAppear {
            if selection == nil {
                selection = .driveMappings
            }
            refreshExtensionStatus()
        }
        .onChange(of: selection) { value in
            if value == .browserIntegration {
                refreshExtensionStatus()
            }
        }
    }
}

private extension SettingsView {
    func sidebarItem(for pane: SettingsPane) -> some View {
        HStack {
            Label(pane.title, systemImage: pane.symbol)
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .tag(Optional(pane))
            .padding(.vertical, 3)
    }

    func pageHeader(for pane: SettingsPane) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(pane.title, systemImage: pane.symbol)
                .font(.system(size: 24, weight: .semibold))

            Text(pane.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
    }

    @ViewBuilder
    func content(for pane: SettingsPane) -> some View {
        switch pane {
        case .browserIntegration:
            browserIntegrationCard
        case .driveMappings:
            driveMappingsCard
        case .sharePointMappings:
            sharePointMappingsCard
        }
    }

    var browserIntegrationCard: some View {
        SettingsCard(backgroundColor: cardBackgroundColor, borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $mappingStore.browserIntegrationEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable SharePoint Browser Handoff")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Allows PathFatter to receive `pathfatter://` deep links from browser workflows.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                .toggleStyle(.switch)

                Toggle("Automatically open converted folder in Finder", isOn: $mappingStore.browserAutoOpenFinder)
                    .font(.system(size: 12.5, weight: .medium))
                    .disabled(!mappingStore.browserIntegrationEnabled)

                Toggle("Automatically copy converted path", isOn: $mappingStore.browserAutoCopyConvertedPath)
                    .font(.system(size: 12.5, weight: .medium))
                    .disabled(!mappingStore.browserIntegrationEnabled)

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: mappingStore.browserIntegrationEnabled ? "checkmark.circle.fill" : "minus.circle.fill")
                        .foregroundStyle(mappingStore.browserIntegrationEnabled ? .green : secondaryTextColor)
                    Text(mappingStore.browserIntegrationEnabled ? "Status: Enabled" : "Status: Disabled")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                HStack(spacing: 8) {
                    Image(systemName: extensionStatusIcon)
                        .foregroundStyle(extensionStatusColor)
                    Text(extensionStatus.message)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                if let event = mappingStore.browserIntegrationLastEvent, !event.isEmpty {
                    Text("Last event: \(event)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Setup")
                        .font(.system(size: 12.5, weight: .semibold))

                    Text("1. Open Safari settings for this extension.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                    Text("2. Enable PathFatterWebExtension.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                    Text("3. On SharePoint pages, click the extension toolbar button.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                HStack(spacing: 8) {
                    Button {
                        openSafariExtensionPreferences()
                    } label: {
                        Label("Open Safari Extension Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        refreshExtensionStatus()
                    } label: {
                        Label(isCheckingExtensionStatus ? "Checking..." : "Check Extension Status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isCheckingExtensionStatus)
                }

                HStack(spacing: 8) {
                    Button {
                        copySafariBookmarklet()
                    } label: {
                        Label(didCopyBookmarklet ? "Copied Safari Bookmarklet" : "Copy Safari Bookmarklet (Fallback)", systemImage: didCopyBookmarklet ? "checkmark.circle.fill" : "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Text("Create a Safari bookmark using the copied JavaScript URL.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                }

                Text("Deep link format: `pathfatter://open?sharepoint=<encoded-url>`")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    var driveMappingsCard: some View {
        SettingsCard(backgroundColor: cardBackgroundColor, borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Label("Drive Mappings", systemImage: "externaldrive")
                        .font(.system(size: 15, weight: .semibold))

                    countBadge(mappingStore.mappings.count)

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            mappingStore.mappings.append(PathMapping(id: UUID(), windowsPrefix: "", macPrefix: ""))
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            importMappings()
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            exportMappings()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.small)
                }

                mappingContainer {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text("Windows Drive")
                                .frame(width: 140, alignment: .leading)

                            Text("macOS Folder / SMB Path")
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Color.clear.frame(width: 26, height: 1)
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        Divider()

                        if mappingStore.mappings.isEmpty {
                            emptyRowsMessage("No drive mappings yet.")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(mappingStore.mappings.enumerated()), id: \.element.id) { index, mapping in
                                    DriveMappingRow(mapping: binding(for: mapping.id)) {
                                        removeMapping(mapping.id)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)

                                    if index < mappingStore.mappings.count - 1 {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var sharePointMappingsCard: some View {
        SettingsCard(backgroundColor: cardBackgroundColor, borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Label("SharePoint Mappings", systemImage: "link")
                        .font(.system(size: 15, weight: .semibold))

                    countBadge(mappingStore.sharePointMappings.count)

                    Spacer()

                    Button {
                        mappingStore.sharePointMappings.append(
                            SharePointMapping(id: UUID(), sharePointPrefix: "", localRoot: "")
                        )
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                mappingContainer {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text("SharePoint Prefix")
                                .frame(minWidth: 240, idealWidth: 290, alignment: .leading)

                            Text("Local Folder")
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Color.clear.frame(width: 26, height: 1)
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        Divider()

                        if mappingStore.sharePointMappings.isEmpty {
                            emptyRowsMessage("No SharePoint mappings yet.")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(mappingStore.sharePointMappings.enumerated()), id: \.element.id) { index, mapping in
                                    SharePointMappingRow(mapping: sharePointBinding(for: mapping.id)) {
                                        removeSharePointMapping(mapping.id)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)

                                    if index < mappingStore.sharePointMappings.count - 1 {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func mappingContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
    }

    func emptyRowsMessage(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(secondaryTextColor)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }

    func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(colorScheme == .dark ? Color.secondary : Color(white: 0.4))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.16)))
    }

    func binding(for id: UUID) -> Binding<PathMapping> {
        guard let index = mappingStore.mappings.firstIndex(where: { $0.id == id }) else {
            fatalError("Missing mapping binding")
        }
        return $mappingStore.mappings[index]
    }

    func sharePointBinding(for id: UUID) -> Binding<SharePointMapping> {
        guard let index = mappingStore.sharePointMappings.firstIndex(where: { $0.id == id }) else {
            fatalError("Missing SharePoint mapping binding")
        }
        return $mappingStore.sharePointMappings[index]
    }

    func removeMapping(_ id: UUID) {
        mappingStore.mappings.removeAll { $0.id == id }
    }

    func removeSharePointMapping(_ id: UUID) {
        mappingStore.sharePointMappings.removeAll { $0.id == id }
    }

    var extensionStatusIcon: String {
        switch extensionStatus {
        case .enabled:
            return "checkmark.shield.fill"
        case .disabled:
            return "exclamationmark.shield.fill"
        case .unavailable:
            return "questionmark.app.dashed"
        case .error:
            return "xmark.octagon.fill"
        case .unknown:
            return "shield.lefthalf.filled"
        }
    }

    var extensionStatusColor: Color {
        switch extensionStatus {
        case .enabled:
            return .green
        case .disabled:
            return .orange
        case .unavailable:
            return .secondary
        case .error:
            return .red
        case .unknown:
            return .secondary
        }
    }

    func refreshExtensionStatus() {
        isCheckingExtensionStatus = true
        BrowserIntegrationHelper.checkSafariExtensionStatus { status in
            extensionStatus = status
            isCheckingExtensionStatus = false
        }
    }

    func openSafariExtensionPreferences() {
        BrowserIntegrationHelper.openSafariExtensionPreferences { status in
            if case .error = status {
                extensionStatus = status
                return
            }

            mappingStore.browserIntegrationLastEvent = "Opened Safari extension settings."
            refreshExtensionStatus()
        }
    }

    func importMappings() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try mappingStore.importFromURL(url)
                errorMessage = nil
            } catch {
                errorMessage = "Import failed. Please check the JSON format."
            }
        }
    }

    func exportMappings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "pathfatter-mappings.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try mappingStore.exportToURL(url)
                errorMessage = nil
            } catch {
                errorMessage = "Export failed."
            }
        }
    }

    func copySafariBookmarklet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.safariBookmarklet, forType: .string)

        didCopyBookmarklet = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.didCopyBookmarklet = false
        }
    }

    static var safariBookmarklet: String {
        "javascript:(function(){var u=encodeURIComponent(window.location.href);window.location.href='pathfatter://open?sharepoint='+u+'&open=1';})();"
    }
}

private enum SettingsPane: String, CaseIterable, Hashable {
    case browserIntegration
    case driveMappings
    case sharePointMappings

    var title: String {
        switch self {
        case .browserIntegration:
            return "Browser Integration"
        case .driveMappings:
            return "Drive Mappings"
        case .sharePointMappings:
            return "SharePoint Mappings"
        }
    }

    var subtitle: String {
        switch self {
        case .browserIntegration:
            return "Control deep-link handoff from browser workflows."
        case .driveMappings:
            return "Map Windows drive prefixes to macOS folder roots."
        case .sharePointMappings:
            return "Map SharePoint paths to local synced folders."
        }
    }

    var symbol: String {
        switch self {
        case .browserIntegration:
            return "safari"
        case .driveMappings:
            return "externaldrive"
        case .sharePointMappings:
            return "link"
        }
    }

    static let mappingPanes: [SettingsPane] = [.driveMappings, .sharePointMappings]
    static let integrationPanes: [SettingsPane] = [.browserIntegration]
}

private struct SettingsCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color
    var borderColor: Color

    init(backgroundColor: Color = .clear, borderColor: Color = .clear, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
    }
}

private struct InlineIssueMessage: View {
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.yellow.opacity(0.14))
        )
    }
}

private struct DriveMappingRow: View {
    @Binding var mapping: PathMapping
    var onRemove: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                TextField("A:", text: $mapping.windowsPrefix)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(width: 140)

                TextField("smb://server/share/path", text: $mapping.macPrefix)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)

                removeButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("A:", text: $mapping.windowsPrefix)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
                    removeButton
                }

                TextField("smb://server/share/path", text: $mapping.macPrefix)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
            }
        }
        .controlSize(.small)
    }

    private var removeButton: some View {
        Button(role: .destructive, action: onRemove) {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Remove mapping")
    }
}

private struct SharePointMappingRow: View {
    @Binding var mapping: SharePointMapping
    var onRemove: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                TextField("/sites/team/Shared Documents", text: $mapping.sharePointPrefix)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(minWidth: 240, idealWidth: 290)

                TextField("/Users/you/Library/CloudStorage/...", text: $mapping.localRoot)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)

                removeButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("/sites/team/Shared Documents", text: $mapping.sharePointPrefix)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
                    removeButton
                }

                TextField("/Users/you/Library/CloudStorage/...", text: $mapping.localRoot)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
            }
        }
        .controlSize(.small)
    }

    private var removeButton: some View {
        Button(role: .destructive, action: onRemove) {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Remove mapping")
    }
}
