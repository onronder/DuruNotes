import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // TODO: Add dependency
import 'package:shared_preferences/shared_preferences.dart';

/// Modern onboarding screen with gradient design and smooth animations
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Onboarding pages data
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Duru Notes',
      subtitle: 'Your intelligent note-taking companion',
      description:
          'Capture thoughts, organize ideas, and boost your productivity with AI-powered features',
      icon: CupertinoIcons.sparkles,
      gradientColors: [
        const Color(0xFF048ABF),
        const Color(0xFF5FD0CB),
      ],
      features: [
        'Smart note organization',
        'Advanced reminders',
        'Cross-platform sync',
      ],
    ),
    OnboardingPage(
      title: 'AI-Powered Intelligence',
      subtitle: 'Let AI enhance your productivity',
      description:
          'Experience semantic search, smart suggestions, and intelligent task extraction',
      icon: CupertinoIcons.lightbulb,
      gradientColors: [
        const Color(0xFF9333EA),
        const Color(0xFF3B82F6),
      ],
      features: [
        'Semantic search',
        'Smart suggestions',
        'Auto-categorization',
      ],
    ),
    OnboardingPage(
      title: 'Advanced Task Management',
      subtitle: 'Never miss what matters',
      description:
          'Create tasks from notes, set location-based reminders, and track your productivity',
      icon: CupertinoIcons.checkmark_shield_fill,
      gradientColors: [
        const Color(0xFF10B981),
        const Color(0xFF3B82F6),
      ],
      features: [
        'Task extraction from notes',
        'Location reminders',
        'Productivity analytics',
      ],
    ),
    OnboardingPage(
      title: 'Your Privacy Matters',
      subtitle: 'Security you can trust',
      description:
          'End-to-end encryption, on-device AI processing, and complete data control',
      icon: CupertinoIcons.lock_shield_fill,
      gradientColors: [
        const Color(0xFFEF4444),
        const Color(0xFFF59E0B),
      ],
      features: [
        'End-to-end encryption',
        'On-device AI',
        'Private by design',
      ],
    ),
    OnboardingPage(
      title: 'Ready to Begin?',
      subtitle: "Let's set up your workspace",
      description:
          'Personalize your experience and start your productivity journey',
      icon: CupertinoIcons.rocket_fill,
      gradientColors: [
        const Color(0xFF048ABF),
        const Color(0xFF9333EA),
      ],
      features: [
        'Personalized setup',
        'Import existing notes',
        'Choose your theme',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Skip Setup?'),
        content: const Text(
          'You can always access these features later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeOnboarding();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_currentPage].gradientColors[0].withValues(alpha: 0.1),
                  _pages[_currentPage].gradientColors[1].withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                if (_currentPage < _pages.length - 1)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      HapticFeedback.lightImpact();
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon with gradient background
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: page.gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: page.gradientColors[0]
                                            .withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    page.icon,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 32.0),

                                // Title
                                Text(
                                  page.title,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8.0),

                                // Subtitle
                                Text(
                                  page.subtitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: page.gradientColors[0],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24.0),

                                // Description
                                Text(
                                  page.description,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: (isDark ? Colors.white : Colors.black87)
                                        .withValues(alpha: 0.7),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32.0),

                                // Feature chips
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  alignment: WrapAlignment.center,
                                  children: page.features.map((feature) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            page.gradientColors[0].withValues(alpha: 0.1),
                                            page.gradientColors[1].withValues(alpha: 0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: page.gradientColors[0]
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.checkmark_circle_fill,
                                            size: 16,
                                            color: page.gradientColors[0],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            feature,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom controls
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Page indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _pages[_currentPage].gradientColors[0]
                                  : Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Action buttons
                      Row(
                        children: [
                          if (_currentPage > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: _pages[_currentPage].gradientColors[0]
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                          if (_currentPage > 0) const SizedBox(width: 16.0),
                          Expanded(
                            flex: _currentPage > 0 ? 2 : 1,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _pages[_currentPage].gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _pages[_currentPage].gradientColors[0]
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentPage == _pages.length - 1
                                          ? 'Get Started'
                                          : 'Continue',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_currentPage < _pages.length - 1) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        CupertinoIcons.arrow_right,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<String> features;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.features,
  });
}