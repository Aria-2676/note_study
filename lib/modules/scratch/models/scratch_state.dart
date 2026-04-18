enum ScratchState {
    idle,
    scratching,
    revealed,
}

extension ScratchStateExtension on ScratchState {
    bool get canStartScratch => this == ScratchState.idle;
    bool get isScratching => this == ScratchState.scratching;
    bool get isRevealed => this == ScratchState.revealed;
    bool get canChangeCost => this == ScratchState.idle;
}
