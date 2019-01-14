import Foundation
import UIKit

class DraggableTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return DraggablePresentationController(presentedViewController: presented, presenting: source)
    }
}

private extension CGFloat {
    static let springDampingRatio: CGFloat = 0.7
    static let springInitialVelocityY: CGFloat =  10
}

private extension Double {
    static let animationDuration: Double = 0.3
}

enum DragDirection {
    case up
    case down
}

enum DraggablePosition {
    case open
    case midway
    case collapsed

    var heightMulitiplier: CGFloat {
        switch self {
        case .collapsed:
            return 0.2
        case .open:
            return 0.80
        case .midway:
            return 0.5
        }
    }

    var downBoundary: CGFloat {
        switch self {
        case .collapsed:
            return 0.0
        case .open:
            return 0.8
        case .midway:
            return 0.35
        }
    }

    var upBoundary: CGFloat {
        switch self {
        case .collapsed:
            return 0.0
        case .open:
            return 0.65
        case .midway:
            return 0.27
        }
    }

    func yOrigin(for maxHeight: CGFloat) -> CGFloat {
        return maxHeight - (maxHeight * heightMulitiplier)
    }
}

final class DraggablePresentationController: UIPresentationController {

    private var draggableView: DraggableViewType? {
        return presentedViewController as? DraggableViewType
    }

    private var presentedViewOriginY: CGFloat {
        return presentedView?.frame.origin.y ?? 0
    }

    // MARK: Private
    private var dimmingView = UIView()

    private var dragDirection: DragDirection = .up

    private var draggablePosition: DraggablePosition = .open {
        didSet {
            if draggablePosition == .open {
                draggableView?.handleInteraction(enabled: true)
            } else {
                draggableView?.handleInteraction(enabled: false)
            }
        }
    }

    private let springTiming = UISpringTimingParameters(dampingRatio: .springDampingRatio, initialVelocity: CGVector(dx: 0, dy: .springInitialVelocityY))
    private var animator: UIViewPropertyAnimator?

    private var maxFrame: CGRect {
        return CGRect(x: 0, y: 0, width: containerView?.bounds.width ?? 0, height: containerView?.bounds.height ?? 0)
    }

    private var panOnPresented = UIPanGestureRecognizer()

    private var containerViewGestureRecognizer = UITapGestureRecognizer()

    override var frameOfPresentedViewInContainerView: CGRect {
        let presentedViewOrigin = CGPoint(x: 0, y: draggablePosition.yOrigin(for: maxFrame.height))
        let presentedViewSize = CGSize(width: containerView?.bounds.width ?? 0,
                                       height: containerView?.bounds.height ?? 0)
        return CGRect(origin: presentedViewOrigin, size: presentedViewSize)
    }

    override func presentationTransitionWillBegin() {
        draggableView?.handleInteraction(enabled: true)
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        draggableView?.scrollView.delegate = self
        animator = UIViewPropertyAnimator(duration: .animationDuration, timingParameters: self.springTiming)
        animator?.isInterruptible = true
        panOnPresented = UIPanGestureRecognizer(target: self, action: #selector(userDidPan(panRecognizer:)))
        presentedView?.addGestureRecognizer(panOnPresented)
        containerViewGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(receivedTouch))
        containerViewGestureRecognizer.delegate = self
        containerView?.addGestureRecognizer(containerViewGestureRecognizer)
        animate(to: .open)
    }

    @objc func receivedTouch(tapRecognizer: UITapGestureRecognizer) {
        presentedViewController.dismiss(animated: true, completion: nil)
    }

    @objc private func userDidPan(panRecognizer: UIPanGestureRecognizer) {
        draggableView?.dismissKeyboard()
        draggableView?.scrollView.setContentOffset(.zero, animated: false)
        let translationPoint = panRecognizer.translation(in: presentedView)
        let currentOriginY = draggablePosition.yOrigin(for: maxFrame.height)
        let newOffset = translationPoint.y + currentOriginY
        let adjustedOffset = (newOffset < 0) ? -1 * newOffset : newOffset

        dragDirection = adjustedOffset > currentOriginY ? .down : .up

        let canDragInProposedDirection = dragDirection == .up &&
            draggablePosition == .open ? false : true

        if newOffset >= 0 && canDragInProposedDirection {
            switch panRecognizer.state {
            case .began, .changed:
                presentedView?.frame.origin.y = max(DraggablePosition.open.yOrigin(for: maxFrame.height), adjustedOffset)
            case .ended:
                animate(max(DraggablePosition.open.yOrigin(for: maxFrame.height), adjustedOffset))
            default:
                break
            }
        }
    }

    private func animate(_ dragOffset: CGFloat) {
        let distanceFromBottom = maxFrame.height - dragOffset

        switch dragDirection {
        case .up:
            if distanceFromBottom > (maxFrame.height * DraggablePosition.open.upBoundary) {
                animate(to: .open)
            } else if distanceFromBottom > (maxFrame.height * DraggablePosition.midway.upBoundary) {
                animate(to: .midway)
            } else {
                animate(to: .collapsed)
            }
        case .down:
            if distanceFromBottom > (maxFrame.height * DraggablePosition.open.downBoundary) {
                animate(to: .open)
            } else if distanceFromBottom > (maxFrame.height * DraggablePosition.midway.downBoundary) {
                animate(to: .midway)
            } else {
                animate(to: .collapsed)
            }
        }
    }

    func getDraggablePosition() -> DraggablePosition {
        let distanceFromBottom = maxFrame.height - presentedViewOriginY

        switch dragDirection {
        case .up:
            if distanceFromBottom > (maxFrame.height * DraggablePosition.open.upBoundary) {
                return .open
            } else if distanceFromBottom > (maxFrame.height * DraggablePosition.midway.upBoundary) {
                return .midway
            } else {
                return .collapsed
            }
        case .down:
            if distanceFromBottom > (maxFrame.height * DraggablePosition.open.downBoundary) {
                return .open
            } else if distanceFromBottom > (maxFrame.height * DraggablePosition.midway.downBoundary) {
                return .midway
            } else {
                return .collapsed
            }
        }
    }

    private func animate(to position: DraggablePosition) {
        guard let animator = animator else { return }

        animator.addAnimations {
            self.presentedView?.frame.origin.y = position.yOrigin(for: self.maxFrame.height)
        }

        animator.addCompletion { _ in
            self.draggablePosition = position
        }
        animator.startAnimation()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        presentedViewController.dismiss(animated: true)
    }
}

extension DraggablePresentationController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: presentedView)
        return presentedView?.bounds.contains(touchPoint) == false
    }
}

extension DraggablePresentationController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y <= 0, draggablePosition == .open {
            var yOrigin = presentedViewOriginY + (scrollView.contentOffset.y * -0.10)
            let downboundary = maxFrame.height - 84
            yOrigin = yOrigin < downboundary ? yOrigin : downboundary
            presentedView?.frame.origin.y = yOrigin
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        animate(to: getDraggablePosition())
    }
}


