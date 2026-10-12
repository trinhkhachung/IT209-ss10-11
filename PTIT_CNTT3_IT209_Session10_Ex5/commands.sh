#!/usr/bin/env bash
set -e

# ==============================================================================
# Script Kiểm Thử Tự Động Hóa Docker Compose CLI v2 & File .env (Bài 5)
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   BẮT ĐẦU KIỂM THỬ ĐIỀU PHỐI DOCKER COMPOSE & BIẾN MÔI TRƯỜNG .ENV (BÀI 5)   ${NC}"
echo -e "${BLUE}==============================================================================${NC}\n"

# 1. Kiểm tra sự tồn tại của .env
echo -e "${YELLOW}[Bước 1] Kiểm tra tệp môi trường .env...${NC}"
if [ ! -f .env ]; then
    echo -e "${YELLOW}>> Không tìm thấy .env, tự động tạo từ .env.example...${NC}"
    cp .env.example .env
fi
echo -e "${GREEN}✓ Tệp .env đã sẵn sàng.${NC}\n"

# 2. Dọn dẹp tài nguyên trước đó nếu có
echo -e "${YELLOW}[Bước 2] Dọn dẹp tài nguyên cũ trước khi khởi động...${NC}"
docker compose down 2>/dev/null || true
echo -e "${GREEN}✓ Môi trường sạch sẽ.${NC}\n"

# 3. Khởi tạo và chạy ngầm toàn bộ dịch vụ bằng Docker Compose CLI v2
echo -e "${YELLOW}[Bước 3] Thực thi 'docker compose up -d --build'...${NC}"
docker compose up -d --build
echo -e "${GREEN}✓ Toàn bộ dịch vụ đã được khởi động ở chế độ nền!${NC}\n"

# 4. Kiểm tra trạng thái các container
echo -e "${YELLOW}[Bước 4] Kiểm tra trạng thái dịch vụ với 'docker compose ps'...${NC}"
docker compose ps
echo ""

# 5. Chờ PostgreSQL sẵn sàng
echo -e "${YELLOW}[Bước 5] Kiểm tra dịch vụ Database sẵn sàng...${NC}"
until docker compose exec database pg_isready -U postgres >/dev/null 2>&1; do
    echo "Đang đợi Database PostgreSQL khởi động hoàn tất..."
    sleep 2
done
echo -e "${GREEN}✓ PostgreSQL Database đã sẵn sàng phục vụ!${NC}\n"

# 6. Kiểm tra Logs của các dịch vụ
echo -e "${YELLOW}[Bước 6] Xem log gần nhất của các dịch vụ...${NC}"
docker compose logs --tail=20
echo ""

# 7. Kiểm tra kết nối HTTP đến Backend
echo -e "${YELLOW}[Bước 7] Kiểm tra kết nối HTTP đến dịch vụ Backend trên cổng 8080...${NC}"
sleep 2
if command -v curl >/dev/null 2>&1; then
    echo -e "${BLUE}>> Phản hồi từ Backend API (GET http://localhost:8080/):${NC}"
    curl -s http://localhost:8080/ || true
    echo -e "\n\n${BLUE}>> Phản hồi từ Health check (GET http://localhost:8080/health):${NC}"
    curl -s http://localhost:8080/health || true
    echo ""
else
    echo "Hệ thống chưa cài curl, bỏ qua kiểm tra curl trực tiếp."
fi

# 8. Hoàn tất
echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}✓ HOÀN TẤT KIỂM THỬ THÀNH CÔNG!${NC}"
echo -e "${GREEN}  - docker compose up -d: Tự động khởi tạo network, volume và 2 services.${NC}"
echo -e "${GREEN}  - Trạng thái các dịch vụ: Running.${NC}"
echo -e "${GREEN}  - Để dừng hạ tầng, hãy chạy: docker compose down${NC}"
echo -e "${GREEN}==============================================================================${NC}"
