//
//  PageCurlLayout.swift
//  PageCurlKit
//

import SwiftUI

/// Cách bày trang khi lật.
public enum PageCurlLayout: Hashable, Sendable {
    /// Một trang, gáy sách ở mép trái — màn hẹp (iPhone dọc).
    case single
    /// Hai trang liền nhau như cuốn sách mở, gáy ở giữa — màn rộng (iPad, iPhone xoay ngang).
    case spread

    /// Chọn bố cục theo vùng hiển thị: nằm ngang và đủ rộng thì mở 2 trang.
    public static func preferred(for size: CGSize, minimumSpreadWidth: CGFloat = 600) -> PageCurlLayout {
        size.width >= size.height && size.width >= minimumSpreadWidth ? .spread : .single
    }

    /// Số trang hiển thị cùng lúc.
    public var pagesPerView: Int {
        self == .spread ? 2 : 1
    }

    /// Số ô trang cần dựng: chế độ 2 trang luôn cần số chẵn, thiếu thì thêm 1 trang trắng.
    public func slotCount(forPageCount pageCount: Int) -> Int {
        let count = max(pageCount, 0)
        return self == .spread ? count + count % 2 : count
    }

    /// Trang đầu tiên (trang trái khi mở 2 trang) của màn đang chứa `page`. `page` phải ≥ 0.
    public func firstVisiblePage(for page: Int) -> Int {
        self == .spread ? page - page % 2 : page
    }

    /// Các trang đang hiển thị khi mở tới `page`, đã giới hạn trong `0..<pageCount`.
    public func visiblePages(for page: Int, pageCount: Int) -> ClosedRange<Int>? {
        guard pageCount > 0 else { return nil }
        let first = firstVisiblePage(for: min(max(page, 0), pageCount - 1))
        return first...min(first + pagesPerView - 1, pageCount - 1)
    }

    /// Vị trí của ô trang `slot` so với gáy sách.
    public func side(forSlot slot: Int) -> PageSide {
        switch self {
        case .single: .single
        case .spread: slot.isMultiple(of: 2) ? .left : .right
        }
    }
}

/// Vị trí của một trang so với gáy sách — dùng để vẽ bóng gáy, đặt số trang…
public enum PageSide: Hashable, Sendable {
    /// Một trang, gáy ở mép trái.
    case single
    /// Trang trái khi mở 2 trang, gáy ở mép phải.
    case left
    /// Trang phải khi mở 2 trang, gáy ở mép trái.
    case right

    /// Mép trang nằm sát gáy sách.
    public var spineEdge: HorizontalEdge {
        self == .left ? .trailing : .leading
    }
}
