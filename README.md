# Antigravity Remote Control for iOS

Ứng dụng iOS native (SwiftUI + WKWebView) cho phép bạn truy cập, điều khiển và theo dõi các phiên làm việc của Google Antigravity trực tiếp từ iPhone.

## Tính năng
- Toàn màn hình (Full-screen immersion), không bị thanh địa chỉ hay thanh công cụ của Safari làm che khuất.
- Hỗ trợ vuốt điều hướng quay lại / tiến tới mượt mà.
- Hỗ trợ nút cài đặt nhanh (nút bánh răng) để chuyển đổi giữa https://antigravity.google (chính thức) hoặc địa chỉ IP mạng nội bộ (Local/Tunnel daemon).

## Cách lấy file .ipa qua GitHub Actions

1. Tạo một repository mới trên GitHub (có thể đặt là ntigravity-ios-remote và để chế độ Private).
2. Đẩy toàn bộ thư mục này lên repository đó:
   `ash
   git init
   git add .
   git commit -m "Initial iOS Antigravity app"
   git branch -M main
   git remote add origin https://github.com/<tai-khoan-cua-ban>/<repo-cua-ban>.git
   git push -u origin main
   `
3. Sau khi push xong, vào tab **Actions** trên GitHub:
   - Bạn sẽ thấy quy trình **Build iOS IPA** tự động chạy trên máy ảo macOS.
   - Quá trình build mất khoảng 1 - 2 phút.
4. Khi hoàn thành (dấu tích xanh), bấm vào lượt chạy đó, kéo xuống mục **Artifacts** để tải về file **AntigravityRemote-IPA.zip**.
5. Giải nén bạn sẽ có file AntigravityRemote.ipa.
6. Dùng chứng chỉ riêng của bạn (qua Sideloadly, AltStore, TrollStore, Scarlet, v.v.) để ký và cài vào iPhone.
