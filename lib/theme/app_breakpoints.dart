/// 窗口三档断点(Material 自适应布局规范):
/// - compact (<600):手机竖屏,双抽屉模式
/// - medium (600-1099):平板竖屏 / 手机横屏,内容 + 至多一个内嵌面板,侧栏走抽屉
/// - expanded (>=1100):桌面 / 平板横屏,最多三栏内嵌
enum WindowTier { compact, medium, expanded }

WindowTier windowTierForWidth(double width) {
  if (width < 600) return WindowTier.compact;
  if (width < 1100) return WindowTier.medium;
  return WindowTier.expanded;
}

/// 阅读内容区最大宽度:超宽屏下行宽受限,保证舒适阅读
const double readingContentMaxWidth = 840.0;
