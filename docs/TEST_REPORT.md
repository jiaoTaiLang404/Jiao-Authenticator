# Jiao Authenticator 0.1.0+1 测试记录

验证日期：2026-11-10。Flutter 3.47.9 / Dart 3.13.7，Android API 36 专用模拟器，正式包 min API 24 / target 36。

## 最终界面

- 移除首页大号「验证码」标题和账号数量，不保留原占位。
- 底部取消全宽背景托盘，添加按钮透明悬浮；仅胶囊内部进行局部玻璃模糊/轻折射，两侧仍可拖动列表。
- 列表末尾随字号预留空间，末项可滚到按钮上方；键盘打开时隐藏添加按钮。
- 保留 Next、各算法/周期/位数和主题色 → 黄 → 红倒计时。

## 自动化结果

| 项目 | 结果 |
|---|---|
| flutter analyze | No issues found!；exit 0 |
| 修改前基线 | 54 passed；exit 0（53 个原测试 + 1 个布局恢复探针） |
| 最终单元/widget 测试 | 57 passed；exit 0 |
| 行覆盖率 | 1024/1396，73.4% |
| 独立副本回滚 | 原始哈希恢复，54 passed；exit 0 |
| Android 集成 | 3 个声明场景通过；Flutter 内部运行输出 +4 All tests passed!；exit 0 |
| 正式 APK 构建 | flutter build apk --release；exit 0 |
| 正式签名 | apksigner verify；v2，RSA 3072，1 signer；exit 0 |

RFC 6238 SHA1/SHA256/SHA512 全测试向量、前导零、边界/2038 后/系统时间跳变、Next 衔接，Base32/URI 非法参数、存储失败/重启/损坏不覆盖、去重合并、后台 29/31 秒与异步会话隔离均在测试中覆盖。备份包含真实 600000 次 PBKDF2 的往返、错误口令、头部/tag/密文篡改、超限和版本拒绝。

Android 飞行模式验证：系统照片选择器选图、单/多二维码内置离线识别、安全存储不含明文种子、加密备份原生保存/读取/重复恢复、剪贴板保留后来内容并清理到期自身内容、实际系统设备凭据认证、相机权限拒绝返回其他方式。

最终正式 APK 已在同一专用模拟器安装、解锁，空列表正确、没有大标题/数量行，AIRPLANE_MODE=1。完整 Android 集成执行在悬浮按钮版本上；后续仅删除标题行，已由深浅主题 widget 测试及最终正式 APK 冒烟再次验证。

正式 APK 后台与取消实测：

```text
BACKGROUND_29=PASS; measured=29.13s; state=还没有账号
BACKGROUND_31=PASS; measured=31.10s; state=本机密钥库已锁定
AUTH_CANCEL=PASS; state=locked
RELEASE_BACKGROUND_EXIT=0
```

## 复现与回滚

交付目录 `VERIFY.ps1` 在当前机器的独立验证副本执行 BASELINE / MODIFIED / ROLLBACK；完整命令、输入和原始输出见 `VERIFICATION.txt`。回滚只操作带标记的测试源码副本，不触碰桌面项目、应用数据或签名材料。恢复后的旧版大标题/数量与底部托盘保留 Next 和倒计时变色；正式源码仍保持新 UI。

TDD 已先复现失败：悬浮布局 4 个断言、删除标题的深浅主题 2 个断言；修复后最终全套通过。`flutter test integration_test` 的一次启动服务竞态经本地 RPC 定位后，使用官方 integrationDriver 路径完成集成验证；原生测试结果不是模拟输出。

## 人工复核与手机待确认

复核包括时窗计算、提交后更新、锁定引用清理、备份认证头、剪贴板所有权、滤镜局部裁剪及签名/权限合并。真实手机的相机成像、真实指纹、厂商最近任务行为与低端 GPU 帧率仍待本人设备确认。预览是真实 Flutter widget 渲染，只有合成账号；测试字体与 Android 字体可能略有差异。
