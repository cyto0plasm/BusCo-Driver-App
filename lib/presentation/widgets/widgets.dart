import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/constants.dart';

// ─────────────────────────────────────────────────────────────
//  APP BAR  (white surface, navy title, sky accent)
// ─────────────────────────────────────────────────────────────
class BAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String        title;
  final List<Widget>? actions;
  final bool          canPop;
  final PreferredSizeWidget? bottom;

  const BAppBar(this.title, {super.key, this.actions, this.canPop = true, this.bottom});

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? 104 : 58);

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return AppBar(
      backgroundColor: c.surface,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: canPop ? null : Sp.md,
      title: Text(title, style: T.h3(c: c.ink)),
      automaticallyImplyLeading: canPop,
      actions: actions != null
          ? [...actions!, const SizedBox(width: Sp.xs)]
          : null,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, color: c.border),
                  bottom!,
                ],
              ),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: c.border),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CARD  (white surface, subtle shadow, rounded)
// ─────────────────────────────────────────────────────────────
class BCard extends StatelessWidget {
  final Widget       child;
  final EdgeInsets?  padding;
  final Color?       color;
  final Color?       borderColor;
  final VoidCallback? onTap;
  final double?      borderWidth;
  final double?      radius;

  const BCard({super.key, required this.child,
    this.padding, this.color, this.onTap,
    this.borderColor, this.borderWidth, this.radius});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final r = radius ?? Rd.lg;
    return Material(
      color: color ?? c.surface,
      borderRadius: BorderRadius.circular(r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        splashColor: Brand.sky.withOpacity(0.06),
        highlightColor: Brand.sky.withOpacity(0.04),
        child: Container(
          padding: padding ?? const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor ?? c.border,
              width: borderWidth ?? 1,
            ),
            borderRadius: BorderRadius.circular(r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BUTTON — navy solid (RideWave primary)
// ─────────────────────────────────────────────────────────────
class BBtn extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  final Color?        bg;
  final Color?        fg;
  final Widget?       icon;
  final bool          loading;
  final bool          expand;

  const BBtn(this.label, {super.key, this.onTap, this.bg, this.fg,
    this.icon, this.loading = false, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final c       = C.of(context);
    final bgColor = bg ?? c.amber;   // navy in light, sky in dark
    final fgColor = fg ?? Colors.white;
    final disabled = loading || onTap == null;

    final btn = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: disabled ? 0.55 : 1.0,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(Rd.md),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(Rd.md),
          splashColor: Colors.white.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 15),
            child: loading
                ? Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fgColor)))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: Sp.sm)],
                      Text(label, style: T.btn(c: fgColor)),
                    ]),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class BGhostBtn extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  final Color?        color;
  const BGhostBtn(this.label, {super.key, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final col = color ?? c.amber;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: col,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
      ),
      child: Text(label, style: T.btn(c: col)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TEXT FIELD  (white bg, sky focus border)
// ─────────────────────────────────────────────────────────────
class BField extends StatelessWidget {
  final String                label;
  final TextEditingController controller;
  final bool                  obscure;
  final TextInputType?        keyboardType;
  final Widget?               prefix;
  final Widget?               suffix;
  final String?               hint;
  final int?                  maxLines;
  final bool                  enabled;

  const BField({super.key, required this.label, required this.controller,
    this.obscure = false, this.keyboardType, this.prefix, this.suffix,
    this.hint, this.maxLines = 1, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label.toUpperCase(), style: T.label(c: c.inkSoft)),
        ),
        TextField(
          controller:   controller,
          obscureText:  obscure,
          keyboardType: keyboardType,
          maxLines:     maxLines,
          enabled:      enabled,
          style:        T.body(c: c.ink),
          decoration: InputDecoration(
            hintText:       hint,
            hintStyle:      T.body(c: c.inkHint),
            prefixIcon:     prefix != null
                ? Padding(padding: const EdgeInsets.only(left: 4), child: prefix)
                : null,
            suffixIcon:     suffix,
            filled:         true,
            fillColor:      enabled ? c.surface : c.surfaceLt,
            contentPadding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 15),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rd.md),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rd.md),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rd.md),
                borderSide: const BorderSide(color: Brand.sky, width: 2)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rd.md),
                borderSide: BorderSide(color: c.border.withOpacity(0.5))),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AVATAR  (navy gradient placeholder)
// ─────────────────────────────────────────────────────────────
class BAvatar extends StatelessWidget {
  final String? url;
  final String? localPath;
  final String? name;
  final double  size;

  const BAvatar({super.key, this.url, this.localPath, this.name, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (localPath != null) {
      return _ring(context, ClipOval(child: Image.file(
          File(localPath!), width: size, height: size, fit: BoxFit.cover)));
    }
    if (url != null && url!.isNotEmpty) {
      return _ring(context, ClipOval(child: CachedNetworkImage(
        imageUrl: url!, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      )));
    }
    return _placeholder();
  }

  Widget _ring(BuildContext context, Widget child) {
    return Container(
      width: size + 4, height: size + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Brand.sky.withOpacity(0.4), width: 2),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _placeholder() {
    final init = (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Brand.navy, Brand.sky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(init, style: TextStyle(
        fontFamily: 'Sora', fontSize: size * 0.36,
        fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS CHIP  (RideWave color-coded)
// ─────────────────────────────────────────────────────────────
class BChip extends StatelessWidget {
  final String  label;
  final Color?  bg;
  final Color?  fg;
  final double? dotSize;
  final bool    isStatus;

  const BChip(this.label, {super.key,
    this.bg, this.fg, this.dotSize, this.isStatus = false});

  static BChip status(String status, {double? dotSize}) =>
      BChip(status, isStatus: true, dotSize: dotSize,
        bg: _statusBg(status), fg: _statusFg(status));

  static Color _statusBg(String s) => switch (s.toUpperCase()) {
    'ACTIVE'   => const Color(0xFFE8F5E9),
    'BROKEN'   => const Color(0xFFFBE9E9),
    'OPEN'     => const Color(0xFFFBF0E3),
    'RESOLVED' => const Color(0xFFE8F5E9),
    'HIGH'     => const Color(0xFFFBE9E9),
    'MEDIUM'   => const Color(0xFFFBF0E3),
    'LOW'      => const Color(0xFFD8ECF9),
    'IDLE'     => const Color(0xFFF0F1E9),
    'ENDED'    => const Color(0xFFF0F1E9),
    _          => const Color(0xFFF0F1E9),
  };

  static Color _statusFg(String s) => switch (s.toUpperCase()) {
    'ACTIVE'   || 'RESOLVED' => Brand.green,
    'BROKEN'   || 'HIGH'     => Brand.red,
    'OPEN'     || 'MEDIUM'   => Brand.orange,
    'LOW'                    => Brand.sky,
    'IDLE'                   => Brand.navy,
    'ENDED'                  => const Color(0xFF5A7A90),
    _                        => const Color(0xFF5A7A90),
  };

  @override
  Widget build(BuildContext context) {
    final chipBg = bg ?? const Color(0xFFF0F1E9);
    final chipFg = fg ?? const Color(0xFF5A7A90);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(Rd.full),
        border: Border.all(color: chipFg.withOpacity(0.25), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dotSize != null) ...[
          Container(width: dotSize, height: dotSize,
              decoration: BoxDecoration(color: chipFg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Text(label, style: T.label(c: chipFg)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  METRIC TILE
// ─────────────────────────────────────────────────────────────
class BMetric extends StatelessWidget {
  final String value, label;
  final Color? valueColor;
  final double valueSize;

  const BMetric(this.value, this.label,
      {super.key, this.valueColor, this.valueSize = 22});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: T.num(c: valueColor ?? Brand.navy, size: valueSize)),
      const SizedBox(height: 3),
      Text(label.toUpperCase(), style: T.label(c: c.inkHint)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────
class BEmpty extends StatelessWidget {
  final String   title;
  final String?  subtitle;
  final IconData icon;

  const BEmpty(this.title, {super.key,
    this.subtitle, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Center(child: Padding(
      padding: const EdgeInsets.all(Sp.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Brand.light.withOpacity(0.20),
            shape: BoxShape.circle,
            border: Border.all(color: Brand.sky.withOpacity(0.25)),
          ),
          child: Icon(icon, size: 32, color: Brand.sky.withOpacity(0.6)),
        ),
        const SizedBox(height: Sp.md),
        Text(title, style: T.h4(c: c.inkSoft), textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: Sp.xs),
          Text(subtitle!, style: T.bodySm(c: c.inkHint), textAlign: TextAlign.center),
        ],
      ]),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  INFO ROW
// ─────────────────────────────────────────────────────────────
class BInfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool   divider;
  const BInfoRow(this.label, this.value,
      {super.key, this.valueColor, this.divider = true});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(label, style: T.bodySm(c: c.inkSoft)),
          const Spacer(),
          Flexible(child: Text(value,
              style: T.labelMd(c: valueColor ?? c.ink),
              textAlign: TextAlign.right)),
        ]),
      ),
      if (divider) Divider(color: c.border, height: 1),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────
class BSectionHeader extends StatelessWidget {
  final String  title;
  final Widget? trailing;
  const BSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Row(children: [
        Expanded(child: Text(title.toUpperCase(),
            style: T.label(c: c.inkHint))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SNACKBARS
// ─────────────────────────────────────────────────────────────
class BSnack {
  static void ok(BuildContext ctx, String msg)   => _show(ctx, msg, Brand.green, Icons.check_circle_outline);
  static void err(BuildContext ctx, String msg)  => _show(ctx, msg, Brand.red, Icons.error_outline);
  static void info(BuildContext ctx, String msg) => _show(ctx, msg, Brand.navy, Icons.info_outline);

  static void _show(BuildContext ctx, String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: Sp.sm),
        Expanded(child: Text(msg, style: const TextStyle(
            fontFamily: 'Sora', fontSize: 13,
            fontWeight: FontWeight.w500, color: Colors.white))),
      ]),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  LOADING SPINNER  (sky blue)
// ─────────────────────────────────────────────────────────────
class BLoading extends StatelessWidget {
  const BLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32, height: 32,
          child: CircularProgressIndicator(
            color: Brand.sky,
            strokeWidth: 2.5,
            backgroundColor: Color(0x259CD5FF),
          ),
        ),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  STAT CARD
// ─────────────────────────────────────────────────────────────
class BStatCard extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color?   accentColor;

  const BStatCard({super.key,
    required this.value, required this.label,
    required this.icon,  this.accentColor});

  @override
  Widget build(BuildContext context) {
    final c     = C.of(context);
    final color = accentColor ?? Brand.navy;
    return BCard(
      borderColor: color.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(Rd.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: Sp.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: T.num(c: color, size: 20)),
          ),
          const SizedBox(height: 2),
          Text(label, style: T.caption(c: c.inkSoft),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ICON BUTTON
// ─────────────────────────────────────────────────────────────
class BIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final Color?       color;
  const BIconBtn(this.icon, {super.key, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rd.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.sm),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color ?? c.inkSoft),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BOTTOM SHEET HANDLE
// ─────────────────────────────────────────────────────────────
class BSheetHandle extends StatelessWidget {
  const BSheetHandle({super.key});
  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Center(child: Container(
      width: 36, height: 4,
      margin: const EdgeInsets.only(bottom: Sp.sm),
      decoration: BoxDecoration(
        color: c.borderHi,
        borderRadius: BorderRadius.circular(2),
      ),
    ));
  }
}
