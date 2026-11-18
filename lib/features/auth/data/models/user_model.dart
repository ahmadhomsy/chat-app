import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.photoUrl,
    super.phone,
    super.isOnline = false,
    super.lastSeen,
    super.createdAt,
    super.provider = 'email',
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return UserModel(
      id: id,
      name:
          (map['name'] as String?)?.trim() ??
          (map['username'] as String?)?.trim() ??
          'Unknown User',
      email: (map['email'] as String?)?.trim() ?? '',
      photoUrl: map['photoUrl'] as String?,
      phone: map['phone'] as String?,
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: parseTimestamp(map['lastSeen']),
      createdAt: parseTimestamp(map['createdAt']),
      provider: (map['provider'] as String?) ?? 'email',
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      if (phone != null) 'phone': phone,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      if (createdAt != null)
        'createdAt': Timestamp.fromDate(createdAt!)
      else
        'createdAt': FieldValue.serverTimestamp(),
      'provider': provider,
    };
  }
}
