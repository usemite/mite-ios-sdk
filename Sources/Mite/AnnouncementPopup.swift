import SwiftUI

/// A sheet containing an announcement title, Markdown body, optional action,
/// and a dismiss button.
public struct MiteAnnouncementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let announcement: Announcement
    private let dismissLabel: String
    private let onDismiss: () -> Void
    private let onCTAPress: ((URL) -> Void)?

    public init(
        announcement: Announcement,
        dismissLabel: String = "Got it",
        onDismiss: @escaping () -> Void,
        onCTAPress: ((URL) -> Void)? = nil
    ) {
        self.announcement = announcement
        self.dismissLabel = dismissLabel
        self.onDismiss = onDismiss
        self.onCTAPress = onCTAPress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(announcement.title)
                .font(.title2.bold())
                .accessibilityIdentifier("mite.announcement.title")

            ScrollView {
                Group {
                    if announcement.content.isEmpty {
                        Text("Nothing else to add.")
                            .foregroundColor(.secondary)
                    } else {
                        Text(markdownContent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let ctaURL {
                Button {
                    onCTAPress?(ctaURL)
                    openURL(ctaURL)
                } label: {
                    Text(announcement.ctaLabel ?? "Learn more")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("mite.announcement.cta")
            }

            Button {
                onDismiss()
                dismiss()
            } label: {
                Text(dismissLabel)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("mite.announcement.dismiss")
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mite.announcement.popup")
    }

    private var ctaURL: URL? {
        guard let raw = announcement.ctaUrl else { return nil }
        return URL(string: raw)
    }

    private var markdownContent: AttributedString {
        (try? AttributedString(markdown: announcement.content))
            ?? AttributedString(announcement.content)
    }
}

private struct MiteAnnouncementPopupModifier: ViewModifier {
    @ObservedObject var controller: MiteAnnouncementController
    let dismissLabel: String
    let onDismiss: (() -> Void)?
    let onCTAPress: ((URL) -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(item: presentationBinding, onDismiss: sheetDidDismiss) { announcement in
                MiteAnnouncementView(
                    announcement: announcement,
                    dismissLabel: dismissLabel,
                    onDismiss: controller.prepareForDismissal,
                    onCTAPress: onCTAPress
                )
            }
            .task {
                await controller.load()
            }
    }

    private var presentationBinding: Binding<Announcement?> {
        Binding(
            get: { controller.presentedAnnouncement },
            set: { value in
                if value == nil {
                    controller.prepareForDismissal()
                }
            }
        )
    }

    private func sheetDidDismiss() {
        Task {
            if await controller.dismiss() {
                onDismiss?()
            }
        }
    }
}

private struct AutomaticMiteAnnouncementPopupModifier: ViewModifier {
    @StateObject private var controller: MiteAnnouncementController
    private let dismissLabel: String
    private let onDismiss: (() -> Void)?
    private let onCTAPress: ((URL) -> Void)?

    init(
        client: MiteClient?,
        platform: ReleasePlatform?,
        limit: Int?,
        enabled: Bool,
        dismissLabel: String,
        onDismiss: (() -> Void)?,
        onCTAPress: ((URL) -> Void)?
    ) {
        _controller = StateObject(wrappedValue: MiteAnnouncementController(
            client: client,
            platform: platform,
            limit: limit,
            enabled: enabled
        ))
        self.dismissLabel = dismissLabel
        self.onDismiss = onDismiss
        self.onCTAPress = onCTAPress
    }

    func body(content: Content) -> some View {
        content.modifier(MiteAnnouncementPopupModifier(
            controller: controller,
            dismissLabel: dismissLabel,
            onDismiss: onDismiss,
            onCTAPress: onCTAPress
        ))
    }
}

public extension View {
    /// Mounts an announcement popup that automatically presents the newest
    /// active iOS announcement once per device.
    func miteAnnouncementPopup(
        client: MiteClient? = nil,
        platform: ReleasePlatform? = .ios,
        limit: Int? = 10,
        enabled: Bool = true,
        dismissLabel: String = "Got it",
        onDismiss: (() -> Void)? = nil,
        onCTAPress: ((URL) -> Void)? = nil
    ) -> some View {
        modifier(AutomaticMiteAnnouncementPopupModifier(
            client: client,
            platform: platform,
            limit: limit,
            enabled: enabled,
            dismissLabel: dismissLabel,
            onDismiss: onDismiss,
            onCTAPress: onCTAPress
        ))
    }

    /// Mounts an announcement popup controlled by an observable controller.
    /// Keep the controller in `@StateObject` when you need to call `show()`
    /// from elsewhere in your interface.
    func miteAnnouncementPopup(
        controller: MiteAnnouncementController,
        dismissLabel: String = "Got it",
        onDismiss: (() -> Void)? = nil,
        onCTAPress: ((URL) -> Void)? = nil
    ) -> some View {
        modifier(MiteAnnouncementPopupModifier(
            controller: controller,
            dismissLabel: dismissLabel,
            onDismiss: onDismiss,
            onCTAPress: onCTAPress
        ))
    }
}
