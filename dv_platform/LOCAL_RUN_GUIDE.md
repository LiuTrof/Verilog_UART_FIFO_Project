# DV Platform 本地启动说明

本文说明如何在本机启动 Chip DV Platform 的前端、后端和验证回归任务，并检查它们是否
正常工作。

## 1. 打开本地终端

项目根目录是 `Verilog_UART_FIFO_0524`。所有命令都应从该目录开始执行。

### 在 IDE 中打开

如果正在使用 VS Code 或兼容 IDE：

1. 打开菜单 `Terminal` -> `New Terminal`。
2. 在终端中确认当前位置：

```bash
pwd
```

3. 如果不是项目根目录，切换到项目目录：

```bash
cd /Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524
```

需要同时运行前端、后端和独立回归时，在终端面板点击 `+` 新建终端即可。建议使用三个
终端，彼此不要关闭。

### 在 macOS Terminal 中打开

1. 按 `Command + Space`，输入 `Terminal`，按回车。
2. 执行：

```bash
cd /Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524
```

## 2. 环境检查

在项目根目录执行以下命令：

```bash
python3 --version
node --version
npm --version
iverilog -V
```

本项目需要：

- Python 3.10 或更高版本，用于 FastAPI 后端和自动化回归。
- Node.js 18 或更高版本，用于 React/Vite 前端。
- Icarus Verilog（`iverilog`），用于本机兼容回归。

标准 UVM 回归还需要 VCS、Xcelium 或 Questa/ModelSim 中的一种；Icarus 不能执行
class-based UVM testbench。

## 3. 启动后端服务

在终端 1 中，从项目根目录执行。

首次使用或 Python 依赖更新后：

```bash
python3 -m venv .venv
.venv/bin/pip install -r dv_platform/backend/requirements.txt
```

启动后端：

```bash
.venv/bin/uvicorn dv_platform.backend.app.main:app --reload --host 127.0.0.1 --port 8000
```

服务启动成功后，保持该终端运行。后端地址为：

- API 健康检查：`http://127.0.0.1:8000/api/v1/health`
- API 文档：`http://127.0.0.1:8000/docs`

可在另一个终端验证后端：

```bash
curl http://127.0.0.1:8000/api/v1/health
```

预期返回：

```json
{"status":"ok","service":"chip-dv-platform"}
```

后端启动时会自动创建或复用 `sim/dv_platform/platform.db`，用于保存项目、用例和回归
历史。

## 4. 启动前端服务

在终端 2 中执行：

```bash
cd /Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524/dv_platform/frontend
export PATH="$HOME/.nvm/versions/node/v22.22.0/bin:$PATH"  # 本机同时安装 Node 14 时必须先执行。
npm ci
npm run dev -- --host 127.0.0.1
```

启动成功后，在浏览器打开：

```text
http://127.0.0.1:5173
```

前端开发服务器会将 `/api` 请求代理到 `http://127.0.0.1:8000`，因此后端必须先保持
运行。打开页面后可依次检查：

1. 仪表盘能显示 UART FIFO 项目和最近回归信息。
2. 测试管理能显示预置的 `single`、`multi`、`stream`、`fifo`、`reset` 场景。
3. 回归中心可启动新任务并查看每个场景的日志结果。
4. 波形信号索引可查看已有 VCD，或上传 `.vcd` 文件。

## 5. 执行验证回归

验证回归不是常驻网络服务，而是按需在终端执行的任务。可在终端 3 中从项目根目录运行：

```bash
python3 -m dv_platform.automation --cases fifo
```

这会执行一个快速 FIFO 边界烟雾回归。完整兼容回归使用：

```bash
python3 -m dv_platform.automation --cases all
```

可单独运行 UART 场景：

```bash
python3 -m dv_platform.automation --cases single
python3 -m dv_platform.automation --cases multi
python3 -m dv_platform.automation --cases stream
python3 -m dv_platform.automation --cases reset
```

自动化命令会优先检测 VCS、Xcelium 或 Questa/ModelSim；检测到时会调用与
`./run.sh` 相同的 UVM 入口。没有商业 UVM 仿真器而检测到 Icarus 时，结果中的仿真器名称为
`iverilog-legacy`，表示它运行的是项目保留的 legacy 自检兼容入口，而不是 UVM。

回归产物会写入：

```text
sim/dv_platform/build/   # Icarus 编译产物
sim/dv_platform/log/     # 每个场景的原始日志
sim/dv_platform/report/  # JSON 格式回归报告
```

也可以从前端的“回归中心”或“测试管理”发起回归。该操作会请求后端
`POST /api/v1/projects/1/regressions`，后端在自身进程中异步执行同一套自动化流程；
前端只在该任务处于 `queued` 状态且回归页面可见时轮询状态，并采用 5、10、20、30 秒的
退避间隔。每个由平台发起的单场景任务都会生成一个带回归 ID 的 VCD，随后可在“波形分析”
页面直接查看；“导入 VCD”按钮也会将本地 `.vcd` 文件上传并建立信号索引。

## 6. 标准 UVM 与波形运行

当本机已经配置支持 UVM 1.2 的商业仿真器时，使用项目原有入口：

```bash
./run.sh all
```

单一场景生成 VCD 并启动 GTKWave：

```bash
./run.sh multi --wave
```

该入口会优先检测 VCS、Xcelium、Questa/ModelSim。日志位于：

```text
sim/uart_fifo_sim/log/
```

## 7. 常见问题

### 端口 8000 或 5173 已被占用

先查看占用端口的进程：

```bash
lsof -nP -iTCP:8000 -sTCP:LISTEN
lsof -nP -iTCP:5173 -sTCP:LISTEN
```

若确认是之前启动的本项目服务，可在对应终端按 `Control + C` 停止。无法找到原终端时，
确认 PID 后再执行：

```bash
kill <PID>
```

不要对不确定归属的进程执行 `kill`。

### 前端页面无法获取数据

按以下顺序检查：

1. 后端终端仍在运行，且 `curl http://127.0.0.1:8000/api/v1/health` 返回 `ok`。
2. 前端地址是 `http://127.0.0.1:5173`。
3. 前端终端没有 Node.js 或依赖安装错误。
4. 浏览器开发者工具的 Network 面板中 `/api/v1/...` 请求不是 `502` 或 `500`。

### `iverilog: command not found`

使用 Homebrew 安装 Icarus Verilog：

```bash
brew install icarus-verilog
```

重新打开终端后执行 `iverilog -V` 确认安装成功。

### `npm` 使用了过旧的 Node.js

如果系统同时安装了多个 Node.js，可先确认：

```bash
which node
node --version
```

使用 nvm 的环境可切换到较新的 LTS 版本后，再重新运行 `npm ci`。

本机还安装了 `/usr/local/bin/node` 的 Node 14，它无法解析 Vite 5 所用的
`??=` 语法。若看到 `Unexpected token '??='`，在前端终端先执行：

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.0/bin:$PATH"
node --version
```

确认显示 `v22.22.0` 后，再执行 `npm run dev` 或 `npm run build`。

## 8. 停止服务

后端和前端都在各自的终端按 `Control + C` 停止。独立回归完成后会自动退出，无需额外
停止操作。

再次启动时，重复第 3、4、5 节的命令即可；Python 虚拟环境和 `node_modules` 已存在时，
无需每次重复安装依赖。

## 9. 固定公网演示链接

项目提供 `dv_platform/start_demo_tunnel.sh`，用于通过 Serveo 将本机前端临时公开为固定
HTTPS 地址。首次使用需要在 Serveo 绑定本机 SSH 公钥；绑定后，即使关闭并重新打开隧道
终端，只要前端和后端已启动，重新运行脚本就会恢复相同的地址。

首次绑定完成后，在新的终端执行：

```bash
cd /Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524
./dv_platform/start_demo_tunnel.sh
```

默认固定地址是：

```text
https://chip-dv-uart-demo.serveousercontent.com
```

可传入自己的子域名作为第一个参数：

```bash
./dv_platform/start_demo_tunnel.sh my-chip-dv-demo
```

该隧道只在脚本所在终端运行期间对公网开放。脚本会在 SSH 隧道意外断开时自动重连；按
`Control + C` 停止。之后重新执行同一条命令即可恢复同一个固定地址。演示链接拥有平台
当前的完整功能，不应公开给不受信任的人员。

Serveo 固定地址要求 Serveo 账户仍有可用隧道额度，且当前机器的 SSH 公钥已在该账户中
成功授权。若终端显示 `remote port forwarding failed for listen port 80`，请在 Serveo Console
关闭旧的活跃隧道后再重试；浏览器返回 `502` 表示公网转发没有成功建立，并非访问者是否
与本机处于同一个 Wi-Fi 所致。

## 10. Cloudflare 临时公网演示链接

当 Serveo 的额度或固定地址不可用时，可使用项目提供的 Cloudflare 备用隧道。该方式不需要
访问者与本机连接同一网络，但每次重启会生成一个新的 `trycloudflare.com` 地址。

首次安装工具：

```bash
brew install cloudflared
```

在前端和后端都已启动后，另开一个终端执行：

```bash
cd /Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524
./dv_platform/start_cloudflare_demo_tunnel.sh
```

终端打印的 `https://*.trycloudflare.com` 即为可分享地址。该终端、前端终端和后端终端都必须
持续运行；按 `Control + C` 停止隧道后，公网地址立即失效。
