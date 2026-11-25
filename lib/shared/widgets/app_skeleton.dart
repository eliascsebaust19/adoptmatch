import 'package:flutter/material.dart';

// ── Reusable Animated Shimmer & Skeleton Loaders ─────────────────────────────

/// Provides a shared shimmering gradient sweep for skeleton placeholder widgets.
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    final isWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (isWidgetTest) {
      _controller.value = 0.5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final shift = _controller.value * 2.0 - 1.0;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.2 + shift, -0.2),
            end: Alignment(0.4 + shift, 0.2),
            colors: const [
              Color(0xFFE2E8F0),
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
            ],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Rectangular skeleton block with rounded corners.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color color;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 10,
    this.color = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Circular skeleton placeholder for avatars and icon badges.
class SkeletonCircle extends StatelessWidget {
  final double size;
  final Color color;

  const SkeletonCircle({
    super.key,
    this.size = 44,
    this.color = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 2-column pet card grid skeleton for User Home, Saved Pets, and Admin Pet Inventory.
class PetGridSkeleton extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;

  const PetGridSkeleton({
    super.key,
    this.itemCount = 4,
    this.shrinkWrap = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          mainAxisExtent: 252,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(10),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 138, borderRadius: 12),
              SizedBox(height: 10),
              SkeletonBox(width: 110, height: 14, borderRadius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 80, height: 11, borderRadius: 6),
              Spacer(),
              Row(
                children: [
                  SkeletonBox(width: 56, height: 22, borderRadius: 12),
                  Spacer(),
                  SkeletonCircle(size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card list skeleton for Admin queues, Applications, Chat Inbox, Appointments, Notifications & Plans.
class ListCardSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final bool showTrailingButton;

  const ListCardSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
    this.showTrailingButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const SkeletonCircle(size: 46),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(height: 11, borderRadius: 6),
                    SizedBox(height: 6),
                    SkeletonBox(width: 110, height: 10, borderRadius: 6),
                  ],
                ),
              ),
              if (showTrailingButton) ...[
                const SizedBox(width: 10),
                const SkeletonBox(width: 72, height: 32, borderRadius: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Admin Dashboard KPI strip + application queue skeleton.
class AdminDashboardSkeleton extends StatelessWidget {
  const AdminDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 210, height: 22, borderRadius: 8),
            const SizedBox(height: 8),
            const SkeletonBox(width: 260, height: 13, borderRadius: 6),
            const SizedBox(height: 18),
            SizedBox(
              height: 106,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => Container(
                  width: 164,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonBox(width: 82, height: 12, borderRadius: 6),
                          Spacer(),
                          SkeletonCircle(size: 28),
                        ],
                      ),
                      Spacer(),
                      SkeletonBox(width: 48, height: 22, borderRadius: 6),
                      SizedBox(height: 6),
                      SkeletonBox(width: 96, height: 10, borderRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const SkeletonBox(height: 44, borderRadius: 12),
            const SizedBox(height: 16),
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      SkeletonBox(width: 22, height: 22, borderRadius: 6),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 150, height: 14, borderRadius: 6),
                            SizedBox(height: 8),
                            SkeletonBox(height: 11, borderRadius: 6),
                            SizedBox(height: 6),
                            SkeletonBox(width: 130, height: 10, borderRadius: 6),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      SkeletonBox(width: 48, height: 48, borderRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail page skeleton for Pet Details, Pet Comparison, Swipe Deck, and Adoption Form.
class DetailPageSkeleton extends StatelessWidget {
  const DetailPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 260, borderRadius: 20),
            SizedBox(height: 18),
            Row(
              children: [
                SkeletonBox(width: 150, height: 22, borderRadius: 8),
                Spacer(),
                SkeletonBox(width: 82, height: 28, borderRadius: 14),
              ],
            ),
            SizedBox(height: 10),
            SkeletonBox(width: 190, height: 13, borderRadius: 6),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 68, borderRadius: 14)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 68, borderRadius: 14)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 68, borderRadius: 14)),
              ],
            ),
            SizedBox(height: 20),
            SkeletonBox(height: 14, borderRadius: 6),
            SizedBox(height: 8),
            SkeletonBox(height: 14, borderRadius: 6),
            SizedBox(height: 8),
            SkeletonBox(width: 220, height: 14, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// Chat thread bubble skeleton for ChatConversationScreen.
class ChatConversationSkeleton extends StatelessWidget {
  const ChatConversationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 220, height: 52, borderRadius: 16),
          ),
          SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonBox(width: 190, height: 46, borderRadius: 16),
          ),
          SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 250, height: 64, borderRadius: 16),
          ),
          SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonBox(width: 170, height: 44, borderRadius: 16),
          ),
        ],
      ),
    );
  }
}
