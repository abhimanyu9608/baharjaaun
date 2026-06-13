import 'dart:math';
import '../models/aqi_category.dart';

// TODO: add ~10 lines per category total for variety
const Map<String, List<String>> kVerdicts = {
  'GOOD': [
    'Hawa actually saaf hai aaj! Screenshot le lo, ye roz nahi hota. Bahar bhaago!',
    'AQI itna kam? Lag raha hai Delhi nahi, koi hill station hai.',
    'Deep breath lene ka full paisa vasool din. Jeeyo, bahar jaao.',
    'Aaj ki hawa certified fresh! Park mein jaao, dost ko call karo.',
    'Yaar, aaj bahar nahi gaya toh pachtaoge. Seriously jaao.',
  ],
  'SATISFACTORY': [
    'Theek-thaak hai. Mast nahi, par marne wala bhi nahi. Nikal jaao.',
    'Aaj ki hawa: passing marks. Chal jayega.',
    'Not great, not terrible. Dilli standard se toh bilkul theek hai.',
    'Jaa sakte ho. Mask optional, attitude mandatory.',
  ],
  'MODERATE': [
    "Hawa 'thodi kharab' — matlab Delhi ke hisaab se normal. Mask rakh lo.",
    'Mask optional hai, par ego pe mat lena. Pehen lo.',
    'Thoda smog hai. Sunglasses aur mask dono kaam aayenge.',
    'Bahar jao par zyaada gehri saans mat lo. Samjhe?',
  ],
  'POOR': [
    'AQI 250+? Tumhare lungs ne resignation letter type kar diya. Ghar pe raho.',
    'Bahar jaana hai? Pehle phephdo se permission le lo.',
    'Aaj ki hawa free cigarette ke barabar. Smoker bano bina smoke kiye.',
    'N95 pehno ya sofa pe baitho. Beech ka raasta nahi hai.',
    'Ghar pe chai piyo. Hawa ne aaj aapko gift nahi diya.',
  ],
  'VERY_POOR': [
    'Khidki band karo. Bahar Delhi nahi, gas chamber hai. Maggi banao, andar raho.',
    'AQI itna high ki air purifier ne bhi haath khade kar diye.',
    'Bahar jaana = ek ghante mein 10 cigarette peena. Socho.',
    'Aaj ke liye plan: Netflix, chai, aur khidki band.',
  ],
  'SEVERE': [
    'AQI 400 paar! Ye air nahi, soup hai. Bahar mat nikalna.',
    'Mars pe rover bhej do, par Delhi ki hawa nahi sudhregi.',
    'Emergency level. Seriously. Ghar mein raho. Ye maza nahi, warning hai.',
    'Aaj bahar nikalna = direct pulmonologist appointment book karna.',
  ],
};

const Map<String, String> kHealthFacts = {
  'GOOD': 'Hawa saaf. Bahar nikalne ka perfect din.',
  'SATISFACTORY': 'Zyaadatar logon ke liye theek. Sensitive logon ko halki dikkat.',
  'MODERATE': 'Asthma/heart walon ko dikkat ho sakti hai. Baaki dhyaan se.',
  'POOR': 'Saans mein dikkat ho sakti hai. Lambi outdoor activity avoid karo.',
  'VERY_POOR': 'Sabko saans ki problem ho sakti hai. Bahar minimum rakho.',
  'SEVERE': 'Emergency level. Healthy logon ko bhi serious asar. Bahar mat jaao.',
};

final _random = Random();

String pickVerdict(AqiCategory cat) {
  final lines = kVerdicts[cat.key] ?? ['Hawa ka haal theek nahi.'];
  return lines[_random.nextInt(lines.length)];
}

String pickVerdict2(AqiCategory cat, String current) {
  final lines = kVerdicts[cat.key] ?? ['Hawa ka haal theek nahi.'];
  if (lines.length == 1) return lines[0];
  String next;
  do {
    next = lines[_random.nextInt(lines.length)];
  } while (next == current);
  return next;
}

String healthFact(AqiCategory cat) =>
    kHealthFacts[cat.key] ?? 'Data available nahi hai.';

const Map<String, List<String>> kActivityTips = {
  'GOOD': [
    '🏃 Subah ki jogging ke liye perfect time',
    '🪟 Khidkiyaan kholo, taazi hawa aane do',
    '🌿 Bachche bahar khel sakte hain bejhijhak',
    '☕ Terrace pe chai ka maza lo aaj',
  ],
  'SATISFACTORY': [
    '🚶 Bahar jaana bilkul theek hai aaj',
    '🤸 Exercise theek hai, zyada intense mat karo',
    '😷 Sensitive log chahein toh mask rakh sakte hain',
    '🪟 Ventilation achhi hai, fresh air enjoy karo',
  ],
  'MODERATE': [
    '😷 Bahar jaate waqt mask pehno zaroor',
    '🏃 Heavy outdoor exercise avoid karo',
    '🏠 Asthma / heart patients ghar pe rahein',
    '🌱 Ghar mein indoor plants lagao, thoda fark padta hai',
  ],
  'POOR': [
    '🏠 Ghar mein rehna behtar hai aaj',
    '😷 Bahar jaana ho toh N95 mask mandatory hai',
    '🚫 Outdoor exercise bilkul mat karo',
    '💨 Air purifier chalao ghar mein',
  ],
  'VERY_POOR': [
    '🚨 Bahar jaana jitna ho sake avoid karo',
    '👴 Buzurg aur bachche ghar se bilkul mat niklein',
    '🪟 Khidkiyaan band rakho, cracks seal karo',
    '🏥 Saans mein dikkat aaye toh turant doctor se milo',
  ],
  'SEVERE': [
    '🆘 Aaj ghar se mat niklo — emergency jaisi situation',
    '🪟 Khidkiyaan aur darwaaze sealed band rakho',
    '😷 Nikalna absolutely zaroori ho toh N95 + eye cover',
    '📵 Jogging, cycling, bahar kuch bhi — bilkul nahi aaj',
  ],
};

List<String> activityTips(AqiCategory cat) =>
    kActivityTips[cat.key] ?? ['Hawa ke hisaab se dhyaan se rahein.'];

// ── Forecast comparison lines ─────────────────────────────────────────────────

const Map<String, List<String>> kForecastLines = {
  'WORSE': [
    'Kal aur kharab hoga — aaj hi ghoom lo.',
    'Kal hawa aur bigdegi. Aaj bahar jaana smart move hai.',
    'Kal ke liye N95 taiyaar rakh lo bhai.',
    'Tomorrow? Downgrade confirmed. Aaj agar nikalna ho toh niklo.',
    'Kal toh andar raho. Aaj ka maza lo.',
  ],
  'BETTER': [
    'Kal thodi saans le paaoge. Kal ka plan banao.',
    'Good news: kal hawa theek hogi. Kal enjoy karo.',
    'Kal better rahega! Aaj indoor, kal outdoor.',
    'Kal thodi rahat milegi. Hold on, wait karo.',
    'Aane wala kal thoda meherbaan lagta hai. Kal niklo.',
  ],
  'SIMILAR': [
    'Kal bhi wahi kahani. Delhi consistent hai, kharab mein.',
    'Koi khaas fark nahi — yahi Delhi ka "normal" hai.',
    'Kal bhi same scene. Mask aur chai ready rakh.',
    'Consistency! (buri wali). Kal bhi aaj jaisi hawa.',
    'Delhi ka charm: kal bhi same hoga. Adjust kar lo.',
  ],
};

// ── Villain lines per pollutant ───────────────────────────────────────────────

const Map<String, String> kVillainLines = {
  'PM2.5': '🦹 Aaj ka villain: PM2.5 — chhupa rustam, seedha lungs mein ghusega. Mask must.',
  'PM10': '💨 Aaj ka villain: PM10 — dhool ka daitya haazir! Naak aur mooh dhak lo.',
  'NO2': '🚗 Aaj ka villain: NO2 — traffic ka kaala tohfa. Sadak se door raho.',
  'O3': '🌫️ Aaj ka villain: Ozone — dhoop mein chhupa khatarnak. Dopahar bahar mat jao.',
  'SO2': '🏭 Aaj ka villain: SO2 — factory ka kaala jaadu. Andar raho yaar.',
  'CO': '🔥 Aaj ka villain: CO — dikhta nahi, par nuksaan karta hai. Hawa aane do.',
  'NH3': '🌾 Aaj ka villain: Ammonia — khet se city tak pahuncha. Khidki band karo.',
};

// ── Streak milestone messages ─────────────────────────────────────────────────

const Map<int, String> kStreakMilestones = {
  3: 'Teen din! Hawa ka hisaab rakh rahe ho 🔥',
  7: 'Ek hafta! Asli Dilliwale ho tum 🏆',
  14: 'Do hafte! Delhi ka pakka hawa-tracker 💪',
  30: 'Poora mahina! Legend. Salute! 🫡',
};

// ── Date-seeded daily verdict (stable all day, changes at midnight) ────────────

String pickDailyVerdict(AqiCategory cat) {
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day;
  final lines = kVerdicts[cat.key] ?? ['Hawa ka haal theek nahi.'];
  return lines[seed % lines.length];
}

String pickForecastLine(String comparison) {
  final lines = kForecastLines[comparison] ?? kForecastLines['SIMILAR']!;
  return lines[_random.nextInt(lines.length)];
}

String villainLine(String key) =>
    kVillainLines[key] ?? '🌫️ Hawa mein kuch theek nahi aaj.';
