import 'dart:convert';

import 'package:http/http.dart' as http;

/// A GGUF model on Hugging Face that a local Ollama can run.
class HfModel {
  const HfModel({
    required this.id,
    required this.downloads,
    required this.likes,
    this.parameterHint,
  });

  /// `TheBloke/Mistral-7B-Instruct-v0.2-GGUF` etc.
  final String id;
  final int downloads;
  final int likes;

  /// Parsed out of the repo name (`7B`, `13B`, ...) when it's there. Used to
  /// warn about models that won't fit in typical RAM.
  final String? parameterHint;

  String get owner => id.contains('/') ? id.split('/').first : '';
  String get name => id.contains('/') ? id.split('/').last : id;

  /// What you hand to Ollama to pull it. Ollama supports Hugging Face repos
  /// directly with this prefix, which is why NEXUS doesn't need its own
  /// downloader or GGUF loader.
  String get ollamaRef => 'hf.co/$id';
}

/// Searches Hugging Face for models a local Ollama can actually run.
///
/// Filtered to GGUF on purpose: that's the format llama.cpp - and therefore
/// Ollama - loads. Listing the full Hub would mostly offer PyTorch
/// checkpoints that would fail at pull time with nothing explaining why.
///
/// Unauthenticated: the search API is public, so NEXUS needs no HF account
/// and never holds a Hugging Face token.
class HuggingFaceCatalog {
  HuggingFaceCatalog({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://huggingface.co/api/models';

  Future<List<HfModel>> search(String query, {int limit = 20}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'filter': 'gguf',
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'sort': 'downloads',
      'direction': '-1',
      'limit': '$limit',
    });
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HuggingFaceException(
        'Hugging Face search failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map<String, dynamic> && entry['id'] is String)
          HfModel(
            id: entry['id'] as String,
            downloads: (entry['downloads'] as num?)?.toInt() ?? 0,
            likes: (entry['likes'] as num?)?.toInt() ?? 0,
            parameterHint: parameterHint(entry['id'] as String),
          ),
    ];
  }

  void dispose() => _client.close();
}

/// Pulls a size like `7B` out of a repo id.
///
/// Deliberately conservative - it only matches a digit-run followed by B/b at a
/// token boundary, so `Llama-3.1-8B-Instruct` gives `8B` while something like
/// `bert-base` gives null rather than a wrong guess.
String? parameterHint(String id) {
  final match = RegExp(r'(?<![A-Za-z0-9])(\d+(?:\.\d+)?)\s*[bB](?![A-Za-z0-9])')
      .firstMatch(id.split('/').last);
  if (match == null) return null;
  return '${match.group(1)}B';
}

/// Rough RAM needed to run a model of this size, quantized to ~4 bits.
///
/// A number in the UI beats discovering it by watching a 40 GB download fail:
/// roughly 0.6 GB per billion parameters at Q4, plus ~1 GB of overhead.
double? estimatedRamGb(String? parameterHint) {
  if (parameterHint == null) return null;
  final billions = double.tryParse(parameterHint.replaceAll(RegExp('[bB]'), ''));
  if (billions == null) return null;
  return billions * 0.6 + 1;
}

class HuggingFaceException implements Exception {
  const HuggingFaceException(this.message);
  final String message;
  @override
  String toString() => message;
}
