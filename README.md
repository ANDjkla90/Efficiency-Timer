# 驰马时记

一款专为小时工、日结工设计的**本地工时记账 App**——记一笔工时，自动算工钱，随时查账。

**完全离线 · 零权限 · 不收集任何数据**，所有账目只保存在你自己的手机上。

> 核心就是四件事：**记工 + 算账 + 查账 + 结算**。
>
> 当前版本 **3.2 结算对账版**（午休扣除、结算单、时间段筛选、删除可撤销、PIN 应用锁），
> 变更明细见 [CHANGELOG.md](CHANGELOG.md)。

---

## 功能特性

- **快速记一笔**：日期、起止时间（或直接填工时）、小时工资、加班、补贴、工种，一步记好。
- **午休扣除**：起止时间之外可再填「休息扣除」，09:00–18:00 扣 1 小时午休就按 8 小时算钱；常用 0/30/60/90 分钟一键选。
- **夜班跨天**：22:00 → 06:00 正确记 8 小时，结束时间自动落到次日。
- **三种计薪方式**：时薪（工时 × 时薪）、日薪（天数 × 日薪）、计件（件数 × 单价），按账本设置自动切换录入项。
- **自动算账**：本笔合计 = 正常工资 + 加班费 + 补贴，实时预览；首页汇总今日工资 / 本月收入 / 累计收入。
- **多维查账**：按日期、雇主、工种三种维度查看账目，每个分组带小计；支持全部 / 今日 / 本周 / 本月 / 自定义时间段筛选。
- **结算对账**：选雇主 + 周期，把未结算记录汇总成结算单（金额为生成时快照），一键复制纯文本账单发给老板；结算过的记录带「已结算」标记，不重复计入，可撤销后重结。
- **删除可撤销**：账目左滑删除，5 秒内可撤销；已结算的记录删除前会单独提醒。
- **PIN 应用锁**：可选 4/6 位本地 PIN，启动与回前台需解锁；连续输错 5 次后递增延时（1s→30s 封顶），不申请任何权限，PIN 只存加盐哈希。
- **复制上次**：同样的活一键复刻，连续记工不用重复填。
- **多雇主管理**：不同老板 / 工地分开记账，各自独立单价。
- **统计汇总**：今日 / 本月 / 累计收入；工作量按计薪方式分开统计——时薪看累计工时、日薪看累计天数、计件看累计件数。
- **本地备份**：手动导出 / 导入 JSON 备份文件（含结算单与休息扣除），换手机不丢数据。
- **按地区显示货币**：默认按中国 / 人民币显示；可在「我的 → 国家/地区与货币」切换地区或开启「跟随系统地区」。金额数值与计算逻辑不受影响。
- **自适应图标**：品牌蓝渐变 `#1E88E5 → #0D47A1` + 白色钟形圆环 + 环内 `¥`（时间 × 工钱）。圆环外沿 54dp，落在 Android 66dp 安全区之内、占系统可见区（72dp）的 75%，圆形 / 圆角方形 / 方形蒙版裁切后都不会缺角；支持 Android 8+ 自适应图标与 Android 13 主题图标（`tool/gen_icons.py` 可重新生成，含像素级安全区校验）。

## 隐私承诺

- **完全离线**：APK 中不含 INTERNET 权限，代码里没有任何网络请求，无统计 / 广告 / 崩溃上报 SDK。
- **零权限**：Manifest 中无任何 `uses-permission`；备份走系统文件选择器（SAF），不需要存储权限。
- **关闭自动备份**：已设置 `allowBackup=false`，避免系统把本地数据库同步到云端。
- **不收集数据**：无需注册登录，所有账目只存在本机 SQLite。
- **数据归你**：备份文件由你导出到你指定的位置，是否保留完全由你决定；卸载即彻底清除。

以上承诺可自行核验：`aapt dump badging <apk>` 查看权限清单，或直接查看 `android/app/src/main/AndroidManifest.xml`。

隐私声明在 App 内「我的 → 隐私声明」可随时查看。

## 技术栈

| 项 | 说明 |
| --- | --- |
| 框架 | Flutter 3.50（Dart 3.14），仅 Android 平台 |
| 本地存储 | SQLite（`sqflite`）+ `shared_preferences` |
| 文件备份 | `file_picker`（系统文件选择器，免存储权限） |
| 权限 | 零 `uses-permission` |
| 包体积 | arm64 分包 18.8 MB，armeabi-v7a 16.8 MB（v3.2 正式签名包实测） |

无 Firebase、无推送、无崩溃上报、无广告SDK——从依赖层面杜绝数据外传。

## 项目结构

```
jigongshi/
├── pubspec.yaml              # 项目配置与依赖
├── CHANGELOG.md              # 版本变更记录
├── LICENSE                   # MIT 许可证
├── lib/
│   ├── main.dart             # 应用入口
│   ├── theme.dart            # 全局主题
│   ├── config/
│   │   └── currency_config.dart    # 国家/地区 → 货币集中配置表
│   ├── utils/
│   │   └── time_utils.dart         # 工时/跨天计算（纯函数，可单测）
│   ├── models/
│   │   ├── ledger.dart       # 雇主/账本模型
│   │   ├── work_record.dart  # 工时记录模型（含加班/补贴/工种/休息扣除/结算关联）
│   │   └── settlement.dart   # 结算单模型（周期 + 金额快照）
│   ├── database/
│   │   └── database_helper.dart  # 本地 SQLite（含 v1→v2→v3 迁移）
│   ├── services/
│   │   ├── pay_service.dart       # 统一算钱逻辑
│   │   ├── settlement_service.dart # 结算周期/待结筛选/账单文本（纯函数）
│   │   ├── app_lock.dart          # PIN 应用锁（盐 + SHA-256）
│   │   ├── backup_service.dart    # 备份导出/导入
│   │   └── data_notifier.dart     # 数据刷新通知
│   ├── widgets/
│   │   └── pin_pad.dart      # PIN 数字键盘（解锁/设置/验证共用）
│   └── pages/
│       ├── main_shell.dart        # 底部导航框架
│       ├── home_page.dart         # 首页（快速记账工作台）
│       ├── record_page.dart       # 记一笔 / 编辑 / 复制上次
│       ├── record_list_page.dart  # 账目（按日期/雇主/工种 + 时间段筛选）
│       ├── ledger_manage_page.dart# 雇主/账本管理
│       ├── settlement_page.dart   # 结算对账
│       ├── stats_page.dart        # 统计汇总
│       ├── settings_page.dart     # 设置与备份
│       ├── lock_page.dart         # 解锁页
│       ├── currency_page.dart     # 国家/地区与货币
│       └── privacy_page.dart      # 隐私声明
├── tool/
│   └── gen_icons.py          # 生成启动图标（含自适应分层）
├── .github/workflows/ci.yml  # CI：analyze + test + release 打包
├── android/                  # Android 原生脚手架（零权限 Manifest）
├── store/icon-512.png        # 512px 商店图标
└── test/                     # 测试
```

## 本地构建

### 环境准备

1. 安装 [Flutter SDK](https://docs.flutter.cn/get-started/install/)（本项目用 3.50.0）。
2. 安装 Android Studio（自带 Android SDK 与 JDK 17）。
3. 国内网络建议设置镜像：

   ```bash
   export PUB_HOSTED_URL=https://pub.flutter-io.cn
   export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
   ```

4. 用 `flutter doctor` 确认 Flutter 与 Android toolchain 可用。

### 拉取依赖并打包

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

产物在 `build/app/outputs/flutter-apk/`，其中 `app-arm64-v8a-release.apk` 适配绝大多数现代手机。也可去掉 `--split-per-abi` 打一个通用包。

将 APK 传到手机点击安装即可（首次需允许「未知来源」，因为未上架应用商店）。

> **签名策略**：有 `android/key.properties` 且密钥文件存在时，release 包使用正式签名；缺失时自动回退 debug 签名并打印提示，保证新克隆的仓库和 CI 也能正常出包。
>
> 本机的正式密钥**已移出项目目录**（`D:\workB2\signing-keys\chima-release.jks`），`key.properties` 里写绝对路径；`*.jks`、`key.properties` 均被 `.gitignore` 排除。迁移时用 `keytool -importkeystore` 换了强密码，**证书指纹不变**，因此已安装的旧版本仍可覆盖升级。
>
> 自己打包时执行：
>
> ```bash
> keytool -genkeypair -v -keystore ~/keystore/chima.jks -keyalg RSA -keysize 2048 -validity 10000 -alias chima
> ```
>
> 然后建 `android/key.properties`（`storeFile` 建议写项目外的绝对路径）：
>
> ```properties
> storeFile=/absolute/path/to/chima.jks
> storePassword=你的密码
> keyAlias=chima
> keyPassword=你的密码
> ```
>
> ⚠️ **同一个包名的后续版本必须用同一把密钥签名**，否则用户只能卸载重装（= 丢数据）。密钥请自行备份（密码管理器 + 离线 U 盘各一份），丢了就再也无法覆盖升级。
>
> 密钥安全提醒：
> - 不要把整个项目目录打包发给别人——`.jks` 虽然在 `.gitignore` 里，但压缩包会把它一起带走。本机已把密钥放到项目目录之外。
> - 密钥密码不要用生日、手机号等可猜字符串；仓库里所有版本共用同一把密钥，泄露等于任何人都能发布「升级包」。
> - CI 若要出正式签名的包，把 `.jks` 转成 base64 存 `KEYSTORE_BASE64`，密码存 `KEYSTORE_PASSWORD` / `KEY_PASSWORD`，在 workflow 里解码后再构建；不给 secrets 时 CI 只出 debug 签名包，用于验证能编译。
> - R8 混淆只能增加反编译难度，**保护不了 Dart 业务逻辑**（AOT 快照仍可被逆向）。真正的护城河是本项目的离线与零权限，而不是混淆。

## 路线图

- **月度趋势图**：按天/周的收入曲线与工时曲线（当前只有文字排行）。
- **日历视图**：按天展示记工情况。日薪/计件记录已统一存当天 00:00（v3 迁移把历史的假 09:00 归零），日历不会再把 09:00 当真实上班时间。
- 上架前的合规材料与商店截图。

## 数据备份

数据只存本机。换手机或重装前，请在 App 内「我的 → 导出数据备份」导出 JSON 文件；在新设备用「导入数据备份」恢复。整个过程不联网。

## 贡献

欢迎提 Issue 反馈问题或建议，也欢迎 Pull Request。提交前请：

- 运行 `flutter analyze` 确保无 error；
- 运行 `flutter test` 确保测试通过；
- 核心记账必须保持离线——「不联网」是本项目的产品底线，任何引入网络请求、权限申请的改动需先开 issue 讨论。

## 许可证

[MIT](LICENSE) © 2026 驰马时记 项目贡献者。可自由使用、修改、商用，请保留版权声明。
