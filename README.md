# Codex Setup Scripts

一键配置 [OpenAI Codex](https://openai.com/codex/) / ChatGPT 桌面端 / Codex CLI 以适配各种大模型平台的 PowerShell 脚本（Windows）。

## 支持的平台

| 脚本 | 平台 | Provider ID | Base URL |
|------|------|-------------|----------|
| `codex-deepseek-setup.ps1` | DeepSeek | `deepseek` | `https://api.deepseek.com/` |
| `codex-longcat-setup.ps1` | LongCat (美团龙猫) | `longcat` | `https://api.longcat.chat/openai/v1/` |
| `codex-glm-setup.ps1` | GLM (智谱 AI) | `glm` | `https://open.bigmodel.cn/api/paas/v4` |
| `codex-kimi-setup.ps1` | Kimi (月之暗面) | `kimi` | `https://api.moonshot.cn/v1` |
| `codex-minimax-setup.ps1` | MiniMax | `minimax` | `https://api.minimax.chat/v1` |
| `codex-qwen-setup.ps1` | Qwen (通义千问) | `qwen` | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| `codex-custom-setup.ps1` | 自定义（任意 OpenAI 兼容 API） | 用户自定义 | 用户自定义 |

## 快速开始

### 方式一：一键安装（推荐）

在 PowerShell 中运行：

```powershell
irm https://raw.githubusercontent.com/techmsh/codex-setup-scripts/main/codex-<provider>-setup.ps1 | iex
```

例如配置 DeepSeek：

```powershell
irm https://raw.githubusercontent.com/techmsh/codex-setup-scripts/main/codex-deepseek-setup.ps1 | iex
```

### 方式二：手动运行

1. 下载对应脚本到本地
2. 在 PowerShell 中执行：

```powershell
.\codex-deepseek-setup.ps1
```

3. 按提示选择要使用的模型

## 功能

- **模型选择**：支持各平台全部模型，动态菜单列出
- **自动发现**：自定义脚本支持调用 API `/models` 端点自动获取可用模型
- **配置生成**：自动生成 `config.toml` + `models.json`
- **备份还原**：安装前自动备份原有配置，支持一键还原
- **模型切换**：随时切换模型，无需重新配置
- **6 级推理**：支持 low / medium / high / xhigh / ultra / max 全部推理等级

## 菜单说明

运行脚本后：

```
请选择要执行的操作：
  1. model-flash          - 高速模型描述
  2. model-pro            - 旗舰模型描述
  ...
  99. 自定义模型（手动输入 slug）
  9.  恢复默认的 Codex 配置
```

- 选择 `1`~`N`：使用预设模型
- 选择 `99`：手动输入任意 model slug
- 选择 `9`：恢复安装前的配置

## 系统要求

- Windows PowerShell 5.1+ 或 PowerShell 7+
- 已安装 Codex CLI / ChatGPT 桌面客户端 / VS Code Codex 插件

## 目录结构

运行后会在 `~/.codex/` 目录下生成：

```
~/.codex/
├── config.toml          # Codex 配置文件
├── models.json          # 模型目录（包含所有可用模型）
└── backup-<provider>/   # 备份目录
    ├── config.toml      # 原始配置备份
    └── manifest.txt     # 安装记录
```

## 常见问题

**Q: 配置后不生效？**
A: 请完全退出 ChatGPT 桌面端后重新打开（右键任务栏托盘图标选择退出；仅关闭窗口进程仍在后台，不算退出）。

**Q: 如何确认已生效？**
A: 打开 ChatGPT 桌面端，右下角显示"自定义"或所选模型名即表示成功。

**Q: 支持哪些模型？**
A: 每个平台脚本都包含该平台的全部可用模型，也可通过选项 99 手动输入任意 slug。

## 许可证

[MIT License](LICENSE) © 2026 msh (https://github.com/techmsh)

## 贡献

欢迎提交 Issue 和 PR！
