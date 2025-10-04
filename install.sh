#!/bin/bash

# Trojan-gRPC 转发器 - Debian 安装脚本
# 使用方法: sudo ./install-debian.sh

set -e

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    echo "用法: sudo ./install-debian.sh"
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

# 显示标题
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              ${WHITE}Trojan-gRPC 转发器安装脚本${CYAN}                 ║${NC}"
echo -e "${CYAN}║                     ${YELLOW}Debian/Ubuntu${CYAN}                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查可执行文件
echo -e "${BLUE}[1/8]${NC} 检查可执行文件..."
if [ ! -f "trojan-grpc-forwarder" ]; then
    echo -e "${RED}❌ 可执行文件 'trojan-grpc-forwarder' 不存在！${NC}"
    echo -e "${YELLOW}请先运行构建脚本: ${WHITE}./build-debian.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 可执行文件检查通过${NC}"

# 创建用户
echo -e "${BLUE}[2/8]${NC} 创建系统用户..."
if ! id "$USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false "$USER"
    echo -e "${GREEN}✅ 用户 '$USER' 创建成功${NC}"
else
    echo -e "${YELLOW}⚠️  用户 '$USER' 已存在${NC}"
fi

# 创建目录
echo -e "${BLUE}[3/8]${NC} 创建系统目录..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
echo -e "${GREEN}✅ 系统目录创建完成${NC}"

# 复制可执行文件
echo -e "${BLUE}[4/8]${NC} 安装可执行文件..."
cp trojan-grpc-forwarder "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/trojan-grpc-forwarder"
echo -e "${GREEN}✅ 可执行文件安装完成${NC}"

# 设置权限
echo -e "${BLUE}[5/8]${NC} 设置文件权限..."
chown -R "$USER:$USER" "$INSTALL_DIR"
chown -R "$USER:$USER" "$CONFIG_DIR"
chown -R "$USER:$USER" "$LOG_DIR"
echo -e "${GREEN}✅ 文件权限设置完成${NC}"

# 创建 systemd 服务文件
echo -e "${BLUE}[6/8]${NC} 创建 systemd 服务..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Trojan-gRPC Forwarder
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
ExecStart=$INSTALL_DIR/trojan-grpc-forwarder
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
echo -e "${GREEN}✅ systemd 服务文件创建完成${NC}"

# 重载 systemd
echo -e "${BLUE}[7/8]${NC} 重载 systemd 配置..."
systemctl daemon-reload
echo -e "${GREEN}✅ systemd 配置重载完成${NC}"

# 启用服务
echo -e "${BLUE}[8/8]${NC} 启用服务..."
systemctl enable "$SERVICE_NAME"
echo -e "${GREEN}✅ 服务启用完成${NC}"

# 显示安装结果
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      ${GREEN}安装完成！${CYAN}                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${WHITE}📁 安装目录: ${GREEN}$INSTALL_DIR${NC}"
echo -e "${WHITE}⚙️  配置目录: ${GREEN}$CONFIG_DIR${NC}"
echo -e "${WHITE}📋 日志目录: ${GREEN}$LOG_DIR${NC}"
echo -e "${WHITE}👤 运行用户: ${GREEN}$USER${NC}"
echo ""

echo -e "${YELLOW}🎮 服务管理命令:${NC}"
echo -e "   ${WHITE}启动服务: ${GREEN}sudo systemctl start $SERVICE_NAME${NC}"
echo -e "   ${WHITE}停止服务: ${RED}sudo systemctl stop $SERVICE_NAME${NC}"
echo -e "   ${WHITE}重启服务: ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
echo -e "   ${WHITE}查看状态: ${BLUE}sudo systemctl status $SERVICE_NAME${NC}"
echo -e "   ${WHITE}查看日志: ${CYAN}sudo journalctl -u $SERVICE_NAME -f${NC}"
echo ""

echo -e "${YELLOW}📝 配置文件:${NC}"
echo -e "   ${WHITE}请在 ${GREEN}$CONFIG_DIR${WHITE} 目录下创建配置文件${NC}"
echo ""

echo -e "${GREEN}🎉 Trojan-gRPC 转发器安装完成！${NC}"
echo -e "${YELLOW}💡 提示: 配置完成后使用 ${WHITE}sudo systemctl start $SERVICE_NAME${YELLOW} 启动服务${NC}"
