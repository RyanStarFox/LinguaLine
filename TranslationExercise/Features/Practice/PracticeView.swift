import SwiftUI
import TranslationCore

struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Bindable var exercise: Exercise
    var onReview: ((UUID) -> Void)? = nil
    @State private var draft = ""
    @State private var selection = ""
    @State private var glossTask: Task<Void, Never>?

    var body: some View {
        PageScroll { span in
            if span == .paired {
                HStack(alignment: .top, spacing: 16) {
                    passageColumn
                    answerColumn(span)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    passageColumn
                    answerColumn(span)
                }
            }
        }
        .navigationTitle(model.settings.directionText(exercise.direction))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let message = model.statusMessage {
                    failureNotice(message) {
                        Task { await commit() }
                    }
                }
                if showsBottomGloss {
                    glossPanel
                        .padding()
                }
            }
        }
        .onAppear {
            if onReview == nil {
                draft = exercise.userDraft
            }
        }
        .onChange(of: draft) { _, value in
            if onReview == nil {
                exercise.userDraft = value
            }
        }
        .onChange(of: selection) { _, value in
            scheduleLookup(value)
        }
    }

    private var passageColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            PassageText(text: exercise.sourceText, selection: $selection)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .promptSurface()
            if showsInlineGloss {
                glossPanel
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func answerColumn(_ span: PageSpan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("practice_placeholder", text: $draft, axis: .vertical)
                .lineLimit(span == .paired ? 10...28 : 6...14)
                .textFieldStyle(.plain)
                .glassCard()
            HStack(spacing: 12) {
                Button("practice_submit") {
                    Task { await commit() }
                }
                .glassButton(prominent: true)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isWorking || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if model.isWorking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(model.workCaption ?? String(localized: "ai_grading"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var showsBottomGloss: Bool {
        #if os(macOS)
        false
        #else
        sizeClass == .compact && !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #endif
    }

    private var showsInlineGloss: Bool {
        !showsBottomGloss && (!model.glossText.isEmpty || model.glossLoading) && !selection.isEmpty
    }

    private func failureNotice(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("common_retry", action: retry)
                .glassButton(prominent: true)
                .disabled(model.isWorking || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private var glossPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.glossTerm.isEmpty ? selection : model.glossTerm)
                .font(.headline)
            if model.glossLoading {
                ProgressView()
            } else {
                Text(model.glossText)
                if !model.glossIPA.isEmpty {
                    Text(model.glossIPA)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func commit() async {
        if let onReview {
            if let id = await model.submitReview(exercise: exercise, answer: draft) {
                onReview(id)
            }
        } else {
            await model.submit(exercise: exercise, answer: draft)
        }
    }

    private func scheduleLookup(_ value: String) {
        glossTask?.cancel()
        let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            model.clearGloss()
            return
        }
        if model.applyDictionaryGloss(term: term, exercise: exercise) {
            return
        }
        model.glossTerm = term
        model.glossText = ""
        model.glossIPA = ""
        model.glossLoading = true
        glossTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await model.lookup(term: term, exercise: exercise)
        }
    }
}
