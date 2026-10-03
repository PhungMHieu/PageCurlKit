//
//  PageCurlLayoutTests.swift
//  PageCurlKitTests
//

import CoreGraphics
import Testing
@testable import PageCurlKit

struct PageCurlLayoutTests {

    @Test func choosesSpreadOnlyForWideLandscapeAreas() {
        #expect(PageCurlLayout.preferred(for: CGSize(width: 402, height: 874)) == .single)
        #expect(PageCurlLayout.preferred(for: CGSize(width: 874, height: 402)) == .spread)
        // Ngang nhưng hẹp hơn ngưỡng.
        #expect(PageCurlLayout.preferred(for: CGSize(width: 500, height: 300)) == .single)
        #expect(PageCurlLayout.preferred(for: CGSize(width: 500, height: 300), minimumSpreadWidth: 400) == .spread)
    }

    @Test func spreadPadsOddPageCountWithBlankSlot() {
        #expect(PageCurlLayout.single.slotCount(forPageCount: 5) == 5)
        #expect(PageCurlLayout.spread.slotCount(forPageCount: 5) == 6)
        #expect(PageCurlLayout.spread.slotCount(forPageCount: 6) == 6)
        #expect(PageCurlLayout.spread.slotCount(forPageCount: 0) == 0)
    }

    @Test func visiblePagesFollowSpreadPairs() {
        #expect(PageCurlLayout.single.visiblePages(for: 3, pageCount: 10) == 3...3)
        #expect(PageCurlLayout.spread.visiblePages(for: 3, pageCount: 10) == 2...3)
        #expect(PageCurlLayout.spread.visiblePages(for: 4, pageCount: 10) == 4...5)
        // Trang cuối lẻ: chỉ còn trang trái.
        #expect(PageCurlLayout.spread.visiblePages(for: 8, pageCount: 9) == 8...8)
        // Ngoài phạm vi thì kẹp lại.
        #expect(PageCurlLayout.spread.visiblePages(for: 99, pageCount: 9) == 8...8)
        #expect(PageCurlLayout.single.visiblePages(for: 0, pageCount: 0) == nil)
    }

    @Test func sidesAlternateAroundSpine() {
        #expect(PageCurlLayout.single.side(forSlot: 1) == .single)
        #expect(PageCurlLayout.spread.side(forSlot: 0) == .left)
        #expect(PageCurlLayout.spread.side(forSlot: 1) == .right)
        #expect(PageSide.left.spineEdge == .trailing)
        #expect(PageSide.right.spineEdge == .leading)
        #expect(PageSide.single.spineEdge == .leading)
    }
}

struct BookGeometryTests {

    @Test func singlePageFillsWidth() {
        let geometry = BookGeometry(fitting: CGSize(width: 395.5, height: 760))
        #expect(geometry.layout == .single)
        #expect(geometry.pageSize == CGSize(width: 395, height: 760))
        #expect(geometry.bookSize == geometry.pageSize)
    }

    @Test func spreadSplitsWidthAndCapsAspectRatio() {
        // Mỗi trang tối đa 0.8 × 400 = 320, dù vùng chia đôi được 500.
        let geometry = BookGeometry(fitting: CGSize(width: 1000, height: 400))
        #expect(geometry.layout == .spread)
        #expect(geometry.pageSize == CGSize(width: 320, height: 400))
        #expect(geometry.bookSize == CGSize(width: 640, height: 400))
    }

    @Test func explicitLayoutIsRespected() {
        let geometry = BookGeometry(layout: .single, fitting: CGSize(width: 1000, height: 400), maximumPageAspectRatio: 1)
        #expect(geometry.layout == .single)
        #expect(geometry.pageSize == CGSize(width: 400, height: 400))
    }
}
