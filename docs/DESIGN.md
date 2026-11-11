# 黑白玻璃设计规范

方向：Vercel 黑白骨架 + Apple 材质分层。玻璃仅用于控件，不让验证码参与折射。没有远程字体或图标请求。

| 令牌 | 深色 | 浅色 |
|---|---|---|
| 背景 | `#0A0A0A` | `#F5F5F7` |
| 内容表面 | `#191919` | `#FFFFFF` |
| 主要文字/主题色 | `#F7F7F7` | `#111111` |
| 次要文字 | `#B0B0B0` | `#55555C` |
| 边界 | `#343434` | `#D9D9DC` |
| 警示黄 | `#F5C451` | `#A66C00` |
| 紧急红 | `#FF6B6B` | `#C62828` |

- 页面边距 20 dp；卡片间距 12 dp、圆角 20 dp；常规操作热区至少 48 dp。
- 品牌图标统一使用白底拉丝银香蕉（原稿 `artwork/jiao-launcher.png`）。Android 桌面和启动画面共用 `@mipmap/ic_launcher`，覆盖五个像素密度及 Android 8.0+ 自适应图标；Flutter 的解锁、首页、添加账号和设置页通过 `BrandMark` 使用同一原稿。搜索、添加、复制、编辑、删除等功能图标和账号头像保持原样。[Android 图标规范](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive) · [Android 启动画面](https://developer.android.com/develop/ui/views/launch/splash-screen)
- 服务图标取名称首字符，不访问 favicon。
- 当前码 36 sp 等宽，六位 `123 456`，八位 `1234 5678`。小屏使用 scaleDown 保持数字完整。
- Next 位于当前码下方，14 sp 等宽、次要文字色，不属于复制热区。
- 底部搜索胶囊与纯「＋」圆形按钮并排，用相同的局部玻璃材质。列表可从两者后方滚动，控件之间没有托盘。键盘只抬起这一行，账号列表视口和品牌栏不动。
- 首页底部不绘制横向分隔线；搜索和「＋」仍各有局部玻璃边缘。
- 倒计时按每个账号的周期计算：`> 50%` 主题色，`20% < 比例 <= 50%` 黄，`<= 20%` 红。数字和圆弧同步，220 ms 过渡；减少动画时立即切换。保留秒数，紧急状态另有读屏标签。
- 底部 `GlassSurface` 把两枚控件下方的内容按各自中心放大 1.10 倍，叠加轻柔模糊和半透明的高光边缘。效果只在控件轮廓内；搜索文字及「＋」照常绘制，不参与放大。[Flutter 放大镜](https://api.flutter.dev/flutter/widgets/RawMagnifier-class.html)
- 其他 `GlassSurface` 保留局部模糊和轻微折射 shader。减少透明效果或高对比度时使用实色，跳过背景采样。
- Flutter 3.47 的 OpenGL ES 渲染纹理与 Vulkan 同为从上到下采样；玻璃不再额外翻转 Y 轴，避免底部映出倒置的顶部内容。[Flutter 迁移说明](https://docs.flutter.dev/release/breaking-changes/opengles-render-to-texture-top-down)
- 账号卡片为高不透明表面，当前与 Next 数字均没有滤镜变形。
- 首次深色；支持浅色/跟随系统。首页顶部只保留品牌和设置。
- 账号左滑显示编辑、右滑显示删除；同一时间只有一张展开的卡片。点击删除后仍需确认，读屏可使用自定义操作。
- 后台完整遮挡，并排除隐藏内容的焦点和无障碍语义；锁定后重建路由。

预览由真实 Flutter widget 渲染，只含合成账号。测试机字体与 Android 字体可能略有差异。低端手机的实际折射帧率待手机测量。

参考：[shader filter](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html)、[TweenAnimationBuilder](https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html)。
