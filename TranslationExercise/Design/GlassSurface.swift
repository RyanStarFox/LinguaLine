import SwiftUI

enum PageSpan: Equatable {
    case compact
    case paired

    init(width: CGFloat) {
        self = width >= 800 ? .paired : .compact
    }

    var padding: CGFloat {
        self == .compact ? 20 : 28
    }
}

struct PageScroll<Content: View>: View {
    var refresh: (() async -> Void)? = nil
    @ViewBuilder var content: (PageSpan) -> Content

    var body: some View {
        GeometryReader { geo in
            let span = PageSpan(width: geo.size.width)
            ScrollView {
                content(span)
                    .padding(.horizontal, span.padding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .modifier(OptionalRefresh(action: refresh))
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct OptionalRefresh: ViewModifier {
    var action: (() async -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let action {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}

struct PairedStack<Content: View>: View {
    var span: PageSpan
    var spacing: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        if span == .paired {
            HStack(alignment: .top, spacing: spacing) {
                content()
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        }
    }
}

extension View {
    @ViewBuilder
    func glassCard() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            self
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    @ViewBuilder
    func glassBackdrop() -> some View {
        padding(16)
            .background {
                if #available(iOS 26.0, macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
    }

    @ViewBuilder
    func glassButton(prominent: Bool) -> some View {
        if prominent {
            if #available(iOS 26.0, macOS 26.0, *) {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.borderedProminent)
            }
        } else if #available(iOS 26.0, macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
