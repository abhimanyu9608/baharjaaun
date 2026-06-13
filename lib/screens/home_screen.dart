import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/aqi_category.dart';
import '../data/verdicts.dart';
import '../services/aqi_service.dart';
import '../services/location_service.dart';
import '../services/streak_service.dart';
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

  Future<void> _share() async {
    final text = '$_verdict — AQI $_aqi (${_cat.label}) $_city. $_kSiteUrl';
    try { await Clipboard.setData(ClipboardData(text: text)); } catch (_) {}
    final wa = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(wa)) {
      await launchUrl(wa, mode: LaunchMode.externalApplication);
    }
  }

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
              IgnorePointer(child: _SideOrbs(category: _cat, aqi: _aqi)),
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
            Align(
              alignment: Alignment.centerLeft,
              child: _StreakPill(count: _streakCount),
            ),
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

        // PM2.5 + temp row (live data only)
        if (showLive) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(
                  label: 'PM2.5',
                  value: '${_result!.pm25.toStringAsFixed(1)} µg/m³'),
              const SizedBox(width: 8),
              if (_result!.tempCelsius != null)
                _StatPill(
                    label: 'TEMP',
                    value: '${_result!.tempCelsius!.toStringAsFixed(0)}°C'),
            ],
          ),
        ],

        // Visual AQI bar
        const SizedBox(height: 14),
        _AqiBar(aqi: _aqi),
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
  const _SideOrbs({required this.category, required this.aqi});

  @override
  State<_SideOrbs> createState() => _SideOrbsState();
}

class _SideOrbsState extends State<_SideOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // [left_frac, top_frac, size, speed, amplitude, phase]
  static final List<List<double>> _leftOrbData = [
    [0.30, 0.10, 88, 0.80, 12, 0.00],
    [0.72, 0.27, 40, 1.10, 7,  1.20],
    [0.18, 0.50, 108, 0.65, 16, 2.50],
    [0.78, 0.70, 30, 1.35, 5,  0.50],
    [0.45, 0.85, 62, 0.90, 11, 3.10],
  ];

  static final List<List<double>> _rightOrbData = [
    [0.55, 0.15, 72, 0.88, 13, 1.80],
    [0.82, 0.36, 36, 1.18, 8,  0.80],
    [0.20, 0.58, 52, 0.62, 10, 3.00],
    [0.60, 0.76, 84, 0.98, 15, 1.50],
    [0.35, 0.91, 34, 1.42, 6,  2.20],
  ];

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

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx2, ch2) {
        final t = _ctrl.value;
        return Stack(children: [
          // Left: "AQI" watermark
          Positioned(
            left: 0, width: sideW, top: sz.height * 0.05,
            child: Text('AQI',
                textAlign: TextAlign.center,
                style: AppTheme.baloo2(
                    (sideW * 0.45).clamp(32.0, 120.0),
                    color: Colors.white.withValues(alpha: 0.07),
                    weight: FontWeight.w900)),
          ),
          // Left: "DELHI" label
          Positioned(
            left: 0, width: sideW, bottom: 40,
            child: Text('DELHI',
                textAlign: TextAlign.center,
                style: AppTheme.mono(10,
                    color: Colors.white.withValues(alpha: 0.20),
                    weight: FontWeight.w700)
                    .copyWith(letterSpacing: 4)),
          ),
          // Left orbs
          ..._leftOrbData.map((o) {
            final dy = sin(t * 2 * pi * o[3] + o[5]) * o[4];
            return _orb(
              left: sideW * o[0] - o[2] / 2,
              top: sz.height * o[1] + dy - o[2] / 2,
              size: o[2],
              color: widget.category.bgDeepColor.withValues(alpha: 0.22),
            );
          }),
          // Right: AQI number watermark
          Positioned(
            left: sz.width - sideW, width: sideW, top: sz.height * 0.04,
            child: Text('${widget.aqi}',
                textAlign: TextAlign.center,
                style: AppTheme.baloo2(
                    (sideW * 0.60).clamp(36.0, 140.0),
                    color: Colors.white.withValues(alpha: 0.06),
                    weight: FontWeight.w900)),
          ),
          // Right: "HAWA" label
          Positioned(
            left: sz.width - sideW, width: sideW, bottom: 40,
            child: Text('HAWA',
                textAlign: TextAlign.center,
                style: AppTheme.mono(10,
                    color: Colors.white.withValues(alpha: 0.20),
                    weight: FontWeight.w700)
                    .copyWith(letterSpacing: 4)),
          ),
          // Right orbs
          ..._rightOrbData.map((o) {
            final dx = sz.width - sideW;
            final dy = sin(t * 2 * pi * o[3] + o[5]) * o[4];
            return _orb(
              left: dx + sideW * o[0] - o[2] / 2,
              top: sz.height * o[1] + dy - o[2] / 2,
              size: o[2],
              color: widget.category.bgColor.withValues(alpha: 0.18),
            );
          }),
        ]);
      },
    );
  }

  Widget _orb({
    required double left,
    required double top,
    required double size,
    required Color color,
  }) {
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
