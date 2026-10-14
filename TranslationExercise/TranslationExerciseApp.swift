import SwiftUI
import SwiftData

@main
struct TranslationExerciseApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel

    init() {
        let container = try! PracticeStore.makeContainer()
        _model = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .environment(\.locale, locale)
                .task { await model.syncNow() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await model.syncNow() }
                }
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(model)
                .modelContainer(model.container)
                .environment(\.locale, locale)
                .frame(minWidth: 480, idealWidth: 540, minHeight: 560, idealHeight: 680)
        }
        #endif
    }

    private var locale: Locale {
        if let code = model.settings.uiLanguageCode {
            return Locale(identifier: code)
        }
        return .autoupdatingCurrent
    }
}
