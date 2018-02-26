//
//  UITableView+PageLoadable.swift
//  LuooFM
//
//  Created by LawLincoln on 16/4/18.
//  Copyright © 2016年 Luoo.net. All rights reserved.
//

import UIKit

public protocol ScrollviewBatchFetchingable: class {
    func scrollView(_ scrollView: UIScrollView, willBeginBatchFetchWithContext context: BatchFetchingContext)
}
public final class BatchFetchingContext {

	fileprivate lazy var _state: BatchFetchingContextState = .completed
    
    /// Default is 0, set value to enable, if value < 0  will disable
    public var leadingScreensForBatching: CGFloat = 0
    public weak var delegate: ScrollviewBatchFetchingable?
    
	private let _lockQueue = DispatchQueue(label: "com.SelfStudio.SSBatchContext.LockQueue")

	private func performLock(_ closure: () -> ()) {
		_lockQueue.sync { closure() }
	}

	public var fetching: Bool {
		let sem = DispatchSemaphore(value: 0)
		var isFetching = false
        _lockQueue.async {
			isFetching = self._state == .fetching
			sem.signal()
		}
		_ = sem.wait(timeout: DispatchTime.distantFuture)
		return isFetching
	}

	public func batchFetchingWasCancelled() {
		performLock { self._state = .cancelled }
	}

	public func completeBatchFetching(_ didComplete: Bool = true) {
		if didComplete == false { return }
		performLock { self._state = .completed }
	}

	public func beginBatchFetching() {
		performLock { self._state = .fetching }
	}

	public func cancelBatchFetching() {
		performLock { self._state = .cancelled }
	}
}

private final class ScrollObserver: NSObject {

	private weak var _scrollview: UIScrollView?
	fileprivate lazy var context: BatchFetchingContext = BatchFetchingContext()

	init(view: UIScrollView) {
		super.init()
		_scrollview = view
		addObserver()
	}

	private func addObserver() {
		_scrollview?.observeKeyPath("contentOffset", with: { [weak self](_, _, _) in
			guard let sself = self, let value = sself._scrollview else { return }

            guard sself.context._state != .fetching, sself.context.leadingScreensForBatching > 0 else { return }

            let bounds = value.bounds
            // no fetching for null states
            if bounds.equalTo(CGRect.zero) { return }
        
            let leadingScreens = sself.context.leadingScreensForBatching
            let contentSize = value.contentSize
            let contentOffset = value.contentOffset
            let isVertical = bounds.width == contentSize.width

            var viewLength: CGFloat = 0
            var offset: CGFloat = 0
            var contentLength: CGFloat = 0

            if isVertical {
                viewLength = bounds.height
                offset = contentOffset.y
                contentLength = contentSize.height
            } else { // horizontal
                viewLength = bounds.width
                offset = contentOffset.x
                contentLength = contentSize.width
            }

            // target offset will always be 0 if the content size is smaller than the viewport
            let triggerDistance = viewLength * leadingScreens
            let remainingDistance = contentLength - viewLength - offset
            guard  remainingDistance <= triggerDistance, remainingDistance > 0 else { return }
            sself.context._state = .fetching
            var delegate: ScrollviewBatchFetchingable? = sself.context.delegate
            if let p = value as? ScrollviewBatchFetchingable { delegate = p }
            delegate?.scrollView(value, willBeginBatchFetchWithContext: sself.context)
		})
	}

}

public extension UIScrollView {
    
	private var observer: ScrollObserver {
        guard let ob = objc_getAssociatedObject(self, &AssociatedKeys.Observer) as? ScrollObserver else {
            let ob = ScrollObserver(view: self)
            objc_setAssociatedObject(self, &AssociatedKeys.Observer, ob, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return ob
        }
        return ob
	}
    
    public var batchFetchingContext: BatchFetchingContext {
        return observer.context
    }
}

private struct AssociatedKeys {
    static var LeadingScreensForBatching = "LeadingScreensForBatching"
    static var Observer = "Observer"
}

public enum BatchFetchingContextState { case fetching, cancelled, completed }
