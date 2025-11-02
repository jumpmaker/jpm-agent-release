# JPM-Agent

JPM-Agent 是一个用于监控系统指标和 Supervisor 进程的代理服务。

## 功能特性

- 🔍 系统监控：CPU、内存、磁盘、负载等指标监控
- 🔄 Supervisor 进程监控：监控 Supervisor 管理的进程状态
- 📊 Redis 数据存储：支持 AWS ElastiCache 主从和集群模式
- 🔔 告警通知：支持 Lark/Feishu 机器人告警
- ⚙️ 灵活配置：支持 YAML 配置文件

## 安装方式

### 方式一：一键安装（推荐）

使用 curl 直接从远程安装脚本安装：

```bash
curl -fsSL https://raw.githubusercontent.com/jumpmaker/jpm-agent-release/refs/heads/main/install.sh | sh
```

此命令会：
- 自动获取最新版本的安装包
- 从 GitHub Release 下载二进制包
- 自动安装到/data/jpm-agent目录

#### 自定义安装路径

```bash
export INSTALL_DIR=/opt/jpm-agent
export CONFIG_DIR=/opt/jpm-agent
curl -fsSL https://raw.githubusercontent.com/jumpmaker/jpm-agent-release/refs/heads/main/install.sh | sh
```

### 方式二：下载安装包手动安装

#### 步骤 1: 下载安装包

从 GitHub Release 下载安装包：

```bash
# 查看最新版本
# 访问: https://github.com/jumpmaker/jpm-agent-release/releases/latest

# 下载最新版本的 Linux amd64 安装包
# 替换 <VERSION> 为实际版本号，例如 v1.0.0
VERSION="v1.0.0"
wget https://github.com/jumpmaker/jpm-agent-release/releases/download/${VERSION}/jpm-agent-${VERSION}-linux-amd64.tar.gz
# 或使用 curl
curl -LO https://github.com/jumpmaker/jpm-agent-release/releases/download/${VERSION}/jpm-agent-${VERSION}-linux-amd64.tar.gz
```

#### 步骤 2: 解压安装包

```bash
tar -xzf jpm-agent-${VERSION}-linux-amd64.tar.gz
cd jpm-agent
```

#### 步骤 3: 运行安装脚本

```bash
sudo ./install.sh
```

安装脚本会自动：
- 安装二进制文件到 `/data/jpm-agent/jpm-agent`
- 复制默认配置文件 `/data/jpm-agent/config.yaml`
- 安装 systemd service 文件到 `/etc/systemd/system/jpm-agent.service`（如果系统支持 systemd）

#### 步骤 4: 配置（可选）

编辑配置文件：

```bash
sudo vi /data/jpm-agent/config.yaml
```

## 配置说明

### Redis 配置

支持两种 Redis 模式：

**单机/主从模式：**
```yaml
redis:
  mode: "standalone"
  host: "your-redis-endpoint.amazonaws.com"
  port: 6379
  password: "your-password"
  database: 0
  tls:
    enable: true
    insecure_skip_verify: false
```

**集群模式：**
```yaml
redis:
  mode: "cluster"
  host: "your-cluster-config-endpoint.amazonaws.com"
  port: 6379
  password: "your-password"
  tls:
    enable: true
    insecure_skip_verify: false
```

### 监控配置

```yaml
monitor:
  interval: "30s"
  enable_cpu: true
  enable_memory: true
  enable_disk: true
  thresholds:
    cpu_usage: 80.0
    memory_usage: 85.0
    disk_usage: 90.0
```

详细配置说明请参考 `config-example.yaml`。

## 运行服务

### 使用 systemd（推荐）

安装脚本会自动安装 systemd service 文件到 `/etc/systemd/system/jpm-agent.service`（在支持 systemd 的系统上）。

1. 启动服务：
```bash
sudo systemctl start jpm-agent
```

2. 设置开机自启：
```bash
sudo systemctl enable jpm-agent
```

3. 查看服务状态：
```bash
sudo systemctl status jpm-agent
```

4. 查看日志：
```bash
sudo journalctl -u jpm-agent -f
```

5. 重启服务：
```bash
sudo systemctl restart jpm-agent
```

> **注意**：如果使用自定义安装路径（通过 `INSTALL_DIR` 或 `CONFIG_DIR` 环境变量），安装脚本会自动更新 service 文件中的路径。

### 直接运行

```bash
/data/jpm-agent/jpm-agent -c /data/jpm-agent/config.yaml
```

## 卸载

```bash
# 停止服务
sudo systemctl stop jpm-agent
sudo systemctl disable jpm-agent

# 删除文件
sudo rm -f /data/jpm-agent/jpm-agent
sudo rm -rf /data/jpm-agent
sudo rm -f /etc/systemd/system/jpm-agent.service
sudo systemctl daemon-reload
```
