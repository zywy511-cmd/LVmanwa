part of '../reader_page.dart';

class _ReaderImageGesture extends StatelessWidget {
  final Widget child;
  final ValueChanged<Offset>? onSingleTap;
  final VoidCallback onDoubleTap;

  const _ReaderImageGesture({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.onSingleTap,
  });

  @override
  Widget build(BuildContext context) {
    Offset? lastTapGlobalPosition;
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (details) => lastTapGlobalPosition = details.globalPosition,
      onTap: () {
        final position = lastTapGlobalPosition;
        if (position != null) onSingleTap?.call(position);
      },
      onDoubleTap: onDoubleTap,
      child: child,
    );
  }
}
