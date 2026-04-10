import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var mappingStore: PathMappingStore
    @Environment(\.colorScheme) var colorScheme

    @State private var inputPath = ""
    @State private var outputPath = ""
    @State private var conversionContext = PathConverter.makeContext(
        mappings: PathMappingStore.defaultMappings(),
        sharePointMappings: PathMappingStore.defaultSharePointMappings()
    )

    @State private var didCopy = false
    @State private var isHistoryVisible = false
    @State private var isHoveringCopy = false
    @State private var isHoveringOpen = false
    @State private var isHoveringPaste = false
    @State private var isHoveringClear = false
    @State private var isHoveringSwap = false
    @State private var isHoveringHistory = false
    @State private var isHoveringHistoryPanel = false
    @State private var historyWorkItem: DispatchWorkItem?
    @State private var pendingBrowserOpenFinder = false
    @State private var pendingBrowserCopyOutput = false

    @FocusState private var isInputFocused: Bool

    private enum InputKind {
        case empty
        case windows
        case sharePoint
        case mac
    }

    private var trimmedInput: String {
        inputPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var inputKind: InputKind {
        if trimmedInput.isEmpty { return .empty }
        if PathConverter.isSharePointURL(trimmedInput) { return .sharePoint }
        if PathConverter.isWindowsPath(trimmedInput) { return .windows }
        return .mac
    }

    private var sourceTitle: String {
        switch inputKind {
        case .empty:
            return "Input Path"
        case .windows:
            return "Windows Path"
        case .sharePoint:
            return "SharePoint URL"
        case .mac:
            return "macOS Path"
        }
    }

    private var targetTitle: String {
        switch inputKind {
        case .empty:
            return "Output Path"
        case .windows, .sharePoint:
            return "macOS Path"
        case .mac:
            return "Windows Path"
        }
    }

    private var directionLabel: String {
        switch inputKind {
        case .empty:
            return "Ready"
        case .windows:
            return "Windows to macOS"
        case .sharePoint:
            return "SharePoint to macOS"
        case .mac:
            return "macOS to Windows"
        }
    }

    private var statusText: String {
        if outputPath.isEmpty {
            if inputKind == .sharePoint {
                return "Add a SharePoint mapping in Settings"
            }
            return trimmedInput.isEmpty ? "Paste a path to convert" : "No conversion available"
        }
        return "Ready"
    }

    private var canOpenOutputInFinder: Bool {
        let trimmed = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("/") || trimmed.lowercased().hasPrefix("smb://")
    }

    var body: some View {
        GeometryReader { proxy in
            let profile = LayoutProfile(size: proxy.size)

            ZStack {
                backgroundLayer
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: profile.gap) {
                        VStack(alignment: .leading, spacing: profile.gap) {
                            header(profile: profile)
                            cards(profile: profile)

                            if isHistoryVisible && !profile.showSideHistory {
                                historyCard(maxHeight: profile.inlineHistoryHeight)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            footerRow
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if isHistoryVisible && profile.showSideHistory {
                            historyCard(maxHeight: profile.sideHistoryHeight)
                                .frame(width: profile.historyWidth)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(profile.outerPadding)
                    .frame(minHeight: max(0, proxy.size.height - (profile.outerPadding * 2)), alignment: .top)
                }
                .scrollDisabled(isHoveringHistoryPanel)
            }
        }
        .background(WindowConfigurator(minSize: NSSize(width: 640, height: 480)))
        .onAppear {
            refreshConversionContext()
            recomputeOutput(animated: false)
        }
        .onChange(of: inputPath) { _ in
            recomputeOutput(animated: true)
        }
        .onChange(of: mappingStore.mappings) { _ in
            refreshConversionContext()
            recomputeOutput(animated: false)
        }
        .onChange(of: mappingStore.sharePointMappings) { _ in
            refreshConversionContext()
            recomputeOutput(animated: false)
        }
        .onChange(of: mappingStore.incomingSharePointURL) { value in
            guard let value, !value.isEmpty else { return }
            let behavior = mappingStore.consumeIncomingBrowserPreferences()
            pendingBrowserOpenFinder = behavior.openFinder
            pendingBrowserCopyOutput = behavior.copyPath
            inputPath = value
            mappingStore.incomingSharePointURL = nil
        }
        .onChange(of: outputPath) { _ in
            scheduleHistoryCommit()
        }
        .onChange(of: isHistoryVisible) { visible in
            if !visible {
                isHoveringHistoryPanel = false
            }
        }
        // Keyboard shortcuts
        .onKeyPress("c", modifiers: .command) {
            if !outputPath.isEmpty {
                copyToPasteboard(outputPath)
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                    self?.didCopy = false
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress("o", modifiers: .command) {
            if canOpenOutputInFinder {
                openConvertedPath()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("s", modifiers: .command) {
            if !outputPath.isEmpty {
                withAnimation(.easeInOut(duration: 0.18)) {
                    inputPath = outputPath
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if !inputPath.isEmpty {
                inputPath = ""
                return .handled
            }
            return .ignored
        }
    }
}

private extension ContentView {
    func refreshConversionContext() {
        conversionContext = PathConverter.makeContext(
            mappings: mappingStore.mappings,
            sharePointMappings: mappingStore.sharePointMappings
        )
    }

    func recomputeOutput(animated: Bool) {
        let converted = PathConverter.convert(inputPath, context: conversionContext)
        if converted != outputPath {
            if animated {
                withAnimation(.easeInOut(duration: 0.16)) {
                    outputPath = converted
                }
            } else {
                outputPath = converted
            }
        }

        handlePendingBrowserActions(using: converted)
    }

    func handlePendingBrowserActions(using converted: String) {
        guard pendingBrowserOpenFinder || pendingBrowserCopyOutput else { return }

        let trimmed = converted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingBrowserOpenFinder = false
            pendingBrowserCopyOutput = false
            mappingStore.browserIntegrationLastEvent = "Browser link received, but no mapping matched this URL."
            return
        }

        var didOpen = false
        var didCopyPath = false

        if pendingBrowserCopyOutput {
            copyToPasteboard(trimmed)
            didCopyPath = true
            didCopy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                self?.didCopy = false
            }
        }

        if pendingBrowserOpenFinder {
            if trimmed.hasPrefix("/") || trimmed.lowercased().hasPrefix("smb://") {
                openPathInFinder(trimmed)
                didOpen = true
            }
        }

        pendingBrowserOpenFinder = false
        pendingBrowserCopyOutput = false

        if didOpen && didCopyPath {
            mappingStore.browserIntegrationLastEvent = "Opened folder in Finder and copied converted path."
        } else if didOpen {
            mappingStore.browserIntegrationLastEvent = "Opened folder in Finder from browser link."
        } else if didCopyPath {
            mappingStore.browserIntegrationLastEvent = "Copied converted path from browser link."
        } else {
            mappingStore.browserIntegrationLastEvent = "Converted browser link, but resulting path could not be opened."
        }
    }

    func scheduleHistoryCommit() {
        historyWorkItem?.cancel()

        let currentInput = inputPath
        let currentOutput = outputPath
        guard !currentOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Capture only what we need to avoid retain cycles
        let work = DispatchWorkItem { [currentInput, currentOutput, weak mappingStore] in
            guard let mappingStore else { return }
            mappingStore.recordHistory(input: currentInput, output: currentOutput)
        }

        historyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func openConvertedPath() {
        guard canOpenOutputInFinder else { return }
        openPathInFinder(outputPath)
    }

    func openPathInFinder(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.lowercased().hasPrefix("smb://") {
            if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
               let url = URL(string: encoded) {
                NSWorkspace.shared.open(url)
            }
            return
        }

        let fileURL = URL(fileURLWithPath: trimmed)
        let fileManager = FileManager.default
        
        // Try to get attributes for better error handling
        do {
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            let isDirectory = attrs[.type] as? FileAttributeType == .typeDirectory
            
            if isDirectory {
                NSWorkspace.shared.open(fileURL)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
            return
        } catch {
            // Path doesn't exist or no permissions - try parent
            if let existingParent = nearestExistingParent(for: fileURL) {
                NSWorkspace.shared.open(existingParent)
            } else {
                // Show error to user
                mappingStore.browserIntegrationLastEvent = "Path not found: \(trimmed)"
            }
        }
    }

    func nearestExistingParent(for url: URL) -> URL? {
        var candidate = url
        let fileManager = FileManager.default

        while candidate.path.count > 1 {
            candidate.deleteLastPathComponent()
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    func copyToPasteboard(_ value: String) {
        guard !value.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    // MARK: - Color Scheme Aware Colors

    var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.10, blue: 0.14),
                Color(red: 0.05, green: 0.07, blue: 0.11)
            ]
        } else {
            return [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.93, green: 0.95, blue: 0.98)
            ]
        }
    }

    var accentGlowColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.32, green: 0.55, blue: 0.96).opacity(0.24)
        } else {
            return Color(red: 0.22, green: 0.56, blue: 0.94).opacity(0.15)
        }
    }

    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.04)
    }

    var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.12)
    }

    var fieldBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    var fieldBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.15)
    }

    var activeFieldBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.25)
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.secondary : Color(white: 0.45)
    }

    var backgroundLayer: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)

            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    accentGlowColor,
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 540
            )
            .blur(radius: 24)

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    func header(profile: LayoutProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.52, green: 0.76, blue: 1.00),
                                    Color(red: 0.24, green: 0.57, blue: 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: Color(red: 0.25, green: 0.60, blue: 0.95).opacity(0.35), radius: 14, x: 0, y: 6)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PathFatter")
                        .font(.system(size: profile.titleSize, weight: .semibold))
                    Text("Instantly translate Windows and macOS paths")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if !profile.isDense {
                    controlsRow
                }
            }

            if profile.isDense {
                controlsRow
            }
        }
    }

    var controlsRow: some View {
        HStack(spacing: 8) {
            SoftTag(text: directionLabel)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHistoryVisible.toggle()
                }
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringHistory, isActive: isHistoryVisible))
            .onHover { isHoveringHistory = $0 }
        }
    }

    @ViewBuilder
    func cards(profile: LayoutProfile) -> some View {
        if profile.isCompact {
            VStack(spacing: profile.gap) {
                inputCard(profile: profile)
                outputCard(profile: profile)
            }
        } else {
            HStack(alignment: .top, spacing: profile.gap) {
                inputCard(profile: profile)
                outputCard(profile: profile)
            }
        }
    }

    func inputCard(profile: LayoutProfile) -> some View {
        FrostedCard(backgroundColor: cardBackgroundColor, borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: 12) {
                Text(sourceTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)

                FrostedField(
                    isActive: isInputFocused,
                    backgroundColor: fieldBackgroundColor,
                    borderColor: isInputFocused ? activeFieldBorderColor : fieldBorderColor
                ) {
                    PathInputEditor(
                        text: $inputPath,
                        height: profile.inputEditorHeight,
                        isFocused: $isInputFocused
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            inputPath = pasted
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringPaste))
                    .onHover { isHoveringPaste = $0 }

                    Button {
                        inputPath = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringClear))
                    .onHover { isHoveringClear = $0 }

                    Spacer()

                    Text("⌘V to paste")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }
            }
        }
    }

    func outputCard(profile: LayoutProfile) -> some View {
        FrostedCard(backgroundColor: cardBackgroundColor, borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(targetTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)

                    Spacer(minLength: 8)

                    Button {
                        if !outputPath.isEmpty {
                            inputPath = outputPath
                        }
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringSwap, isDisabled: outputPath.isEmpty))
                    .disabled(outputPath.isEmpty)
                    .onHover { isHoveringSwap = $0 }
                }

                FrostedField(
                    isActive: false,
                    backgroundColor: fieldBackgroundColor,
                    borderColor: fieldBorderColor
                ) {
                    PathOutputField(
                        text: outputPath,
                        height: profile.outputEditorHeight
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        guard !outputPath.isEmpty else { return }
                        copyToPasteboard(outputPath)
                        didCopy = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                            self?.didCopy = false
                        }
                    } label: {
                        Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                    .buttonStyle(GlowPrimaryButtonStyle(isHovering: isHoveringCopy, isDisabled: outputPath.isEmpty))
                    .disabled(outputPath.isEmpty)
                    .onHover { isHoveringCopy = $0 }

                    Button {
                        openConvertedPath()
                    } label: {
                        Label("Open in Finder", systemImage: "folder")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringOpen, isDisabled: !canOpenOutputInFinder))
                    .disabled(!canOpenOutputInFinder)
                    .onHover { isHoveringOpen = $0 }

                    Spacer()
                }

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
        }
    }

    var footerRow: some View {
        HStack {
            Spacer()
            Text("Settings ⌘,")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
    }

    func historyCard(maxHeight: CGFloat) -> some View {
        FrostedCard(backgroundColor: cardBackgroundColor, borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isHistoryVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }

                if mappingStore.history.isEmpty {
                    Text("No recent conversions yet.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(mappingStore.history) { item in
                                HistoryRow(
                                    item: item,
                                    onCopy: { copyToPasteboard(item.output) },
                                    onOpen: { openPathInFinder(item.output) }
                                )

                                if item.id != mappingStore.history.last?.id {
                                    Divider().overlay(Color.white.opacity(colorScheme == .dark ? 0.07 : 0.15))
                                }
                            }
                        }
                    }
                    .frame(minHeight: min(160, maxHeight), maxHeight: maxHeight)
                }
            }
        }
        .onHover { isHoveringHistoryPanel = $0 }
    }
}

private struct LayoutProfile {
    let size: CGSize

    var isShort: Bool { size.height < 700 }
    var isVeryShort: Bool { size.height < 500 }

    var isCompact: Bool { size.width < 700 }
    var isDense: Bool { size.width < 580 || size.height < 500 }
    var showSideHistory: Bool { size.width >= 1100 && size.height >= 650 }

    var outerPadding: CGFloat {
        if isDense { return 12 }
        let base = max(12, min(24, size.width * 0.025))
        return isVeryShort ? max(10, base - 2) : base
    }

    var gap: CGFloat {
        if isDense { return 10 }
        let base = max(10, min(16, size.width * 0.014))
        return isVeryShort ? max(8, base - 2) : base
    }

    var historyWidth: CGFloat {
        min(max(size.width * 0.26, 270), 340)
    }

    var inlineHistoryHeight: CGFloat {
        let target = size.height * 0.34
        if isVeryShort { return 160 }
        return max(180, min(280, target))
    }

    var sideHistoryHeight: CGFloat {
        let target = size.height * 0.58
        if isVeryShort { return 200 }
        return max(220, min(420, target))
    }

    var inputEditorHeight: CGFloat {
        if isDense { return 72 }
        if isVeryShort { return 68 }
        return 88
    }

    var outputEditorHeight: CGFloat {
        if isDense { return 66 }
        if isVeryShort { return 62 }
        return 82
    }

    var titleSize: CGFloat {
        if isVeryShort { return 26 }
        if isDense { return 30 }
        return 38
    }
}

private struct PathInputEditor: View {
    @Binding var text: String
    var height: CGFloat
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .focused(isFocused)
                .scrollContentBackground(.hidden)
                .padding(.leading, -4)
                .padding(.top, -3)
                .frame(minHeight: height, maxHeight: height)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Paste a path…")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.top, 6)
                    .padding(.leading, 2)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct PathOutputField: View {
    var text: String
    var height: CGFloat

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "—" : text)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.vertical, 1)
        }
        .frame(minHeight: height, maxHeight: height)
    }
}

private struct HistoryRow: View {
    var item: HistoryItem
    var onCopy: () -> Void
    var onOpen: () -> Void

    @State private var isHoveringAction = false

    private var compactLabel: String {
        let trimmed = item.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }

        let isSMB = trimmed.lowercased().hasPrefix("smb://")
        let normalized = trimmed
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "smb://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var parts = normalized
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        if isSMB && parts.count > 2 {
            parts.removeFirst(2)
        }

        if let first = parts.first, first.hasSuffix(":") {
            parts.removeFirst()
        }

        guard !parts.isEmpty else { return trimmed }
        if parts.count == 1 { return parts[0] }
        return "\(parts[parts.count - 2]) / \(parts[parts.count - 1])"
    }

    private var actionIcon: String {
        item.canOpen ? "folder" : "doc.on.doc"
    }

    private var actionHint: String {
        item.canOpen ? "Open in Finder" : "Copy path"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(compactLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button {
                if item.canOpen {
                    onOpen()
                } else {
                    onCopy()
                }
            } label: {
                Image(systemName: actionIcon)
            }
            .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringAction))
            .onHover { isHoveringAction = $0 }
            .help(actionHint)
        }
    }
}

private struct FrostedCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color
    var borderColor: Color

    init(backgroundColor: Color, borderColor: Color, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundColor)
                .background(
                    VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }
}

private struct FrostedField<Content: View>: View {
    var isActive: Bool
    let content: Content
    var backgroundColor: Color
    var borderColor: Color

    init(isActive: Bool, backgroundColor: Color, borderColor: Color, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.content = content()
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }

    var body: some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color(red: 0.28, green: 0.58, blue: 0.94).opacity(isActive ? 0.20 : 0.05), radius: isActive ? 14 : 6, x: 0, y: 6)
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

private struct SoftTag: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .withinWindow)
                            .clipShape(Capsule())
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            )
    }
}

private struct GlowPrimaryButtonStyle: ButtonStyle {
    var isHovering: Bool
    var isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isDisabled ? Color.white.opacity(0.55) : Color.white)
            .padding(.vertical, 9)
            .padding(.horizontal, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.40, green: 0.74, blue: 1.00),
                                Color(red: 0.22, green: 0.56, blue: 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(isDisabled ? 0.32 : 1.0)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isDisabled ? 0.12 : 0.5), lineWidth: 1)
                    )
            )
            .shadow(color: Color(red: 0.32, green: 0.66, blue: 0.98).opacity(isDisabled ? 0 : (isHovering ? 0.48 : 0.28)), radius: isHovering ? 18 : 12, x: 0, y: 8)
            .scaleEffect(pressed ? 0.98 : (isHovering && !isDisabled ? 1.01 : 1.0))
            .opacity(isDisabled ? 0.5 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.16), value: isHovering)
    }
}

private struct QuietPillButtonStyle: ButtonStyle {
    var isHovering: Bool
    var isActive: Bool = false
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isDisabled ? Color.white.opacity(0.45) : Color.white.opacity(0.9))
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isDisabled ? 0.05 : (isActive ? 0.22 : (isHovering ? 0.18 : 0.11))))
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .withinWindow)
                            .clipShape(Capsule())
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isDisabled ? 0.08 : 0.20), lineWidth: 1)
                    )
            )
            .scaleEffect(pressed ? 0.985 : (isHovering && !isDisabled ? 1.015 : 1.0))
            .opacity(isDisabled ? 0.45 : 1.0)
            .animation(.easeOut(duration: 0.11), value: pressed)
            .animation(.easeOut(duration: 0.14), value: isHovering)
    }
}

private struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.styleMask.insert(.fullSizeContentView)
            window.minSize = minSize
            window.contentMinSize = minSize

            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            guard let container = window.contentView?.superview else { return }

            let offsetX: CGFloat = 16
            let offsetY: CGFloat = 12

            for (index, type) in buttons.enumerated() {
                guard let button = window.standardWindowButton(type) else { continue }
                button.isHidden = false
                button.translatesAutoresizingMaskIntoConstraints = false

                let x = offsetX + CGFloat(index) * 22
                let topID = "pf.titlebar.top.\(type.rawValue)"
                let leadingID = "pf.titlebar.leading.\(type.rawValue)"

                if !container.constraints.contains(where: { $0.identifier == topID || $0.identifier == leadingID }) {
                    let topConstraint = button.topAnchor.constraint(equalTo: container.topAnchor, constant: offsetY)
                    topConstraint.identifier = topID

                    let leadingConstraint = button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: x)
                    leadingConstraint.identifier = leadingID

                    NSLayoutConstraint.activate([topConstraint, leadingConstraint])
                }
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
