class OutfitTip {
  final String emoji;
  final String title;
  final String sub;
  const OutfitTip(
      {required this.emoji, required this.title, required this.sub});
}

const Map<String, OutfitTip> kOutfitTips = {
  'GOOD': OutfitTip(
    emoji: '👕',
    title: 'T-shirt mein niklo!',
    sub: 'Hawa saaf hai — bahar bhaago, enjoy karo!',
  ),
  'SATISFACTORY': OutfitTip(
    emoji: '🧣',
    title: 'Scarf ya light mask — optional.',
    sub: 'Bahar nikalna safe hai aaj. Hat bhi rakh lo.',
  ),
  'MODERATE': OutfitTip(
    emoji: '😷',
    title: 'Surgical mask pehno. Full sleeve better.',
    sub: 'Bahar zyaada der mat ruko. Andar aao jaldi.',
  ),
  'POOR': OutfitTip(
    emoji: '🥽',
    title: 'N95 + goggles. Poora dhakko.',
    sub: 'Kam samay bahar raho. Lungs protest kar rahe hain.',
  ),
  'VERY_POOR': OutfitTip(
    emoji: '🧪',
    title: 'Hazmat mode on karo.',
    sub: 'N95 + eye cover + gloves. Serious situation hai.',
  ),
  'SEVERE': OutfitTip(
    emoji: '🚀',
    title: 'Space suit chahiye bhai.',
    sub: 'Yaar ghar pe raho. Koi bhi reason kaafi nahi.',
  ),
};
