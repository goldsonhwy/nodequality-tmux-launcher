# NodeQuality 测评一键启动脚本

这是一个用于运行 NodeQuality 服务器测评的 Bash 脚本。脚本具有以下功能：

- 自动安装缺少的 `curl` 和 `tmux`。
- 在独立的 `tmux` 后台会话中运行测评。
- 自动输入 `v`、`y`、`y`、`y`。
- SSH 连接断开后，测评仍会继续运行。
- 支持重新连接查看实时输出。
- 自动保存测评输出日志。

## 一键启动

请在 Debian 或 Ubuntu 服务器上执行。当前用户需要具备 root 权限，或者可以使用无需交互输入密码的 `sudo`：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/goldsonhwy/nodequality-tmux-launcher/main/nodequality-tmux.sh)
```

脚本启动后会立即返回，测评会在后台继续运行。

启动成功后会显示以下提示：

```text
脚本已经开始执行，你可以放心关闭SSH，重新连接后在服务器输入look即可返回脚本观看进度。
```

SSH 断开后，重新连接服务器并输入：

```bash
look
```

即可重新进入测评的 `tmux` 会话查看进度。

## 重新连接查看输出

SSH 重新连接服务器后，执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/goldsonhwy/nodequality-tmux-launcher/main/nodequality-tmux.sh) attach
```

也可以直接输入：

```bash
look
```

进入 `tmux` 后，如果想退出查看界面但不停止测评，请按：

```text
Ctrl-b，然后按 d
```

## 查看运行状态

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/goldsonhwy/nodequality-tmux-launcher/main/nodequality-tmux.sh) status
```

如果会话正在运行，会显示 `nodequality` 会话信息。

## 查看保存的日志

默认日志文件为：

```bash
cat ~/nodequality-nodequality.log
```

也可以实时查看日志：

```bash
tail -f ~/nodequality-nodequality.log
```

## 停止测评

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/goldsonhwy/nodequality-tmux-launcher/main/nodequality-tmux.sh) stop
```

## 使用本地脚本

如果已经下载了 `nodequality-tmux.sh`，可以直接执行：

```bash
bash nodequality-tmux.sh
```

重新连接查看输出：

```bash
bash nodequality-tmux.sh attach
```

查看状态：

```bash
bash nodequality-tmux.sh status
```

停止测评：

```bash
bash nodequality-tmux.sh stop
```

## 自定义会话名称

默认会话名称为 `nodequality`。如果需要同时运行多个测评，可以指定不同的会话名称：

```bash
NODEQUALITY_TMUX_SESSION=my-test bash nodequality-tmux.sh
```

重新连接指定会话：

```bash
NODEQUALITY_TMUX_SESSION=my-test bash nodequality-tmux.sh attach
```

对应的日志文件为：

```bash
cat ~/nodequality-my-test.log
```

## 注意事项

脚本运行时会从 `https://run.NodeQuality.com` 下载当前版本的 NodeQuality 测评脚本。测评过程中还会下载其他测试组件，并使用临时目录、挂载和临时系统环境。

启动脚本时会在 `/usr/local/bin/look` 安装查看命令。如果服务器已经存在其他同名命令，脚本不会覆盖它，并会提示你处理命令冲突。

请确认服务器允许相关操作，并在生产服务器上运行前了解测评脚本的行为。
