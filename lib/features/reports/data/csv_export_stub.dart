Future<void> downloadCsvText({
  required String filename,
  required String content,
}) async {
  throw UnsupportedError(
    'CSV download is available in the web build. Use Copy in the app instead.',
  );
}
