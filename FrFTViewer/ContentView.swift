import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = FrFTViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                HStack(spacing: 16) {
                    ImagePanel(
                        title: "Original",
                        subtitle: viewModel.originalSubtitle,
                        image: viewModel.originalImage,
                        emptyMessage: "Drop an image file onto the window"
                    )

                    ImagePanel(
                        title: "FrFT",
                        subtitle: viewModel.frftSubtitle,
                        image: viewModel.transformedImage,
                        emptyMessage: viewModel.transformedEmptyMessage
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .padding(20)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
                .padding(10)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        }
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fractional Fourier Viewer")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                Text("Drop an image, then adjust alpha in real time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("alpha")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.alpha, format: .number.precision(.fractionLength(2)))
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack {
                Text("0.00")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: $viewModel.alpha, in: 0.0...2.0, step: 0.01)
                    .tint(.accentColor)

                Text("2.00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(viewModel.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.isRendering {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?

            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let fileURL = item as? URL {
                url = fileURL
            } else if let fileURL = item as? NSURL {
                url = fileURL as URL
            } else {
                url = nil
            }

            guard let url else { return }

            DispatchQueue.main.async {
                viewModel.loadImage(from: url)
            }
        }

        return true
    }
}

private struct ImagePanel: View {
    let title: String
    let subtitle: String
    let image: NSImage?
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.72))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)

                        Text(emptyMessage)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.76))
        )
    }
}

