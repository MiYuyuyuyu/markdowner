import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

const _mermaidTag = 'mermaid';
const _jsChannelName = 'FlutterMermaidChannel';
const _mermaidHtmlAsset = 'assets/mermaid/mermaid.html';
const _mermaidJsAsset = 'assets/mermaid/mermaid.min.js';

SpanNodeGeneratorWithTag mermaidGenerator = SpanNodeGeneratorWithTag(
  tag: _mermaidTag,
  generator: (e, config, _) => MermaidNode(e.attributes, e.textContent),
);

class MermaidSyntax extends md.InlineSyntax {
  MermaidSyntax() : super(r'<mermaid>(.+?)</mermaid>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final code = match.group(1)!;
    final el = md.Element.text(_mermaidTag, '');
    el.attributes['code'] = code;
    parser.addNode(el);
    return true;
  }
}

/// 解码失败(如手写的非法标签)时返回 null,由调用方降级处理。
String? decodeMermaidCode(String encoded) {
  try {
    final decoded = utf8.decode(base64Url.decode(encoded));
    return decoded.trim().isEmpty ? null : decoded;
  } on FormatException {
    return null;
  }
}

/// 把图表代码编码为可安全内插进 JS 单引号字符串字面量的参数。
/// Uri.encodeComponent 不会转义单引号(属于保留字符),直接内插会
/// 产生非法 JS,图表将永远渲染失败;HTML 侧用 decodeURIComponent
/// 还原参数,因此这里把 ' 补编码为 %27 即可。
String encodeMermaidJsParam(String code) =>
    Uri.encodeComponent(code).replaceAll("'", '%27');

/// WebView2 环境初始化(整个进程一次);正文图表与全屏查看器共用
Future<void>? _windowsEnvironmentFuture;

Future<void> ensureWindowsWebViewEnvironment() =>
    _windowsEnvironmentFuture ??= win.WebviewController.initializeEnvironment();

/// 本地离线渲染:图表在应用内嵌 WebView 中用打包的 mermaid.js 渲染,
/// 不再依赖 mermaid.ink 等在线服务(503/断网即全军覆没)。
///
/// HTML 壳与 mermaid.min.js 都是资产:Android 用 loadFlutterAsset 加载,
/// Windows 把文件释放到临时目录后用 file:// 加载(WebView2 的
/// NavigateToString 有 2MB 内容上限,不能把 3.3MB 的 JS 内联进字符串)。

Future<String>? _windowsHtmlFileFuture;

/// 把 HTML 壳与 mermaid.min.js 释放到临时目录,返回 html 的 file:// 地址。
/// 文件大小与资产不符(应用更新)时重写。
Future<String> _loadWindowsHtmlFile() =>
    _windowsHtmlFileFuture ??= () async {
      final temp = await getTemporaryDirectory();
      final dir = Directory('${temp.path}${Platform.pathSeparator}mermaid');
      await dir.create(recursive: true);

      final jsData = await rootBundle.load(_mermaidJsAsset);
      final jsFile =
          File('${dir.path}${Platform.pathSeparator}mermaid.min.js');
      if (!jsFile.existsSync() || jsFile.lengthSync() != jsData.lengthInBytes) {
        await jsFile.writeAsBytes(jsData.buffer.asUint8List(), flush: true);
      }

      final html = await rootBundle.loadString(_mermaidHtmlAsset);
      final htmlFile = File('${dir.path}${Platform.pathSeparator}mermaid.html');
      await htmlFile.writeAsString(html, flush: true);
      return Uri.file(htmlFile.path).toString();
    }();

enum _MermaidPhase { loading, ready, failed }

/// 单张 Mermaid 图:内嵌 WebView 渲染,渲染完成后上报内容高度,
/// 解析错误上报到失败卡片。测试环境无 WebView,初始化异常降级为失败卡片。
class MermaidView extends StatefulWidget {
  final String code;

  const MermaidView({super.key, required this.code});

  @override
  State<MermaidView> createState() => _MermaidViewState();
}

class _MermaidViewState extends State<MermaidView> {
  _MermaidPhase _phase = _MermaidPhase.loading;
  double? _height;
  String? _error;

  WebViewController? _mobileController;
  win.WebviewController? _windowsController;
  StreamSubscription<dynamic>? _windowsMessageSub;
  StreamSubscription<win.LoadingState>? _windowsLoadingSub;
  bool _pageReady = false;
  String? _lastRenderKey;

  bool _viewerOpen = false;
  TapGestureRecognizer? _tapRecognizer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (Platform.isWindows) {
        await _initWindows().timeout(const Duration(seconds: 10));
      } else {
        await _initMobile().timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _MermaidPhase.failed;
        _error = e.toString();
      });
    }
  }

  Future<void> _initMobile() async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.transparent);
    await controller.addJavaScriptChannel(
      _jsChannelName,
      onMessageReceived: (message) => _onMessage(message.message),
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(onPageFinished: (_) => _onPageReady()),
    );
    await controller.loadFlutterAsset(_mermaidHtmlAsset);
    // html 通过 WebViewAssetLoader 加载,相对路径 mermaid.min.js 同目录解析
    if (!mounted) return;
    setState(() => _mobileController = controller);
    // pageReady/onPageFinished 可能先于本赋值到达:补一次 phase 刷新
    _refreshPhase();
    await _renderCurrent();
  }

  Future<void> _initWindows() async {
    await ensureWindowsWebViewEnvironment();

    final htmlUrl = await _loadWindowsHtmlFile();
    final controller = win.WebviewController();
    await controller.initialize();
    await controller.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
    await controller.setBackgroundColor(Colors.transparent);
    _windowsMessageSub = controller.webMessage.listen(
      (message) => _onMessage(message.toString()),
    );
    _windowsLoadingSub = controller.loadingState.listen((state) {
      if (state == win.LoadingState.navigationCompleted) _onPageReady();
    });
    await controller.loadUrl(htmlUrl);
    if (!mounted) {
      // init 期间 State 已卸载(快速滚动略过多个图表等):控制器尚未
      // 登记到字段,在此释放,避免泄漏原生 WebView2 实例
      await controller.dispose();
      return;
    }
    setState(() => _windowsController = controller);
    // navigationCompleted/pageReady 可能先于本赋值到达:补一次 phase 刷新
    _refreshPhase();
    await _renderCurrent();
  }

  void _onPageReady() {
    if (_pageReady) return;
    _pageReady = true;
    _refreshPhase();
    _renderCurrent();
  }

  void _refreshPhase() {
    final controllerReady =
        _mobileController != null || _windowsController != null;
    if (_pageReady && controllerReady && _phase != _MermaidPhase.failed) {
      if (_phase != _MermaidPhase.ready) {
        setState(() => _phase = _MermaidPhase.ready);
      }
    }
  }

  Future<void> _renderCurrent() async {
    if (!_pageReady || !mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 用内容本身做去重键:widget 重建时 String 实例会变,identityHashCode 不可靠
    final key = '${isDark ? 'dark' : 'light'}|${widget.code}';
    if (_lastRenderKey == key) return;

    final backgroundCss = _cssColor(theme.colorScheme.surface);
    final script = "renderMermaid('${encodeMermaidJsParam(widget.code)}', "
        "'${isDark ? 'dark' : 'default'}', '$backgroundCss');";
    try {
      if (Platform.isWindows) {
        final controller = _windowsController;
        // 未就绪时直接返回:不能把去重键记下来,否则脚本永远不会重发
        if (controller == null) return;
        await controller.executeScript(script);
      } else {
        final controller = _mobileController;
        if (controller == null) return;
        await controller.runJavaScript(script);
      }
      _lastRenderKey = key;
    } catch (_) {
      // 页面随 widget 卸载等瞬时错误:下次主题变化会重试
    }
  }

  String _cssColor(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  void _onMessage(String message) {
    if (!mounted) return;
    if (message == 'pageReady') {
      _onPageReady();
    } else if (message.startsWith('height:')) {
      final height = double.tryParse(message.substring('height:'.length));
      if (height != null &&
          height > 0 &&
          (_height == null || (height - _height!).abs() > 0.5)) {
        setState(() => _height = height);
      }
    } else if (message.startsWith('error:')) {
      final detail = message.substring('error:'.length).trim();
      setState(() {
        _error = detail.isEmpty ? null : detail;
        _phase = _MermaidPhase.failed;
      });
    }
  }

  /// 点击图表:打开全屏矢量查看器(独立 WebView 渲染,任意倍数清晰)
  void _openZoomViewer() {
    if (_phase != _MermaidPhase.ready || _viewerOpen || !mounted) return;
    _viewerOpen = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black87,
      builder: (_) => _MermaidZoomDialog(code: widget.code, isDark: isDark),
    ).then((_) => _viewerOpen = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 深浅色切换:以新主题重新渲染(JS 侧相同 code+theme 会去重)
    _renderCurrent();
  }

  @override
  void dispose() {
    _windowsMessageSub?.cancel();
    _windowsLoadingSub?.cancel();
    _windowsController?.dispose();
    _tapRecognizer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBody(context),
              const SizedBox(height: 8),
              Text(
                'Mermaid',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _MermaidPhase.failed:
        return _buildFailure(context);
      case _MermaidPhase.loading:
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _MermaidPhase.ready:
        // 点击图表打开全屏缩放查看;拖动/滚轮仍交给文档滚动
        Widget webview;
        if (Platform.isWindows) {
          webview = GestureDetector(
            onTap: _openZoomViewer,
            // IgnorePointer 挡住 WebView2 吞事件,opaque 保证 GestureDetector
            // 自身可命中:点按 → 查看器,拖动 → 外层滚动
            behavior: HitTestBehavior.opaque,
            child: IgnorePointer(child: win.Webview(_windowsController!)),
          );
        } else {
          _tapRecognizer ??= TapGestureRecognizer()..onTap = _openZoomViewer;
          webview = WebViewWidget(
            controller: _mobileController!,
            // 只声明点按:WebView 认领单击(打开查看器),
            // 拖动未被认领,自然落到外层滚动列表
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(() => _tapRecognizer!),
            },
          );
        }
        return SizedBox(
          height: _height ?? 200,
          width: double.infinity,
          child: webview,
        );
    }
  }

  Widget _buildFailure(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          Text(
            'Mermaid 图表渲染失败',
            style: TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MermaidNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;

  MermaidNode(this.attributes, this.textContent);

  @override
  InlineSpan build() {
    final encoded = attributes['code'] ?? '';
    if (encoded.isEmpty) return const TextSpan(text: '');

    final code = decodeMermaidCode(encoded);
    if (code == null) {
      // 手写的非法 <mermaid> 标签:降级为纯文本,避免渲染崩溃
      return TextSpan(text: encoded, style: parentStyle);
    }

    return WidgetSpan(child: MermaidView(code: code));
  }
}

/// 全屏矢量查看器:独立 WebView 以 mermaid 自然尺寸渲染同一张图,
/// 平移/缩放由页面内 JS 实现(双指捏合/滚轮/拖动/双击),矢量渲染
/// 任意倍数都清晰。全屏后无需保留文档滚动手势,WebView 直接接管输入。
class _MermaidZoomDialog extends StatefulWidget {
  final String code;
  final bool isDark;

  const _MermaidZoomDialog({required this.code, required this.isDark});

  @override
  State<_MermaidZoomDialog> createState() => _MermaidZoomDialogState();
}

class _MermaidZoomDialogState extends State<_MermaidZoomDialog> {
  WebViewController? _mobileController;
  win.WebviewController? _windowsController;
  StreamSubscription<dynamic>? _windowsMessageSub;
  StreamSubscription<win.LoadingState>? _windowsLoadingSub;
  bool _pageReady = false;
  bool _rendered = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (Platform.isWindows) {
        await _initWindows().timeout(const Duration(seconds: 10));
      } else {
        await _initMobile().timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _initMobile() async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.black);
    await controller.addJavaScriptChannel(
      _jsChannelName,
      onMessageReceived: (message) => _onMessage(message.message),
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(onPageFinished: (_) => _onPageReady()),
    );
    await controller.loadFlutterAsset(_mermaidHtmlAsset);
    if (!mounted) return;
    setState(() => _mobileController = controller);
    _refreshReady();
    await _renderZoom();
  }

  Future<void> _initWindows() async {
    await ensureWindowsWebViewEnvironment();

    final htmlUrl = await _loadWindowsHtmlFile();
    final controller = win.WebviewController();
    await controller.initialize();
    await controller.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
    await controller.setBackgroundColor(Colors.black);
    _windowsMessageSub = controller.webMessage.listen(
      (message) => _onMessage(message.toString()),
    );
    _windowsLoadingSub = controller.loadingState.listen((state) {
      if (state == win.LoadingState.navigationCompleted) _onPageReady();
    });
    await controller.loadUrl(htmlUrl);
    if (!mounted) {
      // 同 _MermaidViewState:卸载后释放未登记的控制器
      await controller.dispose();
      return;
    }
    setState(() => _windowsController = controller);
    _refreshReady();
    await _renderZoom();
  }

  void _onPageReady() {
    if (_pageReady) return;
    _pageReady = true;
    _refreshReady();
    _renderZoom();
  }

  void _refreshReady() {
    final controllerReady =
        _mobileController != null || _windowsController != null;
    if (_pageReady && controllerReady && _error == null) {
      if (!_rendered) setState(() {});
    }
  }

  Future<void> _renderZoom() async {
    if (!_pageReady || !mounted) return;
    final backgroundCss =
        Theme.of(context).brightness == Brightness.dark ? '#101418' : '#000000';
    final script = "renderMermaidZoom('${encodeMermaidJsParam(widget.code)}', "
        "'${widget.isDark ? 'dark' : 'default'}', '$backgroundCss');";
    try {
      if (Platform.isWindows) {
        await _windowsController?.executeScript(script);
      } else {
        await _mobileController?.runJavaScript(script);
      }
    } catch (_) {
      // 页面卸载等瞬时错误,忽略
    }
  }

  void _onMessage(String message) {
    if (!mounted) return;
    if (message == 'pageReady') {
      _onPageReady();
    } else if (message == 'zoomReady') {
      setState(() => _rendered = true);
    } else if (message.startsWith('error:')) {
      final detail = message.substring('error:'.length).trim();
      if (detail.isNotEmpty) setState(() => _error = detail);
    }
  }

  @override
  void dispose() {
    _windowsMessageSub?.cancel();
    _windowsLoadingSub?.cancel();
    _windowsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget? webview;
    if (_mobileController != null) {
      // 不传 gestureRecognizers:全屏下没有需要竞争的手势,
      // 平移/缩放全部交给页面内 JS 处理
      webview = WebViewWidget(controller: _mobileController!);
    } else if (_windowsController != null) {
      webview = win.Webview(_windowsController!);
    }

    return Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (webview != null)
                // 渲染完成前先不显示,避免空白 WebView 闪白
                AnimatedOpacity(
                  opacity: _rendered ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: webview,
                ),
              if (!_rendered && _error == null)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white70),
                      SizedBox(height: 12),
                      Text(
                        '正在打开大图...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        size: 32,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '大图打开失败:$_error',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: 24,
                right: 24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
