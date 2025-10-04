#!/bin/bash

# Trojan-gRPC 转发器 - 一键安装脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/wanglao888/gopf/main/install.sh | bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 配置变量
SERVICE_NAME="gopf"
SERVICE_USER="gopf"
INSTALL_DIR="/opt/gopf"
CONFIG_DIR="/etc/gopf"
LOG_DIR="/var/log/gopf"
GITHUB_REPO="https://raw.githubusercontent.com/wanglao888/gopf/main"

echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}  Trojan-gRPC 转发器 一键安装${NC}"
echo -e "${CYAN}================================${NC}"
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ 请使用 root 用户运行此脚本${NC}"
    echo -e "${YELLOW}用法: curl -fsSL https://raw.githubusercontent.com/wanglao888/gopf/main/install.sh | bash${NC}"
    exit 1
fi

# 检查系统
if ! command -v systemctl &> /dev/null; then
    echo -e "${RED}❌ 此脚本需要 systemd 支持${NC}"
    exit 1
fi

# 检查下载工具
if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo -e "${YELLOW}📦 安装下载工具...${NC}"
    apt-get update -qq
    apt-get install -y curl wget
fi

# 停止现有服务
if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
    echo -e "${YELLOW}🛑 停止现有服务...${NC}"
    systemctl stop $SERVICE_NAME
fi

# 创建用户
if ! id "$SERVICE_USER" &>/dev/null; then
    echo -e "${YELLOW}👤 创建系统用户...${NC}"
    useradd --system --no-create-home --shell /bin/false $SERVICE_USER
fi

# 创建目录
echo -e "${YELLOW}📁 创建目录结构...${NC}"
mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR
chown $SERVICE_USER:$SERVICE_USER $INSTALL_DIR $LOG_DIR
chmod 755 $INSTALL_DIR $CONFIG_DIR
chmod 750 $LOG_DIR

# 下载文件
echo -e "${YELLOW}📥 下载程序文件...${NC}"
if command -v curl &> /dev/null; then
    curl -fsSL "$GITHUB_REPO/grpc-forwarder" -o "$INSTALL_DIR/grpc-forwarder"
    curl -fsSL "$GITHUB_REPO/config.example.json" -o "$CONFIG_DIR/config.json"
else
    wget -q "$GITHUB_REPO/grpc-forwarder" -O "$INSTALL_DIR/grpc-forwarder"
    wget -q "$GITHUB_REPO/config.example.json" -O "$CONFIG_DIR/config.json"
fi

# 设置权限
chmod +x "$INSTALL_DIR/grpc-forwarder"
chown $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR/grpc-forwarder"
chown $SERVICE_USER:$SERVICE_USER "$CONFIG_DIR/config.json"

# 下载管理脚本
echo -e "${YELLOW}📥 下载管理脚本...${NC}"
if command -v curl &> /dev/null; then
    curl -fsSL "$GITHUB_REPO/gopf" -o "/usr/local/bin/gopf"
else
    wget -q "$GITHUB_REPO/gopf" -O "/usr/local/bin/gopf"
fi
chmod +x "/usr/local/bin/gopf"

# 创建 systemd 服务
echo -e "${YELLOW}⚙️  创建系统服务...${NC}"
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Trojan-gRPC Forwarder
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=$INSTALL_DIR/grpc-forwarder -config $CONFIG_DIR/config.json
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR $CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd 并启用服务
echo -e "${YELLOW}🔄 配置系统服务...${NC}"
systemctl daemon-reload
systemctl enable $SERVICE_NAME

# 启动服务
echo -e "${YELLOW}🚀 启动服务...${NC}"
if systemctl start $SERVICE_NAME; then
    sleep 2
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ 服务启动成功${NC}"
    else
        echo -e "${RED}❌ 服务启动失败${NC}"
        echo -e "${YELLOW}查看错误日志: ${WHITE}journalctl -u $SERVICE_NAME --no-pager${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    echo -e "${YELLOW}查看错误日志: ${WHITE}journalctl -u $SERVICE_NAME --no-pager${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 安装完成！${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}📋 服务信息:${NC}"
echo -e "   ${WHITE}服务名称: ${GREEN}$SERVICE_NAME${NC}"
echo -e "   ${WHITE}安装目录: ${BLUE}$INSTALL_DIR${NC}"
echo -e "   ${WHITE}配置文件: ${YELLOW}$CONFIG_DIR/config.json${NC}"
echo -e "   ${WHITE}日志目录: ${CYAN}$LOG_DIR${NC}"
echo ""
echo -e "${WHITE}🎮 管理命令:${NC}"
echo -e "   ${WHITE}打开管理菜单: ${GREEN}gopf${NC}"
echo ""
echo -e "${YELLOW}💡 提示: 请根据需要编辑配置文件 $CONFIG_DIR/config.json${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
