import SwiftUI

enum PageMetrics {
    static let column: CGFloat = 640
}

extension View {
    func pageColumn() -> some View {
        frame(maxWidth: PageMetrics.column)
            .frame(maxWidth: .infinity)
    }
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
