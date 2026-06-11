import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          Text(
            'Data: OpenWeatherMap · CPCB scale · not medical advice',
            style: AppTheme.mono(9.5,
                color: Colors.white.withValues(alpha: 0.65)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 0,
            alignment: WrapAlignment.center,
            children: [
              _Link(label: 'About', route: '/about'),
              _Sep(),
              _Link(label: 'Contact', route: '/contact'),
              _Sep(),
              _Link(label: 'Privacy', route: '/privacy'),
              _Sep(),
              _Link(label: 'Terms', route: '/terms'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '© 2026 Bahar Jaaun? — by Abhimanyu Kumar',
            style: AppTheme.mono(9,
                color: Colors.white.withValues(alpha: 0.45)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(' · ', style: AppTheme.mono(10, color: Colors.white.withValues(alpha: 0.4)));
}

class _Link extends StatefulWidget {
  final String label;
  final String route;
  const _Link({required this.label, required this.route});

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.pushNamedAndRemoveUntil(
            context, widget.route, (r) => r.settings.name == '/'),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: AppTheme.mono(10,
              color: _hovered
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
              weight: FontWeight.w600),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
