import 'package:flutter/material.dart';
import '../widgets/info_scaffold.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoScaffold(
      title: 'Privacy Policy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          InfoBody('Last updated: 11 June 2026'),
          InfoH2('Location data'),
          InfoBody(
            "This app requests your device's location solely to fetch the local "
            "air quality index. Your coordinates are sent to OpenWeatherMap's API "
            'to retrieve pollution data. We do not store or sell your location. '
            'If you deny location permission, the app defaults to Delhi coordinates.',
          ),
          InfoH2('Advertising (Google AdSense)'),
          InfoBody(
            'This app uses Google AdSense to display advertisements. Third-party '
            'vendors, including Google, use cookies to serve ads based on prior '
            'visits to this site or other sites. You may opt out of personalised '
            'advertising by visiting google.com/settings/ads. For more information '
            'about how Google uses data when you use partner sites, see '
            'google.com/policies/technologies/partner-sites.',
          ),
          InfoH2('Analytics'),
          InfoBody(
            'We may use Google Analytics to collect aggregate, anonymised usage '
            'statistics (e.g. pages visited, device type). No personally identifiable '
            'information is collected.',
          ),
          InfoH2("Children's privacy"),
          InfoBody(
            'This app is not directed at children under 13. We do not knowingly '
            'collect information from children under 13.',
          ),
          InfoH2('Contact'),
          InfoBody('Questions? Email: abhik9608@gmail.com'),
        ],
      ),
    );
  }
}
