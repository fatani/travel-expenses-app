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
    String? customBankName,
    String? cardNetwork,
    String? customCardNetwork,
    String? cardTier,
    String? customCardTier,
    String? last4,
    String? displayName,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();

    final isDuplicate = await isDuplicateCard(
      bankName: bankName,
      customBankName: customBankName,
      cardNetwork: cardNetwork,
      customCardNetwork: customCardNetwork,
      cardTier: cardTier,
      customCardTier: customCardTier,
      last4: last4,
    );
    if (isDuplicate) {
      throw const DuplicateCardProfileException();
    }
    
    // Generate displayName if not provided
    final finalDisplayName = displayName ?? 
        _generateDisplayName(
          bankName: bankName,
          customBankName: customBankName,
          cardNetwork: cardNetwork,
          customCardNetwork: customCardNetwork,
          cardTier: cardTier,
          customCardTier: customCardTier,
          last4: last4,
          fallback: name,
        );
    
    final map = <String, Object?>{
      'name': name.trim(),
      'bank_name': bankName,
      'custom_bank_name': _cleanText(customBankName),
      'card_network': cardNetwork,
      'custom_card_network': _cleanText(customCardNetwork),
      'card_tier': cardTier,
      'custom_card_tier': _cleanText(customCardTier),
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
      customBankName: _cleanText(customBankName),
      cardNetwork: cardNetwork,
      customCardNetwork: _cleanText(customCardNetwork),
      cardTier: cardTier,
      customCardTier: _cleanText(customCardTier),
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
    String? customBankName,
    String? cardNetwork,
    String? customCardNetwork,
    String? cardTier,
    String? customCardTier,
    String? last4,
    String? displayName,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();

    final isDuplicate = await isDuplicateCard(
      bankName: bankName,
      customBankName: customBankName,
      cardNetwork: cardNetwork,
      customCardNetwork: customCardNetwork,
      cardTier: cardTier,
      customCardTier: customCardTier,
      last4: last4,
      excludeId: id,
    );
    if (isDuplicate) {
      throw const DuplicateCardProfileException();
    }
    
    // Generate displayName if not provided
    final finalDisplayName = displayName ?? 
        _generateDisplayName(
          bankName: bankName,
          customBankName: customBankName,
          cardNetwork: cardNetwork,
          customCardNetwork: customCardNetwork,
          cardTier: cardTier,
          customCardTier: customCardTier,
          last4: last4,
          fallback: name,
        );
    
    await db.update(
      AppDatabase.cardsTable,
      {
        'name': name.trim(),
        'bank_name': bankName,
        'custom_bank_name': _cleanText(customBankName),
        'card_network': cardNetwork,
        'custom_card_network': _cleanText(customCardNetwork),
        'card_tier': cardTier,
        'custom_card_tier': _cleanText(customCardTier),
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
    required String? customBankName,
    required String? cardNetwork,
    required String? customCardNetwork,
    required String? cardTier,
    required String? customCardTier,
    required String? last4,
    int? excludeId,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(AppDatabase.cardsTable);

    final normalizedBankName = _normalizeText(
      _resolveStoredValue(bankName, customBankName),
    );
    final normalizedCardNetwork = _normalizeText(
      _resolveStoredValue(cardNetwork, customCardNetwork),
    );
    final normalizedCardTier = _normalizeText(
      _resolveStoredValue(cardTier, customCardTier),
    );
    final normalizedLast4 = _normalizeLast4(last4);

    for (final row in rows) {
      final rowId = row['id'] as int;
      if (excludeId != null && rowId == excludeId) {
        continue;
      }

      final matches =
          _normalizeText(
            _resolveStoredValue(
              row['bank_name'] as String?,
              row['custom_bank_name'] as String?,
            ),
          ) ==
              normalizedBankName &&
          _normalizeText(
            _resolveStoredValue(
              row['card_network'] as String?,
              row['custom_card_network'] as String?,
            ),
          ) ==
              normalizedCardNetwork &&
          _normalizeText(
            _resolveStoredValue(
              row['card_tier'] as String?,
              row['custom_card_tier'] as String?,
            ),
          ) ==
              normalizedCardTier &&
          _normalizeLast4(row['last4'] as String?) == normalizedLast4;

      if (matches) {
        return true;
      }
    }

    return false;
  }

  String _generateDisplayName({
    required String? bankName,
    required String? customBankName,
    required String? cardNetwork,
    required String? customCardNetwork,
    required String? cardTier,
    required String? customCardTier,
    required String? last4,
    required String fallback,
  }) {
    final parts = <String>[];

    final resolvedBankName = _resolveStoredValue(bankName, customBankName);
    if (resolvedBankName != null) {
      parts.add(resolvedBankName);
    }

    final resolvedCardNetwork = _resolveStoredValue(
      cardNetwork,
      customCardNetwork,
    );
    if (resolvedCardNetwork != null) {
      parts.add(resolvedCardNetwork);
    }

    final resolvedCardTier = _resolveStoredValue(cardTier, customCardTier);
    if (resolvedCardTier != null) {
      parts.add(resolvedCardTier);
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

  String? _resolveStoredValue(String? baseValue, String? customValue) {
    return _cleanText(customValue) ?? _cleanText(baseValue);
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _normalizeText(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _normalizeLast4(String? value) {
    return value?.trim() ?? '';
  }
}
