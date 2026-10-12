# Bài 5: Nối Job tự động Build & Push Docker Image sau khi Test Gradle xanh

- **Môn học**: IT209 - DevOps & CI/CD
- **Bài thực hành**: Session 11 - Exercise 5
- **Mục tiêu**: Tách luồng CI thành 2 Job riêng biệt: Job `test` (chạy Gradle test & đóng gói JAR) và Job `docker-build` (đóng gói Docker Image đẩy lên GHCR). Ràng buộc thứ tự thực thi bằng từ khóa `needs` để đảm bảo chỉ đóng gói Docker Image khi bài test Gradle thành công.

---

## 1. Cấu trúc dự án

```text
IT209_SS11_Ex5/
├── .github/
│   └── workflows/
│       └── ci.yml               # Kịch bản CI gồm 2 Job liên kết qua needs: test
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── src/
│   ├── main/java/com/example/demo/
│   │   ├── DemoApplication.java
│   │   └── controller/HelloController.java
│   └── test/java/com/example/demo/
│       └── HelloControllerTest.java
├── .gitignore
├── build.gradle
├── Dockerfile                   # Dockerfile đóng gói ứng dụng Spring Boot
├── gradle.properties
├── gradlew
├── gradlew.bat
├── settings.gradle
└── README.md
```

---

## 2. Thiết kế kịch bản CI (`.github/workflows/ci.yml`)

Kịch bản CI được phân chia thành 2 Job tuần tự:

1. **Job `test` (Gradle Test & Package JAR)**:
   - Chạy trên runner `ubuntu-latest`.
   - Cài đặt Java JDK 17 với tính năng cache `gradle`.
   - Thực thi các bài kiểm thử tự động với JUnit qua `./gradlew test`.
   - Đóng gói ứng dụng thành file thực thi `.jar` qua `./gradlew bootJar`.
   - Lưu trữ artifact `app-jar` (`build/libs/*.jar`) bằng action `actions/upload-artifact@v4`.

2. **Job `docker-build` (Build and Push Docker Image)**:
   - Sử dụng từ khóa `needs: test`: Ràng buộc Job này chỉ được chạy khi Job `test` hoàn thành màu xanh (**Success**).
   - Tải về tệp JAR đã đóng gói từ Job 1 thông qua `actions/download-artifact@v4`.
   - Chuẩn hóa tên image sang chữ thường (`ghcr.io/<owner>/<repo>:latest`) để tuân thủ quy chuẩn đặt tên của Docker / GitHub Container Registry.
   - Đăng nhập vào GHCR bằng `docker/login-action@v3` sử dụng `secrets.REGISTRY_TOKEN` hoặc `secrets.GITHUB_TOKEN`.
   - Đóng gói Dockerfile và đẩy Docker Image lên GHCR (`ghcr.io`) thông qua action `docker/build-push-action@v5`.

```yaml
name: CI Pipeline

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  test:
    name: Gradle Test & Package JAR
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập môi trường Java JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Cấp quyền thực thi cho gradlew
        run: |
          if [ -f "./gradlew" ]; then
            chmod +x ./gradlew
          fi

      - name: Chạy Unit Tests
        run: |
          if [ -f "./gradlew" ]; then
            ./gradlew test
          else
            gradle test
          fi

      - name: Đóng gói ứng dụng JAR (bootJar)
        run: |
          if [ -f "./gradlew" ]; then
            ./gradlew bootJar
          else
            gradle bootJar
          fi

      - name: Tải lên Build Artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-jar
          path: build/libs/*.jar
          retention-days: 1

  docker-build:
    name: Build and Push Docker Image
    needs: test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Tải về tệp JAR đã đóng gói
        uses: actions/download-artifact@v4
        with:
          name: app-jar
          path: build/libs

      - name: Thiết lập tên Image (chữ thường)
        run: |
          echo "IMAGE_TAG=ghcr.io/${GITHUB_REPOSITORY,,}:latest" >> $GITHUB_ENV

      - name: Đăng nhập vào GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}

      - name: Đóng gói và đẩy Docker Image lên GHCR
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ env.IMAGE_TAG }}
```

---

## 3. Kiểm tra kịch bản

### Kịch bản 1: Luồng chuẩn (Happy Path)
1. Job `test` thực hiện checkout, chạy test JUnit và đóng gói JAR thành công $\rightarrow$ hiển thị icon xanh lá (**Passed**).
2. Khi Job `test` xanh, điều kiện `needs: test` thỏa mãn, Job `docker-build` được kích hoạt.
3. Trên biểu đồ giao diện Actions: Xuất hiện mũi tên trực quan nối từ Job `test` sang Job `docker-build`.
4. Job `docker-build` hoàn tất việc login GHCR và push Docker Image lên Registry.

### Kịch bản 2: Khi bài Test bị lỗi (Fail-safe Validation)
1. Khi có sự cố trong bài kiểm thử (sửa giá trị kỳ vọng trong `HelloControllerTest.java` khiến JUnit test fail):
   - Job `test` chuyển trạng thái đỏ (**Failed**).
2. Do có ràng buộc `needs: test`, Job `docker-build` tự động chuyển trạng thái xám (**Skipped** / Bị bỏ qua).
3. Đảm bảo nguyên tắc CI/CD: **Không bao giờ đóng gói hoặc phân phối Docker Image khi bài kiểm thử chưa vượt qua**.

---

## 4. Các lệnh khởi tạo Git và đẩy lên Repository

```bash
git init
git add .
git commit -m "feat: setup 2-job CI pipeline with needs: test and docker build-push to ghcr"
git branch -M main
git remote add origin https://github.com/minh-duy2608/PTIT_CNTT3_IT209_Session11_Ex5.git
git push -u origin main
```
