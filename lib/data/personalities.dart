class AqiPersonality {
  final String emoji;
  final String title;
  final String line;
  const AqiPersonality(
      {required this.emoji, required this.title, required this.line});
}

AqiPersonality getPersonality(String catKey, int streak) {
  switch (catKey) {
    case 'GOOD':
      return streak >= 7
          ? const AqiPersonality(
              emoji: '✨',
              title: 'Pure Soul',
              line: 'Delhi mein rehke bhi fresh raha. Superhuman hai tu.')
          : const AqiPersonality(
              emoji: '🍀',
              title: 'Naseeb Wala',
              line: 'Aaj lucky ho. Saaf hawa Delhi mein miracle hai.');
    case 'SATISFACTORY':
      return const AqiPersonality(
          emoji: '😌',
          title: 'Dilli Optimist',
          line: 'Thoda smog, thoda hope. Balance in life bhai.');
    case 'MODERATE':
      return streak >= 10
          ? AqiPersonality(
              emoji: '💪',
              title: 'Veteran Masker',
              line: '$streak din se track kar raha hai. Certified pro.')
          : const AqiPersonality(
              emoji: '😷',
              title: 'Casual Breather',
              line: 'Mask pehna? Good. Warna aaj ek khareed lo.');
    case 'POOR':
      return const AqiPersonality(
          emoji: '🏙️',
          title: 'Hardcore Delhiite',
          line: '250+ AQI mein bhi zinda ho. Fearless legend.');
    case 'VERY_POOR':
      return const AqiPersonality(
          emoji: '☠️',
          title: 'Pollution Veteran',
          line: 'Is level ki hawa mein bhi? Full respect hai bhai.');
    default:
      return const AqiPersonality(
          emoji: '🦾',
          title: 'Iron Lungs',
          line: '400+ AQI. Not human. Pure Delhi machine.');
  }
}
