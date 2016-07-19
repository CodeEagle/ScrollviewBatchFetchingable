//
//  File.swift
//  ScrollviewBatchFetchingable
//
//  Created by LawLincoln on 16/7/4.
//  Copyright © 2016年 CocoaPods. All rights reserved.
//

import Cocoa

private struct AssociatedKeys {
    static var LeadingScreensForBatching = "LeadingScreensForBatching"
    static var Observer = "Observer"
}

public enum SSBatchContextState { case Fetching, Cancelled, Completed }

public final class SSBatchContext {
    
    private lazy var _state: SSBatchContextState = SSBatchContextState.Completed
    
    private let _lockQueue = DispatchQueue.init(label: "com.SelfStudio.SSBatchContext.LockQueue")
    
    private func performLock(closure: () -> Void) {
        _lockQueue.sync(execute: closure)
    }
    
    public var fetching: Bool {
        let sem = DispatchSemaphore(value: 0)
        var isFetching = false
        _lockQueue.async {
            isFetching = self._state == .Fetching
            sem.signal()
        }
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        return isFetching
    }
    
    public func batchFetchingWasCancelled() {
        performLock { self._state = .Cancelled }
    }
    
    public func completeBatchFetching(didComplete: Bool) {
        if !didComplete { return }
        performLock { self._state = .Completed }
    }
    
    public func beginBatchFetching() {
        performLock { self._state = .Fetching }
    }
    
    public func cancelBatchFetching() {
        performLock { self._state = .Cancelled }
    }
}

private final class ScrollObserver: NSObject {
    
    private weak var _scrollview: NSScrollView?
    private lazy var _context: SSBatchContext = SSBatchContext()
    
    weak var _delegate: ScrollviewBatchFetchingable?
    
    init(view: NSScrollView) {
        super.init()
        _scrollview = view
        addObserver()
    }
    
    deinit {
        _delegate = nil
    }
    
    private func addObserver() {
        _scrollview?.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default().addObserver(forName: NSNotification.Name.NSViewBoundsDidChange, object: _scrollview?.contentView, queue: OperationQueue.main()) {[weak self] (note) in
            guard let sself = self, value = sself._scrollview else { return }
            
            if sself._context._state != .Fetching && value.ss_leadingScreensForBatching > 0 {
                
                let bounds = value.bounds
                // no fetching for null states
                if bounds.equalTo(CGRect.zero) { return }
                
                let leadingScreens = value.ss_leadingScreensForBatching
                let contentSize = value.contentSize
                let contentOffset = value.contentView.frame.origin
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
                
                if remainingDistance <= triggerDistance && remainingDistance > 0 {
                    
                    if let p = value as? ScrollviewBatchFetchingable {
                        sself._context._state = .Fetching
                        p.scrollView(scrollView: value, willBeginBatchFetchWithContext: sself._context)
                    } else {
                        sself._context._state = .Fetching
                        sself._delegate?.scrollView(scrollView: value, willBeginBatchFetchWithContext: sself._context)
                    }
                    
                }
            }
        }
        
        
    }
    
}

public extension NSScrollView {
    
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
    
    private var ss_ob: ScrollObserver? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.Observer) as? ScrollObserver }
        set(ob) { objc_setAssociatedObject(self, &AssociatedKeys.Observer, ob, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func setBatchDelegate(delegate: ScrollviewBatchFetchingable?) {
        ss_ob?._delegate = delegate
    }
    
}

public protocol ScrollviewBatchFetchingable: class {
    func scrollView(scrollView: NSScrollView, willBeginBatchFetchWithContext context: SSBatchContext)
}

