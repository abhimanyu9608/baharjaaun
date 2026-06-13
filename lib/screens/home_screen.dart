import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/aqi_category.dart';
import '../data/verdicts.dart';
import '../data/outfit_tips.dart';
import '../services/aqi_service.dart';
import '../services/location_service.dart';
import '../services/streak_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sky_particles.dart';
import '../widgets/mascot.dart';
import '../widgets/side_cast.dart';
import '../widgets/app_footer.dart';

const String _kSiteUrl = 'https://cipherabhi.com/bahar-jaaun';
const double _kMaxWidth = 600;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── live data ──────────────────────────────────────────────────────────────
  AqiResult? _result;
  bool _loading = true;
  String? _error;
  String _city = 'New Delhi';
  bool _isDefault = true;

  AqiCategory _liveCategory = kPoor;
  String _liveVerdict = '';

  // ── preview / rain state ───────────────────────────────────────────────────
  int? _previewIndex;   // null = show live data, 0-5 = preview that category
  bool _isRaining = false;
  String _previewVerdict = '';

  // ── daily engagement features ──────────────────────────────────────────────
  int _streakCount = 0;
  bool _isRashifal = false;
  ForecastResult? _forecast;
  String? _villainKey;

  // ── history & extras ───────────────────────────────────────────────────────
  List<int?> _weekHistory = [];
  int _daysSinceGood = -1;
  List<AreaAqi> _nearbyAreas = [];
  bool _shareToast = false;

  // ── derived display values ─────────────────────────────────────────────────
  AqiCategory get _cat =>
      _previewIndex != null ? kAllCategories[_previewIndex!] : _liveCategory;

  int get _aqi =>
      _previewIndex != null
          ? kAllCategories[_previewIndex!].sampleAqi
          : (_result?.aqi ?? 268);

  String get _verdict =>
      _previewIndex != null ? _previewVerdict : _liveVerdict;

  // ── entrance animation ─────────────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late Animation<double> _topFade;
  late Animation<Offset> _topSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _topFade = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _topSlide =
        Tween<Offset>(begin: const Offset(0, -0.18), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entranceCtrl,
                curve: const Interval(0.0, 0.6,
                    curve: Curves.easeOutBack)));

    _cardFade = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut));
    _cardSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entranceCtrl,
                curve: const Interval(0.2, 1.0,
                    curve: Curves.easeOutBack)));

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; _previewIndex = null; });
    try {
      final streak = await StreakService.checkAndUpdate();
      final loc = await LocationService.getLocation();
      final result = await AqiService.fetch(loc.lat, loc.lon)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _result = result;
        _city = result.city;
        _isDefault = loc.isDefault;
        _liveCategory = result.category;
        _liveVerdict = pickDailyVerdict(result.category);
        _isRashifal = true;
        _streakCount = streak.count;
        _villainKey = findVillainKey(result.components);
        _loading = false;
      });
      _loadForecast(loc.lat, loc.lon, result.aqi);
      _loadHistoryAndExtras(result.aqi, result.category.key);
      _loadNearbyAreas();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _liveVerdict = pickDailyVerdict(_liveCategory);
        _isRashifal = true;
      });
    }
    _entranceCtrl.forward(from: 0);
  }

  Future<void> _loadForecast(double lat, double lon, int todayAqi) async {
    try {
      final fc = await AqiService.fetchForecast(lat, lon, todayAqi);
      if (mounted && fc != null) setState(() => _forecast = fc);
    } catch (_) {}
  }

  Future<void> _loadHistoryAndExtras(int aqi, String catKey) async {
    await HistoryService.recordAqi(aqi, catKey);
    final history = await HistoryService.getLast7Days();
    final days = await HistoryService.daysSinceGood();
    if (mounted) {
      setState(() {
        _weekHistory = history;
        _daysSinceGood = days;
      });
    }
  }

  Future<void> _loadNearbyAreas() async {
    final areas = await AqiService.fetchNearbyAreas();
    if (mounted && areas.isNotEmpty) setState(() => _nearbyAreas = areas);
  }

  void _applyPreview(int i) {
    setState(() {
      _previewIndex = (_previewIndex == i) ? null : i;
      if (_previewIndex != null) {
        _previewVerdict = pickVerdict(kAllCategories[_previewIndex!]);
      }
    });
  }

  void _nextVerdict() {
    setState(() {
      _isRashifal = false;
      if (_previewIndex != null) {
        _previewVerdict = pickVerdict2(kAllCategories[_previewIndex!], _previewVerdict);
      } else {
        _liveVerdict = pickVerdict2(_liveCategory, _liveVerdict);
      }
    });
  }

  String _buildShareText() {
    final emoji = _cat.key == 'GOOD'
        ? '🌿'
        : _cat.key == 'SATISFACTORY'
            ? '😐'
            : _cat.key == 'MODERATE'
                ? '😷'
                : _cat.key == 'POOR'
                    ? '🤧'
                    : '☠️';
    return '$emoji Aaj Delhi ka AQI $_aqi hai — ${_cat.label.toUpperCase()}!\n\n'
        '"$_verdict"\n\n'
        'Bahar jaana chahiye? Check karo:\n$_kSiteUrl';
  }

  Future<void> _copyShare() async {
    await Clipboard.setData(ClipboardData(text: _buildShareText()));
    if (!mounted) return;
    setState(() => _shareToast = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _shareToast = false);
    });
  }

  Future<void> _whatsappShare() async {
    final text = _buildShareText();
    final wa = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(wa)) {
      await launchUrl(wa, mode: LaunchMode.externalApplication);
    }
  }

  // kept for legacy callers
  Future<void> _share() async => _whatsappShare();

  @override
  void dispose() { _entranceCtrl.dispose(); super.dispose(); }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cat.bgColor, _cat.bgDeepColor],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _loading
                  ? _buildLoading()
                  : _error != null && _result == null
                      ? _buildError()
                      : _buildContent(),
              IgnorePointer(child: _SideOrbs(
                category: _cat,
                aqi: _aqi,
                components: _previewIndex == null ? _result?.components : null,
                todayHours: _previewIndex == null
                    ? (_forecast?.todayHours ?? const [])
                    : const [],
              )),
              // Confetti when AQI is GOOD — rare event, celebrate it!
              if (_cat.key == 'GOOD' && !_loading)
                const IgnorePointer(child: _ConfettiOverlay()),
              // Copy-to-clipboard toast
              if (_shareToast)
                Positioned(
                  bottom: 32, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.darkInk,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text('📋 Copied! Paste karo WhatsApp mein',
                          style: AppTheme.fredoka(14,
                              color: Colors.white,
                              weight: FontWeight.w500)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading() => Center(child: _LoadingDots());

  // ── error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😶‍🌫️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x24000000), offset: Offset(0, 10), blurRadius: 0),
                ],
              ),
              child: Column(
                children: [
                  Text('API nahi chali', style: AppTheme.baloo2(22), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('OpenWeather key check karo ya net slow hai.',
                      style: AppTheme.fredoka(14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _HardButton(
              onPressed: _loadData,
              dark: true,
              bgColor: AppTheme.darkInk,
              fgColor: _cat.bgColor,
              child: Text('↻  Dobara try karo',
                  style: AppTheme.fredoka(15, color: _cat.bgColor,
                      weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── main content ───────────────────────────────────────────────────────────

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      color: _cat.bgColor,
      backgroundColor: AppTheme.cream,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  FadeTransition(
                    opacity: _topFade,
                    child: SlideTransition(
                      position: _topSlide,
                      child: _buildHeader(),
                    ),
                  ),

                  // Scene
                  FadeTransition(
                    opacity: _topFade,
                    child: _buildScene(),
                  ),

                  // AQI + cards + dots
                  FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAqiBlock(),
                          const SizedBox(height: 18),
                          _buildVerdictCard(),
                          const SizedBox(height: 12),
                          _buildActivityCard(),
                          if (_villainKey != null && _previewIndex == null) ...[
                            const SizedBox(height: 10),
                            _buildVillainCard(),
                          ],
                          if (_forecast != null && _previewIndex == null) ...[
                            const SizedBox(height: 12),
                            _buildForecastCard(),
                          ],
                          if (_forecast != null &&
                              (_forecast?.todayHours.length ?? 0) >= 3 &&
                              _previewIndex == null) ...[
                            const SizedBox(height: 12),
                            _buildSafeHoursCard(),
                          ],
                          // ── new feature cards ───────────────────────────
                          if (_previewIndex == null) ...[
                            const SizedBox(height: 12),
                            _buildShareRow(),
                            const SizedBox(height: 12),
                            _buildOutfitCard(),
                          ],
                          if (_weekHistory.any((v) => v != null)) ...[
                            const SizedBox(height: 12),
                            _buildSparklineCard(),
                          ],
                          if (_nearbyAreas.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildNeighborhoodCard(),
                          ],
                          const SizedBox(height: 14),
                          _buildButtons(),
                          const SizedBox(height: 22),
                          _buildAdSlot(),
                          const SizedBox(height: 30),
                          _buildScale(),
                          const SizedBox(height: 26),
                          _buildPreviewSection(),
                          const SizedBox(height: 28),
                          const AppFooter(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bahar Jaaun?',
                        style: AppTheme.baloo2(24,
                            color: AppTheme.darkInk, weight: FontWeight.w800)),
                    Text('DELHI · ROZ KA SACH',
                        style: AppTheme.mono(9,
                            color: AppTheme.darkInk.withValues(alpha: 0.6),
                            weight: FontWeight.w600)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _loadData,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.darkInk,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '📍 ${_isDefault ? 'New Delhi' : _city}',
                    style: AppTheme.mono(11,
                        color: _cat.bgColor, weight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (_streakCount > 0) ...[
            const SizedBox(height: 7),
            Row(children: [
              _StreakPill(count: _streakCount),
              if (_daysSinceGood > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🌿 ${_daysSinceGood}d bina saaf hawa ke',
                    style: AppTheme.mono(9,
                        color: Colors.white.withValues(alpha: 0.70),
                        weight: FontWeight.w600),
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  // ── scene ──────────────────────────────────────────────────────────────────

  Widget _buildScene() {
    return Container(
      height: 260,
      margin: const EdgeInsets.only(top: 6),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Sky tint
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent],
                ),
              ),
            ),
          ),

          // Particles / rain
          Positioned.fill(child: SkyParticles(category: _cat, isRaining: _isRaining)),

          // Sun
          if (_cat.isHot)
            const Positioned(top: 4, right: 18, child: _SpinningSun()),

          // Cloud
          const Positioned(top: 24, left: 0, child: _SlidingCloud()),

          // Delhi skyline silhouette (behind everything)
          Positioned(
            bottom: 14, left: 0, right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _DelhiSkylinePainter(
                color: Colors.black.withValues(alpha: 0.10 + _aqi / 600 * 0.14),
              ),
            ),
          ),

          // Ground arc
          Positioned(
            bottom: 0, left: -20, right: -20,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.13),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.elliptical(200, 42)),
              ),
            ),
          ),

          // Side cast
          Positioned.fill(child: SideCast(category: _cat)),

          // Main mascot
          Positioned(
            bottom: 14, left: 0, right: 0,
            child: Center(
              child: Mascot(category: _cat, isRaining: _isRaining),
            ),
          ),
        ],
      ),
    );
  }

  // ── AQI block ──────────────────────────────────────────────────────────────

  Widget _buildAqiBlock() {
    final showLive = _previewIndex == null && _result != null;
    return Column(
      children: [
        // Big number
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _aqi.toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (ctx2, val, ch2) => Text(
            '${val.round()}',
            textAlign: TextAlign.center,
            style: AppTheme.baloo2(58, color: AppTheme.darkInk, weight: FontWeight.w800).copyWith(
              shadows: const [Shadow(color: Color(0x1E000000), offset: Offset(0, 4))],
              height: 1,
            ),
          ),
        ),

        // "India AQI · CPCB Scale" subtitle
        Text(
          'INDIA AQI  ·  CPCB SCALE',
          style: AppTheme.mono(9,
              color: AppTheme.darkInk.withValues(alpha: 0.5),
              weight: FontWeight.w600)
              .copyWith(letterSpacing: 1.5),
        ),

        // Category pill
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(_cat.key),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.darkInk,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _cat.label.toUpperCase(),
              style: AppTheme.mono(13, color: _cat.bgColor, weight: FontWeight.w600)
                  .copyWith(letterSpacing: 1),
            ),
          ),
        ),

        // Stats pills row (live data only)
        if (showLive) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatPill(label: 'PM2.5', value: '${_result!.pm25.toStringAsFixed(1)} µg/m³'),
              if (_result!.tempCelsius != null)
                _StatPill(label: 'TEMP', value: '${_result!.tempCelsius!.toStringAsFixed(0)}°C'),
              if (_result!.windSpeed != null)
                _StatPill(label: '💨', value: '${(_result!.windSpeed! * 3.6).toStringAsFixed(0)} km/h'),
              if (_result!.humidity != null)
                _StatPill(label: '💧', value: '${_result!.humidity}%'),
            ],
          ),
        ],

        // Visual AQI bar
        const SizedBox(height: 14),
        _AqiBar(aqi: _aqi),

        // Cigarette equivalent (only when meaningfully elevated)
        if (showLive && _result!.pm25 > 22) ...[
          const SizedBox(height: 8),
          Text(
            '🚬 ≈ ${(_result!.pm25 / 22).toStringAsFixed(1)} cigarettes/day worth of exposure',
            textAlign: TextAlign.center,
            style: AppTheme.mono(9,
                    color: Colors.white.withValues(alpha: 0.55),
                    weight: FontWeight.w500)
                .copyWith(letterSpacing: 0.3),
          ),
        ],
      ],
    );
  }

  // ── verdict card ───────────────────────────────────────────────────────────

  Widget _buildVerdictCard() {
    final label = (_isRashifal && _previewIndex == null)
        ? 'Aaj ka air-rashifal 🔮'
        : 'Aaj ka faisla';
    return _VerdictCard(
      verdict: _verdict,
      healthFact: healthFact(_cat),
      label: label,
    );
  }

  // ── activity tips card ────────────────────────────────────────────────────

  Widget _buildActivityCard() {
    final tips = activityTips(_cat);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_cat.key),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KYA KARNA CHAHIYE? 🤔',
              style: AppTheme.mono(10,
                  color: AppTheme.darkInk.withValues(alpha: 0.5),
                  weight: FontWeight.w600)
                  .copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(tip,
                  style: AppTheme.fredoka(15,
                      color: AppTheme.darkInk,
                      weight: FontWeight.w500)),
            )),
          ],
        ),
      ),
    );
  }

  // ── villain of the day ────────────────────────────────────────────────────

  Widget _buildVillainCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_villainKey),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Text(
          villainLine(_villainKey!),
          style: AppTheme.fredoka(14, color: Colors.white, weight: FontWeight.w500)
              .copyWith(height: 1.3),
        ),
      ),
    );
  }

  // ── tomorrow's forecast card ───────────────────────────────────────────────

  Widget _buildForecastCard() {
    final fc = _forecast!;
    final catColor = fc.tomorrowCategory.bgColor;
    final line = pickForecastLine(fc.comparison);
    final arrowLabel = fc.comparison == 'WORSE'
        ? '↑ Worse than today'
        : fc.comparison == 'BETTER'
            ? '↓ Better than today'
            : '↔ Similar to today';
    final arrowColor = fc.comparison == 'WORSE'
        ? const Color(0xFFFF8A80)
        : fc.comparison == 'BETTER'
            ? const Color(0xFF80FFAA)
            : Colors.white.withValues(alpha: 0.45);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(fc.tomorrowAqi),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppTheme.darkInk,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: catColor.withValues(alpha: 0.28),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: catColor.withValues(alpha: 0.32),
              offset: const Offset(0, 8),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'KAL KA HAAL',
                  style: AppTheme.mono(10,
                          color: Colors.white.withValues(alpha: 0.5),
                          weight: FontWeight.w600)
                      .copyWith(letterSpacing: 2),
                ),
                const SizedBox(width: 8),
                const _PulseEmoji(emoji: '🔮'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fc.tomorrowAqi.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (ctx3, val, _) => Text(
                    '${val.round()}',
                    style: AppTheme.baloo2(40, color: catColor,
                            weight: FontWeight.w800)
                        .copyWith(height: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        fc.tomorrowCategory.label.toUpperCase(),
                        style: AppTheme.mono(10,
                                color: Colors.white, weight: FontWeight.w700)
                            .copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(arrowLabel,
                        style: AppTheme.mono(9,
                            color: arrowColor, weight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              line,
              style: AppTheme.fredoka(15,
                      color: Colors.white.withValues(alpha: 0.85))
                  .copyWith(height: 1.3),
            ),
            const SizedBox(height: 14),
            _AqiBar(aqi: fc.tomorrowAqi),
          ],
        ),
      ),
    );
  }

  // ── safe hours today ──────────────────────────────────────────────────────

  Widget _buildSafeHoursCard() {
    final hours = _forecast!.todayHours;
    final sorted = List.of(hours)..sort((a, b) => a.aqi.compareTo(b.aqi));
    final bestHour = sorted.first;
    final bestCat = categoryForAqi(bestHour.aqi);

    String fmt(int h) {
      if (h == 0) return '12am';
      if (h < 12) return '${h}am';
      if (h == 12) return '12pm';
      return '${h - 12}pm';
    }

    // Show every other hour if more than 10 entries
    final display = hours.length > 10
        ? hours.where((h) => h.hour % 2 == 0).toList()
        : hours;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AAJ KA SAFE TIME',
                style: AppTheme.mono(10,
                        color: AppTheme.darkInk.withValues(alpha: 0.5),
                        weight: FontWeight.w600)
                    .copyWith(letterSpacing: 2),
              ),
              const SizedBox(width: 6),
              const Text('⏰', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Best: ',
                  style: AppTheme.fredoka(14,
                      color: AppTheme.darkInk.withValues(alpha: 0.6)),
                ),
                TextSpan(
                  text: fmt(bestHour.hour),
                  style: AppTheme.baloo2(16,
                      color: bestCat.bgDeepColor, weight: FontWeight.w800),
                ),
                TextSpan(
                  text: '  AQI ${bestHour.aqi}',
                  style: AppTheme.mono(11,
                      color: AppTheme.darkInk.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Hourly colour bars
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: display.map((h) {
                final cat = categoryForAqi(h.aqi);
                final barH = ((h.aqi.clamp(0, 500) / 500) * 28 + 4).toDouble();
                final isBest = h.hour == bestHour.hour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isBest)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppTheme.darkInk,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: barH,
                          decoration: BoxDecoration(
                            color: isBest
                                ? cat.bgDeepColor
                                : cat.bgColor.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmt(h.hour),
                          style: AppTheme.mono(6,
                              color: isBest
                                  ? AppTheme.darkInk
                                  : AppTheme.darkInk.withValues(alpha: 0.4),
                              weight: isBest
                                  ? FontWeight.w700
                                  : FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── share row ─────────────────────────────────────────────────────────────

  Widget _buildShareRow() {
    return Row(children: [
      Expanded(
        child: _HardButton(
          onPressed: _copyShare,
          dark: false,
          bgColor: Colors.black.withValues(alpha: 0.18),
          fgColor: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📋', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text('Copy karo',
                  style: AppTheme.fredoka(14,
                      color: Colors.white, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _HardButton(
          onPressed: _whatsappShare,
          dark: false,
          bgColor: const Color(0xFF25D366).withValues(alpha: 0.85),
          fgColor: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💬', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text('WhatsApp',
                  style: AppTheme.fredoka(14,
                      color: Colors.white, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ]);
  }

  // ── outfit card ───────────────────────────────────────────────────────────

  Widget _buildOutfitCard() {
    final tip = kOutfitTips[_cat.key] ??
        kOutfitTips['MODERATE']!;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000),
              offset: Offset(0, 6),
              blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Text(tip.emoji,
              style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYA PEHNU AAJ? 👗',
                  style: AppTheme.mono(9,
                          color: AppTheme.darkInk.withValues(alpha: 0.45),
                          weight: FontWeight.w600)
                      .copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(tip.title,
                    style: AppTheme.fredoka(15,
                        color: AppTheme.darkInk,
                        weight: FontWeight.w600)),
                Text(tip.sub,
                    style: AppTheme.fredoka(13,
                        color: AppTheme.darkInk.withValues(alpha: 0.60),
                        weight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── weekly sparkline card ─────────────────────────────────────────────────

  Widget _buildSparklineCard() {
    final now = DateTime.now();
    final labels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return ['S', 'M', 'T', 'W', 'T', 'F', 'S'][d.weekday % 7];
    });
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.darkInk,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x2E000000),
              offset: Offset(0, 6),
              blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IS HAFTE KI KAHANI 📊',
            style: AppTheme.mono(9,
                    color: Colors.white.withValues(alpha: 0.45),
                    weight: FontWeight.w600)
                .copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: CustomPaint(
              size: const Size(double.infinity, 64),
              painter: _SparklinePainter(
                  values: _weekHistory, labels: labels),
            ),
          ),
        ],
      ),
    );
  }

  // ── neighborhood comparison card ──────────────────────────────────────────

  Widget _buildNeighborhoodCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000),
              offset: Offset(0, 6),
              blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELHI AREAS AAJKAL 🗺️',
            style: AppTheme.mono(9,
                    color: AppTheme.darkInk.withValues(alpha: 0.45),
                    weight: FontWeight.w600)
                .copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _nearbyAreas.map((area) {
              final color = area.category.bgColor;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: color.withValues(alpha: 0.50), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(area.name,
                        style: AppTheme.mono(10,
                            color: AppTheme.darkInk,
                            weight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Text('${area.aqi}',
                        style: AppTheme.mono(10,
                            color: AppTheme.darkInk.withValues(alpha: 0.65),
                            weight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── buttons ────────────────────────────────────────────────────────────────

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: _HardButton(
            onPressed: _nextVerdict,
            dark: true,
            bgColor: AppTheme.darkInk,
            fgColor: _cat.bgColor,
            child: Text('🎲 Aur sunao',
                style: AppTheme.fredoka(15,
                    color: _cat.bgColor, weight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HardButton(
            onPressed: _share,
            dark: false,
            bgColor: AppTheme.cream,
            fgColor: AppTheme.darkInk,
            child: Text('📤 Share',
                style: AppTheme.fredoka(15,
                    color: AppTheme.darkInk, weight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── ad slot ────────────────────────────────────────────────────────────────

  Widget _buildAdSlot() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
            style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'ADVERTISEMENT',
          style: AppTheme.mono(11,
              color: Colors.white.withValues(alpha: 0.7),
              weight: FontWeight.w600)
              .copyWith(letterSpacing: 2),
        ),
      ),
      // TODO: AdSense ad unit goes here
    );
  }

  // ── AQI scale ──────────────────────────────────────────────────────────────

  Widget _buildScale() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AQI ka matlab? 🌫️',
              style: AppTheme.baloo2(18, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...kAllCategories.map((cat) => _ScaleRow(cat: cat)),
        ],
      ),
    );
  }

  // ── preview section (rain toggle + dots) ───────────────────────────────────

  Widget _buildPreviewSection() {
    return Column(
      children: [
        // Rain toggle button
        _RainToggle(
          isOn: _isRaining,
          onTap: () => setState(() => _isRaining = !_isRaining),
        ),
        const SizedBox(height: 14),

        // Label
        Text(
          'TAP TO PREVIEW AIR STATES',
          style: AppTheme.mono(10,
              color: Colors.white.withValues(alpha: 0.75),
              weight: FontWeight.w600)
              .copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 9),

        // Color dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: kAllCategories.asMap().entries.map((e) {
            final i = e.key;
            final cat = e.value;
            final isOn = _previewIndex == i;
            return GestureDetector(
              onTap: () => _applyPreview(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4.5),
                width: isOn ? 39 : 34,
                height: isOn ? 39 : 34,
                decoration: BoxDecoration(
                  color: cat.bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.transparent, width: 0),
                ),
                child: AnimatedOpacity(
                  opacity: isOn ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // "tap dot again to return to live" hint when previewing
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _previewIndex != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: GestureDetector(
                    onTap: () => setState(() { _previewIndex = null; }),
                    child: Text(
                      '← back to live data',
                      style: AppTheme.mono(9,
                          color: Colors.white.withValues(alpha: 0.6),
                          weight: FontWeight.w600),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Rain toggle button ────────────────────────────────────────────────────────

class _RainToggle extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;
  const _RainToggle({required this.isOn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isOn ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(
          '🌧️  Toggle baarish',
          style: AppTheme.mono(10,
              color: isOn ? AppTheme.darkInk : Colors.white,
              weight: FontWeight.w600)
              .copyWith(letterSpacing: 1),
        ),
      ),
    );
  }
}

// ── Verdict card ──────────────────────────────────────────────────────────────

class _VerdictCard extends StatefulWidget {
  final String verdict;
  final String healthFact;
  final String label;
  const _VerdictCard({
    required this.verdict,
    required this.healthFact,
    required this.label,
  });

  @override
  State<_VerdictCard> createState() => _VerdictCardState();
}

class _VerdictCardState extends State<_VerdictCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  String _shown = '';

  @override
  void initState() {
    super.initState();
    _shown = widget.verdict;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_VerdictCard old) {
    super.didUpdateWidget(old);
    if (old.verdict != widget.verdict) {
      _ctrl.reverse().then((_) {
        if (mounted) { setState(() => _shown = widget.verdict); _ctrl.forward(); }
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 10), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label: "Aaj ka air-rashifal 🔮" on first open, else "Aaj ka faisla"
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.label,
              key: ValueKey(widget.label),
              style: AppTheme.mono(10,
                      color: AppTheme.darkInk.withValues(alpha: 0.5),
                      weight: FontWeight.w600)
                  .copyWith(letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 9),

          // Verdict line — Baloo 2 700 22px
          FadeTransition(
            opacity: _fade,
            child: Text(
              _shown,
              style: AppTheme.baloo2(22, weight: FontWeight.w700).copyWith(height: 1.3),
            ),
          ),

          // Dotted divider + health fact
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.darkInk.withValues(alpha: 0.15),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: Text(
              widget.healthFact,
              style: AppTheme.fredoka(14,
                  color: AppTheme.darkInk.withValues(alpha: 0.78)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hard-shadow neo-brutalist button ─────────────────────────────────────────

class _HardButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool dark;
  final Color bgColor;
  final Color fgColor;
  final Widget child;
  const _HardButton({
    required this.onPressed,
    required this.dark,
    required this.bgColor,
    required this.fgColor,
    required this.child,
  });

  @override
  State<_HardButton> createState() => _HardButtonState();
}

class _HardButtonState extends State<_HardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shadow = widget.dark
        ? const Color(0x4D000000)
        : const Color(0x2E000000);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onPressed(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed
              ? [BoxShadow(color: shadow, offset: const Offset(0, 1), blurRadius: 0)]
              : [BoxShadow(color: shadow, offset: const Offset(0, 5), blurRadius: 0)],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

// ── AQI scale row ─────────────────────────────────────────────────────────────

class _ScaleRow extends StatelessWidget {
  final AqiCategory cat;
  const _ScaleRow({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkInk.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            constraints: const BoxConstraints(minWidth: 56),
            decoration: BoxDecoration(
              color: cat.bgDeepColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${cat.min}–${cat.max}',
              textAlign: TextAlign.center,
              style: AppTheme.mono(11, color: Colors.white, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cat.label,
              style: AppTheme.fredoka(13, color: AppTheme.darkInk,
                  weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spinning sun ──────────────────────────────────────────────────────────────

class _SpinningSun extends StatefulWidget {
  const _SpinningSun();

  @override
  State<_SpinningSun> createState() => _SpinningSunState();
}

class _SpinningSunState extends State<_SpinningSun>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return _sun(0);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx2, ch2) => _sun(_ctrl.value * 2 * pi),
    );
  }

  Widget _sun(double angle) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.2),
          colors: [Color(0xFFFFE680), Color(0xFFFFB13B)],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x40FFDC78), blurRadius: 0, spreadRadius: 7),
          BoxShadow(color: Color(0x66FFC85A), blurRadius: 36),
        ],
      ),
    ),
  );
}

// ── Sliding cloud ─────────────────────────────────────────────────────────────

class _SlidingCloud extends StatefulWidget {
  const _SlidingCloud();

  @override
  State<_SlidingCloud> createState() => _SlidingCloudState();
}

class _SlidingCloudState extends State<_SlidingCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return _cloud(0.15);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx2, ch2) => _cloud(_ctrl.value),
    );
  }

  Widget _cloud(double t) {
    final w = MediaQuery.of(context).size.width.clamp(0.0, _kMaxWidth);
    return Transform.translate(
      offset: Offset(-120 + t * (w + 220), 0),
      child: SizedBox(
        width: 84,
        height: 26,
        child: CustomPaint(painter: _CloudPainter()),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 4, size.width, size.height - 4),
            const Radius.circular(40)), p);
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.25), 14, p);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.1), 11, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Side ambient orbs (desktop decoration) ───────────────────────────────────

class _SideOrbs extends StatefulWidget {
  final AqiCategory category;
  final int aqi;
  final AqiComponents? components;
  final List<HourlyForecast> todayHours;

  const _SideOrbs({
    required this.category,
    required this.aqi,
    this.components,
    this.todayHours = const [],
  });

  @override
  State<_SideOrbs> createState() => _SideOrbsState();
}

class _SideOrbsState extends State<_SideOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static final List<List<double>> _leftOrbData = [
    [0.25, 0.08, 55, 0.80, 10, 0.00],
    [0.78, 0.28, 30, 1.10, 6,  1.20],
    [0.12, 0.72, 70, 0.65, 14, 2.50],
    [0.82, 0.88, 22, 1.35, 4,  0.50],
  ];

  static final List<List<double>> _rightOrbData = [
    [0.60, 0.10, 48, 0.88, 11, 1.80],
    [0.88, 0.35, 24, 1.18, 7,  0.80],
    [0.15, 0.75, 36, 0.62, 9,  3.00],
    [0.70, 0.90, 58, 0.98, 13, 1.50],
  ];

  double get _anger {
    switch (widget.category.key) {
      case 'GOOD': return 0.0;
      case 'SATISFACTORY': return 0.15;
      case 'MODERATE': return 0.42;
      case 'POOR': return 0.65;
      case 'VERY_POOR': return 0.85;
      default: return 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final sideW = ((sz.width - _kMaxWidth) / 2).clamp(0.0, 500.0);
    if (sideW < 60) return const SizedBox.shrink();

    final pad = sideW * 0.12;
    final barW = sideW - pad * 2 - 36;
    final anger = _anger;

    String fmtHour(int h) {
      if (h == 0) return '12a';
      if (h < 12) return '${h}a';
      if (h == 12) return '12p';
      return '${h - 12}p';
    }

    final displayHours = widget.todayHours.length > 8
        ? widget.todayHours.where((h) => h.hour % 2 == 0).toList()
        : widget.todayHours;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx2, ch2) {
        final t = _ctrl.value;
        return Stack(children: [

          // ── Left background orbs ──────────────────────────────────────────
          ..._leftOrbData.map((o) {
            final dy = sin(t * 2 * pi * o[3] + o[5]) * o[4];
            return _orb(
              left: sideW * o[0] - o[2] / 2,
              top: sz.height * o[1] + dy - o[2] / 2,
              size: o[2],
              color: widget.category.bgDeepColor.withValues(alpha: 0.14),
            );
          }),

          // ── Left: "AQI" faint watermark ──────────────────────────────────
          Positioned(
            left: 0, width: sideW, top: sz.height * 0.03,
            child: Text('AQI',
                textAlign: TextAlign.center,
                style: AppTheme.baloo2(
                    (sideW * 0.40).clamp(28.0, 100.0),
                    color: Colors.white.withValues(alpha: 0.04),
                    weight: FontWeight.w900)),
          ),

          // ── Left: Pollutant bars ──────────────────────────────────────────
          if (widget.components != null && sideW >= 90)
            Positioned(
              left: 0, width: sideW, top: sz.height * 0.14,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('POLLUTANTS',
                        style: AppTheme.mono(7,
                            color: Colors.white.withValues(alpha: 0.35),
                            weight: FontWeight.w700)
                            .copyWith(letterSpacing: 2)),
                    const SizedBox(height: 10),
                    _pollBar('PM2.5', widget.components!.pm25, 60, barW),
                    _pollBar('PM10', widget.components!.pm10, 100, barW),
                    _pollBar('NO₂', widget.components!.no2, 80, barW),
                    _pollBar('O₃', widget.components!.o3, 100, barW),
                    _pollBar('SO₂', widget.components!.so2, 80, barW),
                  ],
                ),
              ),
            ),

          // ── Left: Smog Baba character ─────────────────────────────────────
          Positioned(
            left: 0, width: sideW,
            top: sz.height * (widget.components != null ? 0.50 : 0.30),
            child: Center(child: _buildSmogBaba(sideW, t, anger)),
          ),

          // ── Left: DELHI label ─────────────────────────────────────────────
          Positioned(
            left: 0, width: sideW, bottom: 32,
            child: Text('DELHI',
                textAlign: TextAlign.center,
                style: AppTheme.mono(9,
                    color: Colors.white.withValues(alpha: 0.18),
                    weight: FontWeight.w700)
                    .copyWith(letterSpacing: 4)),
          ),

          // ── Right background orbs ─────────────────────────────────────────
          ..._rightOrbData.map((o) {
            final dx = sz.width - sideW;
            final dy = sin(t * 2 * pi * o[3] + o[5]) * o[4];
            return _orb(
              left: dx + sideW * o[0] - o[2] / 2,
              top: sz.height * o[1] + dy - o[2] / 2,
              size: o[2],
              color: widget.category.bgColor.withValues(alpha: 0.12),
            );
          }),

          // ── Right: AQI number watermark ───────────────────────────────────
          Positioned(
            left: sz.width - sideW, width: sideW, top: sz.height * 0.03,
            child: Text('${widget.aqi}',
                textAlign: TextAlign.center,
                style: AppTheme.baloo2(
                    (sideW * 0.55).clamp(32.0, 130.0),
                    color: Colors.white.withValues(alpha: 0.04),
                    weight: FontWeight.w900)),
          ),

          // ── Right: Hourly forecast dots ───────────────────────────────────
          if (displayHours.isNotEmpty && sideW >= 90)
            Positioned(
              left: sz.width - sideW, width: sideW, top: sz.height * 0.14,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SAFE HOURS',
                        style: AppTheme.mono(7,
                            color: Colors.white.withValues(alpha: 0.35),
                            weight: FontWeight.w700)
                            .copyWith(letterSpacing: 2)),
                    const SizedBox(height: 10),
                    ...displayHours.take(8).map((h) {
                      final cat = categoryForAqi(h.aqi);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          SizedBox(
                            width: 22,
                            child: Text(fmtHour(h.hour),
                                style: AppTheme.mono(8,
                                    color: Colors.white.withValues(alpha: 0.50),
                                    weight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: cat.bgColor.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('${h.aqi}',
                              style: AppTheme.mono(8,
                                  color: Colors.white.withValues(alpha: 0.60),
                                  weight: FontWeight.w600)),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // ── Right: Lungs Ji character ─────────────────────────────────────
          Positioned(
            left: sz.width - sideW, width: sideW,
            top: sz.height * (displayHours.isNotEmpty ? 0.54 : 0.30),
            child: Center(child: _buildLungsJi(sideW, t, anger)),
          ),

          // ── Right: HAWA label ─────────────────────────────────────────────
          Positioned(
            left: sz.width - sideW, width: sideW, bottom: 32,
            child: Text('HAWA',
                textAlign: TextAlign.center,
                style: AppTheme.mono(9,
                    color: Colors.white.withValues(alpha: 0.18),
                    weight: FontWeight.w700)
                    .copyWith(letterSpacing: 4)),
          ),
        ]);
      },
    );
  }

  // ── Smog Baba ─────────────────────────────────────────────────────────────
  // Left character: cloud face that gets angrier as AQI worsens.
  // GOOD → sleeping (ZZZ). SEVERE → screaming + !!!

  Widget _buildSmogBaba(double sideW, double t, double anger) {
    final bob = sin(t * 2 * pi) * 7.0;
    final bodySize = (sideW * (0.42 + anger * 0.24)).clamp(44.0, 106.0);
    final bodyColor = widget.category.bgColor;
    final breatheScale = 1.0 +
        sin(t * 2 * pi * (1.8 + anger * 2.0)) * (0.04 + anger * 0.04);

    return Transform.translate(
      offset: Offset(0, bob),
      child: Transform.scale(
        scale: breatheScale,
        child: SizedBox(
          width: bodySize * 1.9,
          height: bodySize * 2.1,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Smoke puffs (moderate+)
              if (anger >= 0.40) ..._smokePuffs(t, bodySize, bodyColor, anger),

              // Body blob
              Container(
                width: bodySize, height: bodySize * 0.96,
                decoration: BoxDecoration(
                  color: bodyColor.withValues(alpha: 0.42 + anger * 0.42),
                  borderRadius: BorderRadius.circular(bodySize * 0.48),
                  boxShadow: anger > 0.25 ? [
                    BoxShadow(
                      color: bodyColor.withValues(alpha: anger * 0.50),
                      blurRadius: 6 + anger * 22,
                      spreadRadius: anger * 6,
                    ),
                  ] : null,
                ),
              ),

              // Angry brows (moderate+)
              if (anger >= 0.40)
                Positioned(
                  bottom: bodySize * 0.57,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _brow(bodySize * 0.20, true, anger),
                    SizedBox(width: bodySize * 0.22),
                    _brow(bodySize * 0.20, false, anger),
                  ]),
                ),

              // Eyes
              Positioned(
                bottom: bodySize * 0.44,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _eyeWidget(bodySize * 0.17,
                      sin(t * 2 * pi * 1.7) * 3.5, anger),
                  SizedBox(width: bodySize * 0.24),
                  _eyeWidget(bodySize * 0.17,
                      sin(t * 2 * pi * 1.7 + 0.6) * 3.5, anger),
                ]),
              ),

              // Mouth
              Positioned(
                bottom: bodySize * 0.14,
                child: _mouthWidget(bodySize * 0.42, anger),
              ),

              // ZZZ when GOOD
              if (anger < 0.10) ...[
                Positioned(
                  right: bodySize * 0.08, bottom: bodySize * 0.88,
                  child: Opacity(
                    opacity: (sin(t * 2 * pi) * 0.5 + 0.5),
                    child: Text('z', style: AppTheme.baloo2(
                        bodySize * 0.22,
                        color: Colors.white.withValues(alpha: 0.75),
                        weight: FontWeight.w700)),
                  ),
                ),
                Positioned(
                  right: bodySize * -0.02, bottom: bodySize * 1.06,
                  child: Opacity(
                    opacity: (sin(t * 2 * pi - 1.2) * 0.5 + 0.5),
                    child: Text('Z', style: AppTheme.baloo2(
                        bodySize * 0.30,
                        color: Colors.white.withValues(alpha: 0.60),
                        weight: FontWeight.w700)),
                  ),
                ),
              ],

              // !!! when SEVERE
              if (anger >= 0.95)
                Positioned(
                  bottom: bodySize * 1.02,
                  child: Text('!!!', style: AppTheme.baloo2(
                      bodySize * 0.28,
                      color: Colors.red.withValues(alpha: 0.90),
                      weight: FontWeight.w900)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _smokePuffs(
      double t, double bodySize, Color color, double anger) {
    return List.generate(3, (i) {
      final phase = (t + i / 3.0) % 1.0;
      final riseY = phase * bodySize * 1.35;
      final swayX = sin(phase * pi + i * 1.6) * bodySize * 0.22;
      final puffSize =
          bodySize * (0.13 + i * 0.06) * (1 - phase * 0.45);
      return Positioned(
        bottom: bodySize * 0.94 + riseY,
        left: bodySize * (0.22 + i * 0.24) + swayX,
        child: Opacity(
          opacity: ((1 - phase) * anger * 0.62).clamp(0.0, 1.0),
          child: Container(
            width: puffSize, height: puffSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
  }

  Widget _eyeWidget(double size, double pupilX, double anger) {
    if (anger >= 0.83) {
      return SizedBox(
        width: size, height: size,
        child: Center(child: Text('✕', style: TextStyle(
            color: Colors.white, fontSize: size * 0.88,
            fontWeight: FontWeight.w900, height: 1.0))),
      );
    }
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
          color: Colors.white, shape: BoxShape.circle),
      child: Stack(children: [
        Positioned(
          left: (size / 2 - size * 0.25) +
              pupilX.clamp(-size * 0.22, size * 0.22),
          top: size * 0.22,
          child: Container(
            width: size * 0.50, height: size * 0.50,
            decoration: BoxDecoration(
              color: anger > 0.55
                  ? const Color(0xFFBB1111)
                  : const Color(0xFF1A1A2E),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _brow(double w, bool isLeft, double anger) {
    return Transform.rotate(
      angle: isLeft ? -(anger - 0.3) * 0.55 : (anger - 0.3) * 0.55,
      child: Container(
        width: w,
        height: (w * 0.22).clamp(2.5, 8.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(w * 0.12),
        ),
      ),
    );
  }

  Widget _mouthWidget(double w, double anger) {
    if (anger >= 0.78) {
      return Container(
        width: w * 0.50, height: w * 0.42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(w * 0.22),
        ),
      );
    }
    final smiling = anger < 0.35;
    return ClipRect(
      child: Align(
        alignment: smiling ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: Container(
          width: w, height: w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.90), width: 3),
          ),
        ),
      ),
    );
  }

  // ── Lungs Ji ──────────────────────────────────────────────────────────────
  // Right character: two lungs with a face. Breathes, gets distressed.
  // GOOD → pink + heartbeat. SEVERE → gray + shaking + X eyes + 💨 wheeze.

  Widget _buildLungsJi(double sideW, double t, double anger) {
    final breathSpeed = 1.4 + anger * 2.2;
    final breathScale = 1.0 +
        sin(t * 2 * pi * breathSpeed) * (0.06 + anger * 0.05);
    final bob = sin(t * 2 * pi * 0.75 + 1.2) * 5.0;
    final sz = (sideW * 0.40).clamp(40.0, 88.0);

    final healthColor = Color.lerp(
      const Color(0xFFFF9FB2),
      const Color(0xFF9A9A9A),
      anger,
    )!;

    return Transform.translate(
      offset: Offset(0, bob),
      child: Transform.scale(
        scale: breathScale,
        child: SizedBox(
          width: sz * 2.7,
          height: sz * 1.9,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0, top: sz * 0.24,
                child: _lungShape(
                    sz * 0.92, sz * 1.12, healthColor, anger, t, true),
              ),
              Positioned(
                right: 0, top: sz * 0.24,
                child: _lungShape(
                    sz * 0.92, sz * 1.12, healthColor, anger, t, false),
              ),
              Positioned(
                top: 0,
                child: _lungFaceCircle(sz * 0.58, anger, t),
              ),
              if (anger >= 0.60) ..._wheezePuffs(t, sz, anger),
              if (anger < 0.18)
                Positioned(
                  bottom: 0,
                  child: Opacity(
                    opacity: (sin(t * 2 * pi * 2.4) * 0.5 + 0.5),
                    child: Text('♥', style: TextStyle(
                        color: Colors.pink.shade300,
                        fontSize: sz * 0.30)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lungShape(double w, double h, Color color,
      double anger, double t, bool isLeft) {
    final shakeX = anger > 0.78
        ? sin(t * 2 * pi * 10) * 2.8 * anger
        : 0.0;
    return Transform.translate(
      offset: Offset(isLeft ? -shakeX : shakeX, 0),
      child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.58 + anger * 0.12),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isLeft ? w * 0.72 : w * 0.22),
            topRight: Radius.circular(isLeft ? w * 0.22 : w * 0.72),
            bottomLeft: Radius.circular(w * 0.40),
            bottomRight: Radius.circular(w * 0.40),
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.30),
                blurRadius: 8, spreadRadius: 1),
          ],
        ),
      ),
    );
  }

  Widget _lungFaceCircle(double sz, double anger, double t) {
    final eyeX = sin(t * 2 * pi * 1.1) * 2.2;
    return Container(
      width: sz, height: sz,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6),
        ],
      ),
      child: Stack(alignment: Alignment.center, children: [
        if (anger >= 0.38)
          Positioned(
            top: sz * 0.16,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _brow(sz * 0.18, true, anger),
              SizedBox(width: sz * 0.16),
              _brow(sz * 0.18, false, anger),
            ]),
          ),
        Positioned(
          top: anger >= 0.38 ? sz * 0.32 : sz * 0.26,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _smallEye(sz * 0.16, eyeX, anger),
            SizedBox(width: sz * 0.14),
            _smallEye(sz * 0.16, -eyeX, anger),
          ]),
        ),
        if (anger > 0.32 && anger < 0.68)
          Positioned(
            right: sz * 0.10, top: sz * 0.18,
            child: _sweatDrop(sz * 0.11),
          ),
        Positioned(
          bottom: sz * 0.17,
          child: _mouthWidget(sz * 0.44, anger),
        ),
      ]),
    );
  }

  Widget _smallEye(double size, double eyeX, double anger) {
    if (anger >= 0.83) {
      return SizedBox(
        width: size, height: size,
        child: Center(child: Text('✕', style: TextStyle(
            color: Colors.grey.shade600, fontSize: size * 0.85,
            fontWeight: FontWeight.w900, height: 1.0))),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: anger > 0.55
            ? Colors.grey.shade700
            : const Color(0xFF1A1A2E),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _sweatDrop(double size) {
    return Container(
      width: size, height: size * 1.55,
      decoration: BoxDecoration(
        color: Colors.lightBlue.withValues(alpha: 0.65),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.5),
          topRight: Radius.circular(size * 0.5),
          bottomLeft: Radius.circular(size),
          bottomRight: Radius.circular(size),
        ),
      ),
    );
  }

  List<Widget> _wheezePuffs(double t, double sz, double anger) {
    return List.generate(3, (i) {
      final phase = (t * 1.3 + i / 3.0) % 1.0;
      return Positioned(
        right: sz * (0.52 + i * 0.10) +
            sin(t * 2 * pi * 2.2 + i) * sz * 0.10,
        top: sz * 0.25 + (1 - phase) * sz * 0.55,
        child: Opacity(
          opacity: ((1 - phase) * anger * 0.75).clamp(0.0, 1.0),
          child: Text('💨',
              style: TextStyle(fontSize: sz * (0.14 + i * 0.04))),
        ),
      );
    });
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _pollBar(String label, double value, double threshold, double maxW) {
    final ratio = (value / threshold).clamp(0.0, 3.0);
    final fillW = ((ratio / 3.0) * maxW).clamp(3.0, maxW);
    final color = ratio < 1.0
        ? const Color(0xFF46C07A)
        : ratio < 2.0
            ? const Color(0xFFE8C23A)
            : const Color(0xFFD65A32);

    final displayVal = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : value.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text(label,
              style: AppTheme.mono(7,
                  color: Colors.white.withValues(alpha: 0.52),
                  weight: FontWeight.w600)),
        ),
        Expanded(
          child: Stack(children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              width: fillW, height: 5,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 5),
        Text(displayVal,
            style: AppTheme.mono(7,
                color: Colors.white.withValues(alpha: 0.55),
                weight: FontWeight.w600)),
      ]),
    );
  }

  Widget _orb({required double left, required double top,
      required double size, required Color color}) {
    return Positioned(
      left: left, top: top,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Delhi skyline painter ────────────────────────────────────────────────────

class _DelhiSkylinePainter extends CustomPainter {
  final Color color;
  const _DelhiSkylinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Building silhouettes from left to right
    final path = Path();
    path.moveTo(0, h);

    // Left cluster of buildings
    _rect(path, w * 0.00, h, w * 0.06, h * 0.55);
    _rect(path, w * 0.06, h, w * 0.10, h * 0.35);
    _rect(path, w * 0.10, h, w * 0.15, h * 0.65);

    // India Gate arch (center-left)
    final gateX = w * 0.28;
    path.lineTo(gateX - w * 0.05, h);
    path.lineTo(gateX - w * 0.05, h * 0.42);
    path.lineTo(gateX - w * 0.03, h * 0.42);
    // arch
    path.arcToPoint(
      Offset(gateX + w * 0.03, h * 0.42),
      radius: Radius.circular(w * 0.035),
      clockwise: false,
    );
    path.lineTo(gateX + w * 0.05, h * 0.42);
    path.lineTo(gateX + w * 0.05, h);

    // Mid buildings
    _rect(path, w * 0.38, h, w * 0.42, h * 0.50);
    _rect(path, w * 0.42, h, w * 0.47, h * 0.70);

    // Qutub Minar (center-right) — tall tapered tower
    final minarX = w * 0.60;
    path.lineTo(minarX - w * 0.015, h);
    path.lineTo(minarX - w * 0.012, h * 0.55);
    path.lineTo(minarX - w * 0.008, h * 0.30);
    path.lineTo(minarX - w * 0.005, h * 0.12);
    // top bulge
    path.quadraticBezierTo(minarX, h * 0.06, minarX + w * 0.005, h * 0.12);
    path.lineTo(minarX + w * 0.008, h * 0.30);
    path.lineTo(minarX + w * 0.012, h * 0.55);
    path.lineTo(minarX + w * 0.015, h);

    // Right cluster
    _rect(path, w * 0.68, h, w * 0.74, h * 0.45);
    _rect(path, w * 0.74, h, w * 0.80, h * 0.60);
    _rect(path, w * 0.80, h, w * 0.86, h * 0.38);
    _rect(path, w * 0.86, h, w * 0.92, h * 0.58);
    _rect(path, w * 0.92, h, w * 1.00, h * 0.48);

    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, p);
  }

  void _rect(Path path, double x1, double bottom, double x2, double top) {
    path.lineTo(x1, bottom);
    path.lineTo(x1, top);
    path.lineTo(x2, top);
    path.lineTo(x2, bottom);
  }

  @override
  bool shouldRepaint(_DelhiSkylinePainter old) => old.color != color;
}

// ── Weekly sparkline painter ──────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<int?> values;
  final List<String> labels;
  const _SparklinePainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxAqi = values.whereType<int>().fold(0, max).toDouble();
    final displayMax = maxAqi < 100 ? 100.0 : maxAqi * 1.15;

    final barW = size.width / values.length;
    final barZone = size.height - 18; // leave space for labels

    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final cx = barW * i + barW / 2;

      // Label
      final lbl = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 9,
              fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lbl.paint(canvas,
          Offset(cx - lbl.width / 2, size.height - lbl.height));

      if (v == null) continue;

      final frac = (v / displayMax).clamp(0.04, 1.0);
      final barH = frac * barZone;
      final top = barZone - barH;

      final color = v < 100
          ? const Color(0xFF46C07A)
          : v < 200
              ? const Color(0xFFE8C23A)
              : v < 300
                  ? const Color(0xFFE07840)
                  : const Color(0xFFCC3333);

      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW * 0.28, top, barW * 0.56, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(
          rr, Paint()..color = color.withValues(alpha: 0.75)..style = PaintingStyle.fill);

      // AQI label on bar
      final valLbl = TextPainter(
        text: TextSpan(
          text: '$v',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 8,
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (barH > 16) {
        valLbl.paint(canvas, Offset(cx - valLbl.width / 2, top + 3));
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

// ── Confetti overlay ─────────────────────────────────────────────────────────

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ConfettiPiece> _pieces;

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF9671),
    Color(0xFFC77DFF),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    final rng = Random();
    _pieces = List.generate(45, (i) => _ConfettiPiece(
      x: rng.nextDouble(),
      phase: rng.nextDouble(),
      speed: 0.14 + rng.nextDouble() * 0.22,
      size: 5 + rng.nextDouble() * 7,
      color: _colors[rng.nextInt(_colors.length)],
      rotation: rng.nextDouble(),
      wide: rng.nextBool(),
    ));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;
        return Stack(
          children: _pieces.map((p) {
            final phase = (t * p.speed + p.phase) % 1.0;
            final y = phase;
            final swayX = sin(phase * 2 * pi * 2.2 + p.phase * 7) * 0.035;
            final opacity = y > 0.80
                ? (1 - (y - 0.80) / 0.20).clamp(0.0, 1.0)
                : 1.0;
            return Positioned(
              left: ((p.x + swayX).clamp(0.0, 0.98)) * sz.width,
              top: y * sz.height,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: phase * 2 * pi * p.rotation * 3,
                  child: Container(
                    width: p.wide ? p.size * 1.8 : p.size,
                    height: p.wide ? p.size * 0.5 : p.size,
                    decoration: BoxDecoration(
                      color: p.color.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(p.size * 0.2),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ConfettiPiece {
  final double x, phase, speed, size, rotation;
  final Color color;
  final bool wide;
  const _ConfettiPiece({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.wide,
  });
}

// ── Stat pill (PM2.5, temp) ───────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: AppTheme.mono(9,
                  color: Colors.white.withValues(alpha: 0.6),
                  weight: FontWeight.w600)
                  .copyWith(letterSpacing: 1),
            ),
            TextSpan(
              text: value,
              style: AppTheme.mono(11,
                  color: Colors.white,
                  weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AQI gradient bar (0–500 with position marker) ────────────────────────────

class _AqiBar extends StatelessWidget {
  final int aqi;
  const _AqiBar({required this.aqi});

  static const _segments = [
    (flex: 1, color: Color(0xFF46C07A)),   // Good      0–50
    (flex: 1, color: Color(0xFFB9C64A)),   // Satisfactory 51–100
    (flex: 2, color: Color(0xFFE8C23A)),   // Moderate 101–200
    (flex: 2, color: Color(0xFFE8923A)),   // Poor     201–300
    (flex: 2, color: Color(0xFFD65A32)),   // Very Poor 301–400
    (flex: 2, color: Color(0xFFA23350)),   // Severe   401–500
  ];

  @override
  Widget build(BuildContext context) {
    final pct = (aqi.clamp(0, 500) / 500);
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final markerLeft = (pct * w - 7).clamp(0.0, w - 14);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Colored gradient segments
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: _segments
                        .map((s) => Expanded(
                              flex: s.flex,
                              child: Container(color: s.color),
                            ))
                        .toList(),
                  ),
                ),
              ),
              // White position marker
              Positioned(
                left: markerLeft,
                top: -4,
                child: Container(
                  width: 14,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0',
                  style: AppTheme.mono(8,
                      color: Colors.white.withValues(alpha: 0.5))),
              Text('AQI SCALE',
                  style: AppTheme.mono(8,
                      color: Colors.white.withValues(alpha: 0.45))
                      .copyWith(letterSpacing: 1)),
              Text('500',
                  style: AppTheme.mono(8,
                      color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
        ],
      );
    });
  }
}

// ── Streak pill (🔥 n din) ────────────────────────────────────────────────────

class _StreakPill extends StatefulWidget {
  final int count;
  const _StreakPill({required this.count});

  @override
  State<_StreakPill> createState() => _StreakPillState();
}

class _StreakPillState extends State<_StreakPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return const SizedBox.shrink();
    final isMilestone = kStreakMilestones.containsKey(widget.count);

    return ScaleTransition(
      scale: _scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: isMilestone
                  ? const Color(0xFFFF6B35)
                  : Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Text(
              '🔥 ${widget.count} din',
              style: AppTheme.mono(10,
                  color: Colors.white, weight: FontWeight.w700),
            ),
          ),
          if (isMilestone) ...[
            const SizedBox(height: 3),
            Text(
              kStreakMilestones[widget.count]!,
              style: AppTheme.fredoka(11,
                  color: Colors.white.withValues(alpha: 0.75),
                  weight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pulsing emoji (used for 🔮 in forecast card) ──────────────────────────────

class _PulseEmoji extends StatefulWidget {
  final String emoji;
  const _PulseEmoji({required this.emoji});

  @override
  State<_PulseEmoji> createState() => _PulseEmojiState();
}

class _PulseEmojiState extends State<_PulseEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(widget.emoji, style: const TextStyle(fontSize: 15));
    }
    return ScaleTransition(
      scale: _scale,
      child: Text(widget.emoji, style: const TextStyle(fontSize: 15)),
    );
  }
}

// ── Loading dots ──────────────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('😶‍🌫️', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx2, ch2) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final t = ((_ctrl.value - i / 3) % 1.0).clamp(0.0, 1.0);
              final s = 0.5 + sin(t * pi) * 0.5;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 10, height: 10,
                transform: Matrix4.translationValues(0, -s * 7, 0),
                decoration: BoxDecoration(
                  color: AppTheme.darkInk.withValues(alpha: 0.3 + s * 0.7),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        Text('Hawa check ho rahi hai…',
            style: AppTheme.fredoka(16,
                color: AppTheme.darkInk.withValues(alpha: 0.65))),
      ],
    );
  }
}
