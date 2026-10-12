# Báo Cáo Thực Hành: Bài 4 - Thiết Lập Custom Network & Named Volume Bằng Docker CLI

---

## 1. Mục Tiêu Bài Thực Hành
- **Custom Bridge Network:** Tạo Docker Bridge Network tùy biến (`app-net`) để kích hoạt cơ chế Docker Embedded DNS Resolver, cho phép các container giao tiếp nội bộ thông qua tên container (`db-server`) thay vì địa chỉ IP động.
- **Named Volume & Data Persistence:** Tạo Named Volume (`db-data`) để tách rời tầng lưu trữ (storage layer) khỏi vòng đời của container (container lifecycle), đảm bảo dữ liệu của cơ sở dữ liệu PostgreSQL không bị mất khi container bị xóa bỏ (`docker rm -f`).
- **Mô hình kết nối đa container:** Giả lập kiến trúc Backend Web API (`app-container`) kết nối với Database (`db-server`).

---

## 2. Cấu Trúc Thư Mục
Theo quy định nộp bài, các tệp được tổ chức như sau:

```text
homework/session_10/ex4/
├── commands.sh      # Script tự động thực thi toàn bộ quy trình thiết lập & kiểm thử
└── README.md        # Tài liệu hướng dẫn, giải thích chi tiết câu lệnh và kết quả
```

---

## 3. Danh Sách Câu Lệnh Chi Tiết & Giải Thích

### Bước 1: Tạo Custom Bridge Network
```bash
docker network create --driver bridge app-net
```
* **Giải thích:** Tạo mạng bridge mang tên `app-net`. Khác với mạng bridge mặc định (`bridge`), mạng user-defined bridge cung cấp tính năng **Automatic Service Discovery qua DNS nội bộ**. Các container trong cùng mạng có thể truy cập lẫn nhau thông qua tên container.

---

### Bước 2: Tạo Named Volume
```bash
docker volume create db-data
```
* **Giải thích:** Tạo volume được quản lý bởi Docker Engine mang tên `db-data`. Dữ liệu ghi vào volume này sẽ được lưu trữ an toàn trên máy host, độc lập với vòng đời của container.

---

### Bước 3: Khởi chạy Database Container (`db-server`)
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword \
  -e POSTGRES_DB=testdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```
* **Giải thích các tham số:**
  * `-d`: Chạy container ở chế độ nền (detached mode).
  * `--name db-server`: Đặt tên container là `db-server` (đây cũng là hostname nội bộ trong mạng).
  * `--network app-net`: Gán container vào mạng `app-net`.
  * `-e POSTGRES_USER=postgres`, `-e POSTGRES_PASSWORD=secretpassword`, `-e POSTGRES_DB=testdb`: Cấu hình tài khoản, mật khẩu và tên cơ sở dữ liệu khởi tạo.
  * `-v db-data:/var/lib/postgresql/data`: Mount volume `db-data` vào thư mục lưu trữ dữ liệu của PostgreSQL (`/var/lib/postgresql/data`).
  * `postgres:15-alpine`: Image cơ sở dữ liệu PostgreSQL phiên bản 15 bản nhẹ Alpine.

---

### Bước 4: Khởi chạy Backend Container (`app-container`)
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=secretpassword \
  -e DB_NAME=testdb \
  alpine sleep 3600
```
* **Giải thích các tham số:**
  * `--name app-container`: Container đóng vai trò backend.
  * `--network app-net`: Cùng tham gia vào mạng `app-net` với `db-server`.
  * `-e DB_HOST=db-server`: Truyền hostname của Database bằng tên service `db-server`.
  * `alpine sleep 3600`: Sử dụng hệ điều hành Alpine nhỏ gọn chạy nền để tiến hành kiểm thử mạng qua lệnh `ping`.

---

### Bước 5: Kiểm Tra Kết Nối Mạng & Phân Giải Tên Miền (DNS Resolution)

1. **Kiểm tra danh sách mạng:**
   ```bash
   docker network ls | grep app-net
   ```
2. **Kiểm tra danh sách volume:**
   ```bash
   docker volume ls | grep db-data
   ```
3. **Kiểm tra chi tiết thông số mạng:**
   ```bash
   docker network inspect app-net
   ```
   *(Hiển thị danh sách container đang kết nối và IP nội bộ được cấp phát)*
4. **Kiểm tra ping từ `app-container` sang `db-server`:**
   ```bash
   docker exec -it app-container ping -c 2 db-server
   ```
   * **Kết quả:** Lệnh ping giải mã thành công IP nội bộ của container `db-server` thông qua DNS nội bộ của Docker.

---

### Bước 6: Kiểm Thử Tính Bền Vững Của Dữ Liệu (Data Persistence Test)

1. **Thêm dữ liệu mẫu vào cơ sở dữ liệu `db-server`:**
   ```bash
   docker exec -i db-server psql -U postgres -d testdb -c "
   CREATE TABLE IF NOT EXISTS users (
       id SERIAL PRIMARY KEY,
       name VARCHAR(100),
       email VARCHAR(100)
   );
   INSERT INTO users (name, email) VALUES 
   ('Nguyen Van A', 'vana@example.com'), 
   ('Tran Thi B', 'thib@example.com');
   "
   ```

2. **Xem dữ liệu đã tạo:**
   ```bash
   docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
   ```

3. **Xóa cứng container Database cũ:**
   ```bash
   docker rm -f db-server
   ```
   * *Lưu ý:* Thao tác này tiêu hủy hoàn toàn container `db-server` cùng tầng ghi đè (writable layer) của nó. Tuy nhiên volume `db-data` vẫn tồn tại nguyên vẹn.

4. **Khởi chạy container Database MỚI gắn cùng Named Volume `db-data`:**
   ```bash
   docker run -d \
     --name db-server \
     --network app-net \
     -e POSTGRES_USER=postgres \
     -e POSTGRES_PASSWORD=secretpassword \
     -e POSTGRES_DB=testdb \
     -v db-data:/var/lib/postgresql/data \
     postgres:15-alpine
   ```

5. **Xác minh dữ liệu không bị mất:**
   ```bash
   docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
   ```
   * **Kết quả:** Toàn bộ bản ghi bảng `users` (`Nguyen Van A`, `Tran Thi B`) vẫn hiển thị đầy đủ, chứng minh tính bền vững dữ liệu qua Named Volume.

---

## 4. Hướng Dẫn Chạy Script

### Cách 1: Chạy tự động qua file script `commands.sh`
Mở terminal (Git Bash, WSL hoặc Linux terminal):
```bash
chmod +x commands.sh
./commands.sh
```

### Cách 2: Chạy trên Windows PowerShell
Người dùng có thể thực thi lần lượt từng lệnh hoặc sử dụng PowerShell / Git Bash:
```powershell
bash commands.sh
```

---

## 5. Kết Quả Kiểm Tra Mẫu (Expected Output)

### 5.1. Kết quả kiểm tra mạng (`docker network inspect app-net`)
```json
[
    {
        "Name": "app-net",
        "Driver": "bridge",
        "Containers": {
            "...": {
                "Name": "db-server",
                "IPv4Address": "172.18.0.2/16"
            },
            "...": {
                "Name": "app-container",
                "IPv4Address": "172.18.0.3/16"
            }
        }
    }
]
```

### 5.2. Kết quả kiểm tra DNS resolution (`docker exec -it app-container ping -c 2 db-server`)
```text
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.065 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.065/0.073/0.082 ms
```

### 5.3. Kết quả xác minh dữ liệu sau khi tái tạo Container (`SELECT * FROM users;`)
```text
 id |     name     |       email       
----+--------------+-------------------
  1 | Nguyen Van A | vana@example.com
  2 | Tran Thi B   | thib@example.com
(2 rows)
```
Dữ liệu được bảo toàn 100%.
