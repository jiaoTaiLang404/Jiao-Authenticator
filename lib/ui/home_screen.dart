import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/android_files.dart';
import '../core/totp.dart';
import '../core/vault_controller.dart';
import 'account_screens.dart';
import 'account_swipe.dart';
import 'countdown_indicator.dart';
import 'jiao_theme.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.vault, required this.files});
  final VaultController vault;
  final AndroidFiles files;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _clock = ValueNotifier<int>(0);
  ({String id, AccountSwipeAction action})? _swiped;
  Timer? _timer;

  VaultController get vault => widget.vault;

  @override
  void initState() {
    super.initState();
    vault.addListener(_syncTimer);
    _syncTimer();
  }

  void _syncTimer() {
    if (vault.foreground && !vault.locked && !vault.readFailed) {
      _updateClock();
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _updateClock(),
      );
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _updateClock() => _clock.value = vault.now().millisecondsSinceEpoch;

  @override
  void dispose() {
    vault.removeListener(_syncTimer);
    _timer?.cancel();
    _clock.dispose();
    _search.dispose();
    super.dispose();
  }

  void _openSettings() {
    _closeSwipe();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(vault: vault, files: widget.files),
      ),
    );
  }

  void _openAdd() {
    _closeSwipe();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddScreen(vault: vault, files: widget.files),
      ),
    );
  }

  Future<void> _copy(OtpAccount account) async {
    final value = const TotpService().at(
      account,
      vault.now().millisecondsSinceEpoch,
    );
    try {
      await deviceChannel.invokeMethod<void>('copyCode', value.code);
      if (mounted) showNotice(context, '已复制验证码');
    } on PlatformException {
      if (mounted) showNotice(context, '剪贴板暂不可用，请直接输入验证码。');
    }
  }

  void _closeSwipe() {
    if (_swiped != null) setState(() => _swiped = null);
  }

  Future<void> _accountAction(
    OtpAccount account,
    AccountSwipeAction action,
  ) async {
    _closeSwipe();
    FocusScope.of(context).unfocus();
    if (action == AccountSwipeAction.edit) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AccountEditor(vault: vault, initial: account, editing: true),
        ),
      );
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除账号？'),
          content: Text('将从本机删除「${account.issuer}」。请确认你仍能使用该服务的恢复方式。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        await vault.deleteAccount(account.id);
        if (mounted) showNotice(context, '已删除账号');
      } on Exception {
        if (mounted) showNotice(context, '删除失败，原账号已保留。');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vault,
    builder: (context, _) => Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const JiaoBackdrop(showFooterRule: false),
          SafeArea(
            maintainBottomViewPadding: true,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    pageInset,
                    14,
                    pageInset,
                    12,
                  ),
                  child: Row(
                    children: [
                      const BrandMark(),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('settings'),
                        tooltip: '设置',
                        onPressed: _openSettings,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bounds) {
                      final showControls = !vault.loading && !vault.readFailed;
                      final height = math.max(
                        52.0,
                        MediaQuery.textScalerOf(context).scale(15) * 1.4 + 22,
                      );
                      // The list keeps its viewport when the IME opens; only the
                      // glass controls move above the keyboard.
                      final keyboardLift = math.max(
                        0.0,
                        MediaQuery.viewInsetsOf(this.context).bottom -
                            MediaQuery.viewPaddingOf(this.context).bottom,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _list(bottomPadding: showControls ? height + 24 : 12),
                          if (showControls)
                            Positioned(
                              left: pageInset,
                              right: pageInset,
                              bottom: math.min(
                                12 + keyboardLift,
                                math.max(0.0, bounds.maxHeight - height),
                              ),
                              child: _bottomControls(context, height),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bottomControls(BuildContext context, double height) => SizedBox(
    height: height,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GlassSurface(
            key: const Key('search-glass'),
            floating: true,
            radius: height / 2,
            reduced: vault.preferences.reduceTransparency,
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: _search,
                builder: (context, value, _) => TextField(
                  key: const Key('search-accounts'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  enableIMEPersonalizedLearning: false,
                  onChanged: (_) => _closeSwipe(),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '搜索服务或账号',
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _search.clear();
                              _closeSwipe();
                            },
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                    hintStyle: TextStyle(color: muted(context), fontSize: 15),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.only(right: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: '添加账号',
          excludeFromSemantics: true,
          child: SizedBox.square(
            dimension: height,
            child: GlassSurface(
              key: const Key('add-account'),
              floating: true,
              radius: height / 2,
              reduced: vault.preferences.reduceTransparency,
              onTap: _openAdd,
              semanticLabel: '添加账号',
              child: const Icon(Icons.add_rounded, size: 25),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _list({double bottomPadding = 12}) {
    if (vault.loading) return const Center(child: CircularProgressIndicator());
    if (vault.readFailed) {
      return _HomeMessage(
        icon: Icons.lock_reset_rounded,
        title: '本机密钥库未读出',
        details: '原数据保持不变。可以重试，或使用加密备份恢复到独立密钥库。',
        action: Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(
              onPressed: vault.retryRead,
              child: const Text('重新读取'),
            ),
            FilledButton(onPressed: _openSettings, child: const Text('从备份恢复')),
          ],
        ),
      );
    }
    return ValueListenableBuilder(
      valueListenable: _search,
      builder: (context, value, _) {
        final query = value.text.trim().toLowerCase();
        final matching = vault.accounts
            .where(
              (a) =>
                  a.issuer.toLowerCase().contains(query) ||
                  a.label.toLowerCase().contains(query),
            )
            .toList();
        if (matching.isEmpty) {
          return vault.accounts.isEmpty
              ? const _HomeMessage(
                  icon: Icons.vpn_key_outlined,
                  title: '还没有账号',
                  details: '添加服务提供的二维码或密钥，就能离线生成验证码。',
                )
              : const _HomeMessage(
                  icon: Icons.search_off_rounded,
                  title: '没有匹配的账号',
                  details: '试试服务名称、账号名或邮箱。',
                );
        }
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(pageInset, 2, pageInset, bottomPadding),
          itemCount: matching.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final account = matching[index];
            return AccountSwipe(
              key: ValueKey(account.id),
              accountId: account.id,
              revealed: _swiped?.id == account.id ? _swiped?.action : null,
              onStart: () {
                if (_swiped?.id != account.id) _closeSwipe();
              },
              onReveal: (action) => setState(() {
                _swiped = action == null
                    ? null
                    : (id: account.id, action: action);
              }),
              onAction: (action) => _accountAction(account, action),
              child: _CodeCard(
                account: account,
                clock: _clock,
                onCopy: () => _copy(account),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({
    required this.icon,
    required this.title,
    required this.details,
    this.action,
  });
  final IconData icon;
  final String title;
  final String details;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 25),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              details,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted(context)),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: action!),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.account,
    required this.clock,
    required this.onCopy,
  });
  final OtpAccount account;
  final ValueNotifier<int> clock;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      account.issuer.characters.first.toUpperCase(),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.issuer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder(
            valueListenable: clock,
            builder: (context, millis, _) {
              final snapshot = const TotpService().at(account, millis);
              final next = const TotpService().nextAt(account, millis);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onCopy,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 15, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                snapshot.formatted,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CountdownIndicator(
                            remaining: snapshot.remaining,
                            period: account.period,
                          ),
                          const SizedBox(width: 11),
                          Semantics(
                            label: '复制验证码',
                            child: Icon(
                              Icons.content_copy_rounded,
                              size: 18,
                              color: muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Semantics(
                      label: '下一周期验证码 ${next.code}',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(
                              color: muted(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: .3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              next.formatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted(context),
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
