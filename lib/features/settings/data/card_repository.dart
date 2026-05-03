import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/card_profile.dart';
import '../domain/card_profile_exceptions.dart';

class CardRepository {
  CardRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<CardProfile>> getAllCards() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cardsTable,
      orderBy: 'created_at ASC',
    );
    return rows.map(CardProfile.fromMap).toList();
  }

  Future<CardProfile> addCard({
    required String name,
    String? bankName,
    String? cardNetwork,
    String? cardTier,
    String? last4,
    String? displayName,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();

    final isDuplicate = await isDuplicateCard(
      bankName: bankName,
      cardNetwork: cardNetwork,
      cardTier: cardTier,
      last4: last4,
    );
    if (isDuplicate) {
      throw const DuplicateCardProfileException();
    }
    
    // Generate displayName if not provided
    final finalDisplayName = displayName ?? 
        _generateDisplayName(bankName, cardNetwork, cardTier, last4, name);
    
    final map = <String, Object?>{
      'name': name.trim(),
      'bank_name': bankName,
      'card_network': cardNetwork,
      'card_tier': cardTier,
      'last4': last4,
      'display_name': finalDisplayName,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final id = await db.insert(
      AppDatabase.cardsTable,
      map,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return CardProfile(
      id: id,
      name: name.trim(),
      bankName: bankName,
      cardNetwork: cardNetwork,
      cardTier: cardTier,
      last4: last4,
      displayName: finalDisplayName,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<CardProfile> updateCard({
    required int id,
    required String name,
    String? bankName,
    String? cardNetwork,
    String? cardTier,
    String? last4,
    String? displayName,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();

    final isDuplicate = await isDuplicateCard(
      bankName: bankName,
      cardNetwork: cardNetwork,
      cardTier: cardTier,
      last4: last4,
      excludeId: id,
    );
    if (isDuplicate) {
      throw const DuplicateCardProfileException();
    }
    
    // Generate displayName if not provided
    final finalDisplayName = displayName ?? 
        _generateDisplayName(bankName, cardNetwork, cardTier, last4, name);
    
    await db.update(
      AppDatabase.cardsTable,
      {
        'name': name.trim(),
        'bank_name': bankName,
        'card_network': cardNetwork,
        'card_tier': cardTier,
        'last4': last4,
        'display_name': finalDisplayName,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final rows = await db.query(
      AppDatabase.cardsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return CardProfile.fromMap(rows.first);
  }

  Future<void> deleteCard(int id) async {
    final db = await _appDatabase.database;
    await db.delete(AppDatabase.cardsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isDuplicateCard({
    required String? bankName,
    required String? cardNetwork,
    required String? cardTier,
    required String? last4,
    int? excludeId,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(AppDatabase.cardsTable);

    final normalizedBankName = _normalizeText(bankName);
    final normalizedCardNetwork = _normalizeText(cardNetwork);
    final normalizedCardTier = _normalizeText(cardTier);
    final normalizedLast4 = _normalizeLast4(last4);

    for (final row in rows) {
      final rowId = row['id'] as int;
      if (excludeId != null && rowId == excludeId) {
        continue;
      }

      final matches = _normalizeText(row['bank_name'] as String?) == normalizedBankName &&
          _normalizeText(row['card_network'] as String?) == normalizedCardNetwork &&
          _normalizeText(row['card_tier'] as String?) == normalizedCardTier &&
          _normalizeLast4(row['last4'] as String?) == normalizedLast4;

      if (matches) {
        return true;
      }
    }

    return false;
  }

  String _generateDisplayName(
    String? bankName,
    String? cardNetwork,
    String? cardTier,
    String? last4,
    String fallback,
  ) {
    final parts = <String>[];
    
    if (bankName != null && bankName.isNotEmpty) {
      parts.add(bankName);
    }
    if (cardNetwork != null && cardNetwork.isNotEmpty) {
      parts.add(cardNetwork);
    }
    if (cardTier != null && cardTier.isNotEmpty) {
      parts.add(cardTier);
    }
    
    String displayName;
    if (parts.isNotEmpty) {
      displayName = parts.join(' ');
    } else {
      displayName = fallback;
    }
    
    if (last4 != null && last4.isNotEmpty && last4.length == 4) {
      displayName += ' ••••$last4';
    }
    
    return displayName;
  }

  String _normalizeText(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _normalizeLast4(String? value) {
    return value?.trim() ?? '';
  }
}
