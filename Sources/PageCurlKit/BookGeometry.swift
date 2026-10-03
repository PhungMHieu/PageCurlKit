//
//  BookGeometry.swift
//  PageCurlKit
//

import CoreGraphics

/// Kích thước trang và bố cục cho một vùng hiển thị.
///
/// Thường dùng trước khi dàn trang: biết `pageSize` mới chia được chữ vào từng trang.
public struct BookGeometry: Equatable, Sendable {
    public let layout: PageCurlLayout
    /// Kích thước một trang giấy.
    public let pageSize: CGSize

    /// Kích thước cả cuốn sách đang mở (1 hoặc 2 trang).
    public var bookSize: CGSize {
        CGSize(width: pageSize.width * CGFloat(layout.pagesPerView), height: pageSize.height)
    }

    /// - Parameters:
    ///   - layout: bố cục muốn dùng.
    ///   - size: vùng dành cho cuốn sách.
    ///   - maximumPageAspectRatio: trang không rộng quá `tỉ lệ × chiều cao`, để vẫn ra dáng trang sách
    ///     trên màn hình rất rộng.
    public init(layout: PageCurlLayout, fitting size: CGSize, maximumPageAspectRatio: CGFloat = 0.8) {
        let height = max(floor(size.height), 0)
        let width = max(floor(size.width / CGFloat(layout.pagesPerView)), 0)
        self.layout = layout
        pageSize = CGSize(width: min(width, floor(height * maximumPageAspectRatio)), height: height)
    }

    /// Tự chọn bố cục bằng `PageCurlLayout.preferred(for:minimumSpreadWidth:)`.
    public init(fitting size: CGSize, minimumSpreadWidth: CGFloat = 600, maximumPageAspectRatio: CGFloat = 0.8) {
        self.init(
            layout: .preferred(for: size, minimumSpreadWidth: minimumSpreadWidth),
            fitting: size,
            maximumPageAspectRatio: maximumPageAspectRatio
        )
    }
}
