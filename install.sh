#!/bin/bash

# gRPC转发器一键安装和管理脚本
# 适用于 Debian/Ubuntu 系统

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 配置路径
SERVICE_NAME="grpc-forwarder"
INSTALL_DIR="/opt/grpc-forwarder"
CONFIG_DIR="/etc/grpc-forwarder"
LOG_DIR="/var/log/grpc-forwarder"
SERVICE_FILE="/etc/systemd/system/grpc-forwarder.service"
GOFP_COMMAND="/usr/local/bin/gofp"
SYSTEMD_SERVICE="/etc/systemd/system/${SERVICE_NAME}.service"
BINARY_NAME="gofp"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        print_info "请使用: $0 $1"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ ! -f /etc/debian_version ]]; then
        print_error "此脚本仅支持 Debian/Ubuntu 系统"
        exit 1
    fi
}

# 安装服务
# 安装Go环境
install_go() {
    print_info "检测系统架构..."
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) GO_ARCH="amd64" ;;
        aarch64) GO_ARCH="arm64" ;;
        armv7l) GO_ARCH="armv6l" ;;
        *) print_error "不支持的系统架构: $ARCH"; exit 1 ;;
    esac
    
    GO_VERSION="1.21.5"
    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    
    print_info "下载 Go ${GO_VERSION}..."
    cd /tmp
    wget -q "https://golang.org/dl/${GO_TAR}"
    
    print_info "安装 Go..."
    tar -C /usr/local -xzf "${GO_TAR}"
    
    # 设置环境变量
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    
    print_success "Go 安装完成"
}

install_service() {
    print_info "开始安装 gRPC 反向代理服务..."
    
    # 检查是否需要下载可执行文件
    if [[ ! -f "./${BINARY_NAME}" ]]; then
        print_info "未找到可执行文件，开始下载预编译版本..."
        
        # 下载预编译的可执行文件
        print_info "下载 grpc-forwarder 可执行文件..."
        cd /tmp
        if command -v wget &> /dev/null; then
            wget -O grpc-forwarder "https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/grpc-forwarder"
        elif command -v curl &> /dev/null; then
            curl -L -o grpc-forwarder "https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/grpc-forwarder"
        else
            print_error "需要 wget 或 curl 来下载文件"
            exit 1
        fi
        
        # 重命名为 gofp
        mv grpc-forwarder gofp
        chmod +x gofp
        
        # 下载配置文件示例
        print_info "下载配置文件示例..."
        if command -v wget &> /dev/null; then
            wget -O config.example.js "https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/config.example.js"
        else
            curl -L -o config.example.js "https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/config.example.js"
        fi
        
        # 创建HTTP模式配置文件
        cat > config.http.example.js << 'EOF'
{
  "listen_port": 8080,
  "mode": "http",
  "services": {
    "example.UserService": {
      "host": "127.0.0.1",
      "port": 50051
    },
    "example.ProductService": {
      "host": "127.0.0.1", 
      "port": 50052
    },
    "greet.Greeter": {
      "host": "127.0.0.1",
      "port": 50053
    }
  },
  "default_fallback": {
    "host": "127.0.0.1",
    "port": 50051
  }
}
EOF
        
        print_success "文件下载完成"
    fi
    
    # 创建目录
    print_info "创建安装目录..."
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${LOG_DIR}"
    
    # 复制文件
    print_info "复制程序文件..."
    cp "./${BINARY_NAME}" "${INSTALL_DIR}/"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    
    # 复制配置文件示例
    if [[ -f "./config.example.js" ]]; then
        cp "./config.example.js" "${CONFIG_DIR}/"
        print_info "配置文件示例已复制到 ${CONFIG_DIR}/config.example.js"
    fi
    
    if [[ -f "./config.http.example.js" ]]; then
        cp "./config.http.example.js" "${CONFIG_DIR}/"
        print_info "HTTP模式配置文件已复制到 ${CONFIG_DIR}/config.http.example.js"
    fi
    
    # 安装管理脚本到全局路径
    print_info "安装管理脚本..."
    # 创建交互式管理脚本
    cat > "${GOFP_COMMAND}" << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICE_NAME="grpc-forwarder"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_menu() {
    clear
    echo "=================================="
    echo "    gRPC 反向代理服务管理"
    echo "=================================="
    echo ""
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 重启服务"
    echo "4. 查看服务状态"
    echo "5. 查看实时日志"
    echo "6. 查看最近日志"
    echo "7. 编辑配置文件"
    echo "8. 重载配置"
    echo "0. 退出"
    echo ""
    echo -n "请选择操作 [0-8]: "
}

handle_choice() {
    case $1 in
        1)
            print_info "启动服务..."
            systemctl start "${SERVICE_NAME}"
            if systemctl is-active --quiet "${SERVICE_NAME}"; then
                print_success "服务启动成功"
            else
                print_error "服务启动失败"
            fi
            ;;
        2)
            print_info "停止服务..."
            systemctl stop "${SERVICE_NAME}"
            if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
                print_success "服务已停止"
            else
                print_error "服务停止失败"
            fi
            ;;
        3)
            print_info "重启服务..."
            systemctl restart "${SERVICE_NAME}"
            if systemctl is-active --quiet "${SERVICE_NAME}"; then
                print_success "服务重启成功"
                print_info "服务重启后会自动拉取最新配置文件"
            else
                print_error "服务重启失败"
            fi
            ;;
        4)
            print_info "服务状态:"
            systemctl status "${SERVICE_NAME}" --no-pager -l
            echo ""
            print_info "端口监听状态:"
            netstat -tlnp | grep ":443 " || netstat -tlnp | grep ":8080 " || print_warning "未检测到443或8080端口监听"
            ;;
        5)
            print_info "实时日志 (按 Ctrl+C 退出):"
            journalctl -u "${SERVICE_NAME}" -f
            ;;
        6)
            print_info "最近50条日志:"
            journalctl -u "${SERVICE_NAME}" --no-pager -n 50
            ;;
        7)
            print_info "配置文件位置: /etc/grpc-forwarder/"
            ls -la /etc/grpc-forwarder/
            echo ""
            echo "选择要编辑的配置文件:"
            echo "1) TLS模式配置文件 (config.example.js)"
            echo "2) HTTP模式配置文件 (config.http.example.js)"
            read -p "请选择 [1-2]: " config_choice
            case $config_choice in
                1)
                    if [[ -f "/etc/grpc-forwarder/config.example.js" ]]; then
                        nano /etc/grpc-forwarder/config.example.js
                    else
                        echo "配置文件不存在: /etc/grpc-forwarder/config.example.js"
                    fi
                    ;;
                2)
                    if [[ -f "/etc/grpc-forwarder/config.http.example.js" ]]; then
                        nano /etc/grpc-forwarder/config.http.example.js
                    else
                        echo "配置文件不存在: /etc/grpc-forwarder/config.http.example.js"
                    fi
                    ;;
                *)
                    echo "无效选择"
                    ;;
            esac
            ;;
        8)
            print_info "重载配置 (重启服务)..."
            systemctl restart "${SERVICE_NAME}"
            if systemctl is-active --quiet "${SERVICE_NAME}"; then
                print_success "配置重载成功"
                print_info "服务已重启并拉取最新配置文件"
            else
                print_error "配置重载失败"
            fi
            ;;
        0)
            print_info "退出管理程序"
            exit 0
            ;;
        *)
            print_error "无效选择，请输入 0-8"
            ;;
    esac
}

# 如果有参数，直接执行对应操作
if [ $# -gt 0 ]; then
    case "$1" in
        start) handle_choice 1 ;;
        stop) handle_choice 2 ;;
        restart) handle_choice 3 ;;
        status) handle_choice 4 ;;
        logs) handle_choice 5 ;;
        recent) handle_choice 6 ;;
        *) echo "用法: gofp {start|stop|restart|status|logs|recent}" ;;
    esac
    exit 0
fi

# 交互式菜单
while true; do
    show_menu
    read choice
    echo ""
    handle_choice $choice
    echo ""
    echo "按回车键继续..."
    read
done
EOF
    chmod +x "${GOFP_COMMAND}"
    print_success "已安装 gofp 管理命令到 ${GOFP_COMMAND}"
    
    # 提示用户配置
    print_warning "配置文件说明:"
    print_info "  - TLS模式配置文件示例: $CONFIG_DIR/config.example.js"
    print_info "  - HTTP模式配置文件示例: $CONFIG_DIR/config.http.example.js"
    print_warning "请根据需要编辑配置文件，或准备好远程配置文件URL"
    print_info "注意：程序只支持HTTP/HTTPS URL作为配置源，不支持本地文件路径"
    print_info "建议：如果没有TLS证书，请使用HTTP模式配置文件"
    print_info "新功能：配置服务器会自动从GitHub拉取最新配置文件"
    
    read -p "请输入配置文件URL (回车使用默认配置服务器): " CONFIG_URL
    
    # 如果用户没有输入URL，启动一个简单的HTTP服务器来提供配置文件
    if [[ -z "$CONFIG_URL" ]]; then
        print_info "启动本地配置服务器..."
        
        # 检查是否有TLS证书，决定使用哪个配置文件
        if [[ -f "/etc/V2bX/fullchain.cer" && -f "/etc/V2bX/cert.key" ]]; then
            CONFIG_FILE="$CONFIG_DIR/config.example.js"
            print_info "检测到TLS证书，使用TLS模式配置"
        else
            CONFIG_FILE="$CONFIG_DIR/config.http.example.js"
            print_warning "未检测到TLS证书，使用HTTP模式配置"
        fi
        # 创建一个简单的配置服务器脚本
        cat > "${INSTALL_DIR}/config-server.py" << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
import threading
import time
import urllib.request
import json
from datetime import datetime

PORT = 8888
CONFIG_DIR = "/etc/grpc-forwarder"
REMOTE_CONFIG_URLS = {
    "tls": "https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/config.example.js",
    "http": "https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/config.http.example.js"
}

def log_message(message):
    """记录日志消息"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_file = "/var/log/grpc-forwarder/config-server.log"
    try:
        with open(log_file, "a") as f:
            f.write(f"[{timestamp}] {message}\n")
    except:
        pass
    print(f"[{timestamp}] {message}")

def fetch_remote_config(config_type="auto"):
    """从远程URL获取最新配置文件"""
    try:
        # 自动检测使用哪种配置
        if config_type == "auto":
            if os.path.exists("/etc/V2bX/fullchain.cer") and os.path.exists("/etc/V2bX/cert.key"):
                config_type = "tls"
            else:
                config_type = "http"
        
        remote_url = REMOTE_CONFIG_URLS.get(config_type)
        if not remote_url:
            log_message(f"Unknown config type: {config_type}")
            return None
            
        log_message(f"Fetching latest config from: {remote_url}")
        
        # 下载远程配置文件
        with urllib.request.urlopen(remote_url, timeout=10) as response:
            if response.status == 200:
                config_content = response.read().decode('utf-8')
                
                # 验证JSON格式
                try:
                    json.loads(config_content)
                    log_message(f"Successfully fetched and validated {config_type} config")
                    return config_content
                except json.JSONDecodeError as e:
                    log_message(f"Invalid JSON in remote config: {e}")
                    return None
            else:
                log_message(f"Failed to fetch config, HTTP status: {response.status}")
                return None
                
    except Exception as e:
        log_message(f"Error fetching remote config: {e}")
        return None

def get_local_config():
    """获取本地配置文件作为备用"""
    try:
        # 检查是否有TLS证书，决定使用哪个配置文件
        if os.path.exists("/etc/V2bX/fullchain.cer") and os.path.exists("/etc/V2bX/cert.key"):
            config_file = os.path.join(CONFIG_DIR, "config.example.js")
        else:
            config_file = os.path.join(CONFIG_DIR, "config.http.example.js")
        
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                content = f.read()
                log_message(f"Using local config file: {config_file}")
                return content
        else:
            log_message(f"Local config file not found: {config_file}")
            return None
    except Exception as e:
        log_message(f"Error reading local config: {e}")
        return None

class ConfigHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/config.js":
            # 首先尝试从远程获取最新配置
            config_content = fetch_remote_config()
            
            # 如果远程获取失败，使用本地配置作为备用
            if config_content is None:
                log_message("Remote config fetch failed, falling back to local config")
                config_content = get_local_config()
            
            if config_content:
                self.send_response(200)
                self.send_header('Content-type', 'application/javascript')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                self.send_header('Pragma', 'no-cache')
                self.send_header('Expires', '0')
                self.end_headers()
                self.wfile.write(config_content.encode('utf-8'))
            else:
                log_message("No config available (remote and local both failed)")
                self.send_error(404, "Config file not found")
        else:
            self.send_error(404, "Not found")
    
    def log_message(self, format, *args):
        # 重定向日志到文件
        message = format % args
        log_message(f"HTTP: {self.address_string()} - {message}")

def start_server():
    log_message("Starting config server...")
    log_message(f"Remote config URLs: {REMOTE_CONFIG_URLS}")
    
    with socketserver.TCPServer(("0.0.0.0", PORT), ConfigHandler) as httpd:
        log_message(f"Config server running on port {PORT}")
        log_message("Server will fetch latest config from remote URL on each request")
        httpd.serve_forever()

if __name__ == "__main__":
    start_server()
EOF
        chmod +x "${INSTALL_DIR}/config-server.py"
        
        # 创建配置服务器的systemd服务
        cat > "/etc/systemd/system/grpc-config-server.service" << EOF
[Unit]
Description=gRPC Forwarder Config Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/config-server.py ${CONFIG_FILE}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        # 启动配置服务器
        systemctl daemon-reload
        systemctl enable grpc-config-server
        systemctl start grpc-config-server
        
        # 等待服务启动
        sleep 3
        
        # 检查配置服务器是否启动成功
        if systemctl is-active --quiet grpc-config-server; then
            CONFIG_URL="http://127.0.0.1:8888/config.js"
            print_success "本地配置服务器已启动，配置URL: ${CONFIG_URL}"
            print_info "配置服务器将自动从GitHub拉取最新配置文件"
            
            # 测试配置URL是否可访问
            if command -v curl &> /dev/null; then
                if curl -s "${CONFIG_URL}" > /dev/null; then
                    print_success "配置URL测试成功"
                else
                    print_warning "配置URL测试失败，将使用文件路径"
                    CONFIG_URL="file://${CONFIG_DIR}/config.example.js"
                fi
            fi
        else
            print_warning "配置服务器启动失败，使用文件路径"
            CONFIG_URL="file://${CONFIG_DIR}/config.example.js"
        fi
    fi
    
    # 创建systemd服务文件
    print_info "创建systemd服务..."
    
    # 根据选择的配置文件决定服务启动参数
    if [[ "$CONFIG_FILE" == *"config.http.example.js" ]]; then
        SERVICE_CONFIG_URL="file://$CONFIG_FILE"
        print_info "使用HTTP模式配置文件: $CONFIG_FILE"
    else
        SERVICE_CONFIG_URL="file://$CONFIG_FILE"
        print_info "使用TLS模式配置文件: $CONFIG_FILE"
    fi
    cat > "${SYSTEMD_SERVICE}" << EOF
[Unit]
Description=gRPC Reverse Proxy Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/${BINARY_NAME} ${SERVICE_CONFIG_URL}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${LOG_DIR}

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd并启用服务
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    
    print_success "gRPC反向代理服务安装完成!"
    print_info "现在你可以使用以下命令:"
    print_info "  - ${GREEN}gofp${NC}           # 进入管理菜单"
    print_info "  - ${GREEN}systemctl start ${SERVICE_NAME}${NC}   # 启动服务"
    print_info "  - ${GREEN}systemctl status ${SERVICE_NAME}${NC}  # 查看状态"
    
    # 询问是否立即启动服务
    echo ""
    read -p "是否现在启动服务? (Y/n): " start_now
    start_now=${start_now:-Y}
    if [[ $start_now =~ ^[Yy]$ ]]; then
        systemctl start "${SERVICE_NAME}"
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            print_success "服务启动成功!"
            print_info "使用 ${GREEN}gofp${NC} 命令进入管理菜单"
        else
            print_error "服务启动失败，请检查配置"
            print_info "使用 ${GREEN}gofp${NC} 命令查看详细信息"
        fi
    fi
}

# 启动服务
start_service() {
    print_info "启动 gRPC 反向代理服务..."
    systemctl start "${SERVICE_NAME}"
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_success "服务启动成功"
        show_status
    else
        print_error "服务启动失败"
        print_info "查看错误日志: $0 logs"
        exit 1
    fi
}

# 停止服务
stop_service() {
    print_info "停止 gRPC 反向代理服务..."
    systemctl stop "${SERVICE_NAME}"
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_error "服务停止失败"
        exit 1
    else
        print_success "服务已停止"
    fi
}

# 重启服务
restart_service() {
    print_info "重启 gRPC 反向代理服务..."
    systemctl restart "${SERVICE_NAME}"
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_success "服务重启成功"
        print_info "服务重启后会自动拉取最新配置文件"
        show_status
    else
        print_error "服务重启失败"
        print_info "查看错误日志: $0 logs"
        exit 1
    fi
}

# 查看服务状态
show_status() {
    print_info "gRPC 反向代理服务状态:"
    systemctl status "${SERVICE_NAME}" --no-pager -l
    
    echo ""
    print_info "端口监听状态:"
    netstat -tlnp | grep ":443 " || netstat -tlnp | grep ":8080 " || print_warning "未检测到443或8080端口监听"
    
    echo ""
    print_info "最近日志:"
    journalctl -u "${SERVICE_NAME}" --no-pager -n 5
}

# 查看日志
show_logs() {
    print_info "gRPC 反向代理服务日志:"
    echo "按 Ctrl+C 退出日志查看"
    echo ""
    journalctl -u "${SERVICE_NAME}" -f
}

# 查看最近日志
show_recent_logs() {
    print_info "最近50条日志:"
    journalctl -u "${SERVICE_NAME}" --no-pager -n 50
}

# 卸载服务
uninstall_service() {
    # 检查是否有 --force 参数
    if [[ "$2" == "--force" ]] || [[ "$FORCE_UNINSTALL" == "yes" ]]; then
        print_warning "强制卸载 gRPC 反向代理服务"
    else
        print_warning "即将卸载 gRPC 反向代理服务"
        read -p "确认卸载? (y/N): " confirm
        
        if [[ $confirm != [yY] ]]; then
            print_info "取消卸载"
            exit 0
        fi
    fi
    
    print_info "停止并禁用服务..."
    systemctl stop "${SERVICE_NAME}" 2>/dev/null
    systemctl disable "${SERVICE_NAME}" 2>/dev/null
    
    # 停止并删除配置服务器
    print_info "停止配置服务器..."
    systemctl stop grpc-config-server 2>/dev/null
    systemctl disable grpc-config-server 2>/dev/null
    rm -f "/etc/systemd/system/grpc-config-server.service"
    
    print_info "删除服务文件..."
    rm -f "${SYSTEMD_SERVICE}"
    
    # 删除管理命令
    if [ -f "${GOFP_COMMAND}" ]; then
        rm -f "${GOFP_COMMAND}"
        print_success "已删除 gofp 管理命令"
    fi
    
    systemctl daemon-reload
    
    print_info "删除程序文件..."
    rm -rf "${INSTALL_DIR}"
    
    print_info "删除日志文件..."
    rm -rf "${LOG_DIR}"
    
    read -p "是否删除配置文件? (y/N): " del_config
    if [[ $del_config == [yY] ]] || [[ "$2" == "--force" ]] || [[ "$FORCE_UNINSTALL" == "yes" ]]; then
        rm -rf "${CONFIG_DIR}"
        print_info "配置文件已删除"
    else
        print_info "配置文件保留在: ${CONFIG_DIR}"
    fi
    
    print_success "gRPC反向代理服务卸载完成"
}

# 显示帮助信息
show_help() {
    echo "gRPC反向代理服务管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  install     安装服务"
    echo "  start       启动服务"
    echo "  stop        停止服务"
    echo "  restart     重启服务"
    echo "  status      查看服务状态"
    echo "  logs        实时查看日志"
    echo "  recent      查看最近日志"
    echo "  uninstall   卸载服务 (可选: --force 强制卸载)"
    echo "  help        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  bash install    # 安装服务"
    echo "  bash start      # 启动服务"
    echo "  bash status     # 查看状态"
    echo "  bash logs       # 查看日志"
    echo "  bash uninstall --force  # 强制卸载服务"
}

# 主函数
main() {
    case "$1" in
        install)
            check_root
            check_system
            install_service
            ;;
        start)
            check_root
            start_service
            ;;
        stop)
            check_root
            stop_service
            ;;
        restart)
            check_root
            restart_service
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        recent)
            show_recent_logs
            ;;
        uninstall)
            check_root
            uninstall_service "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
