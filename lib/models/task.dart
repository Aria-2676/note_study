class Task {
  final int? id;
  final String title;
  final String? description;
  final bool isWord;
  final bool isOK;
  final DateTime cplTime;
  final String recurrence; // none/daily/weekly/monthly
  final DateTime? completedAt;
  final int rewardPoints; // 完成奖励积分
  final bool isDeducted; // 是否已扣除积分（用于未完成时只扣一次）
  final DateTime createdAt; // 任务创建时间

  Task({
    this.id,
    required this.title,
    this.description,
    this.isWord = false,
    this.isOK = false,
    required this.cplTime,
    this.recurrence = 'none',
    this.completedAt,
    this.rewardPoints = 0, // 默认0积分
    this.isDeducted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? isWord,
    bool? isOK,
    DateTime? cplTime,
    String? recurrence,
    DateTime? completedAt,
    int? rewardPoints,
    bool? isDeducted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isWord: isWord ?? this.isWord,
      isOK: isOK ?? this.isOK,
      cplTime: cplTime ?? this.cplTime,
      recurrence: recurrence ?? this.recurrence,
      completedAt: completedAt ?? this.completedAt,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      isDeducted: isDeducted ?? this.isDeducted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isWord': isWord ? 1 : 0,
      'isOK': isOK ? 1 : 0,
      'cplTime': cplTime.toIso8601String(),
      'recurrence': recurrence,
      'completedAt': completedAt?.toIso8601String(),
      'rewardPoints': rewardPoints,
      'isDeducted': isDeducted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      isWord: (map['isWord'] as int? ?? 0) == 1,
      isOK: (map['isOK'] as int? ?? 0) == 1,
      cplTime: DateTime.parse(map['cplTime'] as String),
      recurrence: map['recurrence'] as String? ?? 'none',
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      rewardPoints: map['rewardPoints'] as int? ?? 0,
      isDeducted: (map['isDeducted'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
