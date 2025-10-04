#!/bin/bash

# Trojan-gRPC 转发器 - Debian 构建脚本
# 使用方法: ./build-debian.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 显示标题
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                ${WHITE}Trojan-gRPC 转发器构建脚本${CYAN}                  ║${NC}"
echo -e "${CYAN}║                     ${YELLOW}Debian/Ubuntu${CYAN}                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查 Go 环境
echo -e "${BLUE}[1/5]${NC} 检查 Go 环境..."
if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go 未安装！${NC}"
    echo -e "${YELLOW}请先安装 Go: ${WHITE}sudo apt update && sudo apt install golang-go${NC}"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}')
echo -e "${GREEN}✅ Go 环境检查通过: ${WHITE}${GO_VERSION}${NC}"

# 检查依赖
echo -e "${BLUE}[2/5]${NC} 检查项目依赖..."
if [ ! -f "go.mod" ]; then
    echo -e "${RED}❌ go.mod 文件不存在！${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 项目依赖检查通过${NC}"

# 下载依赖
echo -e "${BLUE}[3/5]${NC} 下载 Go 模块依赖..."
go mod download
echo -e "${GREEN}✅ 依赖下载完成${NC}"

# 编译程序
echo -e "${BLUE}[4/5]${NC} 编译 Trojan-gRPC 转发器..."
echo -e "${YELLOW}目标平台: ${WHITE}Linux/AMD64${NC}"

# 设置编译参数
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64

# 编译
go build -ldflags="-s -w" -o trojan-grpc-forwarder main.go

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 编译成功！${NC}"
else
    echo -e "${RED}❌ 编译失败！${NC}"
    exit 1
fi

# 设置权限
echo -e "${BLUE}[5/5]${NC} 设置可执行权限..."
chmod +x trojan-grpc-forwarder
echo -e "${GREEN}✅ 权限设置完成${NC}"

# 显示结果
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      ${GREEN}构建完成！${CYAN}                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 文件信息
if [ -f "trojan-grpc-forwarder" ]; then
    FILE_SIZE=$(du -h trojan-grpc-forwarder | cut -f1)
    echo -e "${WHITE}📁 可执行文件: ${GREEN}trojan-grpc-forwarder${NC}"
    echo -e "${WHITE}📊 文件大小: ${YELLOW}${FILE_SIZE}${NC}"
    echo -e "${WHITE}🏗️  目标平台: ${BLUE}Linux/AMD64${NC}"
    echo ""
    
    # 运行提示
    echo -e "${YELLOW}🚀 运行方法:${NC}"
    echo -e "   ${WHITE}./trojan-grpc-forwarder${NC}"
    echo ""
    echo -e "${YELLOW}📋 安装到系统:${NC}"
    echo -e "   ${WHITE}sudo ./install-debian.sh${NC}"
    echo ""
else
    echo -e "${RED}❌ 可执行文件未找到！${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 构建脚本执行完成！${NC}"
