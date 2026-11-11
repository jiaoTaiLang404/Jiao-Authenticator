# Jiao Authenticator

Android 离线 TOTP 验证器 **0.1.3+4**。中文界面，黑白双主题与局部玻璃材质。没有后端、注册、云同步、广告或统计；正式 APK 不声明网络权限。首次启动为空密钥库。

## 开始使用

1. 在 Android 设置中启用锁屏 PIN、图案或密码，安装后点击「解锁」。
2. 点击底部「＋」，选择相机扫码、二维码图片或手动输入；核对服务、账号及参数后保存。
3. 大号数字是当前验证码，点击复制。**Next 是下一窗口的验证码**，刷新后自动成为当前码。Next 行不复制，避免提前使用。
4. 倒计时大于周期一半为主题色，不超过一半变黄，不超过 20% 变红；新周期恢复主题色。例如 30 秒周期为 30–16 / 15–7 / 6–1 秒。
5. 设置支持深色、浅色、跟随系统与减少透明效果。默认深色、开启应用锁。
6. 在底部搜索服务或账号。键盘弹出时仅搜索和「＋」抬起；左滑卡片显示编辑，右滑显示删除，删除仍需确认。

支持标准 `otpauth://totp`、SHA1/SHA256/SHA512、6/8 位和 1–3600 秒周期，保留前导零与服务参数。首版不处理 HOTP 或 Google 批量迁移码。

离开应用立即遮挡，后台达到 30 秒锁定；冷启动遵循应用锁设置。系统选择器停留较久后返回也需要重新解锁。复制内容标记为敏感，30 秒后在前台且仍属于本次复制时清理，不覆盖用户后来复制的内容。

设置 → 保护中有默认关闭的「允许截屏（临时）」。后续删除时见 `docs/移除临时截屏开关.md`。

## 备份与恢复

设置中导出 `.jiaoauth` 加密文件，独立口令至少 12 字符，输入两次确认。口令不落盘。导入流程为选择文件、解密、预览、确认合并；同密钥同算法同位数同周期跳过，已有账号及名称保持不变。

错误口令、损坏、未知版本、超过 10 MB 或取消操作均不提交数据。读取本机存储失败时保留原数据；显式恢复写入独立密钥库，不覆盖损坏原库。备份只包含账号，不包含设置或签名材料。详见 `docs/使用与恢复.md`。

## 自己打包 APK

在项目根目录双击 **Build-APK.cmd**，构建后自动验签。签名 APK 和 SHA-256 文件输出至项目的 **dist** 目录。也可在 PowerShell 7 执行：

```powershell
& '~\Desktop\Jiao Authenticator\Build-APK.ps1'
```

## 开发

验证环境：Flutter **3.47.9 stable** / Dart **3.13.7**、Java 17、Android compile/target **36**、min **24**。依赖锁定在 `pubspec.lock`。

使用 PowerShell 7；脚本只设置当前进程环境，不修改全局 PATH：

```powershell
pwsh -NoProfile -File "~\Desktop\Jiao Authenticator\tool\dev.ps1" -Action Analyze
pwsh -NoProfile -File "~\Desktop\Jiao Authenticator\tool\dev.ps1" -Action Test
pwsh -NoProfile -File "~\Desktop\Jiao Authenticator\tool\dev.ps1" -Action Release
```

默认 SDK 在 `Documents\Codex\toolchains\flutter`，签名配置在项目外的 `Documents\Codex\toolchains\jiao-signing\signing.json`。源码不包含签名材料。可通过脚本参数指定路径，详见 `docs/BUILD.md`。

## 结构

- `lib/core/totp.dart`：账号、Base32/URI 校验、当前与下一窗口 TOTP。
- `lib/core/vault_repository.dart`：安全存储、序列化、合并去重。
- `lib/core/vault_controller.dart`：串行提交、系统验证、生命周期与会话隔离。
- `lib/core/backup_codec.dart`：后台 isolate AES-GCM 加解密。
- `lib/core/android_files.dart`：有界读取、原生选择器、离线扫码。
- `lib/ui/`、`shaders/`：双主题、玻璃、页面与倒计时。
- `android/`：防截屏、敏感剪贴板、备份排除和签名配置。
- `test/`、`integration_test/`：公开合成账号测试，不在正式应用中预置。

设计规范见 `docs/DESIGN.md`，架构取舍见 `docs/ARCHITECTURE.md`。
