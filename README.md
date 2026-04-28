# Codex Proxy Setup (One-Click)

Bộ cài đặt tự động toàn diện cho Codex CLI và CodexAPI Gateway. Hỗ trợ Windows, macOS và Ubuntu.
Script này giúp bạn cài đặt môi trường Node.js (nếu thiếu), tự động tải bản Codex CLI mới nhất, cấu hình Proxy Gateway chặn thu thập dữ liệu (Telemetry), và thiết lập chạy ngầm cực kỳ ổn định.

---

## 🔑 YÊU CẦU CHUNG (QUAN TRỌNG)
Trước khi cài đặt, bạn **phải có sẵn `API_KEY`** do hệ thống cấp (định dạng `sk-xxxx-xxxx...`). Bạn sẽ cần dán mã key này vào cửa sổ dòng lệnh khi cài đặt.

---

## 🪟 Hướng Dẫn Cài Đặt Trên Windows

Hệ điều hành Windows hỗ trợ cài đặt vô cùng trực quan, không cần gõ lệnh phức tạp.

**Bước 1: Tải mã nguồn về máy**
1. Trên trang GitHub này, bấm vào nút xanh lá cây **"<> Code"** ở góc trên cùng bên phải.
2. Chọn **"Download ZIP"**.
3. Giải nén file ZIP vừa tải về ra một thư mục bất kỳ trên máy tính của bạn (ví dụ: Desktop hoặc Downloads).

**Bước 2: Chạy bộ cài đặt**
1. Mở thư mục vừa giải nén.
2. **Click đúp chuột** vào file `install-windows.bat`.
3. Một cửa sổ đen (Terminal) sẽ hiện ra (có thể Windows sẽ hỏi quyền Administrator, hãy chọn `Yes`).

**Bước 3: Nhập API Key**
1. Tại cửa sổ màu đen, hệ thống sẽ yêu cầu: `Nhap API_KEY cua ban:`
2. Bạn **Copy mã API_KEY** của bạn, **Click chuột phải** vào cửa sổ đen (hoặc nhấn `Ctrl + V`) để dán mã vào, sau đó nhấn **Enter**.
3. Đợi khoảng 1-2 phút. Khi màn hình hiện `CAI DAT THANH CONG! Proxy dang hoat dong. Mo terminal moi va go 'codex' de bat dau su dung.` là xong! Bạn có thể tắt cửa sổ đó.

---

## 🐧 Hướng Dẫn Cài Đặt Trên Ubuntu / Linux

Đối với Linux, chúng ta sẽ tải mã nguồn trực tiếp qua dòng lệnh (Terminal).

**Bước 1: Tải mã nguồn**
Mở Terminal của Ubuntu lên và chạy lệnh sau (copy rồi dán vào Terminal, nhấn Enter):
```bash
git clone https://github.com/khoinguyen59/codex-quick-setup.git
```
*(Lưu ý: Nếu màn hình báo lỗi `Command 'git' not found`, hãy chạy lệnh sửa lỗi này trước: `sudo apt update && sudo apt install git -y`, sau đó chạy lại lệnh git clone).*

**Bước 2: Di chuyển vào thư mục cài đặt**
```bash
cd codex-quick-setup
```

**Bước 3: Chạy Script cài đặt tự động**
```bash
bash install-linux.sh
```

**Bước 4: Nhập API Key**
1. Khi được hỏi `Nhap API_KEY cua ban:`, hãy dán key `sk-...` của bạn vào và nhấn Enter.
2. Script có thể sẽ yêu cầu bạn nhập mật khẩu của máy tính (để cấp quyền cài đặt `Node.js` và `systemd`). Cứ nhập mật khẩu và nhấn Enter.
3. Chờ đến khi thấy thông báo `CAI DAT THANH CONG!` là hoàn tất. Bây giờ bạn chỉ việc gõ `codex` là có thể tương tác với AI.

### 🛠 Các lỗi tự động được xử lý trên Ubuntu Minimal
- **Thiếu `npm` hoặc `curl`**: Một số máy Ubuntu siêu tối giản (Minimal) không cài sẵn `npm` hay `curl`. Bộ cài của chúng tôi **đã tự động tích hợp sẵn cơ chế vá lỗi**. Nó sẽ tự đi tìm, tự tải và cài chuẩn Node.js v20 từ NodeSource mà bạn **không cần thao tác thêm gì**.
- **Cảnh báo vàng: `⚠ Codex's Linux sandbox uses bubblewrap...`**: Lần đầu tiên chạy lệnh `codex`, bạn có thể thấy dòng cảnh báo màu vàng này. Đây là thông báo **hoàn toàn bình thường** của hệ thống bảo mật Sandbox trên Linux. Nó **không ảnh hưởng** đến khả năng code hay phân tích file của AI.

---

## 🍎 Hướng Dẫn Cài Đặt Trên macOS

**Bước 1: Tải mã nguồn**
Mở ứng dụng `Terminal` trên Mac và chạy lệnh:
```bash
git clone https://github.com/khoinguyen59/codex-quick-setup.git
cd codex-quick-setup
```

**Bước 2: Chạy Script cài đặt**
```bash
bash install-mac.sh
```
Làm tương tự bước dán `API_KEY` như các nền tảng khác. Script sẽ tự động gắn proxy vào trình chạy ngầm `launchd` của macOS để AI luôn sẵn sàng hoạt động mọi lúc.
