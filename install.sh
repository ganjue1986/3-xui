#!/bin/bash
# ================================================================
# 自定义 3x-ui 一键管理脚本（自动检测最新版）
# 作者: ganjue1986
# 仓库: https://github.com/ganjue1986/3-xui
# ================================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

REPO="ganjue1986/3-xui"
INSTALL_DIR="/usr/local/x-ui"
SERVICE_FILE="/etc/systemd/system/x-ui.service"

[[ $EUID -ne 0 ]] && echo -e "${red}❌ 请使用 root 权限运行此脚本${plain}" && exit 1

# 检查架构
arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo "amd64" ;;
        i*86) echo "386" ;;
        armv8* | aarch64) echo "arm64" ;;
        armv7* | armv7 | arm) echo "armv7" ;;
        *) echo -e "${red}不支持的架构: $(uname -m)${plain}" && exit 1 ;;
    esac
}

# 检查 GLIBC 版本
check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required="2.32"
    if [[ "$(printf '%s\n' "$required" "$glibc_version" | sort -V | head -n1)" != "$required" ]]; then
        echo -e "${red}GLIBC 版本过低 ($glibc_version)，需要 ≥ 2.32${plain}"
        exit 1
    fi
}

# 安装依赖
install_base() {
    if command -v apt >/dev/null 2>&1; then
        apt update -y && apt install -y curl unzip wget
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl unzip wget
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl unzip wget
    else
        echo -e "${red}无法识别的包管理器，请手动安装 curl unzip wget${plain}"
        exit 1
    fi
}

# 获取公网 IP
get_ip() {
    curl -s --max-time 3 https://api.ipify.org || curl -s --max-time 3 https://4.ident.me
}

# 生成随机字符串
gen_rand() {
    local len=$1
    tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$len" | head -n 1
}

# 获取最新 release 版本 ZIP 下载链接
get_latest_zip() {
    curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url" \
    | grep ".zip" \
    | cut -d '"' -f 4 \
    | head -n 1
}

# 安装 3x-ui
install_xui() {
    echo -e "${blue}📦 正在安装自定义 3x-ui...${plain}"
    install_base
    check_glibc_version
    arch_type=$(arch)

    systemctl stop x-ui >/dev/null 2>&1
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1

    echo -e "${yellow}🔍 检测最新版本...${plain}"
    ZIP_URL=$(get_latest_zip)
    if [[ -z "$ZIP_URL" ]]; then
        echo -e "${red}❌ 获取最新版本失败，请检查仓库是否有 Release${plain}"
        exit 1
    fi
    echo -e "${green}✅ 最新版本: $ZIP_URL${plain}"

    echo -e "${yellow}⬇️  下载中...${plain}"
    curl -L -o "$INSTALL_DIR/3x-ui.zip" "$ZIP_URL" || { echo -e "${red}下载失败${plain}"; exit 1; }

    echo -e "${yellow}🧩 解压中...${plain}"
    unzip -o 3x-ui.zip >/dev/null 2>&1
    rm -f 3x-ui.zip
    chmod +x x-ui

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=3x-ui Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/x-ui
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    chmod +x /usr/local/x-ui/x-ui
    ln -sf /usr/local/x-ui/x-ui /usr/bin/x-ui

    local ip=$(get_ip)
    local username=$(gen_rand 8)
    local password=$(gen_rand 10)
    local port=$(shuf -i 10000-60000 -n 1)
    local webpath=$(gen_rand 10)

    /usr/local/x-ui/x-ui setting -username "$username" -password "$password" -port "$port" -webBasePath "$webpath" >/dev/null 2>&1
    /usr/local/x-ui/x-ui migrate >/dev/null 2>&1

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "\n${green}✅ 安装完成！${plain}"
    echo -e "-------------------------------------------"
    echo -e " 用户名: ${green}$username${plain}"
    echo -e " 密码: ${green}$password${plain}"
    echo -e " 端口: ${green}$port${plain}"
    echo -e " 路径: ${green}/$webpath${plain}"
    echo -e " 登录地址: ${blue}http://$ip:$port/$webpath${plain}"
    echo -e "-------------------------------------------"
}

# 卸载
uninstall_xui() {
    echo -e "${red}⚠️ 确认要卸载 3x-ui 吗？(y/n)${plain}"
    read -r confirm
    [[ "$confirm" != "y" ]] && echo "取消卸载" && exit 0

    systemctl stop x-ui
    systemctl disable x-ui
    rm -f "$SERVICE_FILE"
    rm -rf "$INSTALL_DIR"
    systemctl daemon-reload

    echo -e "${green}✅ 已卸载${plain}"
}

# 查看状态
status_xui() {
    systemctl status x-ui --no-pager
}

# 重启
restart_xui() {
    systemctl restart x-ui
    echo -e "${green}✅ 已重启${plain}"
}

# 菜单
menu() {
    clear
    echo -e "=============================================="
    echo -e " ${green}3x-ui 一键安装脚本 (自动检测版本)${plain}"
    echo -e "=============================================="
    echo -e " 1. 安装 3x-ui"
    echo -e " 2. 卸载 3x-ui"
    echo -e " 3. 重启 3x-ui"
    echo -e " 4. 查看运行状态"
    echo -e " 0. 退出"
    echo -e "=============================================="
    read -rp "请输入选项 [0-4]: " choice

    case "$choice" in
        1) install_xui ;;
        2) uninstall_xui ;;
        3) restart_xui ;;
        4) status_xui ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项" ;;
    esac
}

menu
