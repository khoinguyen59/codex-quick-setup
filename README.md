# Codex Proxy Setup (One-Click)

Bộ cài đặt tự động cho Codex CLI và CodexAPI Gateway.

## Hướng dẫn sử dụng:

### 🪟 Dành cho Windows:
Chỉ cần **Click đúp chuột vào file `install-windows.bat`**.
*(Script sẽ tự động chạy dưới quyền Admin, cài Node.js nếu thiếu, cấu hình config và thiết lập chạy ngầm khi bật máy).*

### 🐧 Dành cho Ubuntu / Linux:

Đối với các máy chủ Ubuntu thông thường hoặc bản rút gọn (Minimal), bạn có thể cài đặt dễ dàng với các lệnh sau:

```bash
# 1. Tải bộ cài đặt về máy (Nếu báo lỗi 'git not found', hãy chạy: sudo apt update && sudo apt install git -y)
git clone https://github.com/khoinguyen59/codex-quick-setup.git

# 2. Di chuyển vào thư mục vừa tải
cd codex-quick-setup

# 3. Chạy script cài đặt
bash install-linux.sh
```

#### 🛠 Các lỗi thường gặp trên Ubuntu và cách xử lý:

1. **Lỗi `Command 'git' not found`**
   - **Nguyên nhân:** Máy chủ Ubuntu bản rút gọn (Minimal) không cài sẵn công cụ quản lý mã nguồn Git.
   - **Khắc phục:** Mở Terminal và chạy lệnh `sudo apt update && sudo apt install git -y`, sau đó thực hiện lại bước tải bộ cài đặt.

2. **Lỗi thiếu `node`, `npm`, hoặc `curl` (sudo: npm: command not found)**
   - **Nguyên nhân:** Tương tự, bản Ubuntu Minimal thường không có sẵn `npm` (dù có thể đã có lõi Node) hoặc thiếu cả trình tải file `curl`.
   - **Khắc phục TỰ ĐỘNG:** Bộ cài `install-linux.sh` đã được tối ưu để tự động phát hiện. Nếu thiếu, script sẽ tự động tải `curl` và Node.js v20 (kèm NPM) chuẩn từ NodeSource. Bạn **không cần phải can thiệp thủ công**, cứ để script tự động sửa lỗi và chạy tiếp.

3. **Cảnh báo vàng: `⚠ Codex's Linux sandbox uses bubblewrap...`**
   - **Nguyên nhân:** Khi khởi động CLI bằng lệnh `codex`, Terminal có thể hiển thị cảnh báo màu vàng về quyền "user namespaces" của Bubblewrap.
   - **Khắc phục:** Đây là thông báo **hoàn toàn bình thường** của cơ chế bảo mật Sandbox trên Linux. Nó **KHÔNG ẢNH HƯỞNG** đến tính năng phân tích code hay đọc/ghi file của AI. Bạn chỉ việc gõ tiếp yêu cầu lập trình (ví dụ: `hello`) và sử dụng bình thường.

### 🍎 Dành cho macOS:
Mở terminal tại thư mục này và chạy:
```bash
bash install-mac.sh
```

---
**Lưu ý:** Bạn cần chuẩn bị sẵn `API_KEY` do Admin cấp (dạng `sk-xxxx-xxxx...`) để dán vào khi cửa sổ cài đặt hiện lên yêu cầu.
