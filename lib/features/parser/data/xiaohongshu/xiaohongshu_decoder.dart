import 'dart:convert';
import '../../domain/parser_result.dart';
import 'xiaohongshu_failure.dart';

Map<String, dynamic> xhsMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

/// Reads JSON-compatible hydration only; never evaluates platform JavaScript.
final class XiaohongshuDecoder {
  const XiaohongshuDecoder();

  Map<String, dynamic> decode(String html, String id) {
    final state = _state(html);
    final mobile = xhsMap(
      xhsMap(xhsMap(state['noteData'])['data'])['noteData'],
    );
    if (mobile['noteId'] == id) return mobile;
    for (final entry in xhsMap(xhsMap(state['note'])['noteDetailMap']).values) {
      final note = xhsMap(xhsMap(entry)['note']);
      if (note['noteId'] == id) return note;
    }
    // A generic login overlay on an otherwise public page is not a gate.
    if (html.contains('/captcha/') || html.contains('验证码')) {
      throw const XiaohongshuFailure(ParserFailureCode.securityChallenge);
    }
    if (html.contains('笔记已删除') || html.contains('内容不存在')) {
      throw const XiaohongshuFailure(ParserFailureCode.notFound);
    }
    if (html.contains('私密笔记') || html.contains('无权访问')) {
      throw const XiaohongshuFailure(ParserFailureCode.privateOrRestricted);
    }
    if (html.contains('登录后查看') || html.contains('登录后访问')) {
      throw const XiaohongshuFailure(ParserFailureCode.loginRequired);
    }
    throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
  }

  Map<String, dynamic> _state(String html) {
    final marker = html.indexOf('window.__INITIAL_STATE__');
    if (marker < 0) return {};
    final assignment = html.indexOf('=', marker);
    if (assignment < 0) return {};
    var start = assignment + 1;
    while (start < html.length && html[start].trim().isEmpty) {
      start++;
    }
    if (start >= html.length || html[start] != '{') return {};
    final output = StringBuffer();
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var i = start; i < html.length; i++) {
      final char = html[i];
      if (quoted) {
        output.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
        continue;
      }
      if (char == '"') {
        quoted = true;
        output.write(char);
        continue;
      }
      if (html.startsWith('undefined', i) &&
          i > start &&
          RegExp(r'[:\[,\s]').hasMatch(html[i - 1]) &&
          i + 9 < html.length &&
          RegExp(r'[,}\]\s]').hasMatch(html[i + 9])) {
        output.write('null');
        i += 8;
        continue;
      }
      output.write(char);
      if (char == '{') depth++;
      if (char == '}' && --depth == 0) {
        try {
          return xhsMap(jsonDecode(output.toString()));
        } on FormatException {
          return {};
        }
      }
    }
    return {};
  }
}
