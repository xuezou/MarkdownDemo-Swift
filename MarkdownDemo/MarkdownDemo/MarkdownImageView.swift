import SwiftUI

struct MarkdownImageView: View {
    let reference: MarkdownImageReference
    var documentURL: URL?
    @Environment(\.markdownTheme) private var theme
    @State private var image: CGImage?
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    private struct Request: Equatable {
        let destination: String
        let documentURL: URL?
        let retryID: UUID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: CGFloat(image.width), alignment: .leading)
                    .accessibilityHidden(false)
                    .accessibilityLabel(reference.altText.isEmpty ? "Image" : reference.altText)
            } else if let errorMessage {
                HStack(alignment: .top, spacing: 12) {
                    Label(errorMessage, systemImage: "photo.badge.exclamationmark")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { retryID = UUID() } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help("Retry Image")
                    .accessibilityLabel("Retry Image")
                }
                .foregroundStyle(theme.text)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.mermaidBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ProgressView().frame(maxWidth: .infinity).frame(height: 120)
            }
            if !reference.altText.isEmpty {
                Text(reference.altText)
                    .font(.caption)
                    .foregroundStyle(theme.text.opacity(0.7))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: Request(destination: reference.destination, documentURL: documentURL, retryID: retryID)) {
            await loadImage()
        }
    }

    private func loadImage() async {
        image = nil
        errorMessage = nil
        do {
            let url = try reference.localURL(relativeTo: documentURL)
            let loading = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                return try MarkdownLocalImage.load(at: url)
            }
            let loaded = try await withTaskCancellationHandler {
                try await loading.value
            } onCancel: {
                loading.cancel()
            }
            try Task.checkCancellation()
            image = loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
