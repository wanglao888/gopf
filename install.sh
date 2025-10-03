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
        print_info "TLS模式配置文件示例已复制到 ${CONFIG_DIR}/config.example.js"
    fi
    
    if [[ -f "./config.http.example.js" ]]; then
        cp "./config.http.example.js" "${CONFIG_DIR}/"
        print_info "HTTP模式配置文件示例已复制到 ${CONFIG_DIR}/config.http.example.js"
    fi
    
    # 安装管理脚本到全局路径
    print_info "安装管理脚本..."
    # 创建简单的管理脚本
    cat > "${GOFP_COMMAND}" << 'EOF'
#!/bin/bash
SERVICE_NAME="grpc-forwarder"
case "$1" in
    start) systemctl start "${SERVICE_NAME}" ;;
    stop) systemctl stop "${SERVICE_NAME}" ;;
    restart) systemctl restart "${SERVICE_NAME}" ;;
    status) systemctl status "${SERVICE_NAME}" ;;
    logs) journalctl -u "${SERVICE_NAME}" -f ;;
    *) echo "用法: gofp {start|stop|restart|status|logs}" ;;
esac
EOF
    chmod +x "${GOFP_COMMAND}"
    print_success "已安装 gofp 管理命令到 ${GOFP_COMMAND}"
    
    # 提示用户配置
    print_warning "配置文件说明:"
    print_info "  - TLS模式 (默认): ${CONFIG_DIR}/config.example.js"
    print_info "  - HTTP模式: ${CONFIG_DIR}/config.http.example.js"
    print_warning "请根据需要编辑相应的配置文件，或准备好远程配置文件URL"
    print_info "注意：程序只支持HTTP/HTTPS URL作为配置源，不支持本地文件路径"
    
    read -p "请输入配置文件URL (回车使用默认配置服务器): " CONFIG_URL
    
    # 如果用户没有输入URL，启动一个简单的HTTP服务器来提供配置文件
    if [[ -z "$CONFIG_URL" ]]; then
        print_info "启动本地配置服务器..."
        # 创建一个简单的配置服务器脚本
        cat > "${INSTALL_DIR}/config-server.py" << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 8888
CONFIG_DIR = "/etc/grpc-forwarder"

class ConfigHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/config.js":
            config_file = os.path.join(CONFIG_DIR, "config.example.js")
            if os.path.exists(config_file):
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                with open(config_file, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404, "Config file not found")
        else:
            self.send_error(404, "Not found")

os.chdir(CONFIG_DIR)
with socketserver.TCPServer(("", PORT), ConfigHandler) as httpd:
    print(f"Config server running on port {PORT}")
    httpd.serve_forever()
EOF
        chmod +x "${INSTALL_DIR}/config-server.py"
        
        # 启动配置服务器
        nohup python3 "${INSTALL_DIR}/config-server.py" > "${LOG_DIR}/config-server.log" 2>&1 &
        CONFIG_SERVER_PID=$!
        echo $CONFIG_SERVER_PID > "${INSTALL_DIR}/config-server.pid"
        
        sleep 2
        CONFIG_URL="http://127.0.0.1:8888/config.js"
        print_success "本地配置服务器已启动，配置URL: ${CONFIG_URL}"
    fi
    
    # 创建systemd服务文件
    print_info "创建systemd服务..."
    cat > "${SYSTEMD_SERVICE}" << EOF
[Unit]
Description=gRPC Reverse Proxy Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/${BINARY_NAME} ${CONFIG_URL}
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
    print_warning "即将卸载 gRPC 反向代理服务"
    read -p "确认卸载? (y/N): " confirm
    
    if [[ $confirm != [yY] ]]; then
        print_info "取消卸载"
        exit 0
    fi
    
    print_info "停止并禁用服务..."
    systemctl stop "${SERVICE_NAME}" 2>/dev/null
    systemctl disable "${SERVICE_NAME}" 2>/dev/null
    
    print_info "删除服务文件..."
    rm -f "${SYSTEMD_SERVICE}"
    
    # 停止配置服务器
    if [ -f "${INSTALL_DIR}/config-server.pid" ]; then
        CONFIG_SERVER_PID=$(cat "${INSTALL_DIR}/config-server.pid")
        if kill -0 "$CONFIG_SERVER_PID" 2>/dev/null; then
            kill "$CONFIG_SERVER_PID"
            print_info "已停止配置服务器"
        fi
        rm -f "${INSTALL_DIR}/config-server.pid"
    fi
    
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
    if [[ $del_config == [yY] ]]; then
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
    echo "  uninstall   卸载服务"
    echo "  help        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 install    # 安装服务"
    echo "  $0 start      # 启动服务"
    echo "  $0 status     # 查看状态"
    echo "  $0 logs       # 查看日志"
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
            uninstall_service
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
