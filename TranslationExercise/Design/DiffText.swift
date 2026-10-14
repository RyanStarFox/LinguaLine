import SwiftUI
import TranslationCore

struct DiffText: View {
    var user: String
    var corrected: String
    var notes: [EditHunk] = []
    @State private var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("review_delete", systemImage: "minus")
                    .foregroundStyle(.red)
                Label("review_add", systemImage: "plus")
                    .foregroundStyle(.green)
                if hasReason {
                    Text("review_reason_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            if hasReason {
                tappable
                if let selected, notes.indices.contains(selected), !notes[selected].reason.isEmpty {
                    Text(notes[selected].reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                composed
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: user) { _, _ in selected = nil }
        .onChange(of: corrected) { _, _ in selected = nil }
    }

    private var hasReason: Bool {
        notes.contains { !$0.reason.isEmpty }
    }

    private var tappable: some View {
        let pieces = TextDiff.pieces(user: user, corrected: corrected)
        return FlowLayout(spacing: 0, lineSpacing: 2) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                pieceView(piece, at: index)
            }
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func pieceView(_ piece: DiffPiece, at index: Int) -> some View {
        let shown = display(piece.token, at: index)
        let hunk = tappableHunk(piece)
        let label = Text(shown)
            .foregroundStyle(color(piece.kind))
            .fixedSize()
            .overlay {
                if piece.kind == .delete {
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1)
                        .padding(.horizontal, 0.5)
                }
            }
            .padding(.vertical, 1)
            .background(
                hunk != nil && selected == hunk ? Color.accentColor.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
        if let hunk {
            label
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = selected == hunk ? nil : hunk
                }
        } else {
            label
        }
    }

    private func tappableHunk(_ piece: DiffPiece) -> Int? {
        guard let hunk = piece.hunk, notes.indices.contains(hunk), !notes[hunk].reason.isEmpty else { return nil }
        return hunk
    }

    private func color(_ kind: DiffPiece.Kind) -> Color {
        switch kind {
        case .same: .primary
        case .delete: .red
        case .insert: .green
        }
    }

    private func display(_ token: String, at index: Int) -> String {
        guard index > 0, TextDiff.needsSpace(before: token) else { return token }
        return " " + token
    }

    private var composed: Text {
        let ops = TextDiff.diff(user: user, corrected: corrected)
        var text = Text("")
        var index = 0
        for op in ops {
            let raw: String
            let styled: Text
            switch op {
            case let .same(token):
                raw = token
                styled = Text(displayToken(token, at: index)).foregroundStyle(.primary)
            case let .delete(token):
                raw = token
                styled = Text(displayToken(token, at: index)).foregroundStyle(.red).strikethrough()
            case let .insert(token):
                raw = token
                styled = Text(displayToken(token, at: index)).foregroundStyle(.green)
            }
            text = text + styled
            index += raw.count
        }
        return text
    }

    private func displayToken(_ token: String, at index: Int) -> String {
        guard index > 0, TextDiff.needsSpace(before: token) else { return token }
        return " " + token
    }
}
