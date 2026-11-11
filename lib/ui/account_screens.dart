import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/android_files.dart';
import '../core/totp.dart';
import '../core/vault_controller.dart';
import 'jiao_theme.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key, required this.vault, required this.files});
  final VaultController vault;
  final AndroidFiles files;

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  bool _busy = false;

  Future<void> _showEditor([OtpAccount? account]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountEditor(vault: widget.vault, initial: account),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _choose(QrCandidates? result) async {
    if (!mounted) return;
    if (result == null) {
      showNotice(context, '已取消选择');
      return;
    }
    if (result.accounts.isEmpty) {
      showNotice(context, result.error ?? '这张图片没有有效的 TOTP 二维码。');
      return;
    }
    final account = result.accounts.length == 1
        ? result.accounts.single
        : await showModalBottomSheet<OtpAccount>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('选择要添加的账号'),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final a in result.accounts)
                          ListTile(
                            title: Text(a.issuer),
                            subtitle: Text(a.label),
                            onTap: () => Navigator.pop(ctx, a),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
    if (account != null && mounted) await _showEditor(account);
  }

  Future<void> _pickImage() async {
    final epoch = widget.vault.session;
    setState(() => _busy = true);
    try {
      final result = await widget.files.pickQrImage();
      if (widget.vault.isCurrent(epoch)) await _choose(result);
    } on FormatException catch (error) {
      if (mounted) showNotice(context, error.message);
    } on Exception {
      if (mounted) showNotice(context, '图片读取或识别失败，请选另一张图片。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<QrCandidates>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result != null) await _choose(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('添加账号')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const JiaoBackdrop(),
        SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(pageInset),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BrandMark(size: 52),
              ),
              const SizedBox(height: 20),
              Text('添加动态验证码', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '从服务的双重验证设置中找到账号二维码或密钥。',
                style: TextStyle(color: muted(context)),
              ),
              const SizedBox(height: 26),
              GlassSurface(
                reduced: widget.vault.preferences.reduceTransparency,
                radius: 20,
                onTap: _busy ? null : _scan,
                child: const _AddOption(
                  icon: Icons.qr_code_scanner_rounded,
                  title: '相机扫码',
                  subtitle: '扫描另一台设备上的二维码',
                ),
              ),
              const SizedBox(height: 12),
              _flatOption(
                context,
                key: const Key('choose-qr-image'),
                onTap: _pickImage,
                child: const _AddOption(
                  icon: Icons.image_outlined,
                  title: '选择二维码图片',
                  subtitle: '从手机中选择一张图片',
                ),
              ),
              const SizedBox(height: 12),
              _flatOption(
                context,
                key: const Key('manual-add'),
                onTap: _showEditor,
                child: const _AddOption(
                  icon: Icons.edit_outlined,
                  title: '手动输入',
                  subtitle: '填写服务名称、账号与密钥',
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _flatOption(
    BuildContext context, {
    required Key key,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(key: key, onTap: _busy ? null : onTap, child: child),
    );
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        SizedBox(width: 40, child: Icon(icon, size: 24)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: muted(context)),
      ],
    ),
  );
}

class AccountEditor extends StatefulWidget {
  const AccountEditor({
    super.key,
    required this.vault,
    this.initial,
    this.editing = false,
  });
  final VaultController vault;
  final OtpAccount? initial;
  final bool editing;

  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  late final _issuer = TextEditingController(text: widget.initial?.issuer);
  late final _label = TextEditingController(text: widget.initial?.label);
  late final _secret = TextEditingController(
    text: widget.editing ? null : widget.initial?.secret,
  );
  late final _period = TextEditingController(
    text: (widget.initial?.period ?? 30).toString(),
  );
  late TotpAlgorithm _algorithm =
      widget.initial?.algorithm ?? TotpAlgorithm.sha1;
  late int _digits = widget.initial?.digits ?? 6;
  bool _busy = false;
  bool _obscured = true;
  String? _error;

  @override
  void dispose() {
    _secret.clear();
    for (final c in [_issuer, _label, _secret, _period]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final account = OtpAccount.create(
        issuer: _issuer.text,
        label: _label.text,
        secret: _secret.text.trim().isEmpty && widget.editing
            ? widget.initial!.secret
            : _secret.text,
        id: widget.initial?.id,
        createdAt: widget.initial?.createdAt,
        algorithm: _algorithm,
        digits: _digits,
        period: int.tryParse(_period.text) ?? 0,
      );
      await widget.vault.saveAccount(account, editing: widget.editing);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) setState(() => _error = '保存失败，原数据已保留。请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.editing
            ? '编辑账号'
            : widget.initial != null
            ? '确认账号'
            : '手动添加',
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(pageInset),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (widget.initial != null && !widget.editing) ...[
            const Text('已读取二维码。核对账号与验证码参数后保存。'),
            const SizedBox(height: 18),
          ],
          TextField(
            key: const Key('issuer-field'),
            controller: _issuer,
            maxLength: 160,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '服务名称',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('label-field'),
            controller: _label,
            maxLength: 160,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(labelText: '账号', counterText: ''),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('secret-field'),
            controller: _secret,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            maxLength: 2048,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Base32 密钥',
              counterText: '',
              helperText: widget.editing ? '留空保留原密钥' : null,
              suffixIcon: IconButton(
                tooltip: _obscured ? '显示密钥' : '隐藏密钥',
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<TotpAlgorithm>(
            initialValue: _algorithm,
            decoration: const InputDecoration(labelText: '算法'),
            onChanged: (value) => setState(() => _algorithm = value!),
            items: [
              for (final a in TotpAlgorithm.values)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _digits,
            decoration: const InputDecoration(labelText: '验证码位数'),
            onChanged: (value) => setState(() => _digits = value!),
            items: const [
              DropdownMenuItem(value: 6, child: Text('6 位')),
              DropdownMenuItem(value: 8, child: Text('8 位')),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _period,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '刷新周期（秒）',
              counterText: '',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text(_error!)),
            ),
          const SizedBox(height: 22),
          FilledButton(
            key: const Key('save-account'),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '正在保存…' : '保存账号'),
          ),
        ],
      ),
    ),
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _completed = false;
  String? _message;

  void _detect(BarcodeCapture capture) {
    if (_completed ||
        !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final raw = capture.barcodes
        .where((b) => b.format == BarcodeFormat.qrCode)
        .map((b) => b.rawValue)
        .nonNulls;
    if (raw.isEmpty) return;
    final result = decodeQrValues(raw);
    if (result.accounts.isEmpty) {
      if (_message != result.error) setState(() => _message = result.error);
      return;
    }
    _completed = true;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('相机扫码')),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: _detect,
              onDetectError: (_, _) {},
              errorBuilder: (context, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        '相机不可用。请在 Android 设置中允许相机权限，或返回选择图片、手动输入。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回添加方式'),
                      ),
                    ],
                  ),
                ),
              ),
              overlayBuilder: (context, bounds) => IgnorePointer(
                child: Center(
                  child: Container(
                    width: bounds.maxWidth * .68,
                    height: bounds.maxWidth * .68,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(pageInset),
            child: Text(
              _message ?? '将服务提供的二维码放入取景框。',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted(context)),
            ),
          ),
        ],
      ),
    ),
  );
}
