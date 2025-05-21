// lib/models/campaign_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType { escrow, upfront }

class Campaign {
  final String campaignId;
  final String title;
  final String description;
  final String productId;
  final DateTime startDate;
  final DateTime endDate;
  final PaymentType paymentType;
  final List<String> invitedInfluencers;
  final Map<String, bool> campaignOffer; // Track influencer acceptance
  final Map<String, Map<String, dynamic>>
      influencerBids; // Track bids and descriptions
  final Timestamp createdAt;

  Campaign({
    required this.campaignId,
    required this.title,
    required this.description,
    required this.productId,
    required this.startDate,
    required this.endDate,
    required this.paymentType,
    required this.invitedInfluencers,
    required this.campaignOffer,
    this.influencerBids = const {},
    required this.createdAt,
  });

  // Convert enum to string for saving in Firestore
  String _paymentTypeToString(PaymentType type) {
    return type.toString().split('.').last;
  }

  // Convert string to enum when reading from Firestore
  PaymentType _stringToPaymentType(String type) {
    return PaymentType.values
        .firstWhere((e) => e.toString().split('.').last == type);
  }

  // Convert Campaign object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'title': title,
      'description': description,
      'productId': productId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'paymentType': _paymentTypeToString(paymentType),
      'invitedInfluencers': invitedInfluencers,
      'campaignOffer': campaignOffer,
      'influencerBids': influencerBids,
      'createdAt': createdAt,
    };
  }

  // Create Campaign object from Firestore Map
  factory Campaign.fromMap(Map<String, dynamic> map) {
    return Campaign(
      campaignId: map['campaignId'],
      title: map['title'],
      description: map['description'],
      productId: map['productId'],
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.toString().split('.').last == map['paymentType'],
      ),
      invitedInfluencers: List<String>.from(map['invitedInfluencers']),
      campaignOffer: Map<String, bool>.from(map['campaignOffer'] ?? {}),
      influencerBids: Map<String, Map<String, dynamic>>.from(
          (map['influencerBids'] ?? {}).map((key, value) =>
              MapEntry(key, Map<String, dynamic>.from(value ?? {})))),
      createdAt: map['createdAt'],
    );
  }
}
