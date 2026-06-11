import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/info_scaffold.dart';
import '../theme/app_theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InfoScaffold(
      title: 'Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoH2('Get in touch'),
          const InfoBody('Email: abhik9608@gmail.com'),
          const SizedBox(height: 4),
          const InfoH2('Find me online'),
          _SocialButton(
            label: 'GitHub — github.com/abhimanyu9608',
            icon: '🐙',
            onTap: () => _launch('https://github.com/abhimanyu9608'),
          ),
          _SocialButton(
            label: 'LinkedIn — Abhimanyu Kumar',
            icon: '💼',
            onTap: () => _launch(
                'https://www.linkedin.com/in/abhimanyu-kumar-1768bb110/'),
          ),
          const InfoH2('Suggest verdict lines'),
          const InfoBody(
            "Got a funnier Hinglish verdict? I'd love to hear it! Drop me an email "
            'and it might show up in the next update.',
          ),
          const InfoH2('Bug reports'),
          const InfoBody(
            'If the AQI looks wrong or something is broken, email me with your '
            'city and the date/time you noticed the issue.',
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE8DA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: AppTheme.fredoka(14,
                        color: const Color(0xFF1A1A2E),
                        weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
