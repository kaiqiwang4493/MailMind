import PhotosUI
import PDFKit
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct UploadView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var uploadedSources: [UploadedMailSource] = []
    @State private var isImportingPDF = false
    @State private var isShowingCamera = false
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var latestRecord: MailRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let latestRecord {
                        AnalysisResultView(record: latestRecord) {
                            resetUpload()
                        }
                    } else {
                        header
                        uploadPicker
                        if !uploadedSources.isEmpty {
                            selectedFilesPanel
                        }
                        submitButton
                    }
                }
                .padding(20)
            }
            .background(MailMindTheme.background.ignoresSafeArea())
            .navigationTitle(latestRecord == nil ? "上传邮件" : "分析结果")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AccountToolbarButton()
                }

            }
            .fileImporter(isPresented: $isImportingPDF, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handlePDFImport(result)
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    handleCapturedImage(image)
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    await handlePhotoSelection(newItems)
                }
            }
            .onChange(of: authSession.ownerID) { _, ownerID in
                if ownerID == nil {
                    resetUpload()
                }
            }
            .alert("分析失败", isPresented: .constant(analysisError != nil)) {
                Button("知道了") {
                    analysisError = nil
                }
            } message: {
                Text(analysisError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("把英文邮件拍下来，MailMind 帮你看重点。")
                .font(.title2.weight(.semibold))
                .foregroundStyle(MailMindTheme.text)
            Text("多张照片会当作同一封邮件的多页一起分析。")
                .font(.body)
                .foregroundStyle(MailMindTheme.mutedText)
        }
    }

    private var uploadPicker: some View {
        SectionPanel(title: "选择邮件文件") {
            VStack(spacing: 12) {
                Button {
                    openCamera()
                } label: {
                    UploadActionRow(icon: "camera", title: "拍摄邮件照片", subtitle: "拍摄邮件照片并加入分析")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cameraCaptureButton")

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 12, matching: .images) {
                    UploadActionRow(icon: "photo.on.rectangle", title: "从相册选择多张照片", subtitle: "适合一封邮件有好几页")
                }

                Button {
                    isImportingPDF = true
                } label: {
                    UploadActionRow(icon: "doc.richtext", title: "上传 PDF 文件", subtitle: "PDF 作为一封邮件处理")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var selectedFilesPanel: some View {
        SectionPanel(title: "已选择") {
            ForEach(uploadedSources) { source in
                HStack(spacing: 12) {
                    Image(systemName: source.type == .pdf ? "doc.text" : "photo")
                        .font(.title2)
                        .foregroundStyle(MailMindTheme.primary)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.displayName)
                            .font(.headline)
                            .foregroundStyle(MailMindTheme.text)
                            .lineLimit(2)
                        Text("\(source.pageCount) 页 · \(source.type.displayName)")
                            .font(.subheadline)
                            .foregroundStyle(MailMindTheme.mutedText)
                    }

                    Spacer()
                }
                .padding(.vertical, 6)
            }

            Button(role: .destructive) {
                selectedPhotoItems = []
                uploadedSources = []
            } label: {
                Label("清除选择", systemImage: "trash")
                    .font(.headline)
            }
            .padding(.top, 4)
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                await submitForAnalysis()
            }
        } label: {
            HStack {
                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                }
                Text(isAnalyzing ? "正在分析..." : "提交分析")
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(MailMindTheme.primary)
        .disabled(uploadedSources.isEmpty || isAnalyzing)
        .accessibilityIdentifier("submitAnalysisButton")
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            analysisError = "当前设备无法打开相机。请在真机上拍摄，或从相册选择照片。"
            return
        }

        isShowingCamera = true
    }

    private func handleCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            analysisError = "无法读取拍摄的照片，请重试。"
            return
        }

        if uploadedSources.contains(where: { $0.type == .pdf }) {
            uploadedSources = []
        }

        selectedPhotoItems = []
        latestRecord = nil
        uploadedSources.append(
            UploadedMailSource(
                type: .photos,
                displayName: "拍摄照片 \(uploadedSources.count + 1)",
                pageCount: 1,
                data: data
            )
        )
    }

    @MainActor
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var sources: [UploadedMailSource] = []

        for (index, item) in items.enumerated() {
            let data = try? await item.loadTransferable(type: Data.self)
            sources.append(
                UploadedMailSource(
                    type: .photos,
                    displayName: "邮件照片 \(index + 1)",
                    pageCount: 1,
                    data: data
                )
            )
        }

        uploadedSources = sources
        latestRecord = nil
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try? Data(contentsOf: url)
            uploadedSources = [
                UploadedMailSource(
                    type: .pdf,
                    displayName: url.lastPathComponent,
                    pageCount: data.flatMap { PDFDocument(data: $0)?.pageCount } ?? 1,
                    data: data
                )
            ]
            selectedPhotoItems = []
            latestRecord = nil
        case .failure(let error):
            analysisError = error.localizedDescription
        }
    }

    @MainActor
    private func submitForAnalysis() async {
        guard !uploadedSources.isEmpty else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let ocrService: OCRServicing = VisionOCRService()
            let extractedText = try await ocrService.extractText(from: uploadedSources)
            let analysisService: MailAnalysisServicing = BackendMailAnalysisService()
            let result = try await analysisService.analyze(text: extractedText, createdAt: .now)
            let sourceType = uploadedSources.first?.type ?? .photos
            guard let ownerID = authSession.ownerID else {
                throw AuthSessionError.signedOut
            }
            let record = MailRecord(
                ownerID: ownerID,
                remoteID: authSession.state.isAuthenticated ? UUID().uuidString : nil,
                sourceType: sourceType,
                sourceNames: uploadedSources.map(\.displayName),
                pageCount: uploadedSources.reduce(0) { $0 + max($1.pageCount, 1) },
                extractedText: extractedText,
                summary: result.summary,
                category: result.category,
                suggestedTodos: result.todoDrafts
            )

            modelContext.insert(record)
            try modelContext.save()
            authSession.saveMailRecordToCloud(record)
            latestRecord = record
        } catch {
            analysisError = error.localizedDescription
        }
    }

    private func resetUpload() {
        selectedPhotoItems = []
        uploadedSources = []
        latestRecord = nil
    }
}

private struct UploadActionRow: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(MailMindTheme.primary)
                .frame(width: 52, height: 52)
                .background(MailMindTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MailMindTheme.text)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MailMindTheme.mutedText)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(MailMindTheme.mutedText)
        }
        .padding(14)
        .background(MailMindTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AnalysisResultView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession
    var record: MailRecord
    var onNewUpload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionPanel(title: "邮件摘要") {
                Text(record.summary)
                    .font(.title3)
                    .foregroundStyle(MailMindTheme.text)
                    .lineSpacing(4)
            }

            SectionPanel(title: "邮件类别") {
                CategoryBadge(category: record.category)
            }

            SectionPanel(title: "需要处理") {
                if record.suggestedTodos.isEmpty {
                    Text("没有发现必须马上处理的事项。")
                        .font(.body)
                        .foregroundStyle(MailMindTheme.mutedText)
                } else {
                    ForEach(record.suggestedTodos) { suggestedTodo in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(suggestedTodo.title)
                                    .font(.headline)
                                    .foregroundStyle(MailMindTheme.text)
                                Label(suggestedTodo.deadline.mailMindShortDate, systemImage: "calendar")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MailMindTheme.urgent)
                            }

                            Spacer(minLength: 8)

                            Button {
                                toggleTodo(suggestedTodo)
                            } label: {
                                Text(isAdded(suggestedTodo) ? "移除待办" : "添加待办")
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.bordered)
                            .tint(isAdded(suggestedTodo) ? MailMindTheme.urgent : MailMindTheme.primary)
                            .accessibilityIdentifier(isAdded(suggestedTodo) ? "removeSuggestedTodoButton" : "addSuggestedTodoButton")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                onNewUpload()
            } label: {
                Label("分析另一封邮件", systemImage: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(MailMindTheme.primary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysisResultView")
    }

    private func toggleTodo(_ suggestedTodo: SuggestedTodo) {
        if let existingTodo = matchingTodo(for: suggestedTodo) {
            authSession.deleteTodoItemFromCloud(existingTodo)
            modelContext.delete(existingTodo)
        } else {
            let todo = TodoItem(
                ownerID: record.ownerID,
                remoteID: record.remoteID == nil ? nil : UUID().uuidString,
                title: suggestedTodo.title,
                deadline: suggestedTodo.deadline,
                mailSummary: record.summary,
                mailRecord: record
            )
            record.todoItems.append(todo)
            modelContext.insert(todo)
            authSession.saveTodoItemToCloud(todo)
        }

        try? modelContext.save()
    }

    private func isAdded(_ suggestedTodo: SuggestedTodo) -> Bool {
        matchingTodo(for: suggestedTodo) != nil
    }

    private func matchingTodo(for suggestedTodo: SuggestedTodo) -> TodoItem? {
        record.todoItems.first {
            $0.title == suggestedTodo.title && Calendar.current.isDate($0.deadline, inSameDayAs: suggestedTodo.deadline)
        }
    }
}
