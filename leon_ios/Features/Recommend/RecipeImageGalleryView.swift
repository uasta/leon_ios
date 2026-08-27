import SwiftUI
import UIKit

struct RecipeImageGalleryView: View {
    let imageURLs: [URL]
    @Binding var selectedIndex: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if imageURLs.isEmpty {
                ContentUnavailableView(
                    L10n.text(L10n.Recommend.galleryEmptyTitle),
                    systemImage: "photo",
                    description: Text(L10n.text(L10n.Recommend.galleryEmptySubtitle))
                )
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        ZoomableRemoteImageView(url: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .padding(20)
            }
            .accessibilityLabel(L10n.text(L10n.Common.close))
        }
    }
}

private struct ZoomableRemoteImageView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tag = Coordinator.imageViewTag
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.load(url: url)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.load(url: url)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        static let imageViewTag = 100

        var imageView: UIImageView?
        private var loadedURL: URL?

        func load(url: URL) {
            guard loadedURL != url else { return }
            loadedURL = url
            imageView?.image = nil

            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = UIImage(data: data) else { return }
                    await MainActor.run {
                        guard let imageView, let scrollView = imageView.superview as? UIScrollView else { return }
                        imageView.image = image
                        self.layoutImage(in: scrollView)
                    }
                } catch {
                    // Keep placeholder empty on failure.
                }
            }
        }

        func layoutImage(in scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else { return }

            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }

            let widthScale = boundsSize.width / image.size.width
            let heightScale = boundsSize.height / image.size.height
            let scale = min(widthScale, heightScale)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            imageView.frame = CGRect(origin: .zero, size: size)
            scrollView.contentSize = size
            scrollView.zoomScale = 1
            centerImage(in: scrollView)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame

            frame.origin.x = frame.size.width < boundsSize.width
                ? (boundsSize.width - frame.size.width) / 2
                : 0
            frame.origin.y = frame.size.height < boundsSize.height
                ? (boundsSize.height - frame.size.height) / 2
                : 0

            imageView.frame = frame
        }
    }
}
