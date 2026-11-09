import 'package:equatable/equatable.dart';

class PaymentRecord extends Equatable {
  final String tranId;
  final String userId;
  final String userName;
  final String userEmail;
  final String planId;
  final String planName;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String? valId;
  final String? bankTranId;
  final String? cardType;
  final String? senderPhone;
  final String? trxId;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? approvedBy;
  final String? adminNote;

  const PaymentRecord({
    required this.tranId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.planId,
    required this.planName,
    required this.amount,
    this.currency = 'BDT',
    required this.status,
    required this.paymentMethod,
    this.valId,
    this.bankTranId,
    this.cardType,
    this.senderPhone,
    this.trxId,
    required this.createdAt,
    this.verifiedAt,
    this.approvedBy,
    this.adminNote,
  });

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';
  bool get isPendingApproval => status.toUpperCase() == 'PENDING_APPROVAL';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  String get formattedAmount => '৳${amount.toInt()} $currency';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      tranId:
          (json['tranId'] ?? json['tran_id']) as String? ??
          'TRAN-${DateTime.now().millisecondsSinceEpoch}',
      userId: (json['userId'] ?? json['user_id']) as String? ?? '',
      userName:
          (json['userName'] ??
                  json['user_name'] ??
                  (json['user'] is Map ? json['user']['full_name'] : null))
              as String? ??
          'User',
      userEmail:
          (json['userEmail'] ??
                  json['user_email'] ??
                  (json['user'] is Map ? json['user']['email'] : null))
              as String? ??
          '',
      planId: (json['planId'] ?? json['plan_id']) as String? ?? '',
      planName:
          (json['planName'] ??
                  json['plan_name'] ??
                  (json['plan'] is Map ? json['plan']['name'] : null))
              as String? ??
          'AdoptMatch Premium',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] as String?) ?? 'BDT',
      status: (json['status'] as String? ?? 'PENDING').toUpperCase(),
      paymentMethod:
          (json['paymentMethod'] ?? json['method']) as String? ?? 'SSLCommerz',
      valId: (json['valId'] ?? json['val_id']) as String?,
      bankTranId: (json['bankTranId'] ?? json['bank_tran_id']) as String?,
      cardType: (json['cardType'] ?? json['card_type']) as String?,
      senderPhone: (json['senderPhone'] ?? json['sender_phone']) as String?,
      trxId: (json['trxId'] ?? json['trx_id']) as String?,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : (json['created_at'] != null
                ? (DateTime.tryParse(json['created_at'] as String) ??
                      DateTime.now())
                : DateTime.now()),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : (json['verified_at'] != null
                ? DateTime.tryParse(json['verified_at'] as String)
                : null),
      approvedBy: (json['approvedBy'] ?? json['verified_by']) as String?,
      adminNote: (json['adminNote'] ?? json['failure_reason']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tranId': tranId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'planId': planId,
      'planName': planName,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paymentMethod': paymentMethod,
      'valId': valId,
      'bankTranId': bankTranId,
      'cardType': cardType,
      'senderPhone': senderPhone,
      'trxId': trxId,
      'createdAt': createdAt.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'adminNote': adminNote,
    };
  }

  @override
  List<Object?> get props => [tranId, userId, planId, amount, status];
}
