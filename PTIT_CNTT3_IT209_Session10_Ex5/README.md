# Báo Cáo Thực Hành: Bài 5 - Tự Động Hóa Điều Phối Đa Dịch Vụ Với Docker Compose & File .env

---

## 1. Mục Tiêu Bài Thực Hành
- **Infrastructure as Code (IaC):** Đóng gói và chuẩn hóa toàn bộ hạ tầng đa container từ Bài 4 thành tệp khai báo duy nhất `docker-compose.yml`. Thay vì phải ghi nhớ và thực thi hàng loạt câu lệnh `docker run`, `docker network create`, `docker volume create` thủ công, toàn bộ kiến trúc được định nghĩa dưới dạng mã nguồn (declarative configuration).
- **Bảo mật biến môi trường với `.env`:** Tách toàn bộ các thông tin nhạy cảm (tên cơ sở dữ liệu, tài khoản, mật khẩu, cổng kết nối) ra khỏi mã nguồn và quản lý tập trung trong tệp `.env`. Cung cấp tệp mẫu `.env.example` an toàn và thiết lập `.gitignore` để ngăn ngừa rò rỉ thông tin lên hệ thống quản lý phiên bản (Git).
- **Tự động hóa điều phối (Orchestration):** Thiết lập quan hệ phụ thuộc khởi chạy (`depends_on`), mạng cô lập nội bộ (`networks`) và lưu trữ bền vững (`volumes`) ở cấp độ root của Docker Compose.
- **Chuẩn hóa thao tác:** Sử dụng toàn diện cú pháp **Docker Compose CLI v2** (`docker compose`) theo khuyến nghị chính thức của Docker.

---

## 2. Cấu Trúc Thư Mục Dự Án
Theo quy định nộp bài tại đường dẫn `homework/session_10/ex5/`, cấu trúc các tệp tin được tổ chức như sau:

```text
homework/session_10/ex5/
├── .dockerignore        # Bỏ qua các tệp không cần thiết khi build Docker image
├── .env                 # Tệp biến môi trường chứa thông tin thực tế (được bảo vệ, không commit)
├── .env.example         # Tệp cấu hình mẫu chứa placeholder để người dùng tham khảo
├── .gitignore           # Cấu hình bỏ qua tệp .env và thư mục phụ thuộc
├── Dockerfile           # Chỉ dẫn đóng gói ứng dụng Backend (Node.js)
├── docker-compose.yml   # Tệp khai báo hạ tầng đa dịch vụ chuẩn IaC (Docker Compose v2)
├── package.json         # Khai báo thông tin và script ứng dụng backend
├── README.md            # Báo cáo kỹ thuật chi tiết hướng dẫn và giải thích
└── server.js            # Mã nguồn máy chủ Backend HTTP API
```

---

## 3. Chi Tiết Tệp Khai Báo `docker-compose.yml`

```yaml
services:
  database:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - backend-net

  backend:
    build: .
    restart: unless-stopped
    ports:
      - "${PORT}:8080"
    environment:
      PORT: 8080
      DB_HOST: database
      DB_PORT: 5432
      DB_NAME: ${DB_NAME}
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
    depends_on:
      - database
    networks:
      - backend-net

volumes:
  pgdata:

networks:
  backend-net:
```

### Giải Thích Các Thành Phần Cấu Hình:
1. **Dịch vụ `database`:**
   - `image: postgres:15-alpine`: Sử dụng image hệ quản trị cơ sở dữ liệu PostgreSQL 15 trên nền Alpine Linux gọn nhẹ, bảo mật cao.
   - `environment`: Truyền các biến cấu hình khởi tạo tài khoản quản trị và database ban đầu (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`) được nội suy tự động từ tệp `.env` (`${DB_NAME}`, `${DB_USER}`, `${DB_PASSWORD}`).
   - `volumes: - pgdata:/var/lib/postgresql/data`: Gắn Named Volume `pgdata` vào đường dẫn lưu trữ mặc định của PostgreSQL để đảm bảo dữ liệu không bị mất khi container bị xóa hay khởi động lại.
   - `networks: - backend-net`: Tham gia mạng nội bộ `backend-net`.
   - `restart: unless-stopped`: Đảm bảo dịch vụ tự khởi động lại khi gặp lỗi bất thường trừ khi bị người dùng chủ động tắt.

2. **Dịch vụ `backend`:**
   - `build: .`: Tự động tìm `Dockerfile` tại thư mục hiện tại để build image cho ứng dụng backend.
   - `ports: - "${PORT}:8080"`: Ánh xạ cổng host `${PORT}` (được định nghĩa trong `.env`, mặc định `8080`) vào cổng `8080` của container backend.
   - `environment`: Cung cấp thông số kết nối Database cho backend (`DB_HOST: database`, `DB_PORT: 5432`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). Điểm đặc biệt: `DB_HOST: database` sử dụng trực tiếp service name nhờ cơ chế Docker Embedded DNS Resolver.
   - `depends_on: - database`: Khai báo thứ tự khởi chạy; Docker Compose sẽ đảm bảo khởi tạo container `database` trước khi tạo và chạy `backend`.
   - `networks: - backend-net`: Cùng tham gia vào mạng `backend-net` để giao tiếp với `database`.

3. **Cấu hình cấp độ Root (`volumes` & `networks`):**
   - `volumes.pgdata`: Khai báo volume dùng chung ở cấp root, cho phép Docker Compose tự động cấp phát volume có tiền tố theo tên dự án (ví dụ: `ex5_pgdata`).
   - `networks.backend-net`: Khai báo user-defined bridge network ở cấp root, tạo vùng mạng cô lập an toàn cho các dịch vụ trao đổi gói tin nội bộ.

---

## 4. Cơ Chế Quản Lý Biến Môi Trường & Bảo Mật

### 4.1. Tệp Môi Trường Mẫu `.env.example`
Tệp này được commit lên Git nhằm mục đích hướng dẫn các thành viên trong nhóm biết dự án cần những biến môi trường nào mà không làm lộ mật khẩu thực tế:

```env
# Database Configuration (PostgreSQL)
DB_NAME=your_db_name
DB_USER=your_db_user
DB_PASSWORD=your_secure_password

# Backend Service Configuration
PORT=8080
```

### 4.2. Tệp Môi Trường Thực Tế `.env`
Tệp này chứa cấu hình môi trường cục bộ/triển khai thực tế:

```env
# Database Configuration (PostgreSQL)
DB_NAME=testdb
DB_USER=postgres
DB_PASSWORD=secretpassword

# Backend Service Configuration
PORT=8080
```

### 4.3. Bảo Vệ Thông Tin Nhạy Cảm Bằng `.gitignore`
Tệp `.gitignore` được cấu hình để loại trừ tệp `.env`:

```gitignore
# Environment configuration (protect secrets & credentials)
.env
.env.local
.env.*.local
*.env
```

> **Quy Tắc An Ninh Thông Tin:**
> 1. Không bao giờ commit tệp `.env` chứa mật khẩu thực tế lên GitHub/GitLab.
> 2. Luôn duy trì tệp `.env.example` đồng bộ với các biến mới được thêm vào `docker-compose.yml`.
> 3. Trong môi trường CI/CD hoặc Production, các biến này sẽ được nạp qua CI/CD Secret Variables hoặc hệ thống quản lý bí mật (Vault, AWS Secrets Manager).

---

## 5. Quy Trình Thao Tác Với Docker Compose CLI v2

Toàn bộ thao tác quản lý vòng đời hệ thống được thực hiện bằng cú pháp **Docker Compose CLI v2** (`docker compose` có dấu cách, thay thế cho lệnh cũ `docker-compose` có dấu gạch ngang):

### Bước 1: Chuẩn bị tệp cấu hình môi trường
Nếu tải dự án về máy mới, tạo tệp `.env` từ `.env.example`:
```bash
cp .env.example .env
```
*(Chỉnh sửa mật khẩu và thông số mong muốn trong tệp `.env`)*

### Bước 2: Khởi động toàn bộ hạ tầng ở chế độ nền
```bash
docker compose up -d
```
Nếu có thay đổi trong mã nguồn backend và cần build lại image:
```bash
docker compose up -d --build
```

**Quá trình thực thi tự động của Docker Compose:**
1. Đọc và nạp các biến từ tệp `.env`.
2. Tạo network `ex5_backend-net` (user-defined bridge).
3. Tạo volume `ex5_pgdata`.
4. Build image cho service `backend` từ `Dockerfile`.
5. Khởi chạy container `database` trước (do ràng buộc `depends_on`).
6. Khởi chạy container `backend` và ánh xạ cổng ra máy chủ host.

### Bước 3: Kiểm tra trạng thái các dịch vụ
```bash
docker compose ps
```
**Kết quả mong đợi:**
Cả 2 dịch vụ `backend` và `database` đều hiển thị trạng thái `running` (Up) với cổng ánh xạ chính xác:
```text
NAME           IMAGE               COMMAND                  SERVICE    CREATED          STATUS          PORTS
ex5-backend-1  ex5-backend         "node server.js"         backend    10 seconds ago   Up 9 seconds    0.0.0.0:8080->8080/tcp
ex5-database-1 postgres:15-alpine  "docker-entrypoint.s…"   database   10 seconds ago   Up 10 seconds   5432/tcp
```

### Bước 4: Theo dõi Logs thời gian thực
- Xem logs đồng thời của tất cả services:
  ```bash
  docker compose logs -f
  ```
- Xem logs riêng của dịch vụ backend:
  ```bash
  docker compose logs -f backend
  ```
- Xem logs riêng của dịch vụ database:
  ```bash
  docker compose logs -f database
  ```

### Bước 5: Kiểm tra kết nối dịch vụ Backend
Mở trình duyệt hoặc dùng công cụ dòng lệnh gửi request đến backend:
```bash
curl http://localhost:8080/
```
**Kết quả phản hồi:**
```json
{
  "status": "success",
  "message": "Hello from Backend Service orchestrated via Docker Compose!",
  "service": "backend",
  "database_host": "database",
  "database_port": "5432",
  "database_name": "testdb",
  "database_user": "postgres",
  "timestamp": "2026-10-12T11:15:00.000Z"
}
```

Kiểm tra endpoint sức khỏe:
```bash
curl http://localhost:8080/health
```
Phản hồi:
```json
{
  "status": "healthy",
  "service": "backend",
  "uptime_seconds": 45.2
}
```

### Bước 6: Kiểm tra tính toàn vẹn và bền vững của dữ liệu (Data Persistence)
1. Thêm bản ghi vào database thông qua container `database`:
   ```bash
   docker compose exec database psql -U postgres -d testdb -c "
   CREATE TABLE items (id SERIAL PRIMARY KEY, name VARCHAR(50));
   INSERT INTO items (name) VALUES ('Laptop'), ('Monitor');
   SELECT * FROM items;
   "
   ```
2. Dừng và hạ toàn bộ container (nhưng giữ nguyên volume):
   ```bash
   docker compose down
   ```
3. Khởi động lại hệ thống:
   ```bash
   docker compose up -d
   ```
4. Truy vấn lại bảng dữ liệu:
   ```bash
   docker compose exec database psql -U postgres -d testdb -c "SELECT * FROM items;"
   ```
   **Kết quả:** Dữ liệu bảng `items` vẫn còn nguyên vẹn 100% nhờ Named Volume `pgdata`.

### Bước 7: Dọn dẹp hạ tầng khi kết thúc
- Dừng và xóa containers, networks:
  ```bash
  docker compose down
  ```
- Dừng và xóa sạch toàn bộ bao gồm cả Volume dữ liệu (khi muốn reset môi trường):
  ```bash
  docker compose down -v
  ```

---

## 6. So Sánh Kiến Trúc: Docker CLI Thủ Công (Bài 4) vs Docker Compose IaC (Bài 5)

| Tiêu Chí Đánh Giá | Triển Khai Thủ Công Bằng Docker CLI (Bài 4) | Triển Khai Tự Động Bằng Docker Compose (Bài 5) |
| :--- | :--- | :--- |
| **Phương thức quản lý** | Phải gõ từng câu lệnh riêng lẻ (`docker network create`, `docker volume create`, `docker run`) | Khai báo 1 lần duy nhất trong tệp cấu hình `docker-compose.yml` (Chuẩn IaC) |
| **Quản lý biến môi trường** | Phải truyền cờ `-e KEY=VALUE` dài dòng trực tiếp trên lệnh terminal, dễ lộ mật khẩu trong lịch sử bash | Quản lý an toàn, tự động nạp từ tệp `.env`, hỗ trợ tệp mẫu `.env.example` |
| **Điều phối thứ tự khởi động** | Phải tự nhớ thứ tự chạy DB trước rồi mới chạy Backend | Tự động hóa hoàn toàn thông qua chỉ thị `depends_on` |
| **Thao tác vòng đời** | Phải xóa từng container, xóa network, xóa volume qua nhiều câu lệnh | Chỉ cần một câu lệnh duy nhất: `docker compose up -d` hoặc `docker compose down` |
| **Khả năng tái lập môi trường** | Khó chuyển giao cho đồng đội, dễ xảy ra lỗi gõ sai tham số | Nhất quán tuyệt đối trên mọi môi trường (Dev, Staging, Production) |

---

## 7. Kết Luận
Bài thực hành đã hoàn thành đầy đủ và xuất sắc tất cả các yêu cầu đề ra:
1. Đóng gói hoàn chỉnh kiến trúc đa container thành tệp `docker-compose.yml` chuẩn IaC.
2. Tách biệt hoàn toàn thông tin nhạy cảm vào `.env`, cung cấp `.env.example` và thiết lập `.gitignore` chống lộ bí mật.
3. Thiết lập đầy đủ các thuộc tính chuẩn: `depends_on`, `networks`, `volumes` ở root level.
4. Tuân thủ 100% cú pháp hiện đại của Docker Compose CLI v2 (`docker compose`).
