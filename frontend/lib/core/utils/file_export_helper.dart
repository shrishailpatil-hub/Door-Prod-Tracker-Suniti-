import 'dart:typed_data';

import 'package:public_file_saver/public_file_saver.dart';

/// Saves exported files behind a mockable application-level abstraction.
class FileExportHelper {
  const FileExportHelper();

  static const _excelMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Builds the filename used for manager audit-log Excel exports.
  String buildExcelFilename([DateTime? timestamp]) {
    final value = (timestamp ?? DateTime.now()).toLocal();
    final date =
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}';
    return 'door_workflow_logs_${date}_$time.xlsx';
  }

  /// Saves the Excel file to a user-visible location and returns its URI/path.
  ///
  /// On Android 10 and later, PublicFileSaver uses MediaStore Downloads.
  Future<String?> saveExcelFile({
    required Uint8List bytes,
    DateTime? timestamp,
  }) async {
    final result = await PublicFileSaver().saveBytes(
      bytes: bytes,
      fileName: buildExcelFilename(timestamp),
      mimeType: _excelMimeType,
    );
    if (result?.isSuccess != true) return null;
    return result!.path ?? result.uri ?? result.fileName;
  }
}
