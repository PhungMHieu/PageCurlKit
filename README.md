# PageCurlKit

Lật trang kiểu cong giấy như sách thật cho SwiftUI, chạy trên `UIPageViewController` (`.pageCurl`).

- **1 trang** (`.single`): gáy sách ở mép trái, cho màn hẹp.
- **2 trang liền nhau** (`.spread`): gáy ở giữa, lật cong quanh gáy, mặt sau trang phải là trang trái kế tiếp. Dùng cho iPad và iPhone xoay ngang.
- `BookGeometry` chọn bố cục và tính kích thước trang cho một vùng hiển thị, để dàn chữ trước khi hiển thị.

Yêu cầu iOS 16 trở lên, Swift 6.

## Thêm vào dự án

**Xcode:** File → Add Package Dependencies… → dán `https://github.com/PhungMHieu/PageCurlKit` → thêm product `PageCurlKit` vào target.

**Package.swift:**

```swift
.package(url: "https://github.com/PhungMHieu/PageCurlKit.git", branch: "main")
```

Khi repo có tag phiên bản, nên ghim theo phiên bản thay cho `branch: "main"`, ví dụ `from: "1.0.0"`.

## Cách dùng

```swift
import PageCurlKit

struct ReaderView: View {
    let pages: [MyPage]          // MyPage: Identifiable
    @State private var page = 0

    var body: some View {
        PageCurlView(pages, currentPage: $page) { page, side in
            MyPageView(page: page, side: side)
        }
    }
}
```

### Tự chuyển 1 trang ↔ 2 trang

```swift
GeometryReader { proxy in
    let geometry = BookGeometry(fitting: proxy.size)   // tự chọn .single / .spread

    PageCurlView(pages, currentPage: $page, layout: geometry.layout) { page, side in
        MyPageView(page: page, side: side)
    } blankPage: { side in
        Paper(side: side)        // trang trắng thêm vào cuối khi mở 2 trang mà số trang lẻ
    }
    .frame(width: geometry.bookSize.width, height: geometry.bookSize.height)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

**Nếu sách nằm trong vùng có thể co giãn** (cột detail của `NavigationSplitView`, có panel bên cạnh…): chọn bố cục theo kích thước **cả cửa sổ**, rồi chỉ dùng vùng chứa để tính kích thước trang. Nếu chọn theo vùng chứa, mở sidebar làm vùng hẹp lại và sách nhảy về 1 trang dù màn hình vẫn rộng.

```swift
@State private var layout: PageCurlLayout = .single

NavigationSplitView { … } detail: {
    GeometryReader { proxy in
        let geometry = BookGeometry(layout: layout, fitting: proxy.size)
        PageCurlView(pages, currentPage: $page, layout: geometry.layout) { … }
    }
}
.onGeometryChange(for: PageCurlLayout.self) { PageCurlLayout.preferred(for: $0.size) } action: { layout = $0 }
```

`side` (`PageSide`) cho biết trang nằm ở đâu so với gáy. Dùng `side.spineEdge` để vẽ bóng gáy, và đặt số trang ở góc ngoài.

Nếu cần dàn chữ theo kích thước trang, dùng `geometry.pageSize`. Nhớ đổi `id` của trang sau mỗi lần dàn lại (xem bên dưới).

## Hành vi của `currentPage`

| Tình huống | Kết quả |
|---|---|
| Người dùng lật xong | Binding được ghi lại (ở `.spread` là trang trái của cặp). View **không** lật thêm. |
| Code gán trang khác (mục lục, thanh trượt) | Lật cong tới trang đó, đúng chiều tới/lùi. |
| Gán trang thuộc cùng cặp đang mở (`.spread`) | Không làm gì. |
| Danh sách trang đổi `id` (dàn trang lại, đổi cỡ chữ…) | Nhảy thẳng tới `currentPage`, **không** hiệu ứng. |
| Đổi `layout` | Tạo lại `UIPageViewController` (vị trí gáy chỉ đặt được lúc tạo). |
| `currentPage` ngoài phạm vi | Kẹp về trang hợp lệ và ghi lại vào binding. |

View chỉ lật khi giá trị `currentPage` **thay đổi** so với lần cập nhật trước. Vì vậy binding phải thực sự lưu giá trị được ghi về (`@State`, hoặc thuộc tính của view model). Nếu bỏ qua giá trị ghi về, lần sau gán lại đúng trang cũ sẽ không có tác dụng.

`id` của trang phải đổi khi nội dung trang đổi. Nếu chỉ dùng số thứ tự trang làm `id`, sau khi dàn lại view sẽ không biết nội dung đã khác. Nên gộp cả lượt dàn trang vào `id`:

```swift
struct MyPage: Identifiable {
    struct ID: Hashable { let generation: Int; let index: Int }
    let id: ID
}
```

Nội dung trang được dựng lại mỗi khi `PageCurlView` cập nhật, nên trang tự đổi theo state bên ngoài (theme, font…) mà không cần đổi `id`.

## Lưu ý

- **Nút đè lên sách:** nếu đặt nút SwiftUI phía trên `PageCurlView` (thanh công cụ, panel), `UIPageViewController` bên dưới đôi khi giành mất cú chạm, nhất là ở gần mép trái. Khi overlay đang hiện, hãy tắt `allowsHitTesting` của vùng sách.
- **`.sheet` / `.popover`:** với cách bọc cũ (thư viện Pages), present sheet làm trang mất nội dung cho đến khi sheet đóng. Chưa kiểm lại với PageCurlKit, nên thử trước nếu cần dùng; cách an toàn là vẽ panel ngay trong màn hình.
- Chỉ giữ vài trang quanh trang đang mở, nên sách dài không tạo hàng trăm `UIHostingController`.

## Nguồn tham khảo

Ý tưởng bọc `UIPageViewController` cho SwiftUI học từ [nachonavarro/pages](https://github.com/nachonavarro/pages) (MIT). PageCurlKit viết lại để:

- không lật thêm một lần sau mỗi lần SwiftUI cập nhật view,
- tạo trang khi cần thay vì dựng sẵn mọi trang,
- phân biệt nhảy trang (có hiệu ứng) với dàn trang lại (không hiệu ứng),
- hỗ trợ chế độ 2 trang với gáy ở giữa.
