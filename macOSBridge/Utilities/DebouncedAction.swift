//
//  DebouncedAction.swift
//  macOSBridge
//

import Foundation

/// Runs an action once, `delay` after the latest of a burst of triggers
/// (trailing debounce). Call `trigger` and `cancel` on the main queue.
final class DebouncedAction {
    private let delay: TimeInterval
    private let action: () -> Void
    private var pending: DispatchWorkItem?

    init(delay: TimeInterval, action: @escaping () -> Void) {
        self.delay = delay
        self.action = action
    }

    func trigger() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pending = nil
            self.action()
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }

    deinit {
        pending?.cancel()
    }
}
