import SwiftUI
import TranslationCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct SelectablePrompt: View {
    var text: String
    @Binding var selection: String
    var minimumHeight: CGFloat = 80

    var body: some View {
        PromptRepresentable(text: text, selection: $selection, minimumHeight: minimumHeight)
    }
}

struct PassageText: View {
    var text: String
    @Binding var selection: String
    var minimumHeight: CGFloat = 44

    var body: some View {
        #if os(iOS)
        TokenPassage(text: text, selection: $selection)
        #else
        SelectablePrompt(text: text, selection: $selection, minimumHeight: minimumHeight)
        #endif
    }
}

struct GlossBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.glossLoading || !model.glossText.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.glossTerm)
                        .font(.headline)
                    Spacer(minLength: 8)
                    Button {
                        model.clearGloss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
        }
    }
}

private struct TokenPassage: View {
    var text: String
    @Binding var selection: String
    @State private var marks = TokenSelection()

    var body: some View {
        let tokens = TextDiff.tokens(text)
        FlowLayout(spacing: 0, lineSpacing: 2) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                Text(shown(token, at: index))
                    .font(.title3)
                    .fixedSize()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                    .background(highlight(index), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { choose(index, in: tokens) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: text) { _, _ in
            marks.clear()
            selection = ""
        }
        .onChange(of: selection) { _, value in
            if value.isEmpty {
                marks.clear()
            }
        }
    }

    private func choose(_ index: Int, in tokens: [String]) {
        guard let range = marks.tap(index) else {
            selection = ""
            return
        }
        selection = TextDiff.joined(Array(tokens[range]))
    }

    private func highlight(_ index: Int) -> Color {
        guard let anchor = marks.anchor, let extent = marks.extent else { return .clear }
        let lower = min(anchor, extent)
        let upper = max(anchor, extent)
        return (lower...upper).contains(index) ? Color.accentColor.opacity(0.28) : .clear
    }

    private func shown(_ token: String, at index: Int) -> String {
        guard index > 0, TextDiff.needsSpace(before: token) else { return token }
        return " " + token
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(width: width, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var items: [Item] = []
        var x: CGFloat = 0
        var height: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(Row(items: items, height: height))
                items = []
                x = 0
                height = 0
            }
            items.append(Item(index: index, size: size))
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !items.isEmpty {
            rows.append(Row(items: items, height: height))
        }
        return rows
    }

    private struct Item {
        var index: Int
        var size: CGSize
    }

    private struct Row {
        var items: [Item]
        var height: CGFloat
    }
}

struct LookupPassage: View {
    @Environment(AppModel.self) private var model
    var exercise: Exercise
    var text: String
    @State private var selection = ""
    @State private var glossTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PassageText(text: text, selection: $selection, minimumHeight: 44)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            #if !os(iOS)
            if showGloss {
                gloss
            }
            #endif
        }
        .onChange(of: selection) { _, value in
            scheduleLookup(value)
        }
        .onDisappear {
            glossTask?.cancel()
            model.clearGloss()
        }
    }

    private var showGloss: Bool {
        let term = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, model.glossLoading || !model.glossText.isEmpty else { return false }
        if model.glossTerm.isEmpty { return true }
        return term.contains(model.glossTerm) || model.glossTerm.contains(term)
    }

    private var gloss: some View {
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

#if os(iOS)
private struct PromptRepresentable: UIViewRepresentable {
    var text: String
    @Binding var selection: String
    var minimumHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textColor = .label
        view.font = .preferredFont(forTextStyle: .title3)
        view.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        view.text = text
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.textColor = .label
        }
        context.coordinator.selection = $selection
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: max(minimumHeight, height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var selection: Binding<String>
        private var work: DispatchWorkItem?

        init(selection: Binding<String>) { self.selection = selection }

        func textViewDidChangeSelection(_ textView: UITextView) {
            work?.cancel()
            let selected = textView.selectedRange
            let value: String
            if let range = Range(selected, in: textView.text) {
                value = String(textView.text[range])
            } else {
                value = ""
            }
            let item = DispatchWorkItem { [weak self] in
                self?.selection.wrappedValue = value
            }
            work = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
        }
    }
}
#else
private struct PromptRepresentable: NSViewRepresentable {
    var text: String
    @Binding var selection: String
    var minimumHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeNSView(context: Context) -> PromptTextView {
        let view = PromptTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = false
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainerInset = NSSize(width: 0, height: 2)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.font = .preferredFont(forTextStyle: .title3)
        view.textColor = .labelColor
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: 4_000, height: 4_000)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.string = text
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateNSView(_ nsView: PromptTextView, context: Context) {
        context.coordinator.selection = $selection
        if nsView.string != text {
            nsView.string = text
            nsView.textColor = .labelColor
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PromptTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let font = nsView.font ?? .preferredFont(forTextStyle: .title3)
        let height = PromptMeasure.height(text: text, width: width, font: font)
        return CGSize(width: width, height: max(minimumHeight, height))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var selection: Binding<String>
        private var work: DispatchWorkItem?

        init(selection: Binding<String>) { self.selection = selection }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            work?.cancel()
            let range = view.selectedRange()
            let value: String
            if range.length > 0, range.location != NSNotFound, let swiftRange = Range(range, in: view.string) {
                value = String(view.string[swiftRange])
            } else {
                value = ""
            }
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.selection.wrappedValue != value else { return }
                self.selection.wrappedValue = value
            }
            work = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
        }
    }
}

private final class PromptTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func invalidateIntrinsicContentSize() {}
}

private enum PromptMeasure {
    static func height(text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let storage = NSTextStorage(string: text)
        let full = NSRange(location: 0, length: storage.length)
        if full.length > 0 {
            storage.addAttribute(.font, value: font, range: full)
        }
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: max(width, 1), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.glyphRange(for: container)
        return ceil(manager.usedRect(for: container).height) + 4
    }
}
#endif

extension View {
    @ViewBuilder
    func promptSurface() -> some View {
        #if os(iOS)
        glassBackdrop()
        #else
        glassCard()
        #endif
    }
}
