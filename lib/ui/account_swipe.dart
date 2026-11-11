import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

enum AccountSwipeAction { edit, delete }

/// The card stays in the list; a gesture only reveals an action, never runs it.
class AccountSwipe extends StatefulWidget {
  const AccountSwipe({
    super.key,
    required this.accountId,
    required this.revealed,
    required this.onStart,
    required this.onReveal,
    required this.onAction,
    required this.child,
  });

  final String accountId;
  final AccountSwipeAction? revealed;
  final VoidCallback onStart;
  final ValueChanged<AccountSwipeAction?> onReveal;
  final ValueChanged<AccountSwipeAction> onAction;
  final Widget child;

  @override
  State<AccountSwipe> createState() => _AccountSwipeState();
}

class _AccountSwipeState extends State<AccountSwipe> {
  static const _width = 76.0;
  double? _drag;

  double get _settled => switch (widget.revealed) {
    AccountSwipeAction.edit => -_width,
    AccountSwipeAction.delete => _width,
    null => 0,
  };

  void _finish() {
    final offset = _drag ?? _settled;
    setState(() => _drag = null);
    widget.onReveal(
      offset <= -_width / 2
          ? AccountSwipeAction.edit
          : offset >= _width / 2
          ? AccountSwipeAction.delete
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.revealed != null;
    return Semantics(
      container: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: '编辑账号'): () =>
            widget.onAction(AccountSwipeAction.edit),
        const CustomSemanticsAction(label: '删除账号'): () =>
            widget.onAction(AccountSwipeAction.delete),
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onHorizontalDragStart: (_) {
            widget.onStart();
            setState(() => _drag = _settled);
          },
          onHorizontalDragUpdate: (details) => setState(() {
            _drag = ((_drag ?? _settled) + details.delta.dx).clamp(
              -_width,
              _width,
            );
          }),
          onHorizontalDragEnd: (_) => _finish(),
          onHorizontalDragCancel: () => setState(() => _drag = null),
          child: Stack(
            children: [
              _rail(context, AccountSwipeAction.delete),
              _rail(context, AccountSwipeAction.edit),
              AnimatedContainer(
                duration:
                    _drag != null || MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(_drag ?? _settled, 0, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: open ? () => widget.onReveal(null) : null,
                  child: IgnorePointer(ignoring: open, child: widget.child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rail(BuildContext context, AccountSwipeAction action) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final destructive = action == AccountSwipeAction.delete;
    final enabled = _drag == null && widget.revealed == action;
    final ink = destructive
        ? (dark ? const Color(0xffffe7e7) : const Color(0xff8a2020))
        : theme.colorScheme.onSurface;
    final label = destructive ? '删除' : '编辑';
    return Positioned(
      top: 0,
      bottom: 0,
      left: destructive ? 0 : null,
      right: destructive ? null : 0,
      width: _width,
      child: IgnorePointer(
        ignoring: !enabled,
        child: ExcludeSemantics(
          excluding: !enabled,
          child: Material(
            color: destructive
                ? (dark ? const Color(0xff652828) : const Color(0xffffe7e7))
                : theme.colorScheme.surfaceContainerHighest,
            child: InkWell(
              key: ValueKey('${action.name}-${widget.accountId}'),
              onTap: enabled ? () => widget.onAction(action) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    destructive ? Icons.delete_outline : Icons.edit_outlined,
                    color: ink,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(color: ink, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
