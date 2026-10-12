import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../utils/database.dart';
import '../utils/platform_utils.dart';

import '../theme/app_colors.dart';

class MainPage extends StatelessWidget {
  final DatabaseManager db;
  final AuthService auth;

  const MainPage({super.key, required this.db, required this.auth});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (auth.isLoadingPermissions) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.headerDarkTeal),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _showExitDialog(context);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;

                // Determine Header Height based on screen width/height
                final double headerHeight = width < 600 ? 120 : 100;

                return Stack(
                  children: [
                    // 1. Fixed Background
                    Positioned.fill(
                      child: CustomPaint(painter: BackgroundPainter()),
                    ),

                    // 2. Scrollable Content
                    Positioned.fill(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(height: headerHeight + 20),
                          ),

                          // Content Area
                          SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1000),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: width * 0.05),
                                  child: Column(
                                    children: [
                                      _MainIllustrationAndTitle(),
                                      const SizedBox(height: 32),
                                      _ResponsiveFeatureGrid(
                                          width: width, auth: auth),
                                      const SizedBox(height: 48),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom Close Button
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: 40,
                                left: width * 0.05,
                                right: width * 0.05,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 600),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showExitDialog(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.closeButtonRed,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: AppColors.closeButtonRed
                                            .withValues(alpha: 0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: const Icon(
                                          Icons.power_settings_new_rounded,
                                          size: 24),
                                      label: const Text(
                                        'إغلاق التطبيق',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Fixed Sticky Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipPath(
                        clipper: HeaderWaveClipper(),
                        child: Container(
                          height: headerHeight,
                          color: AppColors.headerDarkTeal,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.05,
                                vertical: 10,
                              ),
                              child: _TopBar(auth: auth),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تأكيد الإغلاق',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('هل تريد إغلاق التطبيق؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لا'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.closeButtonRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                db.close();
                Navigator.pop(context);
                if (kIsWeb) return;
                exitApp();
              },
              child: const Text('نعم'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side icons (Settings, Notifications)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: Colors.white, size: 24),
              onPressed: () => context.push('/settings'),
              tooltip: 'الإعدادات',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 24),
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              },
              tooltip: 'تسجيل خروج',
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 24),
              onPressed: () {},
              tooltip: 'الإشعارات',
            ),
          ],
        ),

        // Right side (Avatar + Email)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.displayLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'مرحباً بك في تطبيق إدارة المصاريف',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.headerDarkTeal, size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MainIllustrationAndTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Wallet Illustration Container
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Image.asset(
              'assets/app_icon.png',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Titles
        const Text(
          'برنامج توزيع المصاريف',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFeatureGrid extends StatelessWidget {
  final double width;
  final AuthService auth;
  const _ResponsiveFeatureGrid({required this.width, required this.auth});

  @override
  Widget build(BuildContext context) {
    // Dynamic columns calculation based on available width
    int crossAxisCount = (width / 220).floor();
    if (crossAxisCount < 2)
      crossAxisCount = 2; // Minimum 2 columns on small mobiles
    if (crossAxisCount > 4)
      crossAxisCount = 4; // Maximum 4 columns on large screens

    List<Widget> cards = [];

    if (auth.canAccessPage('page_input')) {
      cards.add(_MenuCard(
        title: 'إدخال البيانات',
        subtitle: 'مشاركة ومشتريات',
        icon: Icons.edit_document,
        color: const Color(0xFF3B82F6),
        onTap: () => context.go('/input'),
      ));
    }

    if (auth.canAccessPage('page_view')) {
      cards.add(_MenuCard(
        title: 'عرض وبحث',
        subtitle: 'سجلات ومتابعة',
        icon: Icons.manage_search_rounded,
        color: const Color(0xFF10B981),
        onTap: () => context.go('/view'),
      ));
    }

    if (auth.canAccessPage('page_distribute')) {
      cards.add(_MenuCard(
        title: 'توزيع المصروفات',
        subtitle: 'وجبات ومشتريات',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFF97316),
        onTap: () => context.go('/distribute_expenses'),
      ));
    }

    if (auth.canAccessPage('page_reports')) {
      cards.add(_MenuCard(
        title: 'التقارير',
        subtitle: 'حالية وأرشيف',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => context.go('/reports'),
      ));
    }

    if (auth.canAccessPage('page_end_month')) {
      cards.add(_MenuCard(
        title: 'تقفيل الشهر',
        subtitle: 'أرشفة وتنزيلات',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFFEF4444),
        onTap: () => context.go('/end_month'),
      ));
    }

    if (auth.canAccessPage('page_database')) {
      cards.add(_MenuCard(
        title: 'قاعدة البيانات',
        subtitle: 'نسخ احتياطي ومزامنة',
        icon: Icons.dns_rounded,
        color: const Color(0xFF14B8A6),
        onTap: () => context.go('/database'),
      ));
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: cards,
    );
  }
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -5.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _isHovered ? 0.15 : 0.05),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            hoverColor: widget.color.withValues(alpha: 0.02),
            splashColor: widget.color.withValues(alpha: 0.1),
            highlightColor: widget.color.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Circle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 30),
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    widget.title,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Subtitle
                  Text(
                    widget.subtitle,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
