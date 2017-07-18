//
//  UITableView+PageLoadable.swift
//  LuooFM
//
//  Created by LawLincoln on 16/4/18.
//  Copyright © 2016年 Luoo.net. All rights reserved.
//

#if os(iOS)
    import UIKit
    public typealias ScrollView = UIScrollView
    import KVOBlock
#elseif os(OSX)
    import Cocoa
    public typealias ScrollView = NSScrollView
#endif
private struct AssociatedKeys {
	static var LeadingScreensForBatching = "LeadingScreensForBatching"
	static var Observer = "Observer"
}

public enum SSBatchContextState { case fetching, cancelled, completed }

public final class SSBatchContext {

	fileprivate lazy var _state: SSBatchContextState = .completed
    
    
    
	fileprivate let _lockQueue = DispatchQueue(label: "com.SelfStudio.SSBatchContext.LockQueue", attributes: [])

	fileprivate func performLock(_ closure: () -> ()) {
		_lockQueue.sync { closure() }
	}

	public var fetching: Bool {
		let sem = DispatchSemaphore(value: 0)
		var isFetching = false
		_lockQueue.async(execute: { () -> Void in
			isFetching = self._state == .fetching
			sem.signal()
		})
		_ = sem.wait(timeout: DispatchTime.distantFuture)
		return isFetching
	}

	public func batchFetchingWasCancelled() {
		performLock { self._state = .cancelled }
	}

	public func completeBatchFetching(_ didComplete: Bool) {
		if !didComplete { return }
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

	fileprivate weak var _scrollview: ScrollView?
	fileprivate lazy var _context: SSBatchContext = SSBatchContext()

	weak var _delegate: ScrollviewBatchFetchingable?
    private var _observer: NSObjectProtocol?

	init(view: ScrollView) {
		super.init()
		_scrollview = view
		addObserver()
	}

	deinit {
		_delegate = nil
        guard let ob = _observer else { return }
        NotificationCenter.default.removeObserver(ob)
	}

	fileprivate func addObserver() {
        #if os(iOS)
            _scrollview?.observeKeyPath("contentOffset", with: { [weak self](_, _, _) in
                self?.dealChange()
            })
        #elseif os(OSX)
            _scrollview?.contentView.postsFrameChangedNotifications = true
            _scrollview?.contentView.postsBoundsChangedNotifications = true
            
            _observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: nil, queue: OperationQueue.main) { [unowned self] _ in
                self.dealChange()
            }
            
        #endif
	}

    private func dealChange() {
        guard let value = _scrollview else { return }
        if _context._state != .fetching && value.ss_leadingScreensForBatching > 0 {
            
            let bounds = value.bounds
            // no fetching for null states
            if bounds.equalTo(CGRect.zero) { return }
            
            let leadingScreens = value.ss_leadingScreensForBatching
            #if os(iOS)
                let contentSize = value.contentSize
                let contentOffset = value.contentOffset
            #elseif os(OSX)
                let contentSize = value.documentView?.frame.size ?? .zero
                let contentOffset = value.contentView.bounds.origin
            #endif
            
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
            if abs(remainingDistance) <= triggerDistance {
                if let p = value as? ScrollviewBatchFetchingable {
                    _context._state = .fetching
                    p.scrollView(value, willBeginBatchFetchWithContext: _context)
                } else {
                    _context._state = .fetching
                    _delegate?.scrollView(value, willBeginBatchFetchWithContext: _context)
                }
            }
        }
    }
}

public extension ScrollView {

	/// Default is 0, set value to enable, if value < 0  will disable
	public var ss_leadingScreensForBatching: CGFloat {
		get {
			var factor: CGFloat = 0
			if let value = objc_getAssociatedObject(self, &AssociatedKeys.LeadingScreensForBatching) as? CGFloat {
				factor = value
			}
			return factor
		}
		set(factor) {
			if factor > 0 {
				if ss_ob == nil {
					ss_ob = ScrollObserver(view: self)
				}
			} else {
				ss_ob = nil
			}
			objc_setAssociatedObject(self, &AssociatedKeys.LeadingScreensForBatching, factor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}

	fileprivate var ss_ob: ScrollObserver? {
		get { return objc_getAssociatedObject(self, &AssociatedKeys.Observer) as? ScrollObserver }
		set(ob) { objc_setAssociatedObject(self, &AssociatedKeys.Observer, ob, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
	}

	public func setBatchDelegate(_ delegate: ScrollviewBatchFetchingable?) {
		ss_ob?._delegate = delegate
	}

}

public protocol ScrollviewBatchFetchingable: class {
	func scrollView(_ scrollView: ScrollView, willBeginBatchFetchWithContext context: SSBatchContext)
}
