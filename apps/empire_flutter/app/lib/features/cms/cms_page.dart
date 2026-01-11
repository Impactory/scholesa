import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../services/telemetry_service.dart';
import '../auth/app_state.dart';
import '../landing/lead_capture_card.dart';

class CmsPageScreen extends StatefulWidget {
  const CmsPageScreen({super.key, required this.slug});

  final String slug;

  @override
  State<CmsPageScreen> createState() => _CmsPageScreenState();
}

class _CmsPageScreenState extends State<CmsPageScreen> {
  late Future<CmsPageModel?> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = _load();
  }

  Future<CmsPageModel?> _load() async {
    final repo = CmsRepository();
    final appState = context.read<AppState>();
    final role = appState.role;
    final page = await repo.fetchPublishedBySlug(slug: widget.slug, role: role);
    if (page != null) {
      TelemetryService.instance.logEvent(
        event: 'cms.page.viewed',
        metadata: {'slug': widget.slug},
      );
    }
    return page;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1224), Color(0xFF0F172A), Color(0xFF0B1224)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<CmsPageModel?>(
            future: _pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final page = snapshot.data;
              if (page == null) {
                return _NotFound(slug: widget.slug);
              }
              return _PageContent(page: page);
            },
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});

  final CmsPageModel page;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(slug: page.slug),
          const SizedBox(height: 18),
          Text(
            page.heroTitle ?? page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          if (page.heroSubtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              page.heroSubtitle!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5),
            ),
          ],
          const SizedBox(height: 24),
          ...page.blocks.map((block) => _Block(block: block)),
          const SizedBox(height: 28),
          LeadCaptureCard(source: 'cms', slug: page.slug),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block});

  final CmsBlockModel block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'hero':
        return _HeroBlock(block: block);
      case 'quote':
        return _QuoteBlock(block: block);
      default:
        return _SectionBlock(block: block);
    }
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.block});

  final CmsBlockModel block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF6366F1)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title != null)
            Text(block.title!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          if (block.body != null) ...[
            const SizedBox(height: 8),
            Text(block.body!, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.block});

  final CmsBlockModel block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote, color: Colors.amberAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.body != null)
                  Text(block.body!, style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, height: 1.5)),
                if (block.title != null) ...[
                  const SizedBox(height: 6),
                  Text(block.title!, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.block});

  final CmsBlockModel block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title != null)
            Text(block.title!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          if (block.body != null) ...[
            const SizedBox(height: 8),
            Text(block.body!, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ],
          if (block.bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: block.bullets
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item, style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
              ),
              alignment: Alignment.center,
              child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scholesa', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('/p/$slug', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          child: const Text('Login'),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.public_off, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text('Page not available', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text('The page "$slug" is not published or you do not have access.', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
