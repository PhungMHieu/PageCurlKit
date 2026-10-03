//
//  PageCurlView.swift
//  PageCurlKit
//
//  Ý tưởng bọc UIPageViewController cho SwiftUI học từ thư viện Pages
//  (https://github.com/nachonavarro/pages, MIT), viết lại để hỗ trợ chế độ 2 trang
//  và không bị lật thêm một lần sau mỗi lần cập nhật view.
//

import SwiftUI

/// Lật trang kiểu cong giấy như sách thật, dùng `UIPageViewController` với `.pageCurl`.
///
/// ```swift
/// PageCurlView(pages, currentPage: $page, layout: .spread) { page, side in
///     PageContent(page: page, side: side)
/// } blankPage: { side in
///     Paper(side: side)
/// }
/// ```
///
/// - `currentPage`: trang đang mở. Người dùng lật xong thì binding được ghi lại; gán giá trị mới từ code
///   thì trang lật tới đó (có hiệu ứng). Ở chế độ `.spread`, sau khi người dùng lật, giá trị là trang trái
///   của cặp; gán bất kỳ trang nào thì mở cặp chứa trang đó.
/// - Khi danh sách trang đổi (khác `id`), ví dụ sau khi dàn trang lại, view nhảy thẳng tới `currentPage`
///   mà không có hiệu ứng lật.
/// - `blankPage`: trang trắng chèn vào cuối khi mở 2 trang mà số trang lẻ.
public struct PageCurlView<Data: RandomAccessCollection, Page: View, Blank: View>: View where Data.Element: Identifiable {
    private let items: [Data.Element]
    private let currentPage: Binding<Int>
    private let layout: PageCurlLayout
    private let page: (Data.Element, PageSide) -> Page
    private let blankPage: (PageSide) -> Blank

    public init(
        _ data: Data,
        currentPage: Binding<Int>,
        layout: PageCurlLayout = .single,
        @ViewBuilder page: @escaping (Data.Element, PageSide) -> Page,
        @ViewBuilder blankPage: @escaping (PageSide) -> Blank
    ) {
        items = Array(data)
        self.currentPage = currentPage
        self.layout = layout
        self.page = page
        self.blankPage = blankPage
    }

    public var body: some View {
        let items = self.items
        let layout = self.layout
        let page = self.page
        let blankPage = self.blankPage

        PageCurlRepresentable(
            pageIDs: items.map { AnyHashable($0.id) },
            pageCount: items.count,
            layout: layout,
            // Chụp trang cần mở cùng lúc với danh sách trang. Nếu coordinator đọc thẳng binding, một lần
            // cập nhật muộn của view cũ sẽ thấy trang mới trên danh sách trang cũ và lật nhầm.
            requestedPage: currentPage.wrappedValue,
            currentPage: currentPage,
            content: { slot in
                let side = layout.side(forSlot: slot)
                return items.indices.contains(slot)
                    ? AnyView(page(items[slot], side))
                    : AnyView(blankPage(side))
            }
        )
        // Vị trí gáy sách chỉ đặt được lúc tạo UIPageViewController: đổi bố cục thì tạo mới.
        .id(layout)
    }
}

extension PageCurlView where Blank == EmptyView {
    /// Không cần trang trắng riêng (ô trống ở chế độ 2 trang sẽ trong suốt).
    public init(
        _ data: Data,
        currentPage: Binding<Int>,
        layout: PageCurlLayout = .single,
        @ViewBuilder page: @escaping (Data.Element, PageSide) -> Page
    ) {
        self.init(data, currentPage: currentPage, layout: layout, page: page, blankPage: { _ in EmptyView() })
    }
}

// MARK: - UIKit bridge

struct PageCurlRepresentable: UIViewControllerRepresentable {
    let pageIDs: [AnyHashable]
    let pageCount: Int
    let layout: PageCurlLayout
    /// Trang cần mở, chụp lúc dựng view (khớp với `pageIDs`).
    let requestedPage: Int
    /// Chỉ dùng để ghi lại trang sau khi người dùng lật.
    let currentPage: Binding<Int>
    let content: (Int) -> AnyView

    func makeCoordinator() -> PageCurlCoordinator {
        PageCurlCoordinator()
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let spine: UIPageViewController.SpineLocation = layout == .spread ? .mid : .min
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: spine.rawValue)]
        )
        // Mở 2 trang: mặt sau của trang phải khi lật chính là trang trái kế tiếp.
        controller.isDoubleSided = layout == .spread
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.update(controller, with: self)
    }
}

@MainActor
final class PageCurlCoordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private var pageIDs: [AnyHashable]?
    private var pageCount = 0
    private var layout: PageCurlLayout = .single
    private var content: (Int) -> AnyView = { _ in AnyView(EmptyView()) }
    private var currentPage: Binding<Int>?

    /// Các trang đã tạo, theo ô. Tạo khi UIPageViewController cần, bỏ bớt khi đã lật xa.
    private var pageControllers: [Int: PageHostingController] = [:]
    /// Ô đầu tiên đang hiển thị (trang trái khi mở 2 trang).
    private var displayedSlot: Int?
    /// Trang được yêu cầu ở lần cập nhật trước. Chỉ lật khi giá trị này đổi, nên một lần cập nhật
    /// còn mang giá trị cũ (trước khi binding kịp ghi lại sau khi người dùng lật) không kéo trang về.
    private var lastRequestedPage: Int?

    private var slotCount: Int {
        layout.slotCount(forPageCount: pageCount)
    }

    func update(_ controller: UIPageViewController, with configuration: PageCurlRepresentable) {
        let dataChanged = configuration.pageIDs != pageIDs
        pageIDs = configuration.pageIDs
        pageCount = configuration.pageCount
        layout = configuration.layout
        content = configuration.content
        currentPage = configuration.currentPage

        if dataChanged {
            pageControllers.removeAll()
        } else {
            // Nội dung trang có thể phụ thuộc state bên ngoài: dựng lại các trang đang giữ.
            for (slot, page) in pageControllers {
                page.rootView = content(slot)
            }
        }

        guard pageCount > 0 else {
            if dataChanged || displayedSlot != nil {
                showPlaceholder(in: controller)
            }
            return
        }

        let requested = configuration.requestedPage
        let requestChanged = requested != lastRequestedPage
        lastRequestedPage = requested
        let clamped = min(max(requested, 0), pageCount - 1)
        if clamped != requested {
            let binding = configuration.currentPage
            Task { @MainActor in binding.wrappedValue = clamped }
        }

        let target = layout.firstVisiblePage(for: clamped)
        guard let displayedSlot, !dataChanged else {
            show(target, in: controller, direction: .forward, animated: false)
            return
        }
        // Lật xong bằng tay thì binding ghi lại đúng trang đang hiện: không làm gì, tránh lật thêm lần nữa.
        guard requestChanged, target != displayedSlot else { return }
        show(target, in: controller, direction: target > displayedSlot ? .forward : .reverse, animated: true)
    }

    private func show(
        _ slot: Int,
        in controller: UIPageViewController,
        direction: UIPageViewController.NavigationDirection,
        animated: Bool
    ) {
        let visible = visibleControllers(startingAt: slot)
        displayedSlot = slot
        controller.setViewControllers(visible, direction: direction, animated: animated)
        trimPageControllers(around: slot, keeping: visible)
    }

    private func showPlaceholder(in controller: UIPageViewController) {
        displayedSlot = nil
        controller.setViewControllers(visibleControllers(startingAt: nil), direction: .forward, animated: false)
    }

    /// Luôn trả đúng `pagesPerView` controller: gáy ở giữa bắt buộc đủ cặp, thiếu một trang là
    /// UIPageViewController ném NSInvalidArgumentException. Ô không có trang thì dùng trang trống.
    private func visibleControllers(startingAt slot: Int?) -> [UIViewController] {
        (0..<layout.pagesPerView).map { offset -> UIViewController in
            guard let slot, let page = pageController(for: slot + offset) else {
                return PlaceholderPageController()
            }
            return page
        }
    }

    private func pageController(for slot: Int) -> PageHostingController? {
        guard slot >= 0, slot < slotCount else { return nil }
        if let existing = pageControllers[slot] {
            return existing
        }
        let page = PageHostingController(slot: slot, rootView: content(slot))
        pageControllers[slot] = page
        return page
    }

    /// Chỉ giữ vài trang quanh trang đang mở, để sách dài không tạo hàng trăm UIHostingController.
    private func trimPageControllers(around slot: Int, keeping visible: [UIViewController]) {
        let keptRange = (slot - 2 * layout.pagesPerView)...(slot + 3 * layout.pagesPerView)
        pageControllers = pageControllers.filter { entry in
            keptRange.contains(entry.key) || visible.contains { $0 === entry.value }
        }
    }

    // MARK: UIPageViewControllerDataSource

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let slot = (viewController as? PageHostingController)?.slot else { return nil }
        return pageController(for: slot - 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let slot = (viewController as? PageHostingController)?.slot else { return nil }
        return pageController(for: slot + 1)
    }

    // MARK: UIPageViewControllerDelegate

    /// Gọi khi giao diện đổi hướng (xoay máy, gập/mở máy). Nếu không trả lời, UIKit tự đặt lại trang
    /// theo mặc định và với gáy ở giữa có thể đưa vào 0 trang rồi crash. Vị trí gáy của một
    /// UIPageViewController không đổi (đổi bố cục là tạo cái mới), nên chỉ cần đặt lại đúng cặp đang mở.
    func pageViewController(
        _ pageViewController: UIPageViewController,
        spineLocationFor orientation: UIInterfaceOrientation
    ) -> UIPageViewController.SpineLocation {
        pageViewController.isDoubleSided = layout == .spread
        pageViewController.setViewControllers(
            visibleControllers(startingAt: displayedSlot),
            direction: .forward,
            animated: false
        )
        return layout == .spread ? .mid : .min
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visible = pageViewController.viewControllers,
              let first = visible.first as? PageHostingController else { return }
        displayedSlot = first.slot
        trimPageControllers(around: first.slot, keeping: visible)

        let page = min(first.slot, pageCount - 1)
        if let currentPage, currentPage.wrappedValue != page {
            currentPage.wrappedValue = page
        }
    }
}

/// Trang trống, dùng khi chưa có nội dung hoặc thiếu ô để đủ cặp.
final class PlaceholderPageController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}

/// Một trang: UIHostingController biết mình là ô số mấy, để data source tìm trang trước/sau
/// mà không phụ thuộc vào việc giữ đúng instance.
final class PageHostingController: UIHostingController<AnyView> {
    let slot: Int

    init(slot: Int, rootView: AnyView) {
        self.slot = slot
        super.init(rootView: rootView)
        view.backgroundColor = .clear
        // Trang nằm trong khung sách, không cần né safe area; tránh trang bị đẩy lệch khi đang cong.
        if #available(iOS 16.4, *) {
            safeAreaRegions = []
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
