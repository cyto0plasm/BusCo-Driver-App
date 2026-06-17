import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool  _obscure  = true;
  bool  _emailFocused    = false;
  bool  _passwordFocused = false;

  late AnimationController _entryAc;
  late AnimationController _pulseAc;
  late Animation<double>   _logoFade;
  late Animation<double>   _logoScale;
  late Animation<double>   _cardFade;
  late Animation<Offset>   _cardSlide;
  late Animation<double>   _textFade;
  late Animation<double>   _pulse;

  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _entryAc = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _pulseAc = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

    _logoFade  = CurvedAnimation(parent: _entryAc, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _logoScale = CurvedAnimation(parent: _entryAc, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack));
    _textFade  = CurvedAnimation(parent: _entryAc, curve: const Interval(0.25, 0.6, curve: Curves.easeOut));
    _cardFade  = CurvedAnimation(parent: _entryAc, curve: const Interval(0.4, 0.8, curve: Curves.easeOut));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryAc, curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)));
    _pulse     = CurvedAnimation(parent: _pulseAc, curve: Curves.easeInOut);

    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));

    _entryAc.forward();
  }

  @override
  void dispose() {
    _entryAc.dispose(); _pulseAc.dispose();
    _email.dispose(); _password.dispose();
    _emailFocus.dispose(); _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final e = _email.text.trim();
    final p = _password.text.trim();
    if (e.isEmpty || p.isEmpty) return;
    context.read<AuthBloc>().add(AuthLogin(e, p));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthBloc, AuthState>(
    listener: (ctx, state) {
      if (state is AuthError) BSnack.err(ctx, state.msg);
    },
    builder: (ctx, state) {
      final loading = state is AuthLoading;
      final size    = MediaQuery.of(context).size;

      return Scaffold(
        backgroundColor: Brand.navy,
        resizeToAvoidBottomInset: true,
        body: Stack(children: [

          // ── Layered background geometry ──────────────────
          // Large soft circle — top right
          Positioned(
            top: -size.height * 0.12,
            right: -size.width * 0.25,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: size.width * 0.85,
                height: size.width * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Brand.sky.withOpacity(0.22 + _pulse.value * 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Small circle — bottom left
          Positioned(
            bottom: size.height * 0.35,
            left: -size.width * 0.12,
            child: Container(
              width: size.width * 0.45,
              height: size.width * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Brand.light.withOpacity(0.07),
              ),
            ),
          ),

          // Thin diagonal accent line
          Positioned(
            top: size.height * 0.26,
            left: 0, right: 0,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                height: 1,
                color: Brand.light,
              ),
            ),
          ),

          // ── Scrollable content ───────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height
                    - MediaQuery.of(context).padding.top
                    - MediaQuery.of(context).padding.bottom),
                child: IntrinsicHeight(
                  child: Column(children: [

                    // ── Hero panel (navy) ────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Logo lockup
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              alignment: Alignment.centerLeft,
                              child: Row(children: [
                                // Icon mark
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.18),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(Icons.directions_bus_rounded,
                                      color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('BUSCO',
                                        style: T.label(c: Colors.white).copyWith(
                                          fontSize: 14, letterSpacing: 4,
                                          fontWeight: FontWeight.w700,
                                        )),
                                    Text('DRIVER PORTAL',
                                        style: T.caption(c: Brand.light.withOpacity(0.65)).copyWith(
                                          letterSpacing: 2,
                                        )),
                                  ],
                                ),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Headline
                          FadeTransition(
                            opacity: _textFade,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome\nback.',
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.05,
                                      letterSpacing: -1.5,
                                    )),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Container(
                                    width: 28, height: 2,
                                    decoration: BoxDecoration(
                                      color: Brand.sky,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Sign in to your account',
                                      style: T.body(c: Brand.light.withOpacity(0.75))),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Card panel (white/cream) ─────────────
                    Expanded(
                      child: FadeTransition(
                        opacity: _cardFade,
                        child: SlideTransition(
                          position: _cardSlide,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              28, 32, 28,
                              MediaQuery.of(context).viewInsets.bottom + 28,
                            ),
                            decoration: const BoxDecoration(
                              color: Brand.cream,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(32)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // Section label
                                Text('CREDENTIALS',
                                    style: T.label(c: Brand.navy.withOpacity(0.40)).copyWith(
                                      letterSpacing: 3,
                                    )),
                                const SizedBox(height: 20),

                                // Email field
                                _ElegantField(
                                  label: 'Email address',
                                  controller: _email,
                                  focusNode: _emailFocus,
                                  isFocused: _emailFocused,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.alternate_email_rounded,
                                  hint: 'driver@busco.eg',
                                ),
                                const SizedBox(height: 14),

                                // Password field
                                _ElegantField(
                                  label: 'Password',
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  isFocused: _passwordFocused,
                                  obscure: _obscure,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  hint: '••••••••',
                                  suffix: GestureDetector(
                                    onTap: () => setState(() => _obscure = !_obscure),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Brand.navy.withOpacity(0.40),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // CTA
                                _SignInButton(loading: loading, onTap: loading ? null : _submit),

                                const SizedBox(height: 20),

                                // Trust line
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 4, height: 4,
                                      decoration: BoxDecoration(
                                        color: Brand.navy.withOpacity(0.25),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Secured by BusCo Transport System',
                                        style: T.caption(c: Brand.navy.withOpacity(0.38))),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 4, height: 4,
                                      decoration: BoxDecoration(
                                        color: Brand.navy.withOpacity(0.25),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  ]),
                ),
              ),
            ),
          ),

        ]),
      );
    },
  );
}

// ── Elegant input field ───────────────────────────────────────
class _ElegantField extends StatelessWidget {
  final String                label;
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  isFocused;
  final bool                  obscure;
  final TextInputType?        keyboardType;
  final IconData              prefixIcon;
  final String?               hint;
  final Widget?               suffix;

  const _ElegantField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    this.obscure = false,
    this.keyboardType,
    required this.prefixIcon,
    this.hint,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? Brand.sky : const Color(0xFFDDE0D4),
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [BoxShadow(color: Brand.sky.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isFocused ? Brand.sky : Brand.navy.withOpacity(0.45),
                letterSpacing: 0.8,
              ),
            ),
          ),
          TextField(
            controller:   controller,
            focusNode:    focusNode,
            obscureText:  obscure,
            keyboardType: keyboardType,
            style: T.body(c: Brand.navy).copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText:       hint,
              hintStyle:      T.body(c: Brand.navy.withOpacity(0.28)),
              filled:         false,
              border:         InputBorder.none,
              enabledBorder:  InputBorder.none,
              focusedBorder:  InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 10, bottom: 2),
                child: Icon(prefixIcon,
                    color: isFocused ? Brand.sky : Brand.navy.withOpacity(0.35),
                    size: 17),
              ),
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign-in CTA button ────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool          loading;
  const _SignInButton({this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: loading || onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Brand.navy, Color(0xFF4A7FA0)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Brand.navy.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: loading
              ? const Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Sign In',
                        style: T.btn(c: Colors.white).copyWith(
                          fontSize: 15, letterSpacing: 0.5,
                        )),
                    const SizedBox(width: 10),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
