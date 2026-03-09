# GPS Tracker

即時 GPS 追蹤 + UAV 3D 軌跡 + 照片上傳 + Sionna 無線通道模擬。

## 功能

| 功能 | 說明 |
|------|------|
| GPS 同步 | 手機透過 WebSocket 即時傳送 GPS 至電腦端 3D 地圖 |
| UAV 軌跡 | 手機移動路徑以綠色線條顯示在 3D 場景（NTPU / NYCU 可切換） |
| 拍照上傳 | 手機拍照後立即廣播至電腦端並儲存於後端 |
| Sionna 模擬 | SINR Map、CFR、Doppler、Channel Response 無線通道模擬 |
| Cloudflared | 手機與電腦透過公網安全通道連線，無需同一 WiFi |

---

## 環境需求

- Python **3.12+**
- Node.js **18+**（建議 v22）
- `cloudflared`（選用，只有要用公網才需要）

---

## 快速安裝（git clone 後）

### 1. Clone

```bash
git clone https://github.com/eating0527/gps-tracker.git
cd gps-tracker
```

### 2. 後端：建立虛擬環境並安裝套件

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cd ..
```

> ⚠️ Sionna 需要 TensorFlow，第一次安裝時間較長（約 5–10 分鐘）。
> 如果不需要 Sionna 無線模擬功能，可以先只裝核心套件：
> ```bash
> .venv/bin/pip install fastapi uvicorn[standard] python-multipart aiofiles
> ```

### 3. 前端：安裝 npm 套件

```bash
cd frontend
npm install
cd ..
```

### 4. 設定環境變數

```bash
cp frontend/.env.example frontend/.env
```

本地開發預設值可直接使用，不需要修改。  
若要用 Cloudflare Tunnel 公網連線，再編輯 `frontend/.env` 填入你的網址。

### 5. 啟動

```bash
bash start.sh
```

服務啟動位址：
- 前端：http://localhost:5173
- 後端 API：http://localhost:8000

加上 `--no-tunnel` 可略過 Cloudflare Tunnel：

```bash
bash start.sh --no-tunnel
```

---

## Cloudflare Tunnel 設定（選用）

只有需要手機從外網連線時才需要設定。

### 1. 安裝 cloudflared

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o ~/.local/bin/cloudflared && chmod +x ~/.local/bin/cloudflared
```

### 2. 在根目錄建立 `.env` 填入 Token

```env
CLOUDFLARED_TOKEN=你的token
```

### 3. 設定前端指向公網後端

編輯 `frontend/.env`：

```env
VITE_WS_URL=wss://backend.yourdomain.com/ws/gps
VITE_API_URL=https://backend.yourdomain.com
```
