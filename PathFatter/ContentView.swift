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

    @State private var hoveredHistoryItem: UUID?
    @State private var selectedHistoryItem: UUID?
    @State private var historySearchQuery = ""

    var sourceTitle: String {
        "Windows / SharePoint Path"
    }

    var targetTitle: String {
        "macOS Path"
    }

    var statusText: String {
        if outputPath.isEmpty {
            return "Ready to convert"
        }
        if showConversionFlash {
            return "Conversion successful"
        }
        return "Converted"
    }

    var canOpenOutputInFinder: Bool {
        guard !outputPath.isEmpty else { return false }
        let trimmed = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed)
    }

    var dynamicAccentColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 12 {
            return Color(red: 0.45, green: 0.72, blue: 0.98)
        } else if hour >= 12 && hour < 18 {
            return Color(red: 0.22, green: 0.56, blue: 0.94)
        } else if hour >= 18 && hour < 24 {
            return Color(red: 0.35, green: 0.52, blue: 0.95)
        } else {
            return Color(red: 0.28, green: 0.42, blue: 0.88)
        }
    }

    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15).opacity(0.7) : Color(white: 0.95).opacity(0.8)
    }

    var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }

    var cardInnerShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5)
    }

    var fieldBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.98)
    }

    var fieldBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    var activeFieldBorderColor: Color {
        dynamicAccentColor.opacity(colorScheme == .dark ? 0.5 : 0.4)
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.secondary : Color(white: 0.45)
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .accessibilityHidden(true)
                .ignoresSafeArea()

            mainContent
        }
        .background(WindowConfigurator(minSize: NSSize(width: 640, height: 480)))
        .onAppear {
            refreshConversionContext()
            recomputeOutput(animated: false)
            startBackgroundAnimation()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            _ = handleDrop(providers: providers)
            return true
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
        .onChange(of: mappingStore.incomingSharePointURL) { _ in
            guard let value = mappingStore.incomingSharePointURL, !value.isEmpty else { return }
            let behavior = mappingStore.consumeIncomingBrowserPreferences()
            pendingBrowserOpenFinder = behavior.openFinder
            pendingBrowserCopyOutput = behavior.copyPath
            inputPath = value
            mappingStore.incomingSharePointURL = nil
        }
        .onChange(of: outputPath) { _ in
            scheduleHistoryCommit()
        }
        .onChange(of: isHistoryVisible) { _ in
            if !isHistoryVisible {
                isHoveringHistoryPanel = false
            }
        }
    }

    var mainContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                headerRow
                inputOutputCards
                footerRow
            }
            .padding(24)
        }
        .scrollDisabled(isHoveringHistoryPanel)
    }

    var backgroundLayer: some View {
        ZStack {
            colorScheme == .dark ? Color(white: 0.05) : Color(white: 0.98)
            
            Circle()
                .fill(dynamicAccentColor.opacity(0.08))
                .frame(width: 400, height: 400)
                .offset(x: backgroundOrbOffset.width, y: backgroundOrbOffset.height)
                .blur(radius: 60)
            
            Circle()
                .fill(dynamicAccentColor.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: -backgroundOrbOffset.width * 0.7, y: -backgroundOrbOffset.height * 0.7)
                .blur(radius: 50)
        }
    }

    var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PathFatter")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(dynamicAccentColor)

                Text("Instantly translate Windows and macOS paths")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHistoryVisible.toggle()
                }
            } label: {
                Image(systemName: isHistoryVisible ? "xmark.circle.fill" : "clock.badge.checkmark.fill")
                    .font(.system(size: 24))
                    .foregroundColor(dynamicAccentColor)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringHistory = $0 }
        }
    }

    var inputOutputCards: some View {
        VStack(spacing: 16) {
            inputCard
            outputCard
        }
    }

    var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sourceTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(secondaryTextColor)

            TextField("Paste a Windows or SharePoint path…", text: $inputPath, axis: .vertical)
                .font(.system(size: 14, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(12)
                .background(fieldBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorderColor, lineWidth: 1)
                )

            HStack {
                Button {
                    if let pasted = NSPasteboard.general.string(forType: .string) {
                        inputPath = pasted
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.plain)
                .foregroundColor(dynamicAccentColor)

                Button {
                    inputPath = ""
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(secondaryTextColor)

                Spacer()

                Text("⌘V to paste")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding(16)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(targetTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryTextColor)

                Spacer()

                Button {
                    if !outputPath.isEmpty {
                        inputPath = outputPath
                    }
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.plain)
                .foregroundColor(dynamicAccentColor)
                .disabled(outputPath.isEmpty)
            }

            TextField("Converted path appears here…", text: .constant(outputPath), axis: .vertical)
                .font(.system(size: 14, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(12)
                .background(fieldBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorderColor, lineWidth: 1)
                )
                .disabled(true)

            HStack {
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
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(dynamicAccentColor)
                .cornerRadius(6)
                .disabled(outputPath.isEmpty)

                Button {
                    openConvertedPath()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .buttonStyle(.plain)
                .foregroundColor(dynamicAccentColor)
                .disabled(!canOpenOutputInFinder)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: showConversionFlash ? "checkmark.circle.fill" : "info.circle")
                        .foregroundColor(showConversionFlash ? .green : secondaryTextColor)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(showConversionFlash ? .green : secondaryTextColor)
                }
            }
        }
        .padding(16)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .scaleEffect(cardScale)
    }

    var footerRow: some View {
        HStack {
            Spacer()
            Text("Settings ⌘,")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(secondaryTextColor)
        }
    }

    private func refreshConversionContext() {
        conversionContext = PathConverter.makeContext(
            mappings: mappingStore.mappings,
            sharePointMappings: mappingStore.sharePointMappings
        )
    }

    private func recomputeOutput(animated: Bool) {
        let trimmed = inputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if animated {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    outputPath = ""
                }
            } else {
                outputPath = ""
            }
            return
        }

        let converted = PathConverter.convert(trimmed, context: conversionContext)
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                outputPath = converted
            }
        } else {
            outputPath = converted
        }

        showConversionFlash = true
        if !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showConversionFlash = false
                }
            }
        }

        handlePendingBrowserActions(using: converted)
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
            return
        }

        if pendingBrowserCopyOutput {
            copyToPasteboard(trimmed)
            pendingBrowserCopyOutput = false
        }

        if pendingBrowserOpenFinder {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                openPathInFinder(trimmed)
                pendingBrowserOpenFinder = false
            }
        }
    }

    private func scheduleHistoryCommit() {
        historyWorkItem?.cancel()

        let workItem = DispatchWorkItem { [input = inputPath, output = outputPath] in
            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedInput.isEmpty && !trimmedOutput.isEmpty else { return }
            mappingStore.recordHistory(input: trimmedInput, output: trimmedOutput)
        }

        historyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func openConvertedPath() {
        guard canOpenOutputInFinder else { return }
        openPathInFinder(outputPath)
    }

    private func openPathInFinder(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: trimmed)
            if attrs[.type] as? FileAttributeType == .typeDirectory {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: trimmed)
            } else {
                NSWorkspace.shared.selectFile(trimmed, inFileViewerRootedAtPath: (trimmed as NSString).deletingLastPathComponent)
            }
        } catch {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: trimmed)
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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

    private func startBackgroundAnimation() {
        guard !reduceMotion else { return }

        withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
            backgroundOrbOffset = CGSize(width: 100, height: 80)
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.minSize = minSize
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    ContentView()
        .environmentObject(PathMappingStore())
}
