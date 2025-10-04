#!/bin/bash

# Trojan-gRPC 转发器 - 一键部署脚本
# 使用方法: sudo ./deploy-debian.sh

set -e

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    echo "用法: sudo ./deploy-debian.sh"
    exit 1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 配置变量
SERVICE_NAME="trojan-grpc-forwarder"
INSTALL_DIR="/opt/trojan-grpc-forwarder"
CONFIG_DIR="/etc/trojan-grpc-forwarder"
LOG_DIR="/var/log/trojan-grpc-forwarder"
SERVICE_FILE="/etc/systemd/system/trojan-grpc-forwarder.service"
USER="trojan-grpc"
DOWNLOAD_URL="https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/grpc-forwarder"
CONFIG_URL="https://raw.githubusercontent.com/wanglao888/gopf/refs/heads/main/config.json"

# 显示标题
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              ${WHITE}Trojan-gRPC 转发器一键部署${CYAN}                 ║${NC}"
echo -e "${CYAN}║                     ${YELLOW}Debian/Ubuntu${CYAN}                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查系统依赖
echo -e "${BLUE}[1/10]${NC} 检查系统依赖..."
if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo -e "${YELLOW}⚠️  安装下载工具...${NC}"
    apt-get update -qq
    apt-get install -y curl wget
fi

if ! command -v systemctl &> /dev/null; then
    echo -e "${RED}❌ 系统不支持 systemd！${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 系统依赖检查通过${NC}"

# 停止现有服务（如果存在）
echo -e "${BLUE}[2/10]${NC} 检查现有服务..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  停止现有服务...${NC}"
    systemctl stop "$SERVICE_NAME"
fi
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
fi
echo -e "${GREEN}✅ 现有服务检查完成${NC}"

# 下载可执行文件
echo -e "${BLUE}[3/10]${NC} 下载可执行文件..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if command -v curl &> /dev/null; then
    curl -L -o grpc-forwarder "$DOWNLOAD_URL"
else
    wget -O grpc-forwarder "$DOWNLOAD_URL"
fi

if [ ! -f "grpc-forwarder" ] || [ ! -s "grpc-forwarder" ]; then
    echo -e "${RED}❌ 下载失败或文件为空！${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo -e "${GREEN}✅ 可执行文件下载完成${NC}"

# 创建用户
echo -e "${BLUE}[4/10]${NC} 创建系统用户..."
if ! id "$USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false "$USER"
    echo -e "${GREEN}✅ 用户 '$USER' 创建成功${NC}"
else
    echo -e "${YELLOW}⚠️  用户 '$USER' 已存在${NC}"
fi

# 创建目录
echo -e "${BLUE}[5/10]${NC} 创建系统目录..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
echo -e "${GREEN}✅ 系统目录创建完成${NC}"

# 安装可执行文件
echo -e "${BLUE}[6/10]${NC} 安装可执行文件..."
cp grpc-forwarder "$INSTALL_DIR/trojan-grpc-forwarder"
chmod +x "$INSTALL_DIR/trojan-grpc-forwarder"
echo -e "${GREEN}✅ 可执行文件安装完成${NC}"

# 下载配置文件
echo -e "${BLUE}[7/10]${NC} 下载配置文件..."
if command -v curl &> /dev/null; then
    curl -L -o "$CONFIG_DIR/config.json" "$CONFIG_URL" || echo -e "${YELLOW}⚠️  配置文件下载失败，将创建默认配置${NC}"
else
    wget -O "$CONFIG_DIR/config.json" "$CONFIG_URL" || echo -e "${YELLOW}⚠️  配置文件下载失败，将创建默认配置${NC}"
fi

# 如果配置文件下载失败，创建默认配置
if [ ! -f "$CONFIG_DIR/config.json" ] || [ ! -s "$CONFIG_DIR/config.json" ]; then
    echo -e "${YELLOW}⚠️  创建默认配置文件...${NC}"
    cat > "$CONFIG_DIR/config.json" << 'EOF'
{
    "listen_port": 3443,
    "target_host": "127.0.0.1",
    "target_port": 80,
    "log_level": "info",
    "log_file": "/var/log/trojan-grpc-forwarder/forwarder.log"
}
EOF
fi
echo -e "${GREEN}✅ 配置文件准备完成${NC}"

# 设置权限
echo -e "${BLUE}[8/10]${NC} 设置文件权限..."
chown -R "$USER:$USER" "$INSTALL_DIR"
chown -R "$USER:$USER" "$CONFIG_DIR"
chown -R "$USER:$USER" "$LOG_DIR"
chmod 644 "$CONFIG_DIR/config.json"
echo -e "${GREEN}✅ 文件权限设置完成${NC}"

# 创建 systemd 服务文件
echo -e "${BLUE}[9/10]${NC} 创建 systemd 服务..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Trojan-gRPC Forwarder
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
ExecStart=$INSTALL_DIR/trojan-grpc-forwarder -config $CONFIG_DIR/config.json
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=trojan-grpc-forwarder

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$CONFIG_DIR $LOG_DIR

[Install]
WantedBy=multi-user.target
EOF

# 重载并启用服务
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
echo -e "${GREEN}✅ systemd 服务创建完成${NC}"

# 启动服务
echo -e "${BLUE}[10/10]${NC} 启动服务..."
systemctl start "$SERVICE_NAME"

# 等待服务启动
sleep 2

# 检查服务状态
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✅ 服务启动成功${NC}"
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    echo -e "${YELLOW}查看错误日志: ${WHITE}sudo journalctl -u $SERVICE_NAME --no-pager${NC}"
fi

# 清理临时文件
cd /
rm -rf "$TEMP_DIR"

# 显示部署结果
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    ${GREEN}部署完成！${CYAN}                           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${WHITE}📁 安装目录: ${GREEN}$INSTALL_DIR${NC}"
echo -e "${WHITE}⚙️  配置目录: ${GREEN}$CONFIG_DIR${NC}"
echo -e "${WHITE}📋 日志目录: ${GREEN}$LOG_DIR${NC}"
echo -e "${WHITE}👤 运行用户: ${GREEN}$USER${NC}"
echo -e "${WHITE}🌐 下载地址: ${CYAN}$DOWNLOAD_URL${NC}"
echo ""

echo -e "${YELLOW}🎮 服务管理命令:${NC}"
echo -e "   ${WHITE}查看状态: ${BLUE}sudo systemctl status $SERVICE_NAME${NC}"
echo -e "   ${WHITE}停止服务: ${RED}sudo systemctl stop $SERVICE_NAME${NC}"
echo -e "   ${WHITE}重启服务: ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
echo -e "   ${WHITE}查看日志: ${CYAN}sudo journalctl -u $SERVICE_NAME -f${NC}"
echo -e "   ${WHITE}编辑配置: ${GREEN}sudo nano $CONFIG_DIR/config.json${NC}"
echo ""

echo -e "${YELLOW}📝 配置文件位置:${NC}"
echo -e "   ${WHITE}主配置: ${GREEN}$CONFIG_DIR/config.json${NC}"
echo ""

echo -e "${YELLOW}🔧 常用操作:${NC}"
echo -e "   ${WHITE}修改配置后重启: ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
echo -e "   ${WHITE}卸载服务: ${RED}sudo systemctl stop $SERVICE_NAME && sudo systemctl disable $SERVICE_NAME${NC}"
echo ""

# 显示当前服务状态
echo -e "${BLUE}📊 当前服务状态:${NC}"
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo ""
echo -e "${GREEN}🎉 Trojan-gRPC 转发器一键部署完成！${NC}"
echo -e "${CYAN}💡 服务已自动启动，可通过上述命令进行管理${NC}"
