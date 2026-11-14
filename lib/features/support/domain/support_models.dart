class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolution,
  });
  factory SupportTicket.fromJson(Map<String, Object?> json) => SupportTicket(
    id: json['id'] as int,
    subject: json['subject'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    resolution: json['resolution_summary'] as String?,
  );
  final int id;
  final String subject;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? resolution;
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });
  factory SupportMessage.fromJson(Map<String, Object?> json) => SupportMessage(
    id: json['id'] as int,
    author: json['author_user_id'] as int,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
  final int id;
  final int author;
  final String body;
  final DateTime createdAt;
}

class SupportConversation {
  const SupportConversation({required this.ticket, required this.messages});
  factory SupportConversation.fromJson(Map<String, Object?> json) =>
      SupportConversation(
        ticket: SupportTicket.fromJson(json['ticket'] as Map<String, Object?>),
        messages: (json['messages'] as List<Object?>)
            .map(
              (item) => SupportMessage.fromJson(item as Map<String, Object?>),
            )
            .toList(growable: false),
      );
  final SupportTicket ticket;
  final List<SupportMessage> messages;
}

const supportStatusLabels = {
  'open': 'Abierto',
  'in_progress': 'En atención',
  'escalated': 'Escalado',
  'resolved': 'Resuelto',
};
