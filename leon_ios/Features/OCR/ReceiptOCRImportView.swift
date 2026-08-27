import PhotosUI
import SwiftUI
import UIKit

struct ReceiptOCRImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: IngredientStore

    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var imageData: Data?
    @State private var imageFilename: String = "receipt.jpg"
    @State private var imageMimeType: String = "image/jpeg"

    @State private var candidates: [ReceiptOCRCandidate] = []
    @State private var summary: ReceiptOCRSummary?
    @State private var rawResponseJSON: String?
    @State private var didCopyResponse: Bool = false
    @State private var isRecognizing: Bool = false
    @State private var hasRecognized: Bool = false
    @State private var errorMessage: String?

    private let service = IngredientService(client: APIClient())

    private var selectedCount: Int {
        candidates.filter(\.isSelected).count
    }

    private var allSelected: Bool {
        !candidates.isEmpty && candidates.allSatisfy(\.isSelected)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    photoSection
                }

                if isRecognizing {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(L10n.text(L10n.OCR.recognizing))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasRecognized {
                    if let summary, summaryHasContent(summary) {
                        summarySection(summary)
                    }
                    candidatesSection

                    if let rawResponseJSON, !rawResponseJSON.isEmpty {
                        debugSection(rawJSON: rawResponseJSON)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.text(L10n.OCR.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text(L10n.Common.close)) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text(L10n.OCR.addSelected)) {
                        importSelected()
                    }
                    .disabled(selectedCount == 0 || isRecognizing)
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if hasRecognized, !candidates.isEmpty {
                    Text(L10n.OCR.selectedCount(selectedCount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    await loadPickedItem(newItem)
                }
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(L10n.OCR.pickHint))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        previewImage == nil
                            ? L10n.text(L10n.OCR.pickPhoto)
                            : L10n.text(L10n.OCR.changePhoto),
                        systemImage: "photo.on.rectangle"
                    )
                }
                .buttonStyle(.bordered)

                if imageData != nil {
                    Button {
                        Task { await recognize() }
                    } label: {
                        Text(L10n.text(L10n.OCR.startRecognize))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRecognizing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func summarySection(_ summary: ReceiptOCRSummary) -> some View {
        Section {
            if let platform = summary.platform?.trimmingCharacters(in: .whitespacesAndNewlines),
               !platform.isEmpty,
               platform != "unknown" {
                Text(L10n.OCR.summaryPlatform(platformDisplayName(platform)))
            }
            if let orderStatus = summary.orderStatus?.trimmingCharacters(in: .whitespacesAndNewlines),
               !orderStatus.isEmpty,
               orderStatus != "unknown" {
                Text(L10n.OCR.summaryOrderStatus(orderStatus))
            }
            if let totalAmount = summary.totalAmount {
                Text(L10n.OCR.summaryTotal(totalAmount))
            }
        } header: {
            Text(L10n.text(L10n.OCR.summaryTitle))
        }
    }

    @ViewBuilder
    private var candidatesSection: some View {
        if candidates.isEmpty {
            Section {
                ContentUnavailableView(
                    L10n.text(L10n.OCR.emptyCandidatesTitle),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(L10n.text(L10n.OCR.emptyCandidatesSubtitle))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        } else {
            Section {
                Button(allSelected ? L10n.text(L10n.OCR.deselectAll) : L10n.text(L10n.OCR.selectAll)) {
                    let next = !allSelected
                    for index in candidates.indices {
                        candidates[index].isSelected = next
                    }
                }
            } header: {
                Text(L10n.text(L10n.OCR.candidatesTitle))
            }

            Section {
                ForEach($candidates) { $candidate in
                    Toggle(isOn: $candidate.isSelected) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                                .font(.body.weight(.medium))
                            HStack(spacing: 8) {
                                Text(L10n.OCR.quantityLabel(candidate.quantity))
                                if let price = candidate.actualPrice {
                                    Text(L10n.OCR.priceLabel(price))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func debugSection(rawJSON: String) -> some View {
        Section {
            Button {
                UIPasteboard.general.string = rawJSON
                didCopyResponse = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    didCopyResponse = false
                }
            } label: {
                Label(
                    didCopyResponse
                        ? L10n.text(L10n.OCR.copyResponseDone)
                        : L10n.text(L10n.OCR.copyResponse),
                    systemImage: didCopyResponse ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }

            Text(rawJSON)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text(L10n.text(L10n.OCR.debugSection))
        }
    }

    private func loadPickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        errorMessage = nil
        hasRecognized = false
        candidates = []
        summary = nil
        rawResponseJSON = nil
        didCopyResponse = false

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // 后端只收 jpg/png/webp；相册常见 HEIC，统一转 JPEG 再上传
                let prepared = prepareUploadImage(from: data)
                imageData = prepared.data
                previewImage = UIImage(data: prepared.data) ?? UIImage(data: data)
                imageFilename = prepared.filename
                imageMimeType = prepared.mimeType
            } else {
                errorMessage = L10n.text(L10n.ClientError.generic)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recognize() async {
        guard let imageData else { return }

        isRecognizing = true
        errorMessage = nil
        hasRecognized = false
        candidates = []
        summary = nil
        rawResponseJSON = nil
        didCopyResponse = false

        do {
            let payload = try await service.importReceiptOCR(
                imageData: imageData,
                filename: imageFilename,
                mimeType: imageMimeType
            )
            let flattened = ReceiptOCRCandidate.flatten(from: payload.envelope.data)
            candidates = flattened.candidates
            summary = flattened.summary
            errorMessage = flattened.errorMessage
            rawResponseJSON = payload.rawJSON
            hasRecognized = true
        } catch {
            errorMessage = error.localizedDescription
            hasRecognized = true
            candidates = []
            summary = nil
            rawResponseJSON = nil
        }

        isRecognizing = false
    }

    private func importSelected() {
        let selected = candidates.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        let note = L10n.text(L10n.OCR.importNote)
        let today = Date()
        let ingredients = selected.map { candidate in
            Ingredient(
                name: candidate.name,
                quantity: candidate.quantity,
                unit: "份",
                location: .fridgeChill,
                purchaseDate: today,
                expiryDate: nil,
                note: note,
                tags: []
            )
        }

        store.addMany(ingredients)
        dismiss()
    }

    private func summaryHasContent(_ summary: ReceiptOCRSummary) -> Bool {
        let platform = summary.platform?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let status = summary.orderStatus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasPlatform = !platform.isEmpty && platform != "unknown"
        let hasStatus = !status.isEmpty && status != "unknown"
        return hasPlatform || hasStatus || summary.totalAmount != nil
    }

    private func platformDisplayName(_ platform: String) -> String {
        switch platform.lowercased() {
        case "hema": return "盒马"
        case "sam": return "山姆"
        case "dingdong": return "叮咚买菜"
        case "meituan": return "美团"
        default: return platform
        }
    }

    /// 将相册原图规范为后端可接受的 JPEG/PNG。
    private func prepareUploadImage(from data: Data) -> (data: Data, filename: String, mimeType: String) {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return (data, "receipt.png", "image/png")
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return (data, "receipt.jpg", "image/jpeg")
        }
        // HEIC / 其他格式：转 JPEG
        if let image = UIImage(data: data),
           let jpeg = image.jpegData(compressionQuality: 0.88) {
            return (jpeg, "receipt.jpg", "image/jpeg")
        }
        return (data, "receipt.jpg", "image/jpeg")
    }
}

#Preview {
    ReceiptOCRImportView()
        .environmentObject(IngredientStore())
}
