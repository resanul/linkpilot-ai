class PostModel {
  final String id;
  final String? clientId;
  final String? title;
  final String? topic;
  final String body;
  final String status; // draft, pending_approval, scheduled, published, rejected, failed
  final bool approvalRequired;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String? linkedinPostId;
  final String? errorMessage;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSynced;

  PostModel({
    required this.id,
    this.clientId,
    this.title,
    this.topic,
    required this.body,
    required this.status,
    required this.approvalRequired,
    this.scheduledAt,
    this.publishedAt,
    this.linkedinPostId,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = true,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String?,
      title: json['title'] as String?,
      topic: json['topic'] as String?,
      body: json['body'] as String,
      status: (json['status'] as String?) ?? 'draft',
      approvalRequired: (json['approval_required'] as bool?) ?? true,
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'] as String) : null,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
      linkedinPostId: json['linkedin_post_id'] as String?,
      errorMessage: json['error_message'] as String?,
      retryCount: (json['retry_count'] as int?) ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'title': title,
      'topic': topic,
      'body': body,
      'status': status,
      'approval_required': approvalRequired,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'linkedin_post_id': linkedinPostId,
      'error_message': errorMessage,
      'retry_count': retryCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'client_id': clientId ?? id,
      'title': title,
      'topic': topic,
      'body': body,
      'status': status,
      'approval_required': approvalRequired ? 1 : 0,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'linkedin_post_id': linkedinPostId,
      'error_message': errorMessage,
      'retry_count': retryCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory PostModel.fromSqliteMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String?,
      title: map['title'] as String?,
      topic: map['topic'] as String?,
      body: map['body'] as String,
      status: (map['status'] as String?) ?? 'draft',
      approvalRequired: (map['approval_required'] as int? ?? 1) == 1,
      scheduledAt: map['scheduled_at'] != null ? DateTime.tryParse(map['scheduled_at'] as String) : null,
      publishedAt: map['published_at'] != null ? DateTime.tryParse(map['published_at'] as String) : null,
      linkedinPostId: map['linkedin_post_id'] as String?,
      errorMessage: map['error_message'] as String?,
      retryCount: (map['retry_count'] as int?) ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }

  PostModel copyWith({
    String? id,
    String? clientId,
    String? title,
    String? topic,
    String? body,
    String? status,
    bool? approvalRequired,
    DateTime? scheduledAt,
    DateTime? publishedAt,
    String? linkedinPostId,
    String? errorMessage,
    int? retryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return PostModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      body: body ?? this.body,
      status: status ?? this.status,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      publishedAt: publishedAt ?? this.publishedAt,
      linkedinPostId: linkedinPostId ?? this.linkedinPostId,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
