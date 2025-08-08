import 'dart:convert';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class FileOpener {
  static Future<void> openBase64({
    required String fileName,
    required String dataBase64,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final path = '${tmpDir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(base64Decode(dataBase64), flush: true);
    await OpenFilex.open(file.path);
  }
}
