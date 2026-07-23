import 'dart:convert';

/// Turns a byte stream (an HTTP response body) into complete text lines,
/// buffering across chunk boundaries so a line split between two network
/// packets is still delivered whole. Used by the SSE providers
/// (Anthropic/OpenAI, which then filter `data:` lines) and the Ollama
/// provider (which parses each line as a JSON object).
Stream<String> decodeLines(Stream<List<int>> byteStream) async* {
  var buffer = '';
  await for (final chunk in byteStream.transform(utf8.decoder)) {
    buffer += chunk;
    var newline = buffer.indexOf('\n');
    while (newline != -1) {
      final line = buffer.substring(0, newline).replaceAll('\r', '');
      buffer = buffer.substring(newline + 1);
      yield line;
      newline = buffer.indexOf('\n');
    }
  }
  if (buffer.trim().isNotEmpty) yield buffer.replaceAll('\r', '');
}

/// Extracts the payload of an SSE `data:` line, or null for anything else
/// (event lines, comments, blanks). The sentinel `[DONE]` (OpenAI) is
/// returned as-is for the caller to detect.
String? sseData(String line) {
  if (!line.startsWith('data:')) return null;
  return line.substring(5).trim();
}
