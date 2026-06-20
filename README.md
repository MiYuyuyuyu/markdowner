# Markdown Reader

一个基于 Flutter 的跨平台 Markdown 阅读器，面向数学、公式密集型笔记场景，重点解决 **Markdown 中 LaTeX 公式渲染**、**多标签页阅读** 和 **大屏阅读体验**。

当前主要面向：

- Android 平板
- Windows
- Linux

## 特性

- 浏览器式多标签页
  - 可同时打开多个 Markdown 文件
  - 支持切换、关闭、关闭其他、关闭全部
- Markdown + LaTeX 渲染
  - 支持行内公式 `$...$`
  - 支持块公式 `$$...$$`
  - 针对表格中的公式做了额外兼容处理
- 更适合中文笔记的阅读体验
  - 集成 `HarmonyOS Sans`
  - 支持阅读字号调整
  - 对公式视觉尺寸做了额外校正
- 表格与复杂内容兼容
  - 窄宽度下避免红色溢出警告
  - 宽屏下尽量利用可用空间
- 跨平台文件打开
  - 最近文件列表
  - 本地文件选择
- 亮色 / 暗色主题

## 截图

你可以在这里补充项目截图：

- 主界面
- 多标签页效果
- LaTeX 公式渲染效果
- 表格渲染效果

示例：

```md
![Home](./docs/screenshots/home.png)
![Latex](./docs/screenshots/latex.png)
```

## 技术栈

- Flutter
- Provider
- markdown_widget
- flutter_math_fork
- file_picker
- shared_preferences

## 已实现功能

- [X] 多标签页 Markdown 阅读
- [X] LaTeX 行内 / 块公式渲染
- [X] 表格中的公式兼容处理
- [X] 阅读字号调整
- [X] HarmonyOS Sans 字体接入
- [X] 最近文件列表
- [X] 暗色 / 亮色主题
- [X] 窄屏表格溢出修复
- [X] 公式与中文正文视觉比例优化

## 运行环境

- Flutter 3.x
- Dart 3.x

建议优先在以下平台测试：

- `windows`
- `linux`
- `android`

## 安装与运行

### 1. 克隆项目

```bash
git clone <your-repo-url>
cd markdown_app
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行项目

Windows:

```bash
flutter run -d windows
```

Linux:

```bash
flutter run -d linux
```

Android:

```bash
flutter run -d android
```

## 国内镜像配置

如果你在中国大陆网络环境下使用 Flutter / pub，建议配置镜像。

### 临时配置

PowerShell:

```powershell
$env:PUB_HOSTED_URL="https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

### 永久配置

PowerShell:

```powershell
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://mirrors.tuna.tsinghua.edu.cn/dart-pub", "User")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
```

配置完成后重新打开终端，再执行：

```bash
flutter pub get
```

## 项目结构

```text
lib/
  main.dart
  app.dart
  models/
  providers/
  screens/
  services/
  theme/
  widgets/
    markdown/
    sidebar/
    tab_bar/
    welcome/

assets/
  fonts/

test/
```

## 目录说明

- `models/`：数据模型
- `providers/`：状态管理
- `services/`：文件读取、存储等服务层
- `theme/`：主题与字体配置
- `widgets/markdown/`：Markdown / LaTeX 渲染相关组件
- `widgets/tab_bar/`：多标签页组件
- `widgets/sidebar/`：侧边栏与最近文件列表
- `test/`：渲染和回归测试

## 当前重点

这个项目当前的核心目标不是编辑器，而是：

1. 稳定渲染 Markdown
2. 尽可能正确地渲染 LaTeX 数学公式
3. 在平板和桌面场景下提供舒服的阅读体验

## 后续计划

- [ ] 目录树 / 文档导航
- [ ] 搜索功能
- [ ] 更完整的 Markdown 扩展支持
- [ ] 打开文件夹后的文档管理
- [ ] 阅读状态持久化
- [ ] 更细粒度的公式与表格排版优化
- [ ] Android 平板专门布局优化

## 开发说明

项目开发过程中重点遵循：

- 小文件、清晰分层
- 功能修改配套回归测试
- 使用 git 分阶段提交
- 优先修复 LaTeX / 表格 / 中文阅读体验问题

## 测试

运行静态检查：

```bash
flutter analyze
```

运行测试：

```bash
flutter test
```

## License

 `MIT`
