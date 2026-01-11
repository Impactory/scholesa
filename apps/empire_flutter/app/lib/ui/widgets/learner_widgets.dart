import 'package:flutter/material.dart';
import '../theme/scholesa_theme.dart';

/// A beautiful mission card for displaying learning missions
class MissionCard extends StatelessWidget {

  const MissionCard({
    super.key,
    required this.title,
    required this.description,
    required this.pillar,
    required this.progress,
    this.dueDate,
    this.status = 'not_started',
    this.onTap,
    this.onContinue,
  });
  final String title;
  final String description;
  final String pillar; // 'future_skills', 'leadership', 'impact'
  final double progress;
  final String? dueDate;
  final String status; // 'not_started', 'in_progress', 'submitted', 'reviewed'
  final VoidCallback? onTap;
  final VoidCallback? onContinue;

  Color get pillarColor {
    switch (pillar) {
      case 'future_skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.primary;
    }
  }

  String get pillarLabel {
    switch (pillar) {
      case 'future_skills':
        return 'Future Skills';
      case 'leadership':
        return 'Leadership';
      case 'impact':
        return 'Impact';
      default:
        return pillar;
    }
  }

  IconData get pillarIcon {
    switch (pillar) {
      case 'future_skills':
        return Icons.rocket_launch_rounded;
      case 'leadership':
        return Icons.psychology_rounded;
      case 'impact':
        return Icons.eco_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'submitted':
        return 'Submitted';
      case 'reviewed':
        return 'Reviewed';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'not_started':
        return ScholesaColors.textMuted;
      case 'in_progress':
        return ScholesaColors.info;
      case 'submitted':
        return ScholesaColors.warning;
      case 'reviewed':
        return ScholesaColors.success;
      default:
        return ScholesaColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScholesaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header with pillar color
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[pillarColor, pillarColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        pillarIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            pillarLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ScholesaColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  const Text(
                                    'Progress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ScholesaColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: pillarColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: pillarColor.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(pillarColor),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onContinue != null && status != 'reviewed') ...<Widget>[
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pillarColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              status == 'not_started' ? 'Start' : 'Continue',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (dueDate != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: ScholesaColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Due: $dueDate',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ScholesaColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact mission card for lists
class MissionListTile extends StatelessWidget {

  const MissionListTile({
    super.key,
    required this.title,
    required this.pillar,
    required this.progress,
    this.status = 'not_started',
    this.onTap,
  });
  final String title;
  final String pillar;
  final double progress;
  final String status;
  final VoidCallback? onTap;

  Color get pillarColor {
    switch (pillar) {
      case 'future_skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.primary;
    }
  }

  IconData get pillarIcon {
    switch (pillar) {
      case 'future_skills':
        return Icons.rocket_launch_rounded;
      case 'leadership':
        return Icons.psychology_rounded;
      case 'impact':
        return Icons.eco_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: pillarColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(pillarIcon, color: pillarColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: ScholesaColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: pillarColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(pillarColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
      trailing: Text(
        '${(progress * 100).toInt()}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: pillarColor,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// Habit streak card for the habit coach
class HabitStreakCard extends StatelessWidget {

  const HabitStreakCard({
    super.key,
    required this.habitName,
    required this.currentStreak,
    required this.longestStreak,
    required this.weekProgress,
    this.color = ScholesaColors.impact,
    this.onTap,
    this.onComplete,
  });
  final String habitName;
  final int currentStreak;
  final int longestStreak;
  final List<bool> weekProgress; // 7 days, most recent first
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScholesaColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            habitName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ScholesaColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$currentStreak day streak',
                            style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Complete button
                    if (onComplete != null)
                      IconButton(
                        onPressed: onComplete,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[color, color.withValues(alpha: 0.8)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Week progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (int index) {
                    final List<String> dayNames = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final bool isCompleted = index < weekProgress.length && weekProgress[6 - index];
                    final bool isToday = index == 6;
                    
                    return Column(
                      children: <Widget>[
                        Text(
                          dayNames[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isToday ? color : ScholesaColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? color
                                : isToday
                                    ? color.withValues(alpha: 0.15)
                                    : ScholesaColors.surfaceVariant,
                            shape: BoxShape.circle,
                            border: isToday && !isCompleted
                                ? Border.all(color: color, width: 2)
                                : null,
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 12),
                // Stats
                Row(
                  children: <Widget>[
                    _buildStat('Current', currentStreak.toString(), color),
                    const SizedBox(width: 24),
                    _buildStat('Longest', longestStreak.toString(), ScholesaColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ScholesaColors.textMuted,
          ),
        ),
        Row(
          children: <Widget>[
            Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: valueColor,
            ),
            const SizedBox(width: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Portfolio item card
class PortfolioCard extends StatelessWidget {

  const PortfolioCard({
    super.key,
    required this.title,
    required this.type,
    this.thumbnailUrl,
    required this.date,
    this.skills = const [],
    this.onTap,
  });
  final String title;
  final String type; // 'image', 'document', 'video', 'link'
  final String? thumbnailUrl;
  final String date;
  final List<String> skills;
  final VoidCallback? onTap;

  IconData get typeIcon {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'video':
        return Icons.play_circle_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScholesaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Thumbnail area
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: ScholesaColors.surfaceVariant,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        ),
                      )
                    : _buildPlaceholder(),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ScholesaColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ScholesaColors.textMuted,
                      ),
                    ),
                    if (skills.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: skills.take(3).map((String skill) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ScholesaColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 10,
                              color: ScholesaColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        typeIcon,
        size: 48,
        color: ScholesaColors.textMuted.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Skill progress widget for learner profiles
class SkillProgressWidget extends StatelessWidget {

  const SkillProgressWidget({
    super.key,
    required this.skillName,
    required this.pillar,
    this.level = 1,
    this.maxLevel = 5,
    required this.progress,
    this.onTap,
  });
  final String skillName;
  final String pillar;
  final int level;
  final int maxLevel;
  final double progress;
  final VoidCallback? onTap;

  Color get pillarColor {
    switch (pillar) {
      case 'future_skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[pillarColor, pillarColor.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'L$level',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      title: Text(
        skillName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: ScholesaColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          Row(
            children: List.generate(maxLevel, (int index) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  index < level ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: index < level ? pillarColor : ScholesaColors.textMuted,
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: pillarColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(pillarColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
      trailing: Text(
        '${(progress * 100).toInt()}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: pillarColor,
        ),
      ),
    );
  }
}
