import 'dart:io';
import 'package:busco_driver/domain/entities/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name    = TextEditingController();
  final _phone   = TextEditingController();
  final _license = TextEditingController();
  bool  _editing = false;
  String? _localAvatar;

  @override void dispose() {
    _name.dispose(); _phone.dispose(); _license.dispose(); super.dispose();
  }

  void _startEditing(Driver driver) {
    _name.text    = driver.name;
    _phone.text   = driver.phone;
    _license.text = driver.licenseNo ?? '';
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() { _editing = false; _localAvatar = null; });
    context.read<ProfileBloc>().add(const ProfileReset());
  }

  Future<void> _pickAvatar(BuildContext ctx, int driverId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImageSourceSheet(),
    );
    if (source == null) return;
    final img = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (img == null) return;
    setState(() => _localAvatar = img.path);
    if (mounted) ctx.read<ProfileBloc>().add(ProfileUploadAvatar(driverId, File(img.path)));
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (ctx, state) {
        if (state is ProfileSaved) {
          BSnack.ok(ctx, 'Profile saved');
          setState(() => _editing = false);
          ctx.read<AuthBloc>().add(const AuthRefresh());
        }
        if (state is ProfileUploaded) {
          BSnack.ok(ctx, 'Photo updated');
          ctx.read<AuthBloc>().add(const AuthRefresh());
        }
        if (state is ProfileFailed) BSnack.err(ctx, state.msg);
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (ctx, auth) {
          final driver = auth is AuthAuthenticated ? auth.driver : null;
          if (driver == null) return const BEmpty('Not logged in');

          return Scaffold(
            backgroundColor: c.bg,
            body: CustomScrollView(slivers: [

              SliverToBoxAdapter(child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _ProfileHero(
                    driver:      driver,
                    localAvatar: _localAvatar,
                    editing:     _editing,
                    isDark:      isDark,
                    c:           c,
                    onAvatarTap: () => _pickAvatar(ctx, driver.driverId),
                    onEdit:      () => _startEditing(driver),
                    onCancel:    _cancelEditing,
                  ),
                  // Spacer to push sliver content below the floating card
                  const _ProfileHeroMeasure(),
                ],
              )),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xl),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  if (_editing) ...[
                    _EditSection(
                      c: c, name: _name, phone: _phone,
                      license: _license, driver: driver,
                    ),
                  ] else ...[
                    _InfoSection(c: c, driver: driver),
                  ],

                  const SizedBox(height: Sp.lg),
                  _WalletSection(c: c, driver: driver),
                  const SizedBox(height: Sp.lg),
                  _SettingsSection(c: c, isDark: isDark, ctx: ctx),
                  const SizedBox(height: Sp.lg),
                  _SignOutButton(c: c, ctx: ctx),
                  const SizedBox(height: Sp.xxl),
                ])),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── HERO — premium navy banner ────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final Driver driver;
  final String? localAvatar;
  final bool editing, isDark;
  final C c;
  final VoidCallback onAvatarTap, onEdit, onCancel;

  const _ProfileHero({
    required this.driver, this.localAvatar,
    required this.editing, required this.isDark, required this.c,
    required this.onAvatarTap, required this.onEdit, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Navy gradient banner ─────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, top + 16, 24, 72),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Brand.navy, Color(0xFF4A7FA0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // Decorative circles in banner
            Positioned(
              top: -20, right: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -10, left: -20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Brand.light.withOpacity(0.08),
                ),
              ),
            ),
            // Top bar
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MY PROFILE',
                    style: T.label(c: Colors.white.withOpacity(0.55)).copyWith(
                      letterSpacing: 3, fontSize: 10)),
                const SizedBox(height: 2),
                Text('Account', style: T.h3(c: Colors.white)),
              ]),
              const Spacer(),
              _EditButton(
                editing: editing,
                onEdit: onEdit,
                onCancel: onCancel,
              ),
            ]),
          ]),
        ),

        // ── White card overlapping banner ────────────────
        Positioned(
          top: top + 16 + 52 + 12, // below the top bar text
          left: 0, right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Brand.navy.withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(children: [

              // Avatar
              BlocBuilder<ProfileBloc, ProfileState>(
                builder: (_, ps) {
                  final uploading = ps is ProfileUploading;
                  return GestureDetector(
                    onTap: editing ? onAvatarTap : null,
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      // Gradient ring
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Brand.navy, Brand.sky],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.surface,
                          ),
                          child: BAvatar(
                            url: driver.avatarUrl,
                            localPath: localAvatar,
                            name: driver.name,
                            size: 64,
                          ),
                        ),
                      ),
                      if (editing && !uploading)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Brand.sky,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.surface, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 11, color: Colors.white),
                        ),
                      if (uploading)
                        Positioned.fill(child: Container(
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.black38),
                          child: const Center(child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                        )),
                    ]),
                  );
                },
              ),

              const SizedBox(width: 16),

              // Name + email + badges
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name,
                      style: T.h3(c: c.ink),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(driver.email,
                      style: T.bodySm(c: c.inkSoft),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (driver.busId != null)
                      _PillBadge(
                        icon: Icons.directions_bus_rounded,
                        label: driver.busNumber != null
                            ? 'Bus ${driver.busNumber}'
                            : 'Bus #${driver.busId}',
                        color: Brand.sky,
                      ),
                    if (driver.licenseNo != null &&
                        (driver.licenseNo as String).isNotEmpty)
                      _PillBadge(
                        icon: Icons.badge_outlined,
                        label: driver.licenseNo as String,
                        color: Brand.green,
                      ),
                  ]),
                ],
              )),
            ]),
          ),
        ),

        // Bottom spacer so the sliver accounts for the floating card
        const SizedBox(height: 1),
      ],
    );
  }
}

// Measure the hero height to push content below the floating card
class _ProfileHeroMeasure extends StatelessWidget {
  const _ProfileHeroMeasure();
  @override
  Widget build(BuildContext context) {
    // top padding + banner area + card overlap
    return SizedBox(height: MediaQuery.of(context).padding.top + 16 + 52 + 12 + 120 + 16);
  }
}

class _EditButton extends StatelessWidget {
  final bool editing;
  final VoidCallback onEdit, onCancel;
  const _EditButton({required this.editing, required this.onEdit, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editing ? onCancel : onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(Rd.full),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            editing ? Icons.close_rounded : Icons.edit_outlined,
            size: 13, color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            editing ? 'Cancel' : 'Edit',
            style: T.labelMd(c: Colors.white).copyWith(fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _PillBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(Rd.full),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: T.caption(c: color).copyWith(fontWeight: FontWeight.w600)),
    ]),
  );
}

// Keep old classes for backward compat — they now delegate to new ones
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  final C        c;
  final Color?   color;
  const _ActionChip({required this.icon, required this.label,
    required this.onTap, required this.c, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (color ?? Brand.sky).withOpacity(0.12),
        borderRadius: BorderRadius.circular(Rd.full),
        border: Border.all(color: (color ?? Brand.sky).withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color ?? Brand.sky),
        const SizedBox(width: 5),
        Text(label, style: T.labelMd(c: color ?? Brand.sky)),
      ]),
    ),
  );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final C        c;
  const _Badge({required this.icon, required this.label,
    required this.color, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(Rd.full),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: T.labelMd(c: color)),
    ]),
  );
}

// ── INFO SECTION ─────────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  final C c;
  final Driver driver;
  const _InfoSection({required this.c, required this.driver});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(c: c, text: 'Driver Information'),
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: [
          _InfoRow(c: c, icon: Icons.person_outline,
              label: 'Full Name', value: driver.name),
          _InfoRow(c: c, icon: Icons.phone_outlined,
              label: 'Phone', value: driver.phone),
          _InfoRow(c: c, icon: Icons.email_outlined,
              label: 'Email', value: driver.email),
          if (driver.licenseNo != null &&
              (driver.licenseNo as String).isNotEmpty)
            _InfoRow(c: c, icon: Icons.badge_outlined,
                label: 'License No.', value: driver.licenseNo as String,
                last: true),
        ]),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final C      c;
  final IconData icon;
  final String label, value;
  final bool   last;
  const _InfoRow({required this.c, required this.icon,
    required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Brand.navy.withOpacity(0.08), Brand.sky.withOpacity(0.10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Brand.navy.withOpacity(0.65)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: T.caption(c: c.inkHint).copyWith(letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(value,
                style: T.body(c: c.ink).copyWith(fontWeight: FontWeight.w600)),
          ],
        )),
      ]),
    ),
    if (!last) Divider(height: 1, color: c.border.withOpacity(0.6), indent: 66),
  ]);
}

// ── EDIT SECTION ─────────────────────────────────────────────
class _EditSection extends StatelessWidget {
  final C c;
  final TextEditingController name, phone, license;
  final Driver driver;
  const _EditSection({required this.c, required this.name,
    required this.phone, required this.license, required this.driver});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(c: c, text: 'Edit Profile'),
      BField(label: 'Full Name', controller: name,
          prefix: Icon(Icons.person_outline, color: c.inkSoft, size: 18),
          hint: 'Your full name'),
      const SizedBox(height: Sp.sm),
      BField(label: 'Phone', controller: phone,
          prefix: Icon(Icons.phone_outlined, color: c.inkSoft, size: 18),
          hint: '+20 xxx xxx xxxx',
          keyboardType: TextInputType.phone),
      const SizedBox(height: Sp.sm),
      BField(label: 'License No.', controller: license,
          prefix: Icon(Icons.badge_outlined, color: c.inkSoft, size: 18),
          hint: 'License number'),
      const SizedBox(height: Sp.md),
      BlocBuilder<ProfileBloc, ProfileState>(
        builder: (ctx, ps) => BBtn('Save Changes',
          loading: ps is ProfileSaving,
          icon: Icon(Icons.check_rounded, color: c.onAmber, size: 18),
          onTap: ps is ProfileSaving ? null : () {
            ctx.read<ProfileBloc>().add(ProfileSave(
              driver.driverId,
              name:      name.text,
              phone:     phone.text,
              licenseNo: license.text,
            ));
          },
        ),
      ),
    ],
  );
}

// ── WALLET SECTION ───────────────────────────────────────────
class _WalletSection extends StatelessWidget {
  final C c;
  final Driver driver;
  const _WalletSection({required this.c, required this.driver});

  @override
  Widget build(BuildContext context) {
    if (driver.walletId == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(c: c, text: 'Wallet'),
      BlocBuilder<WalletBloc, WalletState>(
        builder: (_, ws) {
          final bal = ws is WalletLoaded ? ws.bal : driver.balance as double;
          return Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Brand.navy, Brand.sky],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(Rd.lg),
              border: Border.all(color: Brand.sky.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Brand.navy.withOpacity(0.20),
                  blurRadius: 14, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(Rd.md),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: Sp.md),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Wallet Balance', style: T.caption(c: Colors.white60)),
                const SizedBox(height: 3),
                Text('${bal.toStringAsFixed(2)} EGP',
                    style: T.num(c: Colors.white, size: 22)),
              ]),
            ]),
          );
        },
      ),
    ]);
  }
}

// ── SETTINGS SECTION ─────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final C c;
  final bool isDark;
  final BuildContext ctx;
  const _SettingsSection({required this.c,
    required this.isDark, required this.ctx});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(c: c, text: 'Settings'),
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Brand.sky.withOpacity(0.12),
                borderRadius: BorderRadius.circular(Rd.sm),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 15, color: Brand.sky),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(
              isDark ? 'Dark Mode' : 'Light Mode',
              style: T.body(c: c.ink))),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: isDark,
                activeColor: Brand.sky,
                activeTrackColor: Brand.sky.withOpacity(0.20),
                inactiveThumbColor: c.inkSoft,
                inactiveTrackColor: c.border,
                onChanged: (_) => ctx.read<ThemeBloc>().add(const ThemeToggle()),
              ),
            ),
          ]),
        ),
      ),
    ],
  );
}

// ── SIGN OUT BUTTON ───────────────────────────────────────────
class _SignOutButton extends StatelessWidget {
  final C c;
  final BuildContext ctx;
  const _SignOutButton({required this.c, required this.ctx});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showDialog(
      context: context,
      builder: (_) => _LogoutDialog(c: c, ctx: ctx),
    ),
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: Brand.red.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Brand.red.withOpacity(0.08),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Brand.red.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.logout_rounded, color: Brand.red, size: 15),
        ),
        const SizedBox(width: 10),
        Text('Sign Out',
            style: T.btn(c: Brand.red).copyWith(fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _LogoutDialog extends StatelessWidget {
  final C c;
  final BuildContext ctx;
  const _LogoutDialog({required this.c, required this.ctx});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Sign out?', style: T.h3(c: c.ink)),
    content: Text(
      'You will need to log in again to access your account.',
      style: T.body(c: c.inkSoft)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: T.btn(c: c.inkSoft))),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          ctx.read<AuthBloc>().add(const AuthLogout());
        },
        child: Text('Sign Out', style: T.btn(c: c.red))),
    ],
  );
}

// ── IMAGE SOURCE SHEET ────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Container(
      margin: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Rd.xxl),
        border: Border.all(color: c.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: Sp.md),
        const BSheetHandle(),
        const SizedBox(height: Sp.sm),
        Text('Change Photo', style: T.h4()),
        const SizedBox(height: Sp.sm),
        _SheetTile(c: c,
          icon: Icons.camera_alt_outlined, label: 'Take Photo',
          color: Brand.sky,
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        _SheetTile(c: c,
          icon: Icons.photo_library_outlined, label: 'Choose from Gallery',
          color: c.accent,
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        _SheetTile(c: c,
          icon: Icons.close, label: 'Cancel',
          color: c.inkSoft,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: Sp.md),
      ]),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final C    c;
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _SheetTile({required this.c, required this.icon,
    required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Rd.sm)),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(label, style: T.body(c: c.ink)),
    onTap: onTap,
    horizontalTitleGap: 8,
  );
}

// ── SHARED ───────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final C c;
  final String text;
  const _SectionLabel({required this.c, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.sm),
    child: Text(text.toUpperCase(),
        style: T.label(c: c.inkHint)),
  );
}
