import 'package:flutter/material.dart';

import '../core/android_files.dart';
import '../core/backup_codec.dart';
import '../core/totp.dart';
import '../core/vault_controller.dart';
import '../core/vault_repository.dart';
import 'jiao_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.vault, required this.files});
  final VaultController vault;
  final AndroidFiles files;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  String? _status;
  VaultController get vault => widget.vault;

  Future<void> _perform(Future<void> Function(int) operation) async {
    if (_busy) return;
    final epoch = vault.session;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await operation(epoch);
    } on FormatException catch (error) {
      if (mounted && vault.isCurrent(epoch)) {
        setState(() => _status = error.message);
      }
    } on Exception {
      if (mounted && vault.isCurrent(epoch)) {
        setState(() => _status = '操作未完成。请重试，原有账号保持不变。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message, int epoch) {
    if (mounted && vault.isCurrent(epoch)) {
      setState(() => _status = message);
    }
  }

  Future<void> _setTheme() async {
    final theme = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('显示主题')),
            for (final value in [
              ThemeMode.dark,
              ThemeMode.light,
              ThemeMode.system,
            ])
              ListTile(
                key: ValueKey('theme-${value.name}'),
                leading: Icon(switch (value) {
                  ThemeMode.dark => Icons.dark_mode_outlined,
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.system => Icons.brightness_auto_outlined,
                }),
                title: Text(_themeLabel(value)),
                trailing: value == vault.preferences.theme
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (theme != null && mounted) {
      await _perform(
        (_) => vault.setPreferences(vault.preferences.copyWith(theme: theme)),
      );
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => '深色',
    ThemeMode.light => '浅色',
    ThemeMode.system => '跟随系统',
  };

  Future<void> _export(int epoch) async {
    if (vault.readFailed || vault.loading) {
      throw const FormatException('请先恢复或重新读取本机账号。');
    }
    if (vault.accounts.isEmpty) throw const FormatException('添加账号后就可以创建加密备份。');
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(exporting: true),
    );
    if (!mounted || !vault.isCurrent(epoch) || password == null) return;
    final bytes = await const BackupCodec().export(vault.accounts, password);
    if (!mounted || !vault.isCurrent(epoch) || !vault.foreground) return;
    final saved = await widget.files.saveBackup(bytes);
    _notice(saved ? '加密备份已保存。请分开保管文件和口令。' : '已取消导出。', epoch);
  }

  Future<void> _restore(int epoch) async {
    final bytes = await widget.files.pickBackup();
    if (!mounted || !vault.isCurrent(epoch)) return;
    if (bytes == null) {
      _notice('已取消导入。', epoch);
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(exporting: false),
    );
    if (!mounted || !vault.isCurrent(epoch) || password == null) return;
    final incoming = await const BackupCodec().restore(bytes, password);
    if (!mounted || !vault.isCurrent(epoch)) return;
    final recovered = vault.readFailed;
    final preview = mergeAccounts(vault.accounts, incoming);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预览备份'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${preview.added} 个待添加，${preview.skipped} 个重复。'),
                const SizedBox(height: 8),
                Text(recovered ? '将写入独立恢复库，未读出的原数据仍保留。' : '本机已有账号保持不变。'),
                const SizedBox(height: 10),
                for (final OtpAccount account in incoming.take(16))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${account.issuer} · ${account.label}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted(context)),
                    ),
                  ),
                if (incoming.length > 16)
                  Text('另有 ${incoming.length - 16} 个账号'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          if (preview.added > 0)
            FilledButton(
              key: const Key('confirm-restore'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('合并恢复'),
            ),
        ],
      ),
    );
    if (!mounted || !vault.isCurrent(epoch) || confirmed != true) return;
    final result = await vault.restore(incoming, recoverUnreadable: recovered);
    _notice('已恢复 ${result.added} 个账号，跳过 ${result.skipped} 个重复项。', epoch);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vault,
    builder: (context, _) {
      final prefs = vault.preferences;
      final canConfigure = !_busy && !vault.settingsReadFailed;
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const JiaoBackdrop(),
            SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(pageInset),
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 50),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brandName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '私有 · 离线 · 仅本机',
                              style: TextStyle(
                                color: muted(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _section(context, '保护', [
                    SwitchListTile(
                      key: const Key('app-lock-switch'),
                      secondary: const Icon(Icons.lock_outline_rounded),
                      title: const Text('应用锁'),
                      subtitle: const Text('切到后台即遮挡，30 秒后重新解锁'),
                      value: prefs.lockEnabled,
                      onChanged: canConfigure
                          ? (value) => _perform(
                              (_) => vault.setPreferences(
                                prefs.copyWith(lockEnabled: value),
                              ),
                            )
                          : null,
                    ),
                    if (prefs.lockEnabled)
                      ListTile(
                        leading: const Icon(Icons.lock_clock_outlined),
                        title: const Text('立即锁定'),
                        onTap: _busy ? null : vault.lock,
                      ),
                    // TEMP_SCREENSHOT_TOGGLE: remove this entire tile.
                    SwitchListTile(
                      key: const Key('temporary-screenshot-toggle'),
                      secondary: const Icon(Icons.screenshot_outlined),
                      title: const Text('允许截屏（临时）'),
                      subtitle: const Text('仅在应用解锁且位于前台时解除截屏和录屏限制'),
                      value: prefs.allowScreenshots,
                      onChanged: canConfigure
                          ? (value) => _perform(
                              (_) => vault.setPreferences(
                                prefs.copyWith(allowScreenshots: value),
                              ),
                            )
                          : null,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _section(context, '外观', [
                    ListTile(
                      key: const Key('theme-setting'),
                      leading: const Icon(Icons.contrast_rounded),
                      title: const Text('显示主题'),
                      trailing: Text(
                        _themeLabel(prefs.theme),
                        style: TextStyle(color: muted(context)),
                      ),
                      onTap: canConfigure ? _setTheme : null,
                    ),
                    SwitchListTile(
                      key: const Key('reduce-transparency'),
                      secondary: const Icon(Icons.blur_off_rounded),
                      title: const Text('减少透明效果'),
                      value: prefs.reduceTransparency,
                      onChanged: canConfigure
                          ? (value) => _perform(
                              (_) => vault.setPreferences(
                                prefs.copyWith(reduceTransparency: value),
                              ),
                            )
                          : null,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _section(context, '加密备份', [
                    ListTile(
                      key: const Key('export-backup'),
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('导出加密备份'),
                      subtitle: const Text('用独立口令保护 .jiaoauth 文件'),
                      onTap: _busy || vault.readFailed
                          ? null
                          : () => _perform(_export),
                    ),
                    ListTile(
                      key: const Key('restore-backup'),
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('从备份恢复'),
                      subtitle: const Text('先预览，再合并；已有账号保留'),
                      onTap: _busy || vault.loading
                          ? null
                          : () => _perform(_restore),
                    ),
                  ]),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_status != null || vault.settingsReadFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_status ?? '本机设置读取失败，原设置保持不变。'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    '版本 $appVersion',
                    style: TextStyle(color: muted(context), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _section(BuildContext context, String heading, List<Widget> rows) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 8),
          child: Text(
            heading,
            style: TextStyle(
              color: muted(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .7,
            ),
          ),
        ),
        Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i != 0) const Divider(indent: 16, endIndent: 16, height: 1),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.exporting});
  final bool exporting;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  void _submit() {
    final value = _password.text;
    try {
      if (widget.exporting) {
        BackupCodec.checkPassword(value);
        if (value != _confirmation.text) {
          throw const FormatException('两次输入的口令不一致。');
        }
      } else if (value.isEmpty) {
        throw const FormatException('请输入备份口令。');
      }
      Navigator.pop(context, value);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _password.clear();
    _confirmation.clear();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller, Key key) =>
      TextField(
        key: key,
        controller: controller,
        obscureText: true,
        maxLength: 256,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        decoration: InputDecoration(labelText: label, counterText: ''),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.exporting ? '设置备份口令' : '解密备份'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.exporting ? '至少 12 个字符。请另外保存口令，应用不会记住它。' : '请输入创建此文件时设置的口令。',
          ),
          const SizedBox(height: 14),
          _field('备份口令', _password, const Key('backup-password')),
          if (widget.exporting) ...[
            const SizedBox(height: 12),
            _field('确认口令', _confirmation, const Key('backup-password-confirm')),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('backup-password-submit'),
        onPressed: _submit,
        child: Text(widget.exporting ? '生成备份' : '解密'),
      ),
    ],
  );
}
