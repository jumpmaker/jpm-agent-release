#!/bin/sh
# -*- coding: utf-8 -*-
# 此脚本使用 UTF-8 编码，包含中文字符
# This script uses UTF-8 encoding and contains Chinese characters
set -eu

# 确保使用 UTF-8 编码环境
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true
export LANG=C.UTF-8 2>/dev/null || export LANG=en_US.UTF-8 2>/dev/null || true

APP_NAME="jpm-agent"
RELEASE_REPO="${GITHUB_RELEASE_REPO:-jumpmaker/jpm-agent-release}"
INSTALL_DIR="${INSTALL_DIR:-/data/jpm-agent}"
CONFIG_DIR="${CONFIG_DIR:-/data/jpm-agent}"
BIN_DEST="${INSTALL_DIR}/${APP_NAME}"
TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t jpminstall)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误: 需要命令 $1" >&2
        exit 1
    fi
}

can_write_dir() {
    dir="$1"
    if [ -d "$dir" ]; then
        [ -w "$dir" ]
    else
        parent=$(dirname "$dir")
        [ -w "$parent" ]
    fi
}

maybe_use_sudo() {
    if can_write_dir "$1"; then
        echo ""
    elif command -v sudo >/dev/null 2>&1; then
        echo "sudo"
    else
        echo "错误: 没有权限写入 $1 且未找到 sudo" >&2
        exit 1
    fi
}

run_with_prefix() {
    prefix="$1"
    shift
    if [ -z "$prefix" ]; then
        "$@"
    else
        $prefix "$@"
    fi
}

install_systemd_service() {
    # 检查是否存在 systemd
    if [ ! -d "/run/systemd/system" ] && [ ! -d "/etc/systemd/system" ]; then
        return 0  # 不是 systemd 系统，跳过
    fi
    
    # 查找 service 文件
    service_file=""
    staging="$TMP_DIR/$APP_NAME"
    if [ -f "$staging/examples/systemd/${APP_NAME}.service" ]; then
        service_file="$staging/examples/systemd/${APP_NAME}.service"
    elif [ -f "$staging/${APP_NAME}.service" ]; then
        service_file="$staging/${APP_NAME}.service"
    else
        return 0  # 找不到 service 文件，跳过
    fi
    
    systemd_dir="/etc/systemd/system"
    service_dest="${systemd_dir}/${APP_NAME}.service"
    
    sudo_systemd=$(maybe_use_sudo "$systemd_dir")
    
    # 创建临时文件，替换路径
    temp_service="$TMP_DIR/${APP_NAME}.service"
    if [ -f "$temp_service" ]; then
        rm -f "$temp_service"
    fi
    
    # 替换 service 文件中的路径
    # 先替换完整的 ExecStart 行（包含路径和配置文件）
    sed "s|ExecStart=/data/jpm-agent/jpm-agent -c /data/jpm-agent/config.yaml|ExecStart=${INSTALL_DIR}/${APP_NAME} -c ${CONFIG_DIR}/config.yaml|g" \
        "$service_file" | \
    # 再替换只包含二进制路径的行
    sed "s|ExecStart=/data/jpm-agent/jpm-agent|ExecStart=${INSTALL_DIR}/${APP_NAME}|g" | \
    # 替换其他可能的路径引用
    sed "s|/data/jpm-agent/|${INSTALL_DIR}/|g" > "$temp_service"
    
    # 安装 service 文件
    run_with_prefix "$sudo_systemd" install -Dm644 "$temp_service" "$service_dest"
    echo "已安装 systemd service 文件到 $service_dest"
    
    # 重新加载 systemd
    if [ -n "$sudo_systemd" ]; then
        $sudo_systemd systemctl daemon-reload
    else
        systemctl daemon-reload
    fi
    echo "已重新加载 systemd"
}

get_latest_version() {
    # 从 GitHub API 获取最新版本
    need_cmd curl
    
    if [ -n "${JPM_AGENT_VERSION:-}" ]; then
        echo "$JPM_AGENT_VERSION"
        return
    fi
    
    echo "获取最新版本..." >&2
    version=$(curl -fsSL "https://api.github.com/repos/${RELEASE_REPO}/releases/latest" 2>/dev/null | \
        grep '"tag_name":' | \
        sed -E 's/.*"([^"]+)".*/\1/' || echo "")
    
    if [ -z "$version" ]; then
        echo "错误: 无法获取最新版本，请手动指定 JPM_AGENT_VERSION 环境变量" >&2
        exit 1
    fi
    
    echo "$version"
}

download_release() {
    need_cmd curl
    need_cmd tar
    
    version=$(get_latest_version)
    download_url="https://github.com/${RELEASE_REPO}/releases/download/${version}/${APP_NAME}-${version}-linux-amd64.tar.gz"
    archive="$TMP_DIR/${APP_NAME}-${version}-linux-amd64.tar.gz"

    echo "下载版本 $version 从 GitHub Release..." >&2
    echo "URL: $download_url" >&2
    curl -fsSL "$download_url" -o "$archive"
    
    if [ ! -f "$archive" ] || [ ! -s "$archive" ]; then
        echo "错误: 下载安装包失败" >&2
        exit 1
    fi
    
    # 解压时过滤掉 macOS xattr 相关的警告（不影响解压功能）
    # macOS tar 会在遇到未知的扩展属性关键字时发出警告，但不影响解压
    tar_output=$(tar -xzf "$archive" -C "$TMP_DIR" 2>&1)
    tar_exit=$?
    # 过滤掉 xattr 警告，但保留其他错误信息
    echo "$tar_output" | grep -v "Ignoring unknown extended header keyword" >&2 || true
    if [ $tar_exit -ne 0 ]; then
        echo "错误: 解压安装包失败" >&2
        exit 1
    fi
}

install_from_archive() {
    staging="$TMP_DIR/$APP_NAME"
    if [ ! -d "$staging" ]; then
        echo "错误: 发布包缺少 $APP_NAME 目录" >&2
        exit 1
    fi

    sudo_bin=$(maybe_use_sudo "$INSTALL_DIR")
    sudo_cfg=$(maybe_use_sudo "$CONFIG_DIR")

    run_with_prefix "$sudo_bin" install -Dm755 "$staging/$APP_NAME" "$BIN_DEST"
    echo "已安装二进制到 $BIN_DEST"

    run_with_prefix "$sudo_cfg" mkdir -p "$CONFIG_DIR"
    if [ -f "$staging/config.yaml" ] && [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        run_with_prefix "$sudo_cfg" install -Dm644 "$staging/config.yaml" "$CONFIG_DIR/config.yaml"
        echo "已安装默认配置到 $CONFIG_DIR/config.yaml"
    fi
    if [ -f "$staging/config-example.yaml" ]; then
        run_with_prefix "$sudo_cfg" install -Dm644 "$staging/config-example.yaml" "$CONFIG_DIR/config-example.yaml"
    fi
    
    # 安装 systemd service 文件
    install_systemd_service
}

main() {
    # 从远程下载并安装
    download_release
    install_from_archive

    cat <<EOF

安装完成！
  二进制: $BIN_DEST
  配置目录: $CONFIG_DIR

服务管理：
  启动服务: sudo systemctl start $APP_NAME
  设置开机自启: sudo systemctl enable $APP_NAME
  查看状态: sudo systemctl status $APP_NAME
EOF
}

main "$@"

