#!/usr/bin/env bash
# 一鍵啟動 GPS Tracker（後端 + 前端 + Cloudflare Tunnel）
# 用法：bash start.sh
#        bash start.sh --no-tunnel   （不啟動 cloudflared）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
USE_TUNNEL=true

# ── 載入 .env（取得 CLOUDFLARED_TOKEN）────────────────────────────
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# ── 參數解析 ───────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --no-tunnel) USE_TUNNEL=false ;;
  esac
done

# ── 顏色輸出 ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 確認依賴 ───────────────────────────────────────────────────────
[[ -d "$BACKEND_DIR/.venv" ]] || { error "找不到 $BACKEND_DIR/.venv，請先執行：cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"; exit 1; }
[[ -d "$FRONTEND_DIR/node_modules" ]] || { error "找不到 node_modules，請先執行：cd frontend && npm install"; exit 1; }

# ── Log 資料夾 ─────────────────────────────────────────────────────
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"

# ── 儲存子行程 PID ────────────────────────────────────────────────
PIDS=()

cleanup() {
  echo ""
  info "正在關閉所有服務..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null && wait "$pid" 2>/dev/null || true
  done
  info "✅ 已全部關閉"
  exit 0
}
trap cleanup SIGINT SIGTERM

# ── 後端 ──────────────────────────────────────────────────────────
info "🚀 啟動後端 (port 8000)..."
"$BACKEND_DIR/.venv/bin/uvicorn" app.main:app \
  --host 0.0.0.0 --port 8000 --reload \
  --app-dir "$BACKEND_DIR" \
  > "$LOG_DIR/backend.log" 2>&1 &
PIDS+=($!)
info "   後端 PID: ${PIDS[-1]}  log: .logs/backend.log"

# ── 等後端起來 ────────────────────────────────────────────────────
sleep 2

# ── 前端 ──────────────────────────────────────────────────────────
info "🚀 啟動前端 (port 5173)..."
(cd "$FRONTEND_DIR" && npm run dev) \
  > "$LOG_DIR/frontend.log" 2>&1 &
PIDS+=($!)
info "   前端 PID: ${PIDS[-1]}  log: .logs/frontend.log"

# ── Cloudflare Tunnel ─────────────────────────────────────────────
TUNNEL_STARTED=false
if $USE_TUNNEL; then
  # 自動搜尋 cloudflared（系統 PATH 或常見位置）
  CF_BIN="$(command -v cloudflared 2>/dev/null \
    || ls /usr/local/bin/cloudflared /usr/bin/cloudflared \
           ~/bin/cloudflared ~/.local/bin/cloudflared 2>/dev/null | head -1)"

  if [[ -x "$CF_BIN" ]]; then
    # Apply WSL network fixes if applicable to reduce DNS timeouts and QUIC buffer issues
    if command -v bash >/dev/null 2>&1 && [[ -x "$(pwd)/scripts/wsl_network_fix.sh" ]]; then
      (bash "$(pwd)/scripts/wsl_network_fix.sh") || true
    fi
    info "🌐 啟動 Cloudflare Tunnel (simworld2)..."
    # 讀取 .env 裡的 token
    TOKEN=$(grep '^CLOUDFLARED_TOKEN=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2-)
    if [[ -n "$TOKEN" ]]; then
      "$CF_BIN" tunnel run --token "$TOKEN" \
        > "$LOG_DIR/tunnel.log" 2>&1 &
    else
      "$CF_BIN" tunnel run simworld2 \
        > "$LOG_DIR/tunnel.log" 2>&1 &
    fi
    PIDS+=($!)
    TUNNEL_STARTED=true
    info "   Tunnel PID: ${PIDS[-1]}  log: .logs/tunnel.log"
  else
    warn "找不到 cloudflared，略過 Tunnel"
    warn "安裝方法：curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o ~/.local/bin/cloudflared && chmod +x ~/.local/bin/cloudflared"
  fi
fi

# ── 顯示即時 log ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "  前端：${YELLOW}http://localhost:5173${NC}"
$USE_TUNNEL && echo -e "  公網：${YELLOW}https://frontend.simworld.website${NC}"
echo -e "  按 Ctrl+C 關閉所有服務"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""

# 即時跟蹤所有 log（tail -f 並一起顯示）
LOG_FILES=("$LOG_DIR/backend.log" "$LOG_DIR/frontend.log")
$TUNNEL_STARTED && LOG_FILES+=("$LOG_DIR/tunnel.log")
tail -f "${LOG_FILES[@]}" &
PIDS+=($!)

wait
