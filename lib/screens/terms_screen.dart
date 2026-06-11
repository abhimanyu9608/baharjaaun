import 'package:flutter/material.dart';
import '../widgets/info_scaffold.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoScaffold(
      title: 'Terms of Use',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          InfoH2('Purpose'),
          InfoBody(
            'Bahar Jaaun? is provided for fun and informational purposes only. '
            'It is NOT medical advice. Do not make health or safety decisions '
            'based solely on this app.',
          ),
          InfoH2('Data accuracy'),
          InfoBody(
            'AQI data is sourced from a third-party API (OpenWeatherMap). We make '
            'no warranty regarding the accuracy, completeness, or timeliness of '
            'the data. The app is provided "as is" without any guarantees.',
          ),
          InfoH2('Acceptable use'),
          InfoBody(
            'You agree to use this app responsibly. Automated scraping, abuse of '
            'the service, or attempts to bypass rate limits are prohibited.',
          ),
          InfoH2('Advertising & third-party links'),
          InfoBody(
            'This app may display third-party advertisements. We are not responsible '
            'for the content of those ads or any linked third-party sites.',
          ),
          InfoH2('Limitation of liability'),
          InfoBody(
            'To the maximum extent permitted by law, we are not liable for any '
            'damages arising from use of this app or reliance on its data.',
          ),
          InfoH2('Changes to terms'),
          InfoBody(
            'These terms may be updated at any time. Continued use of the app '
            'after changes constitutes acceptance of the revised terms.',
          ),
        ],
      ),
    );
  }
}
