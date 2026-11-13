import SwiftUI
import UIKit

/// Adds the experimenter's three-finger upward completion gesture around the
/// package view. Descendant map exploration and back recognizers stay intact.
struct ResearcherMapContainer<Content: View>: UIViewControllerRepresentable {
    var onComplete: () -> Void
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> ResearcherMapController<Content> {
        ResearcherMapController(content: content(), onComplete: onComplete)
    }

    func updateUIViewController(_ controller: ResearcherMapController<Content>, context: Context) {
        controller.host.rootView = content()
        controller.completionView.onComplete = onComplete
    }
}

final class ResearcherMapController<Content: View>: UIViewController {
    let host: UIHostingController<Content>
    let completionView = ResearcherCompletionView(frame: .zero)

    init(content: Content, onComplete: @escaping () -> Void) {
        host = UIHostingController(rootView: content)
        super.init(nibName: nil, bundle: nil)
        completionView.onComplete = onComplete
    }

    required init?(coder: NSCoder) { fatalError("Use init(content:onComplete:)") }

    override func loadView() {
        view = completionView
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        completionView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: completionView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: completionView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: completionView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: completionView.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}

final class ResearcherCompletionView: UIView, UIGestureRecognizerDelegate {
    var onComplete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(finishExploration))
        swipe.direction = .up
        swipe.numberOfTouchesRequired = 3
        swipe.cancelsTouchesInView = false
        swipe.delegate = self
        addGestureRecognizer(swipe)
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    @objc private func finishExploration() { onComplete?() }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard direction == .up else { return super.accessibilityScroll(direction) }
        onComplete?()
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
