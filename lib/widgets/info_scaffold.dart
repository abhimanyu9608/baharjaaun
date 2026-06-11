import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_footer.dart';

const double _kMaxWidth = 480;

class InfoScaffold extends StatefulWidget {
  final String title;
  final Widget child;

  const InfoScaffold({super.key, required this.title, required this.child});

  @override
  State<InfoScaffold> createState() => _InfoScaffoldState();
}

class _InfoScaffoldState extends State<InfoScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cardFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.1, 1.0, curve: Curves.easeOut));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3DAA6A),
            Color(0xFF2F9D5E),
            Color(0xFF1E6B41),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(widget.title,
                    style: AppTheme.baloo2(21, color: Colors.white)),
                centerTitle: false,
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxWidth),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                        decoration: BoxDecoration(
                          color: AppTheme.cream,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              offset: const Offset(0, 6),
                              blurRadius: 24,
                              spreadRadius: -2,
                            ),
                            const BoxShadow(
                              color: Color(0x28000000),
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InfoH2 extends StatelessWidget {
  final String text;
  const InfoH2(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF2F9D5E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTheme.baloo2(17)),
        ],
      ),
    );
  }
}

class InfoBody extends StatelessWidget {
  final String text;
  const InfoBody(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: AppTheme.fredoka(14.5,
              color: const Color(0xFF333344),
              weight: FontWeight.w400)),
    );
  }
}
