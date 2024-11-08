// lib/main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:html' as html;
import '';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // add this line
  usePathUrlStrategy();
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mozart AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1DB954),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        // URL'i al ve parse et
        final uri = Uri.parse(html.window.location.href);
        var fileParam = uri.queryParameters['file'];

        print('Original URL: ${html.window.location.href}');
        print('File parameter from URL: $fileParam');

        if (fileParam != null) {
          // index.html'i URL'den temizle
          fileParam = fileParam.replaceAll('/index.html', '');

          // Firebase URL'ini düzelt
          if (!fileParam.contains('%2F')) {
            try {
              final firebaseUri = Uri.parse(fileParam);
              if (firebaseUri.path.contains('/o/')) {
                final parts = firebaseUri.path.split('/o/');
                final encodedPath = '${parts[0]}/o/${Uri.encodeComponent(parts[1])}';
                fileParam = firebaseUri.replace(path: encodedPath).toString();
              }
            } catch (e) {
              print('URL parsing error: $e');
            }
          }

          print('Cleaned file parameter: $fileParam');
        }

        return MusicPlayer(fileParam: fileParam);
      },
    ),
    // index.html route'unu ekle
    GoRoute(
      path: '/index.html',
      redirect: (context, state) {
        final uri = Uri.parse(html.window.location.href);
        final fileParam = uri.queryParameters['file'];

        // Query parametrelerini koruyarak ana sayfaya yönlendir
        if (fileParam != null) {
          return '/?file=$fileParam';
        }
        return '/';
      },
    ),
  ],
);

class MusicPlayer extends StatefulWidget {
  final String? fileParam;

  const MusicPlayer({super.key, this.fileParam});
  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _title = 'Mozart AI';
  String _author = '';
  String _imageUrl = '';
  String _mp3Url = '';
  String _lyrics = '';
  bool _showFullLyrics = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    if (widget.fileParam != null) {
      print('Loading content from URL: ${widget.fileParam}');
      _loadContentFromUrl(widget.fileParam!);
    }
    _setupMetaTags();
  }

  void _setupMetaTags() {
    _updateMetaTags(
      title: _title,
      description: 'Listen to AI generated music',
      imageUrl: _imageUrl,
    );
  }

  void _updateMetaTags({
    required String title,
    required String description,
    String? imageUrl,
  }) {
    void _setMetaTag(String property, String content) {
      var element = html.document.querySelector('meta[property="$property"]');
      if (element != null) {
        element.setAttribute('content', content);
      } else {
        final meta = html.MetaElement()
          ..setAttribute('property', property)
          ..setAttribute('content', content);
        html.document.head?.append(meta);
      }
    }

    _setMetaTag('og:title', title);
    _setMetaTag('og:description', description);
    if (imageUrl != null) {
      _setMetaTag('og:image', imageUrl);
    }
    _setMetaTag('og:type', 'music.song');

    // Twitter Cards
    _setMetaTag('twitter:card', 'summary_large_image');
    _setMetaTag('twitter:title', title);
    _setMetaTag('twitter:description', description);
    if (imageUrl != null) {
      _setMetaTag('twitter:image', imageUrl);
    }
  }

  Future<void> _loadContentFromUrl(String fileParam) async {
    print('Loading URL: $fileParam');
    try {
      String jsonData;

      if (fileParam == 'test_song.json') {
        jsonData = _getTestData();
      } else {
        final fixedUrl = fileParam.contains('%2F') ? fileParam : fileParam.replaceAll('/', '%2F');
        final response = await http.get(Uri.parse(fixedUrl));

        // UTF-8 decode işlemi
        jsonData = utf8.decode(response.bodyBytes);
      }

      final songData = json.decode(jsonData);

      setState(() {
        _title = _decodeText(songData['title'] ?? 'Mozart AI');
        _author = _decodeText(songData['author'] ?? '');
        _imageUrl = songData['img'] ?? '';
        _mp3Url = songData['mp3'] ?? '';
        _lyrics = _decodeText(songData['lyric'] ?? '');

        // Debug çıktıları
        print('Decoded title: $_title');
        print('Decoded lyrics: $_lyrics');
      });

      _updateMetaTags(
        title: _title,
        description: 'Now playing: $_title by $_author',
        imageUrl: _imageUrl,
      );

      if (_mp3Url.isNotEmpty) {
        await _audioPlayer.setUrl(_mp3Url);
      }
    } catch (e, stackTrace) {
      print('Error loading content: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _title = 'Error Loading Song';
        _lyrics = 'An error occurred while loading the song. Please try again later.';
      });
    }
  }

  // UTF-8 decode yardımcı fonksiyonu
  String _decodeText(String text) {
    try {
      // Önce mevcut encoding'i tespit et
      if (_isUtf8Encoded(text)) {
        return text;
      }

      // Latin1'den UTF-8'e çevir
      final bytes = latin1.encode(text);
      return utf8.decode(bytes);
    } catch (e) {
      print('Decode error: $e');
      return text;
    }
  }

  // UTF-8 kontrol fonksiyonu
  bool _isUtf8Encoded(String text) {
    try {
      return utf8.decode(utf8.encode(text)) == text;
    } catch (e) {
      return false;
    }
  }

  String _getTestData() {
    return '''
    {
      "title": "Test Song",
      "author": "Mozart AI",
      "mp3": "https://www2.cs.uic.edu/~i101/SoundFiles/BabyElephantWalk60.wav",
      "img": "https://picsum.photos/300/300",
      "lyric": "This is a test song\\nCreated by Mozart AI\\nFor testing purposes\\nHope you enjoy it!"
    }
    ''';
  }

  Future<void> _initializePlayer() async {
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });

    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(0xFF2B3D7A).withOpacity(0.4),
            Color(0xFF750026),
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Column(
          children: [
            _buildBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildAlbumArt(),
                      _buildSongInfo(),
                      _buildProgressBar(),
                      _buildPlayControls(),
                      _buildLyrics(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: () => _handleUniversalLink('/banner/open'),
        child: Row(
          children: [
            Image.network(
              'assets/mozartLogo.jpg',
              height: 40,
              width: 40,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make Your Own Music & AI Song',
                    style: TextStyle(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Turn your photos into a song!',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _launchAppStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22264B),
                foregroundColor: Colors.white,
              ),
              child: const Text('GET'),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildHeader() {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double maxWidth = constraints.maxWidth;
      final double fontSize = maxWidth > 600 
          ? 48.0 
          : MediaQuery.of(context).size.height * 0.056;

      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: maxWidth > 600 ? 48.0 : 24.0,
        ),
        child: Text(
          'Mozart AI',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    },
  );
}

Widget _buildAlbumArt() {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double maxWidth = constraints.maxWidth;
      final double artSize = maxWidth > 600 ? 400 : maxWidth * 0.9;
      final double artHeight = maxWidth > 600 ? 400 : maxWidth * 0.6;

      return _imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _imageUrl,
                height: artHeight,
                width: artSize,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              height: artHeight,
              width: artSize,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note, size: 100, color: Colors.white54),
            );
    },
  );
}

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_author.isNotEmpty)
                  Text(
                    'by $_author',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _shareUrl,
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareUrl,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: _position.inSeconds.toDouble(),
            max: _duration.inSeconds.toDouble(),
            onChanged: (value) {
              final position = Duration(seconds: value.toInt());
              _audioPlayer.seek(position);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: CircleAvatar(
        radius: 35,
        backgroundColor: Colors.white,
        child: IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 40,
          color: Colors.black,
          onPressed: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.play();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLyrics() {
    if (_lyrics.isEmpty) return const SizedBox.shrink();

    final shortLyrics = _lyrics.split('\n').take(2).join('\n');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22264B), Color(0xFF2B3D7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lyrics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showFullLyrics = !_showFullLyrics;
                  });
                },
                child: Text(
                  _showFullLyrics ? 'Show Less' : 'Show More',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          Text(
            _showFullLyrics ? _lyrics : '$shortLyrics...',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          if (_showFullLyrics)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: GestureDetector(
                  onTap: _launchAppStore,
                  child: Image.network(
                    'assets/appstore.png',
                    height: 50,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _shareUrl() {
    final url = html.window.location.href;
    Share.share(url);
  }

  void _handleUniversalLink(String path) {
    final universalLink = 'https://mozartai.app$path'; // Domain adınızı ekleyin
    html.window.location.href = universalLink;
  }

// _launchAppStore() methodunu güncelleyin
  void _launchAppStore() {
    final appStoreLink = 'https://apps.apple.com/app/apple-store/id6502656704?pt=126985321&ct=Banner&mt=8';
    html.window.location.href = appStoreLink;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class TextDecoder {
  static String decode(String text) {
    try {
      // Farklı encoding'leri dene
      final decoders = [
        () => utf8.decode(latin1.encode(text)),
        () => utf8.decode(ascii.encode(text)),
        () => latin1.decode(utf8.encode(text)),
        () => text,
      ];

      for (var decoder in decoders) {
        try {
          final decoded = decoder();
          if (_isReadable(decoded)) {
            return decoded;
          }
        } catch (e) {
          continue;
        }
      }

      return text;
    } catch (e) {
      print('Decode error: $e');
      return text;
    }
  }

  static bool _isReadable(String text) {
    // Türkçe karakterleri kontrol et
    final turkishChars = RegExp(r'[ğüşıöçĞÜŞİÖÇ]');
    return turkishChars.hasMatch(text) || text.contains(RegExp(r'[A-Za-z0-9]'));
  }
}
