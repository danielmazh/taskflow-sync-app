class Task {
  String id;
  String title;
  String? note;
  DateTime? dueAt;
  bool isDone;
  DateTime? snoozedUntil;
  DateTime? completedAt;
  /// Google Calendar event id linked to this task (one-way export). Null when
  /// the task is not (yet) mirrored to a calendar event.
  String? calendarEventId;

  Task({
    required this.id,
    required this.title,
    this.note,
    this.dueAt,
    this.isDone = false,
    this.snoozedUntil,
    this.completedAt,
    this.calendarEventId,
  });

  DateTime? get effectiveDueAt => snoozedUntil ?? dueAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'dueAt': dueAt?.toIso8601String(),
        'isDone': isDone,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'calendarEventId': calendarEventId,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        note: j['note'] as String?,
        dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt'] as String),
        isDone: j['isDone'] as bool? ?? false,
        snoozedUntil: j['snoozedUntil'] == null
            ? null
            : DateTime.parse(j['snoozedUntil'] as String),
        // Pre-5c tasks lack this field; default null = "no completion timestamp
        // recorded" which the outcome helper treats as on-time.
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
        // Pre-Phase-4 tasks lack this field; null means "not mirrored to
        // Google Calendar (yet)" — same as a never-synced task.
        calendarEventId: j['calendarEventId'] as String?,
      );
}
