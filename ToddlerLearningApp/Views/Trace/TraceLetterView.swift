//
//  TraceLetterView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct TraceLetterView: View {

    @State private var viewModel: TraceLetterViewModel
    private let coordinator: AppCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// A phone in landscape: ~330pt of height, against a canvas whose floor is
    /// 200pt plus 220pt of chrome. Stacking cannot fit; the chrome moves beside
    /// the canvas instead.
    private var isShort: Bool { verticalSizeClass == .compact }

    init(viewModel: TraceLetterViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            GeometryReader { geometry in
                let edge = Self.canvasEdge(fitting: geometry.size,
                                           isRegular: horizontalSizeClass == .regular,
                                           isShort: isShort)

                Group {
                    if let letter = viewModel.currentLetter {
                        if isShort {
                            HStack(alignment: .center, spacing: AppSpacing.element) {
                                canvas(letter, edge: edge)

                                VStack(spacing: AppSpacing.element) {
                                    header(letter)
                                    ProgressBar(value: viewModel.coverage,
                                                tint: AppColors.paletteColor(letter.colorIndex))
                                    controls
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: AppSpacing.element) {
                                header(letter)
                                canvas(letter, edge: edge)
                                ProgressBar(value: viewModel.coverage,
                                            tint: AppColors.paletteColor(letter.colorIndex))
                                controls

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(AppSpacing.screen)
                // Constrained to roughly the canvas width on a wide screen:
                // spread across a full 1024pt the two arrows sit so far apart
                // a child cannot reach both.
                .frame(maxWidth: horizontalSizeClass == .regular ? edge + 200 : .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // The view model samples its checkpoint geometry in canvas
                // space, so it has to be told the real edge length — a
                // hardcoded one both clipped on small phones and left the
                // canvas postage-stamp sized on iPad.
                .onAppear { viewModel.updateCanvasSize(edge) }
                .onChange(of: edge) { _, newEdge in viewModel.updateCanvasSize(newEdge) }
            }

            StarBurstView(isActive: viewModel.isComplete)
        }
        .childScreenTypeSize()
        .navigationTitle("Trace Letters")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private func header(_ letter: Letter) -> some View {
        ArrowNavBar(
            canGoBack: viewModel.canGoBack,
            canGoForward: viewModel.canGoForward,
            itemNoun: "letter",
            iconSize: 36,
            onBack: { viewModel.previous() },
            onForward: { viewModel.next() }
        ) {
            VStack(spacing: 2) {
                Text(letter.uppercase)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)
                Text(viewModel.positionCaption)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)
            }
        }
    }

    /// The canvas is square and shares the screen with the header, progress bar
    /// and controls stacked beneath it. Capped so it doesn't balloon on iPad,
    /// floored so a transiently tiny or zero geometry can't produce a negative
    /// frame during a push transition.
    private static func canvasEdge(fitting size: CGSize,
                                   isRegular: Bool,
                                   isShort: Bool) -> CGFloat {
        let availableWidth = size.width - AppSpacing.screen * 2
        // On a short screen the chrome sits *beside* the canvas, so only the
        // screen padding comes out of the height budget.
        let availableHeight = size.height - (isShort ? AppSpacing.screen * 2 : chromeHeight)
        // The ceiling is keyed off the *smaller* screen dimension rather than a
        // constant, so landscape — where height binds, not width — can't ask
        // for a canvas taller than the screen. 420 was tuned for a phone and
        // left the canvas postage-stamp sized on an iPad.
        let ceiling = isRegular ? min(800, min(size.width, size.height) * 0.78) : 420
        // The floor is dropped on a short screen: 200pt simply may not be
        // available, and a canvas that overflows is worse than a smaller one.
        let floor: CGFloat = isShort ? 120 : 200
        return min(max(min(availableWidth, availableHeight), floor), ceiling)
    }

    /// Header, progress bar, controls, the spacing between them, and the screen
    /// padding — everything the canvas has to share the screen with.
    private static let chromeHeight: CGFloat = 220

    private func canvas(_ letter: Letter, edge: CGFloat) -> some View {
        let tint = AppColors.paletteColor(letter.colorIndex)
        let size = edge

        return ZStack {
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                .fill(AppColors.card)
                .softShadow()

            // Faint shape recognition cue behind the dotted guide — no longer
            // load-bearing for hit-testing, unlike the old approach where this
            // exact glyph doubled as the mask source.
            Text(letter.uppercase)
                .font(.system(size: size * 0.8, weight: .heavy, design: .rounded))
                .foregroundStyle(tint.opacity(0.08))

            // The dotted guide and the checkpoint hit-testing both come from
            // the same LetterTracePathContent/TracePathSampler geometry, so
            // they can't drift apart the way the old glyph-vs-mask pair could.
            Canvas { context, _ in
                for path in viewModel.guidePaths {
                    context.stroke(
                        path,
                        with: .color(tint.opacity(0.4)),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round, dash: [1, 16])
                    )
                }
            }

            if !viewModel.isComplete, let start = viewModel.startPoint {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 18, height: 18)
                    .position(start)
            }

            if !viewModel.isComplete, let target = viewModel.nextTargetPoint {
                Circle()
                    .fill(tint)
                    .frame(width: 26, height: 26)
                    .position(target)
                    .opacity(0.85)
            }

            Canvas { context, _ in
                context.stroke(
                    viewModel.strokePath,
                    with: .color(tint),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                )
            }

            if viewModel.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(AppColors.success)
                    .transition(.scale)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in viewModel.addPoint(value.location) }
                .onEnded { _ in viewModel.endStroke() }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.isComplete)
        .accessibilityLabel("Trace the letter \(letter.uppercase) with your finger")
        // Without this trait VoiceOver swallows the drag for its own
        // navigation and the activity is simply unusable with it turned on.
        // `.allowsDirectInteraction` hands raw touches to the canvas instead.
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityValue("\(Int(viewModel.coverage * 100)) percent traced")
        .accessibilityHint("Drag along the dotted guide")
        .accessibilityAction(named: "Hear the letter") { viewModel.speakCurrentLetter() }
        // Centring goes *after* the gesture: applied before it, the drag would
        // report locations in the full-width frame's space rather than the
        // canvas's, offsetting every touch by the left margin.
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: AppSpacing.element) {
            Button {
                viewModel.clear()
            } label: {
                Label("Try again", systemImage: "arrow.counterclockwise")
                    .font(AppFonts.body)
            }
            .buttonStyle(.bordered)

            Spacer()

            Label("\(viewModel.starsThisSession)", systemImage: "star.fill")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.star)
        }
    }
}
