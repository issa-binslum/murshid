class AuditEntry {
  final String id;
  final String action;
  final String entity;
  final String? entityId;
  final String? userId;
  final String? userName;
  final String? userUsername;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    this.entityId,
    this.userId,
    this.userName,
    this.userUsername,
    required this.createdAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    return AuditEntry(
      id: j['id'] as String,
      action: j['action'] as String,
      entity: j['entity'] as String,
      entityId: j['entityId'] as String?,
      userId: j['userId'] as String?,
      userName: user?['fullName'] as String?,
      userUsername: user?['username'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}
