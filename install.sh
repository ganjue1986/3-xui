#!/bin/bash
# 3x-ui Custom Installer by ganjue1986 (based on MHSanaei original)

ZIP_URL="https://github.com/ganjue1986/3-xui/releases/download/1.1/3x-ui-2.6.2.zip"
INSTALL_DIR="/usr/local/x-ui"

red='\033[0;31m'; green='\033[0;32m'; yellow='\033[0;33m'; blue='\033[0;34m'; plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}请使用 root 用户运行本脚本${plain}" && exit 1

arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64";;
    aarch64|arm64) echo "arm64";;
    *) echo "unsupported";;
  esac
}

os_install_base() {
  if [ -x "$(command -v apt-get)" ]; then
    apt-get update && apt-get install -y curl wget unzip tar tzdata
  elif [ -x "$(command -v yum)" ]; then
    yum -y update && yum install -y curl wget unzip tar tzdata
  else
    echo -e "${red}不支持的系统${plain}" && exit 1
  fi
}

gen_random_string() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-12}"
}

config_after_install() {
  local server_ip=$(curl -s https://api.ipify.org)
  local username=$(gen_random_string 8)
  local password=$(gen_random_string 10)
  local webpath=$(gen_random_string 12)
  local port=$(shuf -i 10000-60000 -n 1)

  ${INSTALL_DIR}/x-ui setting -username "${username}" -password "${password}" -port "${port}" -webBasePath "${webpath}" >/dev/null 2>&1
  ${INSTALL_DIR}/x-ui migrate >/dev/null 2>&1

  echo -e "\n${green}安装完成！访问信息如下：${plain}"
  echo "---------------------------------------------"
  echo "地址: http://${server_ip}:${port}/${webpath}"
  echo "用户名: ${username}"
  echo "密码: ${password}"
  echo "---------------------------------------------"
}

install_xui() {
  echo -e "${yellow}正在安装 3x-ui ...${plain}"
  os_install_base
  mkdir -p ${INSTALL_DIR}
  cd /usr/local || exit 1

  curl -L -o 3x-ui.zip ${ZIP_URL} || { echo "${red}下载失败${plain}"; exit 1; }
  unzip -o 3x-ui.zip -d ${INSTALL_DIR} >/dev/null 2>&1
  rm -f 3x-ui.zip
  chmod +x ${INSTALL_DIR}/x-ui

  cat >/etc/systemd/system/x-ui.service <<EOF
[Unit]
Description=3x-ui Panel Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/x-ui
WorkingDirectory=${INSTALL_DIR}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable x-ui
  systemctl restart x-ui

  config_after_install
}

uninstall_xui() {
  systemctl stop x-ui
  systemctl disable x-ui
  rm -rf ${INSTALL_DIR} /etc/systemd/system/x-ui.service /usr/bin/x-ui
  echo -e "${red}3x-ui 已彻底卸载${plain}"
}

show_status() {
  systemctl status x-ui --no-pager
}

menu() {
  clear
  echo -e "${green}=========== 3x-ui 管理菜单 (自定义版) ===========${plain}"
  echo "1. 安装 / 更新"
  echo "2. 启动面板"
  echo "3. 停止面板"
  echo "4. 重启面板"
  echo "5. 查看状态"
  echo "6. 查看日志"
  echo "7. 卸载面板"
  echo "0. 退出"
  echo "---------------------------------------------"
  read -rp "请输入选项: " choice

  case "$choice" in
    1) install_xui ;;
    2) systemctl start x-ui && echo "${green}已启动${plain}" ;;
    3) systemctl stop x-ui && echo "${yellow}已停止${plain}" ;;
    4) systemctl restart x-ui && echo "${green}已重启${plain}" ;;
    5) show_status ;;
    6) journalctl -u x-ui -e --no-pager ;;
    7) uninstall_xui ;;
    0) exit 0 ;;
    *) echo "无效选项" ;;
  esac
}

menu
