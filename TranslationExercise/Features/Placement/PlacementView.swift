import SwiftUI
import SwiftData
import TranslationCore

struct PlacementView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    var direction: Direction

    var body: some View {
        NavigationStack {
            Group {
                if let exercise = current, !exercise.submitted {
                    PracticeView(exercise: exercise)
                        .id(exercise.id)
                } else if let exercise = current, exercise.submitted, !model.isWorking {
                    failurePanel
                } else if model.isWorking, let caption = model.workCaption {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(caption)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.isWorking || model.statusMessage == nil {
                    if !model.isWorking, !model.needsPlacement(language: model.settings.activeLanguage, direction: direction) {
                        ContentUnavailableView("placement_done", systemImage: "checkmark.circle")
                    } else {
                        ProgressView("placement_progress")
                    }
                } else if !model.needsPlacement(language: model.settings.activeLanguage, direction: direction) {
                    ContentUnavailableView("placement_done", systemImage: "checkmark.circle")
                } else {
                    failurePanel
                }
            }
            .navigationTitle(model.settings.directionText(direction))
            .toolbar {
                Button("placement_skip") {
                    model.skipPlacement(direction: direction)
                    dismiss()
                }
                Button("common_close") { dismiss() }
            }
        }
        .onChange(of: model.placementExerciseID) { _, id in
            if id == nil, !model.needsPlacement(language: model.settings.activeLanguage, direction: direction) {
                dismiss()
            }
        }
    }

    private var failurePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.statusMessage ?? String(localized: "common_action_failed"))
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("common_retry") {
                Task { await model.retryPlacement() }
            }
            .glassButton(prominent: true)
            .disabled(model.isWorking)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var current: Exercise? {
        guard let id = model.placementExerciseID, model.placementSession == direction else { return nil }
        return exercises.first { $0.id == id && $0.direction == direction }
    }
}
