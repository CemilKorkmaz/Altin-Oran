import 'dart:convert';

import '../../prices/domain/gold_price.dart';
import 'investment_transaction.dart';

/// JSON/CSV export–import for [InvestmentTransaction].

extension InvestmentTransactionJson on InvestmentTransaction {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetType': assetType.name,
      'amount': amount,
      'unitPrice': unitPrice,
      'dateTime': dateTime.toIso8601String(),
      'purchaseChannel': purchaseChannel.name,
      'direction': direction.name,
      'priceSource': priceSource?.name,
      'isManualPrice': isManualPrice,
      'goldPurity': goldPurity?.name,
      'note': note,
      'customAssetId': customAssetId,
    };
  }
}

InvestmentTransaction transactionFromJson(Map<String, dynamic> json) {
  return InvestmentTransaction(
    id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    assetType: AssetType.values.byName(json['assetType'] as String),
    amount: (json['amount'] as num).toDouble(),
    unitPrice: (json['unitPrice'] as num).toDouble(),
    dateTime: DateTime.parse(json['dateTime'] as String),
    purchaseChannel: PurchaseChannel.values.byName(json['purchaseChannel'] as String),
    direction: TransactionDirection.values.byName(json['direction'] as String? ?? 'buy'),
    priceSource: json['priceSource'] != null
        ? PriceSource.values.byName(json['priceSource'] as String)
        : null,
    isManualPrice: json['isManualPrice'] as bool? ?? false,
    goldPurity: json['goldPurity'] != null
        ? GoldPurity.values.byName(json['goldPurity'] as String)
        : null,
    note: json['note'] as String?,
    customAssetId: json['customAssetId'] as String?,
  );
}

/// Export all transactions as JSON string (array of objects).
String exportTransactionsToJson(List<InvestmentTransaction> transactions) {
  final list = transactions.map((t) => t.toJson()).toList();
  return const JsonEncoder.withIndent('  ').convert(list);
}

/// Parse JSON string (array of objects) to list of transactions.
List<InvestmentTransaction> importTransactionsFromJson(String jsonString) {
  final decoded = jsonDecode(jsonString);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(transactionFromJson)
      .toList();
}

/// CSV header row for transactions.
const List<String> _csvHeaders = [
  'id', 'assetType', 'amount', 'unitPrice', 'dateTime', 'purchaseChannel',
  'direction', 'priceSource', 'isManualPrice', 'goldPurity', 'note', 'customAssetId',
];

/// Export transactions to CSV string (UTF-8, comma-separated, header row).
String exportTransactionsToCsv(List<InvestmentTransaction> transactions) {
  final buffer = StringBuffer();
  buffer.writeln(_csvHeaders.join(','));
  for (final t in transactions) {
    final row = [
      t.id,
      t.assetType.name,
      t.amount,
      t.unitPrice,
      t.dateTime.toIso8601String(),
      t.purchaseChannel.name,
      t.direction.name,
      t.priceSource?.name ?? '',
      t.isManualPrice,
      t.goldPurity?.name ?? '',
      _escapeCsv(t.note ?? ''),
      _escapeCsv(t.customAssetId ?? ''),
    ];
    buffer.writeln(row.map(_csvCell).join(','));
  }
  return buffer.toString();
}

String _csvCell(dynamic value) {
  if (value is String) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
  return value.toString();
}

String _escapeCsv(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Parse CSV string to list of transactions. Expects header row.
List<InvestmentTransaction> importTransactionsFromCsv(String csvString) {
  final lines = csvString.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (lines.isEmpty) return [];
  final header = lines.first.split(',').map((s) => s.trim()).toList();
  final idIdx = _indexOf(header, 'id');
  final assetIdx = _indexOf(header, 'assetType');
  final amountIdx = _indexOf(header, 'amount');
  final priceIdx = _indexOf(header, 'unitPrice');
  final dateIdx = _indexOf(header, 'dateTime');
  final channelIdx = _indexOf(header, 'purchaseChannel');
  if (idIdx < 0 || assetIdx < 0 || amountIdx < 0 || priceIdx < 0 || dateIdx < 0 || channelIdx < 0) {
    return [];
  }
  final result = <InvestmentTransaction>[];
  for (var i = 1; i < lines.length; i++) {
    final cells = _parseCsvLine(lines[i]);
    if (cells.length <= dateIdx) continue;
    try {
      final tx = InvestmentTransaction(
        id: cells[idIdx].trim().isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : cells[idIdx].trim(),
        assetType: AssetType.values.byName(cells[assetIdx].trim()),
        amount: double.tryParse(cells[amountIdx].trim()) ?? 0,
        unitPrice: double.tryParse(cells[priceIdx].trim()) ?? 0,
        dateTime: DateTime.parse(cells[dateIdx].trim()),
        purchaseChannel: PurchaseChannel.values.byName(cells[channelIdx].trim()),
        direction: _optEnum(header, cells, 'direction', TransactionDirection.values) ?? TransactionDirection.buy,
        priceSource: _optEnum(header, cells, 'priceSource', PriceSource.values),
        isManualPrice: _optBool(header, cells, 'isManualPrice', false),
        goldPurity: _optEnum(header, cells, 'goldPurity', GoldPurity.values),
        note: _optStr(header, cells, 'note'),
        customAssetId: _optStr(header, cells, 'customAssetId'),
      );
      result.add(tx);
    } catch (_) {
      // skip malformed row
    }
  }
  return result;
}

int _indexOf(List<String> header, String name) {
  final i = header.indexWhere((h) => h.trim().toLowerCase() == name.toLowerCase());
  return i;
}

T? _optEnum<T extends Enum>(List<String> header, List<String> cells, String name, List<T> values) {
  final i = _indexOf(header, name);
  if (i < 0 || i >= cells.length) return null;
  final s = cells[i].trim();
  if (s.isEmpty) return null;
  try {
    return values.byName(s);
  } catch (_) {
    return null;
  }
}

bool _optBool(List<String> header, List<String> cells, String name, bool defaultValue) {
  final i = _indexOf(header, name);
  if (i < 0 || i >= cells.length) return defaultValue;
  final s = cells[i].trim().toLowerCase();
  if (s.isEmpty) return defaultValue;
  return s == 'true' || s == '1';
}

String? _optStr(List<String> header, List<String> cells, String name) {
  final i = _indexOf(header, name);
  if (i < 0 || i >= cells.length) return null;
  final s = cells[i].trim();
  return s.isEmpty ? null : s;
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var i = 0;
  while (i < line.length) {
    if (line[i] == '"') {
      var cell = '';
      i++;
      while (i < line.length) {
        if (line[i] == '"') {
          i++;
          if (i < line.length && line[i] == '"') {
            cell += '"';
            i++;
          } else {
            break;
          }
        } else {
          cell += line[i];
          i++;
        }
      }
      result.add(cell);
      if (i < line.length && line[i] == ',') i++;
    } else {
      var end = line.indexOf(',', i);
      if (end < 0) end = line.length;
      result.add(line.substring(i, end).trim());
      i = end + 1;
    }
  }
  return result;
}
