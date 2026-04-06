# 📱 短信/电话转 Bark 推送模块 (Msg_2_Bark)

> **简介**：这是一个基于 Magisk/KernelSU 的后台守护模块。它能实时监控安卓备用机的**短信**和**未接来电**，并即时推送到 iOS 设备的 **Bark** 应用，或推送到**企业微信/微信**。
>
> **核心场景**：双卡用户将副卡插在安卓备用机上，通过此模块实现“安卓收信，苹果弹窗”，不错过任何验证码和重要电话。

## ✨ 功能亮点

- **🚀 即时生效**：修改配置文件后无需重启手机或重刷模块，秒级自动加载新配置。
- **📲 多通道支持**：
  - **Bark** (iOS 原生推送体验，推荐)
  - **企业微信/微信群机器人** (适合安卓/PC 端接收)
  - **WxPusher** (微信公众号推送)
- **🛡️ 智能去重**：自动标记已读/已处理，避免重复推送同一条消息。
- **⏰ 历史过滤**：支持设置起始时间，仅推送设定时间之后的新消息，防止开机轰炸。
- **📦 开箱即用**：内置 `sqlite3` 二进制文件，无需额外安装数据库工具模块。

---

## 📥 安装与依赖

1. **环境要求**：
   - 已 Root 的 Android 设备 (Magisk 或 KernelSU)。
   - 目标接收设备：iOS (安装 Bark App) 或 微信/企微账号。
2. **安装步骤**：
   - 在 Magisk/KernelSU 管理器中点击“从本地安装”，选择本模块 ZIP 包。
   - 重启手机（首次安装需重启以注册服务）。
3. **依赖说明**：
   - 模块已内置 `sqlite3`，**无需**单独安装 [sqlite3-magisk-module](https://github.com/rojenzaman/sqlite3-magisk-module)。

---

## ⚙️ 配置说明

配置文件路径：`/data/adb/modules/Msg_2_Bark/config.conf`

> 💡 **提示**：你可以使用 RE 管理器、MT 管理器或通过 ADB 编辑该文件。**保存后立即生效！**

### 配置模板

```ini
# =========================================================
# 短信/电话 转发器配置文件
# 修改本文件后即时生效，无需重启！
# =========================================================

# --- 1. 数据库路径 (一般不需要修改) ---
msg_db_path=/data/data/com.android.providers.telephony/databases/mmssms.db
call_db_path=/data/data/com.android.providers.contacts/databases/calllog.db

# --- 2. Bark 推送设置 (iOS 用户必填) ---
bark_switch=0
bark_url=https://api.day.app/push
device_key=你的BarkKey在这里

# --- 3. 企业微信/微信群机器人设置 ---
wx_switch=0
wx_webhook=

# --- 4. WxPusher 设置 (微信公众号推送) ---
wxpusher=0
wxpusher_token=
wxpusher_topic=

# --- 5. 高级设置 ---
# 【重要】开始监控的时间点 (格式：YYYY-MM-DD HH:MM:SS)
# 建议：首次使用时，设置为当前时间之后的 2 分钟。
startTime=2026-03-15 18:00:00

# --- 6. SIM 卡槽映射 ---
# SIM 卡自定义备注名，显示在推送消息中
sim1_name=
sim2_name=
# 用于识别来电卡槽，不知道的可以看推送
sim1_imei=
sim2_imei=

