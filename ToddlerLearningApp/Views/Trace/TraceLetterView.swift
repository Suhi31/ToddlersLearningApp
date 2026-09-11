//
//  TraceLetterView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct TraceLetterView: View {

    @State private var viewModel: TraceLetterViewModel
    private let coordinator: AppCoordinator

    @State private var isStartPulsing = false

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

            // Spec F27: a finish line rather than this activity running
            // forever. Covers the content above rather than replacing it,
            // same convention as `StarBurstView`.
            if viewModel.isRoundComplete {
                RoundCompleteView(
                    starsEarned: viewModel.lettersCompletedThisRound,
                    onPlayAgain: { viewModel.startNewRound() },
                    onDone: { coordinator.popToRoot() }
                )
            }
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

            // Faint letter behind the dotted guide, drawn from the stroke paths
            // themselves rather than a font glyph: a glyph's proportions never
            // matched the hand-authored strokes, so it sat off to one side of
            // the path it was meant to sit under. All strokes go into one path,
            // stroked once, so where they cross (A's crossbar, B's stem) the
            // overlap isn't drawn darker.
            Canvas { context, _ in
                var letterShape = Path()
                for path in viewModel.guidePaths {
                    letterShape.addPath(path)
                }
                context.stroke(
                    letterShape,
                    with: .color(tint.opacity(0.1)),
                    style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round, lineJoin: .round)
                )
            }

            // The dotted guide and the hit-testing both come from the same
            // LetterTracePathContent/TracePathSampler geometry, so they can't
            // drift apart the way the old glyph-vs-mask pair could. Strokes the
            // child isn't on yet are faded, so which one is live is obvious —
            // previously every stroke was drawn identically.
            Canvas { context, _ in
                for (index, path) in viewModel.guidePaths.enumerated() {
                    let isActive = index == viewModel.currentStrokeIndex
                    context.stroke(
                        path,
                        with: .color(tint.opacity(isActive ? 0.45 : 0.12)),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round, dash: [1, 16])
                    )
                }
            }

            // Which way to travel, visible before the child starts rather than
            // only once they are already moving.
            Canvas { context, _ in
                for marker in viewModel.directionMarkers {
                    let isActive = marker.strokeIndex == viewModel.currentStrokeIndex
                    context.stroke(
                        Self.arrowhead(at: marker.point, tangent: marker.tangent),
                        with: .color(tint.opacity(isActive ? 0.55 : 0.15)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            // Stroke order, for letters drawn in more than one piece.
            if viewModel.strokeCount > 1, !viewModel.isComplete {
                ForEach(Array(viewModel.strokeStartPoints.enumerated()), id: \.offset) { index, point in
                    Text("\(index + 1)")
                        .font(AppFonts.label.weight(.bold))
                        .foregroundStyle(AppColors.ink(on: tint))
                        .frame(width: 20, height: 20)
                        .background(tint.opacity(index == viewModel.currentStrokeIndex ? 0.9 : 0.25))
                        .clipShape(Circle())
                        .position(point)
                }
            }

            if !viewModel.isComplete, let start = viewModel.startPoint {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 18, height: 18)
                    .scaleEffect(isStartPulsing ? 1.35 : 1.0)
                    .opacity(isStartPulsing ? 0.55 : 1.0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                               value: isStartPulsing)
                    .position(start)
            }

            // The moving target now points the way instead of being a bare dot.
            if !viewModel.isComplete, let target = viewModel.nextTarget {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(tint)
                    .rotationEffect(.radians(atan2(target.tangent.dy, target.tangent.dx)))
                    .position(target.point)
                    .opacity(0.85)
            }

            // Ghost dot demonstrating the stroke. Cancelled the moment the
            // child touches down, so it never fights their input.
            if let demo = viewModel.demoProgress,
               let stroke = viewModel.currentStroke,
               let point = stroke.point(atArcLength: demo) {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 22, height: 22)
                    .overlay { Circle().stroke(.white, lineWidth: 3) }
                    .position(point)
                    .shadow(color: AppColors.success.opacity(0.5), radius: 6)
            }

            // The ink is the letter's own path revealed as far as the child has
            // genuinely traced — never the raw finger positions, so it cannot
            // render a line that isn't part of the letter.
            Canvas { context, _ in
                for path in viewModel.tracedPaths {
                    context.stroke(
                        path,
                        with: .color(tint),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                    )
                }
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
        .onAppear { isStartPulsing = true }
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

    /// A small chevron pointing along `tangent`, drawn as two strokes rather
    /// than an SF Symbol so it can live inside the same `Canvas` pass as the
    /// dotted guide instead of costing a view per marker.
    private static func arrowhead(at point: CGPoint, tangent: CGVector, size: CGFloat = 7) -> Path {
        let angle = atan2(tangent.dy, tangent.dx)
        let spread = CGFloat.pi * 0.78

        var path = Path()
        for side in [angle - spread, angle + spread] {
            path.move(to: point)
            path.addLine(to: CGPoint(x: point.x + cos(side) * size,
                                     y: point.y + sin(side) * size))
        }
        return path
    }

    private var controls: some View {
        HStack(spacing: AppSpacing.element) {
            Button {
                viewModel.tryAgain()
            } label: {
                Label("Try again", systemImage: "arrow.counterclockwise")
                    .font(AppFonts.body)
            }
            .buttonStyle(.bordered)

            Spacer()

            // Round progress (spec F27) — how many of this round's letters
            // are done, distinct from the coverage bar above, which tracks
            // progress through the *current* letter.
            Text("\(viewModel.lettersCompletedThisRound) of \(viewModel.lettersPerRound)")
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
                .lineLimit(1)

            Label("\(viewModel.starsThisSession)", systemImage: "star.fill")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.star)
        }
    }
}
