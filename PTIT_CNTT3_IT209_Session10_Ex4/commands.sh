set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' 

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}         BẮT ĐẦU THỰC THI SCRIPT THIẾT LẬP DOCKER NETWORK & VOLUME           ${NC}"
echo -e "${BLUE}==============================================================================${NC}\n"


echo -e "${YELLOW}[Bước 0] Dọn dẹp tài nguyên cũ (nếu tồn tại)...${NC}"
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true
echo -e "${GREEN}✓ Môi trường đã sẵn sàng.${NC}\n"


echo -e "${YELLOW}[Bước 1] Tạo Custom Bridge Network tên 'app-net'...${NC}"
docker network create --driver bridge app-net
echo -e "${GREEN}✓ Đã tạo network 'app-net' thành công.${NC}\n"


echo -e "${YELLOW}[Bước 2] Tạo Named Volume tên 'db-data'...${NC}"
docker volume create db-data
echo -e "${GREEN}✓ Đã tạo volume 'db-data' thành công.${NC}\n"


echo -e "${YELLOW}[Bước 3] Khởi chạy Database Container 'db-server' tham gia 'app-net'...${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword \
  -e POSTGRES_DB=testdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

echo -e "${GREEN}✓ Container 'db-server' đã khởi chạy thành công.${NC}\n"

echo -e "${YELLOW}[Bước 4] Khởi chạy Backend Container 'app-container' tham gia 'app-net'...${NC}"
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=secretpassword \
  -e DB_NAME=testdb \
  alpine sleep 3600

echo -e "${GREEN}✓ Container 'app-container' đã khởi chạy thành công.${NC}\n"

echo -e "${YELLOW}[Bước 5] Kiểm tra danh sách Network, Volume và kiểm tra DNS resolution...${NC}"

echo -e "${BLUE}>> 5.1. Kiểm tra Network 'app-net':${NC}"
docker network ls | grep app-net || docker network ls

echo -e "\n${BLUE}>> 5.2. Kiểm tra Volume 'db-data':${NC}"
docker volume ls | grep db-data || docker volume ls

echo -e "\n${BLUE}>> 5.3. Kiểm tra chi tiết cấu hình Network 'app-net':${NC}"
docker network inspect app-net

echo -e "\n${BLUE}>> 5.4. Kiểm tra Backend Container ping đến Database Container qua tên miền 'db-server':${NC}"
docker exec -it app-container ping -c 2 db-server
echo -e "${GREEN}✓ Ping thành công! Docker DNS Resolver đã phân giải tên 'db-server' thành IP nội bộ.${NC}\n"

echo -e "${YELLOW}[Bước 6] Chờ PostgreSQL sẵn sàng và nạp dữ liệu kiểm thử...${NC}"
until docker exec db-server pg_isready -U postgres -d testdb >/dev/null 2>&1; do
  echo "Đang đợi PostgreSQL khởi động..."
  sleep 2
done

echo -e "${BLUE}>> 6.1. Tạo bảng 'users' và thêm dữ liệu kiểm thử:${NC}"
docker exec -i db-server psql -U postgres -d testdb << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('Nguyen Van A', 'vana@example.com'),
('Tran Thi B', 'thib@example.com'),
('Le Van C', 'vanc@example.com');
EOF

echo -e "\n${BLUE}>> 6.2. Hiển thị dữ liệu trước khi xóa container DB:${NC}"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
echo -e "${GREEN}✓ Đã ghi dữ liệu thành công vào cơ sở dữ liệu.${NC}\n"

echo -e "${YELLOW}[Bước 7] Thực hiện kiểm tra Data Persistence...${NC}"

echo -e "${RED}>> 7.1. Xóa cứng Container Database cũ (docker rm -f db-server):${NC}"
docker rm -f db-server
echo -e "${GREEN}✓ Đã xóa cứng container 'db-server'.${NC}\n"

echo -e "${BLUE}>> 7.2. Khởi chạy container Database MỚI gắn cùng Named Volume 'db-data':${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword \
  -e POSTGRES_DB=testdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

echo "Đang đợi PostgreSQL mới khởi động..."
until docker exec db-server pg_isready -U postgres -d testdb >/dev/null 2>&1; do
  sleep 2
done
echo -e "${GREEN}✓ Container 'db-server' mới đã sẵn sàng phục vụ.${NC}\n"

echo -e "${BLUE}>> 7.3. Xác minh dữ liệu không bị mất sau khi tái tạo Container:${NC}"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}✓ HOÀN THÀNH KIỂM TRA THÀNH CÔNG!                                             ${NC}"
echo -e "${GREEN}  - Custom Bridge Network giải mã hostname 'db-server' chính xác.            ${NC}"
echo -e "${GREEN}  - Dữ liệu nguyên vẹn trên Named Volume 'db-data' sau khi tái tạo container. ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
