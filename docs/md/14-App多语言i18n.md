# App 多语言（i18n）接入说明

## 方案

采用 Apple 官方成熟方案：**String Catalog（`Localizable.xcstrings`）**。

优点：

- Xcode 原生支持，可视化编辑中英文
- 后续加日语 / 繁体等，只需在 Catalog 增加 localization
- 与系统语言自动联动（也可后续做 App 内语言切换）

## 目录结构

```text
leon_ios/Localization/
  L10n.swift                 # 类型化文案入口（Auth / Me / Settings / Common…）
  L10n+Modules.swift         # 业务模块文案（Ingredients / Recommend / Reminders / Presets）
  Localizable.xcstrings      # 文案源（zh-Hans / en）
```

工程已开启：

- `developmentRegion = zh-Hans`
- `knownRegions = en, Base, zh-Hans`

## 使用方式

### 1. 在代码里引用

```swift
Text(L10n.Auth.login)
Button(L10n.Auth.logout) { ... }
navigationTitle(L10n.Me.title)

// 需要 String 时
L10n.text(L10n.Auth.login)

// 带参数
L10n.Auth.verifySubtitle(email: "a@b.com")
L10n.Me.pendingSyncCount(3)
```

### 2. 新增文案

1. 在 `L10n.swift` 增加 `LocalizedStringResource`（带 `defaultValue` 中文兜底）
2. 在 `Localizable.xcstrings` 补齐 `zh-Hans` / `en`
3. 页面把硬编码中文替换成 `L10n.*`

### 3. 新增一种语言（例如日语）

1. Xcode → Project → Info → Localizations → `+` → Japanese
2. 打开 `Localizable.xcstrings`，为每个 key 填 `ja` 翻译
3. 确认 `knownRegions` 含 `ja`
4. **后端**同步加 `lang/ja/api.php`（接口提示）与 locale 映射

前端 UI 与后端 API 提示是两套，但语言协商策略保持一致（系统语言 → `zh` / `en` / …）。

## 职责边界

| 文案类型 | 负责方 |
|----------|--------|
| 按钮、标题、空态、引导 | App `L10n` + String Catalog |
| 接口错误 / 成功 message | 后端 `lang/zh|en` + `ApiCode` |
| 业务分支（未验证邮箱等） | 看 `code`，不看文案 |

## 当前进度

- ✅ 基建：Catalog + `L10n` / `L10n+Modules`
- ✅ 已接入：登录/注册 Sheet、我的页、Tab 标题、客户端兜底错误文案
- ✅ 设置页：手动切换语言（跟随系统 / 简体中文 / English），并驱动 UI + API 语言头
- ✅ 业务模块：食材列表/编辑/详情、推荐首页/详情、提醒、预设管理
- ⏸ 暂缓：菜谱内容多语言（标题 / 推荐理由 / 热词 / 详情步骤仍由后端中文返回，1.0 不做）
- ⏸ 低优先：本地种子/演示数据、Location 存储 key 英文化（不影响主流程验收）

## App 内语言切换

入口：`我的` → `设置` → `语言`

- `跟随系统`：跟 iPhone 系统语言
- `简体中文` / `English`：手动固定，写入 UserDefaults，立即刷新界面
- 请求头 `Accept-Language` / `X-Locale` 同步使用该偏好

实现：`LanguageStore` + 根视图 `.environment(\.locale, ...)` + `.id(language)` 强制刷新。

## 如何验收

1. iPhone 设置 → 通用 → 语言与地区 → iPhone 语言 → English
2. 重新打开 App
3. Tab「Me」、登录页「Sign In」、我的页文案应为英文
4. 切回简体中文，文案恢复中文
5. 接口报错语言应与系统语言一致（App 已发 `Accept-Language` / `X-Locale`）
