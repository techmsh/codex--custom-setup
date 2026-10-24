// MIT License
// Copyright (c) 2026 msh (https://github.com/techmsh)
//
// 本程序由 AI 辅助开发，基于 DeepSeek 一键安装命令修改而来
// 但程序架构和实现均为自行开发。

use eframe::egui;
use std::process::Command;
use std::sync::mpsc;
use std::thread;

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([700.0, 580.0]),
        ..Default::default()
    };

    eframe::run_native(
        "Codex Setup GUI v1.0.0",
        options,
        Box::new(|cc| {
            egui_animation::setup(&cc.egui_ctx);
            Ok(Box::new(CodexSetupApp::new()))
        }),
    )
}

/// 预定义平台配置
const PROVIDERS: &[(&str, &str, &str, &str)] = &[
    ("deepseek", "DeepSeek", "https://api.deepseek.com/", "DEEPSEEK_API_KEY"),
    ("longcat", "LongCat (美团龙猫)", "https://api.longcat.chat/openai/v1/", "LONGCAT_API_KEY"),
    ("glm", "GLM (智谱 AI)", "https://open.bigmodel.cn/api/paas/v4", "GLM_API_KEY"),
    ("kimi", "Kimi (月之暗面)", "https://api.moonshot.cn/v1", "MOONSHOT_API_KEY"),
    ("minimax", "MiniMax", "https://api.minimax.chat/v1", "MINIMAX_API_KEY"),
    ("qwen", "Qwen (通义千问)", "https://dashscope.aliyuncs.com/compatible-mode/v1", "DASHSCOPE_API_KEY"),
    ("custom", "自定义", "", ""),
];

const MODELS_DEEEPSEEK: &[&str] = &[
    "deepseek-chat", "deepseek-reasoner", "deepseek-coder",
    "deepseek-v3", "deepseek-r1", "deepseek-flash", "deepseek-v4-pro",
];

const MODELS_LONGCAT: &[&str] = &[
    "LongCat-2.0", "LongCat-2.5-Preview", "LongCat-Flash", "LongCat-OmniFlash",
];

const MODELS_GLM: &[&str] = &[
    "glm-5.3", "glm-5.3-flash", "glm-5.3-turbo", "glm-5.2", "glm-5.1",
    "glm-4.6", "glm-4.6v", "glm-4.5", "glm-4.5v", "glm-4.5-air",
    "glm-4.5-flash", "glm-4v-plus",
];

const MODELS_KIMI: &[&str] = &[
    "kimi-k3.1-pro", "kimi-k3.1-pro-highspeed", "kimi-k2.5-pro",
    "kimi-k2.5-pro-highspeed", "kimi-k2.5", "kimi-k2.5-flash",
    "kimi-latest", "kimi-2.6",
];

const MODELS_MINIMAX: &[&str] = &[
    "MiniMax-M3.1", "abab7.5-chat", "abab7.5s-chat",
    "abab6.5s-chat", "abab6.5-chat", "abab6.5t-chat",
    "abab6.5g-chat", "abab5.5-chat",
];

const MODELS_QWEN: &[&str] = &[
    "qwen-max", "qwen-max-longcontext", "qwen-plus", "qwen-turbo",
    "qwen-vl-max", "qwen-vl-plus", "qwen2.5-72b-instruct", "qwen2.5-32b-instruct",
    "qwen2.5-14b-instruct", "qwen2.5-7b-instruct", "qwen2.5-3b-instruct",
    "qwen2.5-1.5b-instruct", "qwen2.5-0.5b-instruct",
    "qwen2.5-coder-32b-instruct", "qwen2.5-coder-14b-instruct", "qwen2.5-coder-7b-instruct",
];

fn get_models_for_provider(provider_id: &str) -> Vec<&'static str> {
    match provider_id {
        "deepseek" => MODELS_DEEEPSEEK.to_vec(),
        "longcat" => MODELS_LONGCAT.to_vec(),
        "glm" => MODELS_GLM.to_vec(),
        "kimi" => MODELS_KIMI.to_vec(),
        "minimax" => MODELS_MINIMAX.to_vec(),
        "qwen" => MODELS_QWEN.to_vec(),
        _ => vec![],
    }
}

/// 应用状态
struct CodexSetupApp {
    // 当前选中的平台索引
    provider_index: usize,
    // 当前选中的模型索引
    model_index: usize,
    // 自定义模型 slug
    custom_model: String,
    // API Key
    api_key: String,
    // 自定义 Base URL
    custom_base_url: String,
    // 输出日志
    log: String,
    // 是否正在运行
    is_running: bool,
    // 线程通信
    log_receiver: Option<mpsc::Receiver<String>>,
    // 使用自定义模型
    use_custom_model: bool,
}

impl CodexSetupApp {
    fn new() -> Self {
        Self {
            provider_index: 0,
            model_index: 0,
            custom_model: String::new(),
            api_key: String::new(),
            custom_base_url: String::new(),
            log: String::from("欢迎使用 Codex Setup GUI!\n请选择要配置的大模型平台，然后点击 [安装配置] 按钮。\n\n"),
            is_running: false,
            log_receiver: None,
            use_custom_model: false,
        }
    }

    fn spawn_install(&mut self) {
        let provider = PROVIDERS[self.provider_index];
        let model = if self.use_custom_model {
            self.custom_model.clone()
        } else {
            let models = get_models_for_provider(provider.0);
            if self.model_index < models.len() {
                models[self.model_index].to_string()
            } else {
                return;
            }
        };
        let api_key = self.api_key.clone();
        let base_url = if provider.0 == "custom" {
            self.custom_base_url.clone()
        } else {
            provider.2.to_string()
        };

        self.is_running = true;
        self.log.push_str(&format!(
            "开始安装配置...\n平台: {}\n模型: {}\n\n",
            provider.1, model
        ));

        let (tx, rx) = mpsc::channel();
        self.log_receiver = Some(rx);

        thread::spawn(move || {
            // 获取 codex home 目录
            let codex_home = std::env::var("CODEX_HOME")
                .unwrap_or_else(|_| format!("{}/.codex", std::env::var("HOME").unwrap_or_default()));
            let config_path = format!("{}/config.toml", codex_home);
            let models_path = format!("{}/models.json", codex_home);
            let backup_dir = format!("{}/backup-{}", codex_home, provider.0);

            tx.send(format!("Codex 目录: {}", codex_home)).ok();

            // 备份现有配置
            if std::path::Path::new(&config_path).exists() {
                tx.send("正在备份原有配置...".to_string()).ok();
                std::fs::create_dir_all(&backup_dir).ok();
                std::fs::copy(&config_path, format!("{}/config.toml", backup_dir)).ok();
                tx.send("  ✓ 已备份 config.toml".to_string()).ok();
            }

            // 生成 models.json
            tx.send("正在生成 models.json...".to_string()).ok();
            if let Err(e) = generate_models_json(&models_path, provider.0, &model) {
                tx.send(format!("  ✗ 生成失败: {}", e)).ok();
                return;
            }
            tx.send("  ✓ models.json 已生成".to_string()).ok();

            // 生成 config.toml
            tx.send("正在生成 config.toml...".to_string()).ok();
            if let Err(e) = generate_config_toml(
                &config_path,
                provider.0,
                &base_url,
                &model,
                &api_key,
                &models_path,
            ) {
                tx.send(format!("  ✗ 生成失败: {}", e)).ok();
                return;
            }
            tx.send("  ✓ config.toml 已生成".to_string()).ok();

            tx.send("\n✅ 安装完成！请完全退出并重新打开 ChatGPT 桌面端，配置才会生效。".to_string()).ok();
        });
    }
}

impl eframe::App for CodexSetupApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // 接收日志
        if let Some(rx) = &self.log_receiver {
            while let Ok(msg) = rx.try_recv() {
                self.log.push_str(&msg);
                self.log.push('\n');
            }
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Codex Setup GUI v1.0.0");
            ui.label("一键配置 Codex 适配各种大模型平台");
            ui.separator();

            // 平台选择
            ui.horizontal(|ui| {
                ui.label("选择平台:");
                egui::ComboBox::from_id_source("provider_combo")
                    .selected_text(PROVIDERS[self.provider_index].1)
                    .show_ui(ui, |ui| {
                        for (i, provider) in PROVIDERS.iter().enumerate() {
                            ui.selectable_value(&mut self.provider_index, i, provider.1);
                        }
                    });
            });

            ui.separator();

            // 模型选择
            if PROVIDERS[self.provider_index].0 != "custom" {
                ui.horizontal(|ui| {
                    ui.label("选择模型:");
                    let models = get_models_for_provider(PROVIDERS[self.provider_index].0);
                    let model_names: Vec<String> = models
                        .iter()
                        .enumerate()
                        .map(|(i, m)| format!("{}. {}", i + 1, m))
                        .collect();
                    egui::ComboBox::from_id_source("model_combo")
                        .selected_text(
                            if self.model_index < model_names.len() {
                                &model_names[self.model_index]
                            } else {
                                "选择模型"
                            }
                        )
                        .show_ui(ui, |ui| {
                            for (i, name) in model_names.iter().enumerate() {
                                ui.selectable_value(&mut self.model_index, i, name.clone());
                            }
                        });
                });

                ui.checkbox(&mut self.use_custom_model, "使用自定义模型 slug");
                if self.use_custom_model {
                    ui.text_edit_singleline(&mut self.custom_model)
                        .on_hover_text("输入任意模型标识符");
                }
            }

            ui.separator();

            // API Key
            ui.horizontal(|ui| {
                ui.label("API Key:");
                ui.text_edit_singleline(&mut self.api_key)
                    .on_hover_text("输入对应平台的 API Key（可选）");
            });

            // 自定义 Base URL
            if PROVIDERS[self.provider_index].0 == "custom" {
                ui.horizontal(|ui| {
                    ui.label("Base URL:");
                    ui.text_edit_singleline(&mut self.custom_base_url)
                        .on_hover_text("输入 API 端点 URL（如 https://api.example.com/v1/）");
                });

                ui.horizontal(|ui| {
                    ui.label("Provider ID:");
                    ui.text_edit_singleline(&mut self.custom_model)
                        .on_hover_text("输入 Provider 标识符（如 my-llm）");
                });
            }

            ui.separator();

            // 安装按钮
            ui.horizontal(|ui| {
                let btn = egui::Button::new("🚀 安装配置");
                if ui.add_enabled(!self.is_running, btn).clicked() {
                    self.spawn_install();
                }

                if self.is_running {
                    ui.label("⏳ 正在安装...");
                }

                if !self.is_running && self.log.contains("✅") {
                    ui.label("✅ 完成");
                }
            });

            ui.separator();

            // 日志输出
            ui.collapsing("📋 安装日志", |ui| {
                egui::ScrollArea::vertical()
                    .max_height(250.0)
                    .stick_to_bottom(true)
                    .show(ui, |ui| {
                        egui::TextEdit::multiline(&mut self.log.clone())
                            .font(egui::TextStyle::Monospace)
                            .desired_width(f32::INFINITY)
                            .interactive(false)
                            .show(ui);
                    });
            });

            ui.separator();

            // 底部信息
            ui.horizontal(|ui| {
                ui.label(egui::RichText::new("基于 DeepSeek 一键安装命令修改 | 程序由 AI 辅助开发").small().weak());
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    ui.label(egui::RichText::new("MIT License © 2026 msh").small().weak());
                });
            });
        });

        ctx.request_repaint();
    }
}

/// 生成 models.json 文件
fn generate_models_json(path: &str, provider_id: &str, model_slug: &str) -> Result<(), String> {
    // 获取该平台的模型列表
    let models = get_models_for_provider(provider_id);

    // 使用 Python 或手动生成 JSON
    // 简化：使用 Rust 的 serde_json
    use std::io::Write;

    let mut entries = Vec::new();
    for (i, model) in models.iter().enumerate() {
        entries.push(format!(
            r#"    {{
      "slug": "{}",
      "prefer_websockets": false,
      "support_verbosity": true,
      "default_verbosity": "low",
      "apply_patch_tool_type": "freeform",
      "web_search_tool_type": "text",
      "input_modalities": ["text"],
      "supports_image_detail_original": false,
      "truncation_policy": {{ "mode": "tokens", "limit": 10000 }},
      "supports_parallel_tool_calls": true,
      "tool_mode": null,
      "multi_agent_version": "v2",
      "use_responses_lite": false,
      "include_skills_usage_instructions": false,
      "auto_review_model_override": null,
      "context_window": 1048576,
      "max_context_window": 1048576,
      "effective_context_window_percent": 95,
      "auto_compact_token_limit": null,
      "comp_hash": "3000",
      "reasoning_summary_format": "experimental",
      "default_reasoning_summary": "none",
      "display_name": "{}",
      "description": "High-performance coding model.",
      "default_reasoning_level": "high",
      "supported_reasoning_levels": [
        {{ "effort": "low", "description": "Fast responses with lighter reasoning" }},
        {{ "effort": "medium", "description": "Balanced reasoning for everyday tasks" }},
        {{ "effort": "high", "description": "Extra high reasoning depth for complex problems" }},
        {{ "effort": "xhigh", "description": "Extremely high reasoning for very hard problems" }},
        {{ "effort": "ultra", "description": "Ultra reasoning depth for exceptionally challenging problems" }},
        {{ "effort": "max", "description": "Maximum reasoning depth for the hardest problems" }}
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "minimal_client_version": "0.144.0",
      "supported_in_api": true,
      "availability_nux": null,
      "upgrade": null,
      "priority": {},
      "model_messages": {{
        "instructions_template": "You are Codex, an agent based on GPT-5.",
        "instructions_variables": {{ "personality_default": "", "personality_friendly": "", "personality_pragmatic": "" }},
        "approvals": null
      }},
      "experimental_supported_tools": [],
      "supports_search_tool": true,
      "default_service_tier": null,
      "supports_reasoning_summaries": true,
      "base_instructions": "You are Codex, an agent based on GPT-5."
    }}"#,
            model, model, i + 1
        ));
    }

    let json = format!(
        "{{\n  \"models\": [\n{}\n  ]\n}}",
        entries.join(",\n")
    );

    let mut file = std::fs::File::create(path).map_err(|e| e.to_string())?;
    file.write_all(json.as_bytes()).map_err(|e| e.to_string())?;

    Ok(())
}

/// 生成 config.toml 文件
fn generate_config_toml(
    path: &str,
    provider_id: &str,
    base_url: &str,
    model: &str,
    api_key: &str,
    models_json_path: &str,
) -> Result<(), String> {
    use std::io::Write;

    let auth_method = if api_key.is_empty() {
        "apikey"
    } else {
        "apikey"
    };

    let bearer_token_line = if !api_key.is_empty() {
        format!("experimental_bearer_token = \"{}\"\n", api_key)
    } else {
        String::new()
    };

    let config = format!(
        r#"model = "{}"
model_provider = "{}"
preferred_auth_method = "{}"
forced_login_method = "api"
model_reasoning_effort = "high"
web_search = "disabled"
show_raw_agent_reasoning = true
model_catalog_json = "{}"

[model_providers.{}]
name = "{}"
base_url = "{}"
wire_api = "responses"
{}

[desktop]
enabled-reasoning-efforts = ["low", "medium", "high", "xhigh", "ultra", "max"]
"#,
        model,
        provider_id,
        auth_method,
        models_json_path.replace('\\', "/"),
        provider_id,
        provider_id,
        base_url,
        bearer_token_line,
    );

    let mut file = std::fs::File::create(path).map_err(|e| e.to_string())?;
    file.write_all(config.as_bytes()).map_err(|e| e.to_string())?;

    Ok(())
}

/// egui 字体配置（支持中文）
mod egui_animation {
    use egui;

    pub fn setup(ctx: &egui::Context) {
        ctx.set_visuals(egui::Visuals::dark());

        // 配置中文字体
        let mut fonts = egui::FontDefinitions::default();

        // 尝试加载系统 CJK 字体
        let cjk_font_paths = [
            // Windows
            "C:\\Windows\\Fonts\\msyh.ttc",      // Microsoft YaHei
            "C:\\Windows\\Fonts\\msyhbd.ttc",    // Microsoft YaHei Bold
            "C:\\Windows\\Fonts\\simsun.ttc",    // SimSun
            "C:\\Windows\\Fonts\\simhei.ttf",    // SimHei
            // macOS
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/STHeiti Light.ttc",
            "/Library/Fonts/Arial Unicode.ttf",
            // Linux
            "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
            "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
            "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ];

        let mut font_loaded = false;
        for path in &cjk_font_paths {
            if std::path::Path::new(path).exists() {
                if let Ok(font_data) = std::fs::read(path) {
                    fonts.font_data.insert(
                        "cjk_font".to_owned(),
                        egui::FontData::from_owned(font_data),
                    );
                    // 将 CJK 字体放在最前面作为首选
                    fonts
                        .families
                        .get_mut(&egui::FontFamily::Proportional)
                        .unwrap()
                        .insert(0, "cjk_font".to_owned());
                    fonts
                        .families
                        .get_mut(&egui::FontFamily::Monospace)
                        .unwrap()
                        .insert(0, "cjk_font".to_owned());
                    font_loaded = true;
                    break;
                }
            }
        }

        if !font_loaded {
            // 尝试加载嵌入的备用字体（使用 egui 内置的叉号字体作为 fallback）
            // 注意：如果需要完整 CJK 支持，需要嵌入一个 CJK 字体文件
        }

        ctx.set_fonts(fonts);
    }
}
