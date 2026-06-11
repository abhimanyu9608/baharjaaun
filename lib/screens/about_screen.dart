import 'package:flutter/material.dart';
import '../widgets/info_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoScaffold(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          InfoH2('What is this?'),
          InfoBody(
            'Bahar Jaaun? ("Should I go outside?") is an independent fun project '
            'that tells you the current air quality in Delhi in plain, no-nonsense '
            'Hinglish. No jargon, no government doublespeak.',
          ),
          InfoH2('Who made this?'),
          InfoBody('Made by Abhimanyu Kumar, based in Delhi. '
              'This is a personal side project, not affiliated with any government body.'),
          InfoH2('Data source'),
          InfoBody(
            'Air quality data is sourced from OpenWeatherMap using the Air Pollution API. '
            'AQI is computed from PM2.5 using the official CPCB (India) breakpoints.',
          ),
          InfoH2('Disclaimer'),
          InfoBody(
            'This app is NOT medical advice. The AQI displayed is for informational '
            'purposes only. Always follow official health advisories for your area.',
          ),
        ],
      ),
    );
  }
}
