import 'package:equatable/equatable.dart';

class AdminAuditLog extends Equatable {
  final String id;
  final DateTime timestamp;
  final String actorName;
  final String actorRole;
  final String action;
  final String target;
  final String ipAddress;
  final String details;

  const AdminAuditLog({
    required this.id,
    required this.timestamp,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.target,
    required this.ipAddress,
    required this.details,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        actorName,
        actorRole,
        action,
        target,
        ipAddress,
        details,
      ];
}

