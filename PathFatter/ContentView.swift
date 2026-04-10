import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var mappingStore: PathMappingStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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
    @State private var showConversionFlash = false
    @State private var cardScale: CGFloat = 1.0
    @State private var backgroundOrbOffset: CGSize = .zero

    @FocusState private var isInputFocused: Bool
    @FocusState private var isOutputFocused: Bool

    @State private var hoveredHistoryItem: UUID?
    @State private var selectedHistoryItem: UUID?
    @State private var historySearchQuery = ""

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
        case .empty: return "Input Path"
        case .windows: return "Windows Path"
        case .sharePoint: return "SharePoint URL"
        case .mac: return "macOS Path"
        }
    }

    private var targetTitle: String {
        switch inputKind {
        case .empty: return "Output Path"
        case .windows, .sharePoint: return "macOS Path"
        case .mac: return "Windows Path"
        }
    }

    private var directionLabel: String {
        switch inputKind {
        case .empty: return "Ready"
        case .windows: return "Windows → macOS"
        case .sharePoint: return "SharePoint → macOS"
        case .mac: return "macOS → Windows"
        }
    }

    private var statusText: String {
        if outputPath.isEmpty {
            if inputKind == .sharePoint {
                return "Add a SharePoint mapping in Settings"
            }
            return trimmedInput.isEmpty ? "Paste a path to convert" : "No conversion available"
        }
        return "Conversion complete"
    }

    private var canOpenOutputInFinder: Bool {
        let trimmed = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("/") || trimmed.lowercased().hasPrefix("smb://")
    }

    // MARK: - Dynamic Accent Color (Time-Based)

    var dynamicAccentColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            return Color(red: 0.45, green: 0.72, blue: 0.98)  // Warm morning blue
        case 12..<18:
            return Color(red: 0.22, green: 0.56, blue: 0.94)  // Standard blue
        case 18..<24:
            return Color(red: 0.35, green: 0.52, blue: 0.95)  // Evening purple-blue
        default:
            return Color(red: 0.28, green: 0.42, blue: 0.88)  // Night indigo
        }
    }

    var accentGlowColor: Color {
        dynamicAccentColor.opacity(colorScheme == .dark ? 0.24 : 0.15)
    }

    // MARK: - Color Scheme Aware Colors

    var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.06, green: 0.08, blue: 0.12),
                Color(red: 0.04, green: 0.06, blue: 0.10)
            ]
        } else {
            return [
                Color(red: 0.97, green: 0.98, blue: 0.995),
                Color(red: 0.94, green: 0.96, blue: 0.99)
            ]
        }
    }

    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }

    var cardInnerShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05)
    }

    var fieldBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    var fieldBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
    }

    var activeFieldBorderColor: Color {
        dynamicAccentColor.opacity(colorScheme == .dark ? 0.5 : 0.4)
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.secondary : Color(white: 0.45)
    }

    var body: some View {
        GeometryReader { proxy in
            let profile = LayoutProfile(size: proxy.size, dynamicTypeSize: dynamicTypeSize)

            ZStack {
                // Animated background with gradient orbs
                backgroundLayer
                    .accessibilityHidden(true)
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
            startBackgroundAnimation()
        }
        // Drag and drop support
        .onDrop(of: [.fileURL, .URL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onChange(of: inputPath) { _, _ in
            recomputeOutput(animated: true)
        }
        .onChange(of: mappingStore.mappings) { _, _ in
            refreshConversionContext()
            recomputeOutput(animated: false)
        }
        .onChange(of: mappingStore.sharePointMappings) { _, _ in
            refreshConversionContext()
            recomputeOutput(animated: false)
        }
        .onChange(of: mappingStore.incomingSharePointURL) { _, newValue in
            guard let value = newValue, !value.isEmpty else { return }
            let behavior = mappingStore.consumeIncomingBrowserPreferences()
            pendingBrowserOpenFinder = behavior.openFinder
            pendingBrowserCopyOutput = behavior.copyPath
            inputPath = value
            mappingStore.incomingSharePointURL = nil
        }
        .onChange(of: outputPath) { _, _ in
            scheduleHistoryCommit()
        }
        .onChange(of: isHistoryVisible) { _, newValue in
            if !newValue {
                isHoveringHistoryPanel = false
            }
        }
        // Keyboard shortcuts
        .onKeyPress("c", modifiers: .command) {
            if !outputPath.isEmpty {
                copyToPasteboard(outputPath)
                triggerCopySuccess()
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        .onKeyPress(.downArrow) {
            navigateHistory(direction: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigateHistory(direction: -1)
            return .handled
        }
        .onKeyPress(.return) {
            if let selected = selectedHistoryItem,
               let item = mappingStore.history.first(where: { $0.id == selected }) {
                copyToPasteboard(item.output)
                triggerCopySuccess()
            }
            return .handled
        }
    }

    // MARK: - Background Animation

    private func startBackgroundAnimation() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            backgroundOrbOffset = CGSize(width: 100, height: 100)
        }
    }

    // MARK: - Conversion Logic

    private func refreshConversionContext() {
        conversionContext = PathConverter.makeContext(
            mappings: mappingStore.mappings,
            sharePointMappings: mappingStore.sharePointMappings
        )
    }

    private func recomputeOutput(animated: Bool) {
        let converted = PathConverter.convert(inputPath, context: conversionContext)
        if converted != outputPath {
            if animated {
                withAnimation(.easeInOut(duration: 0.16)) {
                    outputPath = converted
                }
            } else {
                outputPath = converted
            }

            // Trigger conversion flash animation
            if !converted.isEmpty && animated {
                triggerConversionFlash()
            }
        }

        handlePendingBrowserActions(using: converted)
    }

    private func triggerConversionFlash() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 0.4)) {
            showConversionFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConversionFlash = false
            }
        }
    }

    private func triggerCopySuccess() {
        didCopy = true
        guard !reduceMotion else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            cardScale = 1.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardScale = 1.0
            }
        }
    }

    private func handlePendingBrowserActions(using converted: String) {
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
            triggerCopySuccess()
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

    private func scheduleHistoryCommit() {
        historyWorkItem?.cancel()

        let currentInput = inputPath
        let currentOutput = outputPath
        guard !currentOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let work = DispatchWorkItem { [currentInput, currentOutput, weak mappingStore] in
            guard let mappingStore else { return }
            mappingStore.recordHistory(input: currentInput, output: currentOutput)
        }

        historyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func openConvertedPath() {
        guard canOpenOutputInFinder else { return }
        openPathInFinder(outputPath)
    }

    private func openPathInFinder(_ path: String) {
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

        do {
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            let isDirectory = attrs[.type] as? FileAttributeType == .typeDirectory

            if isDirectory {
                NSWorkspace.shared.open(fileURL)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
        } catch {
            if let existingParent = nearestExistingParent(for: fileURL) {
                NSWorkspace.shared.open(existingParent)
            } else {
                mappingStore.browserIntegrationLastEvent = "Path not found: \(trimmed)"
            }
        }
    }

    private func nearestExistingParent(for url: URL) -> URL? {
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

    private func copyToPasteboard(_ value: String) {
        guard !value.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func navigateHistory(direction: Int) {
        guard !mappingStore.history.isEmpty else { return }

        let filteredHistory = filteredHistoryItems
        guard !filteredHistory.isEmpty else { return }

        if let currentIndex = filteredHistory.firstIndex(where: { $0.id == selectedHistoryItem }) {
            let newIndex = currentIndex + direction
            if newIndex >= 0 && newIndex < filteredHistory.count {
                selectedHistoryItem = filteredHistory[newIndex].id
            }
        } else {
            selectedHistoryItem = direction > 0 ? filteredHistory.first?.id : filteredHistory.last?.id
        }
    }

    private var filteredHistoryItems: [HistoryItem] {
        if historySearchQuery.isEmpty {
            return mappingStore.history
        }
        let query = historySearchQuery.lowercased()
        return mappingStore.history.filter {
            $0.input.lowercased().contains(query) || $0.output.lowercased().contains(query)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    DispatchQueue.main.async {
                        if let url = url {
                            inputPath = url.path
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    // MARK: - History Grouping

    enum HistoryGroup: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "This Week"
        case older = "Older"

        static func group(for date: Date) -> HistoryGroup {
            let calendar = Calendar.current
            let now = Date()

            if calendar.isDateInToday(date) {
                return .today
            } else if calendar.isDateInYesterday(date) {
                return .yesterday
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                return .thisWeek
            } else {
                return .older
            }
        }
    }

    private var groupedHistory: [HistoryGroup: [HistoryItem]] {
        var groups: [HistoryGroup: [HistoryItem]] = [:]
        
        // First, add pinned items to a special "Pinned" section (we'll handle this separately)
        // Then group remaining items by date
        let nonPinnedItems = filteredHistoryItems.filter { !mappingStore.pinnedHistoryIds.contains($0.id) }
        
        for item in nonPinnedItems {
            let group = HistoryGroup.group(for: item.timestamp)
            groups[group, default: []].append(item)
        }
        
        return groups
    }

    private var hasPinnedItems: Bool {
        !mappingStore.pinnedHistory.isEmpty
    }
}

// MARK: - Background Layer

private extension ContentView {
    var backgroundLayer: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)

            // Base gradient
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated gradient orb 1 (top trailing)
            RadialGradient(
                colors: [
                    accentGlowColor,
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 540
            )
            .offset(backgroundOrbOffset)
            .blur(radius: 24)

            // Animated gradient orb 2 (bottom leading)
            RadialGradient(
                colors: [
                    dynamicAccentColor.opacity(colorScheme == .dark ? 0.15 : 0.08),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 400
            )
            .offset(CGSize(width: -backgroundOrbOffset.width * 0.5, height: -backgroundOrbOffset.height * 0.5))
            .blur(radius: 32)

            // Subtle noise/gradient overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Header

private extension ContentView {
    func header(profile: LayoutProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                // App icon with gradient and glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    dynamicAccentColor.opacity(0.9),
                                    dynamicAccentColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: dynamicAccentColor.opacity(0.4), radius: 16, x: 0, y: 8)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isHoveringHistory ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringHistory)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PathFatter")
                        .font(.system(size: profile.titleSize, weight: .bold, design: .rounded))
                        .foregroundColor(
                            LinearGradient(
                                colors: [
                                    dynamicAccentColor,
                                    dynamicAccentColor.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(-0.5)

                    Text("Instantly translate Windows and macOS paths")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(secondaryTextColor)
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
        HStack(spacing: 10) {
            SoftTag(text: directionLabel, accentColor: dynamicAccentColor)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isHistoryVisible.toggle()
                }
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringHistory, isActive: isHistoryVisible, accentColor: dynamicAccentColor))
            .onHover { isHoveringHistory = $0 }
        }
    }
}

// MARK: - Cards

private extension ContentView {
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
        EnhancedFrostedCard(
            backgroundColor: cardBackgroundColor,
            borderColor: cardBorderColor,
            innerShadowColor: cardInnerShadowColor,
            accentColor: dynamicAccentColor,
            isHovering: isHoveringPaste || isHoveringClear,
            scale: cardScale
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(sourceTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(secondaryTextColor)
                    .accessibilityLabel(sourceTitle)

                FloatingLabelField(
                    text: $inputPath,
                    placeholder: "Paste a Windows or SharePoint path…",
                    isActive: isInputFocused,
                    accentColor: dynamicAccentColor,
                    backgroundColor: fieldBackgroundColor,
                    borderColor: isInputFocused ? activeFieldBorderColor : fieldBorderColor,
                    height: profile.inputEditorHeight,
                    isFocused: $isInputFocused,
                    showSyntaxHighlighting: false
                )
                .accessibilityLabel("Input path")
                .accessibilityHint("Paste or type a Windows or SharePoint path to convert")

                HStack(spacing: 8) {
                    Button {
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            inputPath = pasted
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringPaste, accentColor: dynamicAccentColor))
                    .onHover { isHoveringPaste = $0 }
                    .accessibilityLabel("Paste from clipboard")
                    .accessibilityHint("Command V")

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            inputPath = ""
                        }
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringClear, accentColor: dynamicAccentColor))
                    .onHover { isHoveringClear = $0 }
                    .accessibilityLabel("Clear input")
                    .accessibilityHint("Escape")

                    Spacer()

                    Text("⌘V to paste")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    func outputCard(profile: LayoutProfile) -> some View {
        EnhancedFrostedCard(
            backgroundColor: cardBackgroundColor,
            borderColor: cardBorderColor,
            innerShadowColor: cardInnerShadowColor,
            accentColor: dynamicAccentColor,
            isHovering: isHoveringCopy || isHoveringOpen || isHoveringSwap,
            scale: cardScale,
            showFlash: showConversionFlash
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(targetTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                        .accessibilityLabel(targetTitle)

                    Spacer(minLength: 8)

                    Button {
                        if !outputPath.isEmpty {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                inputPath = outputPath
                            }
                        }
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringSwap, isDisabled: outputPath.isEmpty, accentColor: dynamicAccentColor))
                    .disabled(outputPath.isEmpty)
                    .onHover { isHoveringSwap = $0 }
                    .accessibilityLabel("Swap input and output")
                    .accessibilityHint("Command S")
                }

                FloatingLabelField(
                    text: .constant(outputPath),
                    placeholder: "Converted path appears here…",
                    isActive: isOutputFocused,
                    accentColor: dynamicAccentColor,
                    backgroundColor: fieldBackgroundColor,
                    borderColor: fieldBorderColor,
                    height: profile.outputEditorHeight,
                    isFocused: $isOutputFocused,
                    showSyntaxHighlighting: true,
                    isReadOnly: true
                )
                .accessibilityLabel("Output path")
                .accessibilityHint(outputPath.isEmpty ? "Converted path will appear here" : "Converted \(inputKind == .mac ? "Windows" : "macOS") path")

                HStack(spacing: 8) {
                    Button {
                        guard !outputPath.isEmpty else { return }
                        copyToPasteboard(outputPath)
                        triggerCopySuccess()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(didCopy ? "Copied" : "Copy")
                        }
                    }
                    .buttonStyle(GlowPrimaryButtonStyle(isHovering: isHoveringCopy, isDisabled: outputPath.isEmpty, accentColor: dynamicAccentColor))
                    .disabled(outputPath.isEmpty)
                    .onHover { isHoveringCopy = $0 }
                    .accessibilityLabel(didCopy ? "Copied to clipboard" : "Copy to clipboard")
                    .accessibilityHint("Command C")

                    Button {
                        openConvertedPath()
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                    .buttonStyle(QuietPillButtonStyle(isHovering: isHoveringOpen, isDisabled: !canOpenOutputInFinder, accentColor: dynamicAccentColor))
                    .disabled(!canOpenOutputInFinder)
                    .onHover { isHoveringOpen = $0 }
                    .accessibilityLabel("Open in Finder")
                    .accessibilityHint("Command O")

                    Spacer()
                }

                HStack {
                    Image(systemName: showConversionFlash ? "checkmark.circle.fill" : "info.circle")
                        .foregroundColor(showConversionFlash ? .green : secondaryTextColor)
                        .scaleEffect(showConversionFlash ? 1.2 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: showConversionFlash)
                        .accessibilityHidden(true)

                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(showConversionFlash ? .green : secondaryTextColor)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.2), value: showConversionFlash)
                }
            }
        }
    }

    var footerRow: some View {
        HStack {
            Spacer()
            Text("Settings ⌘,")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(secondaryTextColor)
        }
    }
}

// MARK: - History Card

private extension ContentView {
    func historyCard(maxHeight: CGFloat) -> some View {
        EnhancedFrostedCard(
            backgroundColor: cardBackgroundColor,
            borderColor: cardBorderColor,
            innerShadowColor: cardInnerShadowColor,
            accentColor: dynamicAccentColor,
            isHovering: isHoveringHistoryPanel,
            scale: 1.0
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isHistoryVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(secondaryTextColor)
                        .font(.system(size: 11))

                    TextField("Search history…", text: $historySearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !historySearchQuery.isEmpty {
                        Button {
                            historySearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(secondaryTextColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fieldBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorderColor, lineWidth: 1)
                )

                if filteredHistoryItems.isEmpty {
                    emptyHistoryView
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            // Pinned items section
                            if hasPinnedItems {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Pinned")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(secondaryTextColor)
                                            .textCase(.uppercase)
                                            .tracking(0.5)

                                        Spacer()

                                        Text("\(mappingStore.pinnedHistory.count)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(dynamicAccentColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(dynamicAccentColor.opacity(0.15))
                                            )
                                    }

                                    LazyVStack(spacing: 6) {
                                        ForEach(mappingStore.pinnedHistory) { item in
                                            HistoryRow(
                                                item: item,
                                                isSelected: selectedHistoryItem == item.id,
                                                isHovered: hoveredHistoryItem == item.id,
                                                onHover: { hoveredHistoryItem = $0 ? item.id : nil },
                                                onSelect: { selectedHistoryItem = item.id },
                                                onCopy: {
                                                    copyToPasteboard(item.output)
                                                    triggerCopySuccess()
                                                },
                                                onOpen: { openPathInFinder(item.output) },
                                                accentColor: dynamicAccentColor,
                                                colorScheme: colorScheme
                                            )
                                        }
                                    }
                                }
                            }

                            // Date-grouped items
                            ForEach(HistoryGroup.allCases, id: \.self) { group in
                                if let items = groupedHistory[group], !items.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(group.rawValue)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(secondaryTextColor)
                                            .textCase(.uppercase)
                                            .tracking(0.5)

                                        LazyVStack(spacing: 6) {
                                            ForEach(items) { item in
                                                HistoryRow(
                                                    item: item,
                                                    isSelected: selectedHistoryItem == item.id,
                                                    isHovered: hoveredHistoryItem == item.id,
                                                    onHover: { hoveredHistoryItem = $0 ? item.id : nil },
                                                    onSelect: { selectedHistoryItem = item.id },
                                                    onCopy: {
                                                        copyToPasteboard(item.output)
                                                        triggerCopySuccess()
                                                    },
                                                    onOpen: { openPathInFinder(item.output) },
                                                    accentColor: dynamicAccentColor,
                                                    colorScheme: colorScheme
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: min(160, maxHeight), maxHeight: maxHeight)
                }
            }
        }
        .onHover { isHoveringHistoryPanel = $0 }
    }

    @ViewBuilder
    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(dynamicAccentColor.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: historySearchQuery.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(dynamicAccentColor)
            }

            VStack(spacing: 4) {
                Text(historySearchQuery.isEmpty ? "No conversions yet" : "No matches found")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.primary : Color(white: 0.3))

                Text(historySearchQuery.isEmpty ? "Paste a path to get started" : "Try a different search term")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }

            if historySearchQuery.isEmpty {
                Button {
                    if let pasted = NSPasteboard.general.string(forType: .string) {
                        inputPath = pasted
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(GlowPrimaryButtonStyle(isHovering: false, isDisabled: false, accentColor: dynamicAccentColor))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Layout Profile

private struct LayoutProfile {
    let size: CGSize
    let dynamicTypeSize: DynamicTypeSize

    var isShort: Bool { size.height < 700 }
    var isVeryShort: Bool { size.height < 500 }

    var isCompact: Bool { size.width < 700 }
    var isDense: Bool { size.width < 580 || size.height < 500 }
    var showSideHistory: Bool { size.width >= 1100 && size.height >= 650 }

    var outerPadding: CGFloat {
        if isDense { return 12 }
        return min(24, size.width * 0.025)
    }

    var gap: CGFloat {
        if isDense { return 10 }
        return min(16, size.width * 0.014)
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
        if isDense { return 76 }
        if isVeryShort { return 72 }
        return 92
    }

    var outputEditorHeight: CGFloat {
        if isDense { return 70 }
        if isVeryShort { return 66 }
        return 86
    }

    var titleSize: CGFloat {
        if isVeryShort { return 28 }
        if isDense { return 32 }
        return 42
    }
}

// MARK: - Enhanced Components

private struct EnhancedFrostedCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color
    var borderColor: Color
    var innerShadowColor: Color
    var accentColor: Color
    var isHovering: Bool
    var scale: CGFloat
    var showFlash: Bool = false

    init(
        backgroundColor: Color,
        borderColor: Color,
        innerShadowColor: Color,
        accentColor: Color,
        isHovering: Bool,
        scale: CGFloat = 1.0,
        showFlash: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.innerShadowColor = innerShadowColor
        self.accentColor = accentColor
        self.isHovering = isHovering
        self.scale = scale
        self.showFlash = showFlash
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    backgroundColor.opacity(0.8),
                                    backgroundColor.opacity(0.4)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background(
                            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            borderColor.opacity(0.5),
                                            borderColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            innerShadowColor.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .blur(radius: 2)
                        )
                        .overlay(
                            Group {
                                if showFlash {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(accentColor.opacity(0.6), lineWidth: 2)
                                        .shadow(color: accentColor.opacity(0.4), radius: 12)
                                }
                            }
                        )
                }
            )
            .shadow(color: accentColor.opacity(isHovering ? 0.2 : 0.1), radius: isHovering ? 24 : 16, x: 0, y: 12)
            .scaleEffect(scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

private struct FloatingLabelField: View {
    @Binding var text: String
    var placeholder: String
    var isActive: Bool
    var accentColor: Color
    var backgroundColor: Color
    var borderColor: Color
    var height: CGFloat
    var isFocused: FocusState<Bool>.Binding
    var showSyntaxHighlighting: Bool
    var isReadOnly: Bool = false

    private var isFloating: Bool {
        !text.isEmpty || isActive
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showSyntaxHighlighting && !text.isEmpty {
                SyntaxHighlightedPathText(path: text, height: height, accentColor: accentColor)
            }

            TextEditor(text: $text)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.primary)
                .focused(isFocused)
                .scrollContentBackground(.hidden)
                .padding(.top, isFloating ? 14 : 2)
                .padding(.leading, 4)
                .frame(minHeight: height, maxHeight: height)
                .disabled(isReadOnly)

            Text(placeholder)
                .font(.system(size: isActive ? 11 : 14, weight: isActive ? .medium : .regular, design: .monospaced))
                .foregroundColor(isActive ? accentColor.opacity(0.8) : .secondary.opacity(0.7))
                .padding(.top, isFloating ? 2 : 6)
                .padding(.leading, 6)
                .allowsHitTesting(false)
                .offset(y: isFloating ? -4 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFloating)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
                .background(
                    VisualEffectView(material: .menu, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1.2)
        )
        .shadow(color: accentColor.opacity(isActive ? 0.25 : 0.05), radius: isActive ? 16 : 8, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

private struct SyntaxHighlightedPathText: View {
    var path: String
    var height: CGFloat
    var accentColor: Color

    var body: some View {
        ScrollView {
            highlightedText
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .padding(.top, 2)
                .padding(.leading, 4)
                .frame(minHeight: height, maxHeight: height)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var highlightedText: some View {
        if path.hasPrefix("smb://") {
            // SMB path highlighting
            let components = path.split(separator: "/", maxSplits: 3, omittingEmptySubsequences: true)
            if components.count >= 3 {
                Text("smb://")
                    .foregroundColor(Color.secondary)
                + Text(String(components[1]))
                    .foregroundColor(accentColor)
                + Text("/")
                    .foregroundColor(Color.secondary)
                + Text(components.count > 2 ? String(components[2]) : "")
                    .foregroundColor(Color.primary)
            } else {
                Text(path)
                    .foregroundColor(Color.primary)
            }
        } else if path.hasPrefix("/") {
            // macOS path
            let components = path.split(separator: "/")
            if !components.isEmpty {
                Text("/")
                    .foregroundColor(Color.secondary)
                + Text(components.first.map(String.init) ?? "")
                    .foregroundColor(accentColor)
                + Text(components.dropFirst().prefix(2).map { "/" + $0 }.joined())
                    .foregroundColor(Color.primary)
                if components.count > 3 {
                    Text("…")
                        .foregroundColor(Color.secondary)
                }
            }
        } else {
            // Windows path
            if path.count >= 2 && path[path.startIndex].isASCII && path[path.index(after: path.startIndex)] == ":" {
                let drive = String(path.prefix(2))
                let remainder = String(path.dropFirst(2))
                Text(drive)
                    .foregroundColor(accentColor)
                + Text(remainder.prefix(30))
                    .foregroundColor(Color.primary)
                if remainder.count > 30 {
                    Text("…")
                        .foregroundColor(Color.secondary)
                }
            } else {
                Text(path)
                    .foregroundColor(Color.primary)
            }
        }
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var mappingStore: PathMappingStore
    var item: HistoryItem
    var isSelected: Bool
    var isHovered: Bool
    var onHover: (Bool) -> Void
    var onSelect: () -> Void
    var onCopy: () -> Void
    var onOpen: () -> Void
    var accentColor: Color
    var colorScheme: ColorScheme

    @State private var actionHover = false

    private var isPinned: Bool {
        mappingStore.pinnedHistoryIds.contains(item.id)
    }

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

    var body: some View {
        HStack(spacing: 10) {
            // Icon based on path type
            Image(systemName: iconForPath(item.output))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : accentColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isSelected ? accentColor : accentColor.opacity(0.15))
                )

            Text(compactLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? Color.primary : Color(white: 0.2)))

            Spacer(minLength: 8)

            if isHovered || isSelected || isPinned {
                HStack(spacing: 6) {
                    // Pin button
                    Button {
                        mappingStore.togglePinned(item.id)
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                    }
                    .buttonStyle(HistoryActionButtonStyle(isHovering: actionHover, accentColor: accentColor))
                    .foregroundColor(isPinned ? accentColor : (colorScheme == .dark ? Color.primary : Color(white: 0.4)))
                    .onHover { actionHover = $0 }
                    .help(isPinned ? "Unpin" : "Pin to top")

                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(HistoryActionButtonStyle(isHovering: actionHover, accentColor: accentColor))
                    .onHover { actionHover = $0 }
                    .help("Copy path")

                    if item.canOpen {
                        Button {
                            onOpen()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(HistoryActionButtonStyle(isHovering: actionHover, accentColor: accentColor))
                        .help("Open in Finder")
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected ? accentColor :
                    isHovered ? accentColor.opacity(0.12) : Color.clear
                )
        )
        .onHover { onHover($0) }
        .onTapGesture { onSelect() }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func iconForPath(_ path: String) -> String {
        if path.lowercased().hasPrefix("smb://") {
            return "network"
        } else if path.hasPrefix("/") {
            return "folder"
        } else {
            return "externaldrive"
        }
    }
}

private struct HistoryActionButtonStyle: ButtonStyle {
    var isHovering: Bool
    var accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isHovering ? .white : accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isHovering ? accentColor : accentColor.opacity(0.15))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Styles

private struct GlowPrimaryButtonStyle: ButtonStyle {
    var isHovering: Bool
    var isDisabled: Bool
    var accentColor: Color

    init(isHovering: Bool = false, isDisabled: Bool = false, accentColor: Color = .blue) {
        self.isHovering = isHovering
        self.isDisabled = isDisabled
        self.accentColor = accentColor
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isDisabled ? Color.white.opacity(0.55) : Color.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.9),
                                accentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(isDisabled ? 0.32 : 1.0)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isDisabled ? 0.12 : 0.4), lineWidth: 1)
                    )
            )
            .shadow(color: accentColor.opacity(isDisabled ? 0 : (isHovering ? 0.5 : 0.3)), radius: isHovering ? 20 : 14, x: 0, y: 10)
            .scaleEffect(pressed ? 0.97 : (isHovering && !isDisabled ? 1.02 : 1.0))
            .opacity(isDisabled ? 0.5 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }
}

private struct QuietPillButtonStyle: ButtonStyle {
    var isHovering: Bool
    var isActive: Bool
    var isDisabled: Bool
    var accentColor: Color

    init(isHovering: Bool = false, isActive: Bool = false, isDisabled: Bool = false, accentColor: Color = .blue) {
        self.isHovering = isHovering
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.accentColor = accentColor
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isDisabled ? Color.white.opacity(0.45) : (isActive ? .white : Color.white.opacity(0.9)))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(
                        isActive ? accentColor :
                        isDisabled ? Color.white.opacity(0.05) :
                        isHovering ? accentColor.opacity(0.2) :
                        Color.white.opacity(0.1)
                    )
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .withinWindow)
                            .clipShape(Capsule())
                    )
                    .overlay(
                        Capsule()
                            .stroke(isActive ? Color.clear : Color.white.opacity(isDisabled ? 0.08 : 0.18), lineWidth: 1)
                    )
            )
            .scaleEffect(pressed ? 0.98 : (isHovering && !isDisabled ? 1.03 : 1.0))
            .opacity(isDisabled ? 0.45 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: pressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }
}

private struct SoftTag: View {
    var text: String
    var accentColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.9),
                                accentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .withinWindow)
                            .clipShape(Capsule())
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Helper Views

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
