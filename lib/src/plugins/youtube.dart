import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import '../core/initializer.dart' show isReleaseMode;

const String _kRequestAuthority = 'www.youtube.com';
const String _kRequestKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
const Map<String, String> _kRequestHeaders = {
  'accept': '*/*',
  'accept-language': 'en-GB,en;q=0.9,en-US;q=0.8',
  'content-type': 'application/json',
  'dpr': '2',
  'sec-ch-ua-arch': '',
  'sec-fetch-dest': 'empty',
  'sec-fetch-mode': 'same-origin',
  'sec-fetch-site': 'same-origin',
  'x-origin': 'https://www.youtube.com',
  'x-youtube-client-name': '67',
  'x-youtube-client-version': '1.20210823.00.00',
};
const Map<String, dynamic> _kRequestPayload = {
  'context': {
    'client': {
      'clientName': 'ANDROID',
      'clientScreen': 'EMBED',
      'clientVersion': '16.43.34',
    },
    'thirdParty': {
      'embedUrl': 'https://www.youtube.com',
    },
  },
};

class YouTube {
  YouTube({
    int port = 6900,
  }) {
    /// If is debug mode use different port from release mode
    _port = isReleaseMode ? port : math.Random().nextInt(999) + 6000;
    _create().catchError((_) {});
  }

  Future<void> close() => _server.close();

  Future<String> _stream(String id) async {
    await _completer.future;
    final response = await http.post(
      Uri.https(
        _kRequestAuthority,
        'youtubei/v1/player',
        {
          'key': _kRequestKey,
        },
      ),
      body: convert.jsonEncode(
        {
          ..._kRequestPayload,
          ...{
            'videoId': id,
          },
        },
      ),
      headers: _kRequestHeaders,
    );
    final body = convert.jsonDecode(response.body)['streamingData'];
    String? opus;
    String? mp4;
    String? aac;
    for (final format in body['adaptiveFormats']) {
      if (format['itag'] == 251) {
        opus = format['url'];
      }
      if (format['itag'] == 140) {
        aac = format['url'];
      }
      if (format['itag'] == 18) {
        mp4 = format['url'];
      }
    }
    return (opus ?? aac ?? mp4)!;
  }

  Future<void> _create() async {
    _server = HttpServer.listenOn(
      await ServerSocket.bind('127.0.0.1', _port),
    );
    _server.listen((request) async {
      switch (request.uri.path) {
        case '/youtube':
          {
            request.response.headers.set(
              'location',
              await _stream(request.uri.queryParameters['id']!),
            );
            request.response.statusCode = 302;
            request.response.close();
            break;
          }
        default:
          break;
      }
    });
    _completer.complete();
  }

  final _completer = Completer();
  late final HttpServer _server;
}

late int _port;

abstract class Plugins {
  static Uri redirect(Uri uri) {
    final string = uri.toString();
    if (string.contains('youtu') && string.contains('/')) {
      final path = 'http://127.0.0.1:$_port/youtube?id=';
      if (string.contains('/watch?v=')) {
        return Uri.parse(
            path + string.substring(string.indexOf('=') + 1).split('&').first);
      } else {
        return Uri.parse(path + string.substring(string.indexOf('.be/') + 4));
      }
    }
    return uri;
  }

  static bool isExternalMedia(Uri uri) =>
      uri.toString().contains('youtu') && uri.toString().contains('/');

  static String artwork(
    Uri uri, {
    bool small = false,
  }) {
    final string = uri.toString();
    if (string.contains('youtu') && string.contains('/')) {
      // YouTube links of the form https://www.youtube.com/watch?v=abcdefghijk.
      if (string.contains('/watch?v=')) {
        return 'https://i.ytimg.com/vi/${string.substring(string.indexOf('=') + 1).split('&').first}/${small ? 'mqdefault' : 'maxresdefault'}.jpg';
      }
      // Re-directed YouTube links of the form https://127.0.0.1:6900/youtube?id=abcdefghijk.
      else if (string.contains('127.0.0.1')) {
        return 'https://i.ytimg.com/vi/${uri.toString().split('=').last}/${small ? 'mqdefault' : 'maxresdefault'}.jpg';
      }
      // YouTube links of the form https://youtu.be/abcdefghijk/.
      else {
        return 'https://i.ytimg.com/vi/${string.substring(string.indexOf('.be/') + 4).split('/').first}/${small ? 'mqdefault' : 'maxresdefault'}.jpg';
      }
    }
    throw FormatException();
  }
}