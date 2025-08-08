// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

class FileOpener {
  static Future<void> openBase64({
    required String fileName,
    required String dataBase64,
  }) async {
    final bytes = base64Decode(dataBase64);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Trigger a download rather than opening in a new tab
    final anchor =
        html.AnchorElement(href: url)
          ..download = fileName
          ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
