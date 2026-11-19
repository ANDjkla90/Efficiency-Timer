import 'package:flutter/material.dart';

/// PIN 输入面板：4/6 位数字、圆点进度、数字键盘。
/// 同时用于「解锁」「设置」「验证当前 PIN」三个场景，避免三套键盘三份 bug。
class PinPad extends StatefulWidget {
  final int length;
  final String title;
  final String? subtitle;
  final String? errorText;
  final void Function(String pin) onCompleted;

  /// 父级处理完一次输入（无论对错）后 +1，输入框自动清空
  final int resetToken;
  final bool compact;
  final Widget? footer;

  /// 冷却期（输错太多次）里置 false：键盘变灰且不响应点击
  final bool enabled;

  const PinPad({
    super.key,
    required this.length,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.errorText,
    this.resetToken = 0,
    this.compact = false,
    this.footer,
    this.enabled = true,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      setState(() => _digits = '');
    }
  }

  void _tap(String d) {
    if (!widget.enabled) return;
    if (_digits.length >= widget.length) return;
    setState(() => _digits += d);
    if (_digits.length == widget.length) {
      final pin = _digits;
      // 等这一帧把最后一个圆点画出来，再交给父级校验
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final error = widget.errorText;
    final size = widget.compact ? 52.0 : 62.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title,
            style: TextStyle(
                fontSize: widget.compact ? 16 : 19,
                fontWeight: FontWeight.bold)),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
        SizedBox(height: widget.compact ? 16 : 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = i < _digits.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: widget.compact ? 12 : 14,
              height: widget.compact ? 12 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? primary : Colors.transparent,
                border: Border.all(
                    color: filled ? primary : Colors.grey.shade400, width: 1.5),
              ),
            );
          }),
        ),
        SizedBox(height: widget.compact ? 8 : 12),
        SizedBox(
          height: 20,
          child: error == null
              ? null
              : Text(error,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
        ),
        SizedBox(height: widget.compact ? 6 : 14),
        IgnorePointer(
          ignoring: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.35,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:
                        row.map((d) => _key(d, size)).toList(growable: false),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: size, height: size),
                    _key('0', size),
                    SizedBox(
                      width: size,
                      height: size,
                      child: IconButton(
                        onPressed: _backspace,
                        icon: const Icon(Icons.backspace_outlined, size: 20),
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.footer != null) ...[
          SizedBox(height: widget.compact ? 4 : 12),
          widget.footer!,
        ],
      ],
    );
  }

  Widget _key(String d, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _tap(d),
            child: Center(
              child: Text(d,
                  style: TextStyle(
                      fontSize: size * 0.36, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹窗式 PIN 输入：设置 / 验证都走这里，返回输入的 PIN（取消返回 null）。
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  required int length,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
        child: SizedBox(
          width: 300,
          child: PinPad(
            length: length,
            title: title,
            subtitle: subtitle,
            compact: true,
            onCompleted: (pin) => Navigator.pop(ctx, pin),
          ),
        ),
      ),
    ),
  );
}
