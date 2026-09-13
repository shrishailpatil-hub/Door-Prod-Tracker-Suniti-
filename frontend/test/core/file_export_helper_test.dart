import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/file_export_helper.dart';

void main() {
  const helper = FileExportHelper();

  test('buildExcelFilename uses the required timestamped Excel name', () {
    expect(
      helper.buildExcelFilename(DateTime(2026, 9, 9, 8, 7, 6)),
      'door_workflow_logs_20260909_080706.xlsx',
    );
  });

  test(
    'FileExportHelper can be substituted without invoking a platform plugin',
    () async {
      final helper = _FakeFileExportHelper();
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result = await helper.saveExcelFile(bytes: bytes);

      expect(result, 'content://downloads/audit.xlsx');
      expect(helper.savedBytes, same(bytes));
    },
  );
}

class _FakeFileExportHelper extends FileExportHelper {
  Uint8List? savedBytes;

  @override
  Future<String?> saveExcelFile({
    required Uint8List bytes,
    DateTime? timestamp,
  }) async {
    savedBytes = bytes;
    return 'content://downloads/audit.xlsx';
  }
}
