//
//  LearnNumbersView.swift
//  ToddlerLearningApp
//
//  Numbers-domain twin of LearnAlphabetView. The stage shows the number's
//  emoji *repeated* rather than a single picture, since counting the
//  quantity — not just naming the numeral — is the point.
//

import SwiftUI

struct LearnNumbersView: View {

    @State private var viewModel: LearnNumbersViewModel
    private let coordinator: AppCoordinator

    private let stripColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    init(viewModel: LearnNumbersViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.element) {
                if let number = viewModel.currentNumber {
                    numberStage(number)
                }

                navigationControls
                numberStrip
            }
            .padding(AppSpacing.screen)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Learn Numbers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private func numberStage(_ number: NumberItem) -> some View {
        let tint = AppColors.paletteColor(number.colorIndex)
        let countingColumns = Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: min(number.id, 5)
        )

        return VStack(spacing: AppSpacing.tight) {
            Text("\(number.id)")
                .font(AppFonts.letterHero)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: number)

            Text(number.name)
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)

            LazyVGrid(columns: countingColumns, spacing: 6) {
                ForEach(0..<number.id, id: \.self) { _ in
                    Text(number.emoji).font(.system(size: 34))
                }
            }
            .frame(maxWidth: 220)

            Button {
                viewModel.repeatSound()
            } label: {
                Label("Hear it again", systemImage: "speaker.wave.2.fill")
                    .font(AppFonts.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.section)
                    .frame(height: 52)
                    .background(tint)
                    .clipShape(Capsule())
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.top, AppSpacing.tight)

            if let rhyme = RhymeContent.rhymes(forNumber: number.id).first {
                Button {
                    coordinator.push(.rhymeDetail(rhyme.id))
                } label: {
                    Label("Hear a rhyme", systemImage: "music.note")
                        .font(AppFonts.caption)
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.element)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private var navigationControls: some View {
        HStack {
            arrowButton("chevron.left.circle.fill",
                        enabled: viewModel.canGoBack,
                        label: "Previous number") {
                viewModel.previous()
            }

            Spacer()

            Text(viewModel.positionCaption)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)

            Spacer()

            arrowButton("chevron.right.circle.fill",
                        enabled: viewModel.canGoForward,
                        label: "Next number") {
                viewModel.next()
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    private func arrowButton(_ systemName: String,
                             enabled: Bool,
                             label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 46))
                .foregroundStyle(enabled ? AppColors.primary : AppColors.disabledIcon)
                .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var numberStrip: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: stripColumns, spacing: 10) {
                ForEach(viewModel.numbers) { number in
                    NumberTile(
                        number: number,
                        mastery: viewModel.mastery(for: number),
                        isHighlighted: number == viewModel.currentNumber
                    ) {
                        viewModel.jump(to: number)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: .infinity)
    }
}
