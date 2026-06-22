import SwiftUI

/// Hosts the import flow in its own navigation stack. CSV files start at column
/// mapping; PDFs go straight to the preview (or an explanatory failure screen).
struct ImportWizardView: View {
    @Environment(\.dismiss) private var dismiss
    let input: ImportInput

    var body: some View {
        NavigationStack {
            switch input {
            case let .csv(session):
                CSVMappingView(session: session, onCancel: { dismiss() })
            case let .pdfPreview(preview):
                if let message = preview.fatalMessage {
                    ImportFailureView(filename: preview.filename, message: message, onClose: { dismiss() })
                } else {
                    ImportPreviewView(preview: preview, onClose: { dismiss() })
                }
            }
        }
    }
}

/// Shown for scanned/unsupported PDFs or files with no recognisable rows.
struct ImportFailureView: View {
    let filename: String
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48, weight: .light)).foregroundStyle(Theme.warning)
            Text("Can't read this file").font(.ledgerTitle()).foregroundStyle(Theme.ink)
            Text(message)
                .font(.ledgerBody()).foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, Theme.Space.xl)
            Text(filename).font(.ledgerCaption()).foregroundStyle(Theme.inkFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onClose) } }
    }
}
