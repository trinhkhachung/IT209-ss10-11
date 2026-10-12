# Bài 2: Đóng gói ứng dụng Web Backend bằng Single-stage Dockerfile

## 1. Giới thiệu
Dự án đóng gói ứng dụng Web Backend (Node.js/Express REST API) thành Docker Image bằng **Single-stage Dockerfile** phục vụ triển khai lên môi trường chạy thử nghiệm.

## 2. Cấu trúc thư mục
```text
homework/session_10/ex2/
├── Dockerfile
├── .dockerignore
├── package.json
├── server.js
└── README.md
```

---

## 3. Chi tiết Dockerfile (Single-stage)
Dockerfile bao gồm đầy đủ các chỉ thị theo chuẩn:

```dockerfile
FROM node:18-alpine

WORKDIR /app

ENV PORT=3000

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

### Giải thích các chỉ thị:
- `FROM node:18-alpine`: Sử dụng base image chính thức của Node.js phiên bản 18 trên nền Alpine Linux để giảm dung lượng image.
- `WORKDIR /app`: Đặt thư mục làm việc mặc định trong container là `/app`. Mọi câu lệnh tiếp theo sẽ thực thi tại đây.
- `ENV PORT=3000`: Khai báo biến môi trường `PORT=3000`, có thể được đọc trực tiếp từ `process.env.PORT` trong Node.js.
- `COPY package*.json ./`: Sao chép file mô tả thư viện phụ thuộc trước nhằm tối ưu hóa Docker build cache.
- `RUN npm install`: Chạy lệnh cài đặt các dependencies (Express) bên trong container image.
- `COPY . .`: Sao chép toàn bộ mã nguồn còn lại của ứng dụng vào container (đã trừ những file/thư mục trong `.dockerignore`).
- `EXPOSE 3000`: Khai báo cổng 3000 mà container sẽ lắng nghe khi chạy.
- `CMD ["node", "server.js"]`: Chỉ định lệnh mặc định dạng exec form để khởi chạy server khi container khởi động.

---

## 4. Hướng dẫn chạy và kiểm tra

### Bước 1: Build Docker Image
```bash
docker build -t hw-backend:v1 .
```

### Bước 2: Chạy Container
Chạy container ở chế độ detached (`-d`), đặt tên container là `app-single-stage` và map port `8080:3000`:
```bash
docker run -d --name app-single-stage -p 8080:3000 hw-backend:v1
```

### Bước 3: Kiểm tra trạng thái Container
```bash
docker ps
```
*Kết quả mong đợi:* Container `app-single-stage` hiển thị trạng thái `Up` và ánh xạ cổng `0.0.0.0:8080->3000/tcp`.

### Bước 4: Kiểm tra log của Container
```bash
docker logs app-single-stage
```
*Kết quả mong đợi:*
```text
Server listening on port 3000
```

### Bước 5: Kiểm tra API bằng `curl`
```bash
curl -i http://localhost:8080/
```
*Kết quả mong đợi:*
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Content-Length: 61
Date: ...
Connection: keep-alive
Keep-Alive: timeout=5

{"status":"success","message":"Hello from Docker Single-stage!"}
```

---

## 5. Dọn dẹp tài nguyên (Tùy chọn)
Sau khi kiểm tra xong, có thể xóa container và image:
```bash
docker stop app-single-stage
docker rm app-single-stage
docker rmi hw-backend:v1
```
