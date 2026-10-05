import BackgroundCore
import BackgroundUI
import SwiftUI

struct HarnessView: View {
    @State private var selection: PreviewDesign = .layeredHills
    @State private var seed: UInt64 = 42
    @State private var element: ShanShuiElement = .leafyTree
    @State private var isPlaying: Bool = true
    @State private var scrollResetID: UInt64 = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        selection.makeView(seed: seed, element: element,
                           isPlaying: isPlaying, scrollResetID: scrollResetID)
            .id(selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: [.horizontal, .bottom])
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Background Harness")
                        .font(.headline)
                    Picker("Design", selection: $selection) {
                        ForEach(PreviewDesign.allCases) { design in
                            Text(design.title).tag(design)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("designPicker")

                    if selection == .shanShuiElements {
                        Picker("Element", selection: $element) {
                            ForEach(ShanShuiElement.allCases, id: \.self) { subject in
                                Text(subject.title).tag(subject)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("elementPicker")
                    }

                    if selection.supportsPlayback {
                        HStack(spacing: 16) {
                            Button(isPlaying && !reduceMotion ? "Pause" : "Play") { isPlaying.toggle() }
                                .disabled(reduceMotion)
                                .accessibilityIdentifier("togglePlayback")
                            Text(reduceMotion ? "Reduce Motion is on. Drag to explore." : "Drag or swipe to explore")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 16) {
                        Stepper("Seed \(seed)", value: $seed, in: 0...9_999)
                            .monospacedDigit()
                            .accessibilityIdentifier("seedStepper")
                        Button("Reset") {
                            seed = 42
                            scrollResetID &+= 1
                        }
                            .accessibilityIdentifier("resetSeed")
                    }
                    .disabled(selection == .paper)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
    }
}

#Preview {
    HarnessView()
}
