# Codex Setup Scripts

一键配置 [OpenAI Codex](https://openai.com/codex/) / ChatGPT 桌面端 / Codex CLI 以适配各种大模型平台的工具集。

> **来源说明**: 本项目基于 [DeepSeek 一键安装命令](https://api-docs.deepseek.com/zh-cn/quick_start/agent_integrations/codex) 修改而来，但程序架构和实现均为自行开发。本项目由 **AI 辅助开发**完成。

## 项目结构

```
codex-setup-scripts/
├── Windows/              # Windows PowerShell 脚本
│   ├── codex-deepseek-setup.ps1
│   ├── codex-longcat-setup.ps1
│   ├── codex-glm-setup.ps1
│   ├── codex-kimi-setup.ps1
│   ├── codex-minimax-setup.ps1
│   ├── codex-qwen-setup.ps1
│   ├── codex-openrouter-setup.ps1
│   ├── codex-xai-setup.ps1
│   ├── codex-fireworks-setup.ps1
│   ├── codex-novita-setup.ps1
│   ├── codex-huggingface-setup.ps1
│   ├── codex-meta-setup.ps1
│   ├── codex-stepfun-setup.ps1
│   ├── codex-xiaomi-setup.ps1
│   └── codex-custom-setup.ps1
├── Linux/                # Linux/macOS Bash 脚本
│   └── codex-*-setup.sh  # 各平台独立脚本
├── GUI/                  # Rust 图形化程序
│   ├── Cargo.toml
│   ├── src/main.rs       # 源码
│   ├── script/           # 内嵌脚本
│   └── target/release/   # 编译产物
├── LICENSE               # MIT License
└── README.md             # 本文件
```

## 支持的平台

| 平台 | Provider ID | Base URL | 模型数量 |
|------|-------------|----------|---------|
| DeepSeek | `deepseek` | `https://api.deepseek.com/` | 7 |
| LongCat (美团龙猫) | `longcat` | `https://api.longcat.chat/openai/v1/` | 4 |
| GLM (智谱 AI) | `glm` | `https://open.bigmodel.cn/api/paas/v4` | 12 |
| Kimi (月之暗面) | `kimi` | `https://api.moonshot.cn/v1` | 8 |
| MiniMax | `minimax` | `https://api.minimax.chat/v1` | 8 |
| Qwen (通义千问) | `qwen` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 16 |
| OpenRouter | `openrouter` | `https://openrouter.ai/api/v1` | 12 |
| xAI (Grok) | `xai` | `https://api.x.ai/v1` | 8 |
| Fireworks AI | `fireworks` | `https://api.fireworks.ai/inference/v1` | 8 |
| Novita AI | `novita` | `https://api.novita.ai/openai/v1` | 8 |
| Hugging Face | `huggingface` | `https://router.huggingface.co/v1` | 7 |
| Meta Model API | `meta` | `https://api.meta.ai/v1` | 6 |
| StepFun | `stepfun` | `https://api.stepfun.ai/v1` | 2 |
| Xiaomi MiMo | `xiaomi` | `https://api.xiaomimimo.com/v1` | 3 |
| 自定义 | 用户定义 | 用户定义 | ∞ |

## 使用方式

### 图形化界面 (GUI)

编译并运行 Rust GUI 程序：

```bash
cd GUI
cargo build --release
./target/release/codex-setup-gui    # Linux/macOS
.\target\release\codex-setup-gui.exe  # Windows
```

### Windows (PowerShell)

```powershell
# 一键安装（推荐）
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-deepseek-setup.ps1 | iex

# 或手动运行
.\Windows\codex-deepseek-setup.ps1
```

新增第三方平台均为独立脚本，每个命令只安装对应平台：

```powershell
# OpenRouter
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-openrouter-setup.ps1 | iex

# xAI / Grok
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-xai-setup.ps1 | iex

# Fireworks AI
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-fireworks-setup.ps1 | iex

# Novita AI
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-novita-setup.ps1 | iex

# Hugging Face
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-huggingface-setup.ps1 | iex

# Meta Model API
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-meta-setup.ps1 | iex

# StepFun
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-stepfun-setup.ps1 | iex

# Xiaomi MiMo
irm https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/codex-xiaomi-setup.ps1 | iex
```

脚本会优先读取对应环境变量；未设置时会提示输入 API Key：

| 平台 | 环境变量 |
|------|----------|
| OpenRouter | `OPENROUTER_API_KEY` |
| xAI | `XAI_API_KEY` |
| Fireworks AI | `FIREWORKS_API_KEY` |
| Novita AI | `NOVITA_API_KEY` |
| Hugging Face | `HF_TOKEN` |
| Meta Model API | `META_MODEL_API_KEY` 或 `MODEL_API_KEY` |
| StepFun | `STEPFUN_API_KEY` |
| Xiaomi MiMo | `XIAOMI_API_KEY` |

### Linux/macOS (Bash)

```bash
# OpenRouter
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-openrouter-setup.sh | bash

# xAI / Grok
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-xai-setup.sh | bash

# Fireworks AI
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-fireworks-setup.sh | bash

# Novita AI
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-novita-setup.sh | bash

# Hugging Face
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-huggingface-setup.sh | bash

# Meta Model API
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-meta-setup.sh | bash

# StepFun
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-stepfun-setup.sh | bash

# Xiaomi MiMo
curl -fsSL https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/codex-xiaomi-setup.sh | bash
```

## 功能

- **模型选择**: 支持各平台全部模型，动态菜单列出
- **自定义模型**: 支持手动输入任意 model slug（选项 99）
- **配置生成**: 自动生成 `config.toml` + `models.json`
- **备份还原**: 安装前自动备份原有配置，支持一键还原
- **模型切换**: 随时切换模型，无需重新配置
- **6 级推理**: 支持 low / medium / high / xhigh / ultra / max
- **图形化界面**: Rust + egui 开发的跨平台 GUI

## 系统要求

### GUI 程序
- Rust 1.70+ (编译用)
- 无额外运行依赖（静态链接）

### Shell 脚本
- Windows: PowerShell 5.1+
- Linux/macOS: Bash 4.3+
- 可选: jq 或 python3（用于 JSON 生成）

## 从源码构建 GUI

```bash
# 克隆仓库
git clone https://github.com/techmsh/codex--custom-setup.git
cd codex--custom-setup/GUI

# 构建
cargo build --release

# 运行
./target/release/codex-setup-gui
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

---

**免责声明**: 本项目与 DeepSeek、LongCat、GLM、Kimi、MiniMax、Qwen 等平台无官方关联，仅为社区工具。
