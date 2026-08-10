import SwiftUI
import PhotosUI
import Mite

struct ReportView: View {
    @State private var title = ""
    @State private var details = ""
    @State private var steps = ""
    @State private var appVersion = "1.0.0"
    @State private var pickedItem: PhotosPickerItem?
    @State private var attachmentURL: URL?
    @State private var isSubmitting = false
    @State private var resultText: String?
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Bug") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Steps to reproduce", text: $steps, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("App version", text: $appVersion)
                }
                Section("Attachment") {
                    PhotosPicker("Pick image", selection: $pickedItem, matching: .images)
                    if attachmentURL != nil {
                        Label("1 image attached", systemImage: "paperclip")
                    }
                }
                Section {
                    Button(isSubmitting ? "Submitting…" : "Submit") {
                        submit()
                    }
                    .disabled(isSubmitting || title.isEmpty || details.isEmpty)
                }
                if let resultText {
                    Section("Result") {
                        Text(resultText)
                    }
                }
            }
            .navigationTitle("Report")
            .onChange(of: pickedItem) { item in
                loadAttachment(item)
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorText != nil },
                    set: { if !$0 { errorText = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func loadAttachment(_ item: PhotosPickerItem?) {
        attachmentURL = nil
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    errorText = "Could not load the picked image."
                    return
                }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("mite-attachment.jpg")
                try data.write(to: url)
                attachmentURL = url
            } catch {
                errorText = "Could not load the picked image."
            }
        }
    }

    private func submit() {
        isSubmitting = true
        resultText = nil
        let payload = BugReportPayload(
            title: title,
            description: details,
            stepsToReproduce: steps.isEmpty ? nil : steps,
            appVersion: appVersion.isEmpty ? nil : appVersion,
            attachments: attachmentURL.map {
                [MiteAttachment(fileURL: $0, contentType: "image/jpeg")]
            }
        )
        Task {
            defer { isSubmitting = false }
            do {
                let result = try await Mite.shared.submitBug(payload)
                resultText = message(for: result)
            } catch {
                errorText = String(describing: error)
            }
        }
    }

    private func message(for result: SubmitBugResult) -> String {
        switch result {
        case let .success(report, dropped):
            var text = "Created report \(report.id) (status: \(report.status))."
            if let dropped {
                text += "\n\(dropped.count) attachment(s) did not upload: \(dropped.refusal.message)"
            }
            return text
        case let .refused(refusal):
            return "Refused (\(refusal.code.rawValue)): \(refusal.message)"
        }
    }
}
