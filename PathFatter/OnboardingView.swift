import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var mappingStore: PathMappingStore

    @State private var currentPage = 0
    @State private var dragOffset: CGSize = .zero

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "arrow.left.arrow.right.circle.fill",
            title: "Instant Path Conversion",
            description: "Paste a Windows or SharePoint path and get the macOS equivalent instantly. No more manual translation.",
            accentColor: Color(red: 0.22, green: 0.56, blue: 0.94)
        ),
        OnboardingPage(
            icon: "externaldrive.fill",
            title: "Custom Mappings",
            description: "Map your Windows drive letters to macOS folders or SMB paths. Configure in Settings (⌘,).",
            accentColor: Color(red: 0.34, green: 0.68, blue: 0.38)
        ),
        OnboardingPage(
            icon: "link.badge.plus",
            title: "SharePoint Support",
            description: "Convert SharePoint URLs to your local OneDrive folder paths. Perfect for hybrid workflows.",
            accentColor: Color(red: 0.78, green: 0.45, blue: 0.88)
        ),
        OnboardingPage(
            icon: "clock.arrow.circlepath",
            title: "History & Quick Access",
            description: "Access your recent conversions anytime. Pin frequently used paths for instant access.",
            accentColor: Color(red: 0.95, green: 0.55, blue: 0.32)
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            ZStack {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.08, blue: 0.12),
                            Color(red: 0.04, green: 0.06, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.98, blue: 0.995),
                            Color(red: 0.94, green: 0.96, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color(white: 0.4))
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }

                // Content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 380)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if value.translation.width > 100 && currentPage > 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentPage -= 1
                                }
                            } else if value.translation.width < -100 && currentPage < pages.count - 1 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            }
                            dragOffset = .zero
                        }
                )

                // Page indicator and next button
                HStack {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? pages[currentPage].accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    Spacer()

                    // Next/Get Started button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentPage += 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(pages[currentPage].accentColor)
                                .shadow(color: pages[currentPage].accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 520, height: 540)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

private struct OnboardingPageView: View {
    var page: OnboardingPage
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                page.accentColor.opacity(0.9),
                                page.accentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: page.accentColor.opacity(0.4), radius: 24, x: 0, y: 12)

                Image(systemName: page.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color(white: 0.15))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.secondary : Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 40)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(PathMappingStore())
    }
}
