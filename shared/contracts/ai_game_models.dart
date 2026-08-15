enum AssistantAudience { admin, store, customer }

enum ChallengeKind { sales, collection, stock, ordering, delivery, learning }

class AssistantRequest {
  final AssistantAudience audience;
  final String question;
  final Map<String, Object?> businessSnapshot;

  const AssistantRequest({required this.audience, required this.question, required this.businessSnapshot});

  Map<String, Object?> toJson() => {'audience': audience.name, 'question': question, 'businessSnapshot': businessSnapshot};
}

class DailyChallenge {
  final String id;
  final ChallengeKind kind;
  final String title;
  final String description;
  final int points;
  final double progress;
  final bool claimed;

  const DailyChallenge({required this.id, required this.kind, required this.title, required this.description, required this.points, required this.progress, this.claimed = false});

  Map<String, Object?> toJson() => {'id': id, 'kind': kind.name, 'title': title, 'description': description, 'points': points, 'progress': progress, 'claimed': claimed};
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final DateTime? unlockedAt;

  const Achievement({required this.id, required this.title, required this.description, this.unlockedAt});

  bool get unlocked => unlockedAt != null;
}
