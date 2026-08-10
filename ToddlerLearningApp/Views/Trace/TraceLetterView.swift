//
//  TraceLetterView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct TraceLetterView: View {

    @State private var viewModel: TraceLetterViewModel
    private let coordinator: AppCoordinator

    init(viewModel: TraceLetterViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.element) {
                if let letter = viewModel.currentLetter {
                    header(letter)
                    canvas(letter)
                    ProgressBar(value: viewModel.coverage, tint: AppColors.paletteColor(letter.colorIndex))
                    controls
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)

            StarBurstView(isActive: viewModel.isComplete)
        }
        .navigationTitle("Trace Letters")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private func header(_ letter: Letter) -> some View {
        HStack {
            Button {
                viewModel.previous()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(viewModel.canGoBack ? AppColors.primary : AppColors.disabledIcon)
                    .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .disabled(!viewModel.canGoBack)
            .accessibilityLabel("Previous letter")

            Spacer()

            VStack(spacing: 2) {
                Text(letter.uppercase)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)
                Text(viewModel.positionCaption)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)
            }

            Spacer()

            Button {
                viewModel.next()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(viewModel.canGoForward ? AppColors.primary : AppColors.disabledIcon)
                    .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .disabled(!viewModel.canGoForward)
            .accessibilityLabel("Next letter")
        }
    }

    private func canvas(_ letter: Letter) -> some View {
        let tint = AppColors.paletteColor(letter.colorIndex)
        let size = TraceLetterViewModel.canvasSize

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
