; Inno Setup 6 打包脚本 —— Markdown Reader
;
; 用法:
;   1. 先构建 Windows 版本:  flutter build windows --release
;   2. 安装 Inno Setup 6:    https://jrsoftware.org/isdl.php
;   3. 编译安装包:            右键本文件 -> Compile,或命令行:
;      "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows_installer.iss
;   4. 产物在 build\installer\ 下
;
; 注意:版本号需与 pubspec.yaml 的 version 保持同步。

#define MyAppName "Markdown Reader"
#define MyAppVersion "0.1.6"
#define MyAppPublisher "MarkdownReader"
#define MyAppExeName "markdown_app.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
; GUID 仅用于区分本应用,重新生成会影响升级安装的识别,保持不变即可
AppId={{B6F3D9A2-4E1C-4A78-9B2D-53C0F1A7E8D4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\MarkdownReader
DisableProgramGroupPage=yes
OutputDir=build\installer
OutputBaseFilename=MarkdownReader-{#MyAppVersion}-setup
; 图标取自 Flutter 工程自带的应用图标
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
; 允许用户选择"仅为当前用户安装"(不需要管理员权限)
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; 安装了 Inno Setup 简体中文语言包(6.3+ 自带)则自动启用中文界面
#if FileExists("compiler:Languages\ChineseSimplified.isl")
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; 打包整个 Release 目录;排除开发过程中可能遗留的快捷方式文件
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion; Excludes: "*.lnk"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
