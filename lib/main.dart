import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

String svgImage = "images/postwoman_bg.svg";
String videoAsset = "videos/postwoman_video.mp4";

class HistoryItem {
  final String method;
  final String url;
  final String body;
  final Map<String, String> headers;
  final int statusCode;
  final String responseBody;
  final int responseTimeMs;
  final double responseSizeKB;
  final DateTime timestamp;
  final String contentType;

  HistoryItem({
    required this.method,
    required this.url,
    required this.body,
    required this.headers,
    required this.statusCode,
    required this.responseBody,
    required this.responseTimeMs,
    required this.responseSizeKB,
    required this.timestamp,
    this.contentType = 'text/plain',
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Post Woman',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 0, 0),
        ),
      ),
      home: const MyHomePage(title: 'Post Woman'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Store headers as key-value pairs
  Map<String, String> headers = {};
  // Store request body as JSON string
  String requestBody = '';
  // Store request method and URL
  String requestMethod = 'GET';
  String requestUrl = '';

  // Loading state and response
  String _responseBody = '';
  String _responseContentType = 'text/plain';
  int _statusCode = 0;
  int _responseTimeMs = 0;
  double _responseSizeKB = 0;

  // Video player controller
  VideoPlayerController? _videoController;

  // Request history
  final List<HistoryItem> _history = [];

  // Drag tracking for gestures
  double _dragStartY = 0;
  double _dragCurrentY = 0;
  bool _isGestureHandled = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.asset(videoAsset);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
    } catch (e) {
      // Video player not supported on this platform, fallback to no video
      debugPrint('Video player initialization failed: $e');
      _videoController = null;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // Send API request
  bool _validateRequest() {
    if (requestUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL first by tapping on the basket'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    if (requestMethod == 'POST' || requestMethod == 'PUT') {
      if (requestBody.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Body is required for $requestMethod requests, Add body tapping on body and try again',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return false;
      }

      try {
        jsonDecode(requestBody);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON format in request body'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _sendApiRequest() async {
    if (!_validateRequest()) return;

    // Start video playback
    if (_videoController != null) {
      if (!_videoController!.value.isInitialized) {
        await _videoController!.initialize();
      }
      await _videoController!.setLooping(true);
      await _videoController!.play();
    }

    // Show loading overlay
    _showLoadingOverlay();

    // Give more time for the video to start and UI to settle
    await Future.delayed(const Duration(milliseconds: 500));

    final stopwatch = Stopwatch()..start();

    try {
      http.Response response;
      final uri = Uri.parse(requestUrl);
      final requestHeaders = {'Content-Type': 'application/json', ...headers};

      switch (requestMethod) {
        case 'GET':
          response = await http.get(uri, headers: requestHeaders);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: requestHeaders,
            body: requestBody.isNotEmpty ? requestBody : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: requestHeaders,
            body: requestBody.isNotEmpty ? requestBody : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: requestHeaders);
          break;
        default:
          response = await http.get(uri, headers: requestHeaders);
      }

      stopwatch.stop();
      _responseTimeMs = stopwatch.elapsedMilliseconds;
      _statusCode = response.statusCode;
      _responseBody = response.body;
      _responseContentType = response.headers['content-type'] ?? 'text/plain';

      // Calculate approximate size in KB
      _responseSizeKB = response.bodyBytes.length / 1024.0;

      // Try to format JSON if possible
      try {
        final jsonData = jsonDecode(response.body);
        _responseBody = const JsonEncoder.withIndent('  ').convert(jsonData);
      } catch (_) {
        // Not JSON, keep as is
      }

      // Add to history
      _addToHistory();
    } catch (e) {
      _statusCode = 0;
      _responseBody = 'Error: ${e.toString()}';
      _addToHistory(); // Record errors too
    }

    // Stop video
    _videoController?.pause();
    _videoController?.seekTo(Duration.zero);

    // Close loading overlay and show response
    if (mounted) {
      Navigator.of(context).pop();
      _showResponseDialog();
    }
  }

  void _addToHistory() {
    setState(() {
      _history.insert(
        0,
        HistoryItem(
          method: requestMethod,
          url: requestUrl,
          body: requestBody,
          headers: Map.from(headers),
          statusCode: _statusCode,
          responseBody: _responseBody,
          responseTimeMs: _responseTimeMs,
          responseSizeKB: _responseSizeKB,
          timestamp: DateTime.now(),
          contentType: _responseContentType,
        ),
      );
      if (_history.length > 5) {
        _history.removeLast();
      }
    });
  }

  void _showLoadingOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) => WillPopScope(
        onWillPop: () async => false,
        child: _LoadingOverlayVideo(
          controller: _videoController,
          method: requestMethod,
          url: requestUrl,
        ),
      ),
    );
  }

  // Show response dialog
  void _showResponseDialog() {
    final isSuccess = _statusCode >= 200 && _statusCode < 300;
    final statusColor = isSuccess ? Colors.green.shade400 : Colors.red.shade400;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        final topPadding =
            kToolbarHeight + MediaQuery.of(context).padding.top + 8;
        return AlertDialog(
          alignment: Alignment.topCenter,
          insetPadding: EdgeInsets.fromLTRB(12, topPadding, 12, 24),
          backgroundColor: Colors.black.withOpacity(0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: statusColor, width: 1.5),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : Icons.error,
                        color: statusColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'STATUS: $_statusCode',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.white70,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _responseBody));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        tooltip: 'Copy',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.share,
                          color: Colors.white70,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Share.share(_responseBody, subject: 'API Response');
                        },
                        tooltip: 'Share',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('TIME', '${_responseTimeMs}ms'),
                    Container(width: 1, height: 16, color: Colors.white24),
                    _buildMetric(
                      'SIZE',
                      '${_responseSizeKB.toStringAsFixed(2)}KB',
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _ResponseViewer(
              body: _responseBody,
              contentType: _responseContentType,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CLOSE',
                style: TextStyle(
                  color: Colors.deepPurple.shade200,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.deepPurpleAccent),
            const SizedBox(width: 8),
            Text(
              'Recent History',
              style: TextStyle(color: Colors.deepPurple.shade100),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _history.isEmpty
              ? const Center(
                  child: Text(
                    'No history yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final isSuccess =
                        item.statusCode >= 200 && item.statusCode < 300;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.method,
                                style: TextStyle(
                                  color: isSuccess
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.url,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Status: ${item.statusCode} • ${item.responseTimeMs}ms • ${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            requestMethod = item.method;
                            requestUrl = item.url;
                            requestBody = item.body;
                            headers = Map.from(item.headers);
                            _responseBody = item.responseBody;
                            _responseContentType = item.contentType;
                            _statusCode = item.statusCode;
                            _responseTimeMs = item.responseTimeMs;
                            _responseSizeKB = item.responseSizeKB;
                            Navigator.pop(context);
                            _showResponseDialog();
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Colors.deepPurple.shade200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Show dialog for adding headers
  void _showHeadersDialog() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
          ),
          title: Text(
            'Add Headers',
            style: TextStyle(color: Colors.deepPurple.shade100),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Header Key',
                    labelStyle: TextStyle(color: Colors.deepPurple.shade200),
                    hintText: 'e.g., Content-Type',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.deepPurple.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.shade100,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Header Value',
                    labelStyle: TextStyle(color: Colors.deepPurple.shade200),
                    hintText: 'e.g., application/json',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.deepPurple.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.shade100,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (headers.isNotEmpty) ...[
                  Text(
                    'Current Headers:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade100,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...headers.entries.map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${e.key}: ${e.value}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                headers.remove(e.key);
                              });
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.deepPurple.shade200),
              ),
            ),
            TextButton(
              onPressed: () {
                if (keyController.text.isNotEmpty &&
                    valueController.text.isNotEmpty) {
                  setState(() {
                    headers[keyController.text] = valueController.text;
                  });
                  setDialogState(() {
                    keyController.clear();
                    valueController.clear();
                  });
                }
              },
              child: Text(
                'Add',
                style: TextStyle(color: Colors.deepPurple.shade100),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done',
                style: TextStyle(color: Colors.green.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog for adding request body
  void _showBodyDialog() {
    final bodyController = TextEditingController(text: requestBody);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
        ),
        title: Text(
          'Add Request Body',
          style: TextStyle(color: Colors.deepPurple.shade100),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: bodyController,
            maxLines: 10,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'JSON Body',
              labelStyle: TextStyle(color: Colors.deepPurple.shade200),
              hintText: '{\n  "key": "value"\n}',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.deepPurple.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.deepPurple.shade100,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.deepPurple.shade200),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                requestBody = bodyController.text;
              });
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: TextStyle(color: Colors.deepPurple.shade100),
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog for request method and URL
  void _showMethodUrlDialog() {
    final urlController = TextEditingController(text: requestUrl);
    String selectedMethod = requestMethod;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
          ),
          title: Text(
            'Request Method & URL',
            style: TextStyle(color: Colors.deepPurple.shade100),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  dropdownColor: Colors.black.withOpacity(0.95),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'HTTP Method',
                    labelStyle: TextStyle(color: Colors.deepPurple.shade200),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.deepPurple.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.shade100,
                        width: 2,
                      ),
                    ),
                  ),
                  items: ['GET', 'POST', 'PUT', 'DELETE']
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(
                            method,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Request URL *',
                    labelStyle: TextStyle(color: Colors.deepPurple.shade200),
                    hintText: 'https://api.example.com/endpoint',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.deepPurple.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.shade100,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'URL is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.deepPurple.shade200),
              ),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    requestMethod = selectedMethod;
                    requestUrl = urlController.text;
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Save',
                style: TextStyle(color: Colors.deepPurple.shade100),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade900.withOpacity(0.8),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.deepPurpleAccent.withOpacity(0.3),
            height: 1.0,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (details) {
          _dragStartY = details.globalPosition.dy;
          _dragCurrentY = details.globalPosition.dy;
          _isGestureHandled = false;
        },
        onVerticalDragUpdate: (details) {
          _dragCurrentY = details.globalPosition.dy;
        },
        onVerticalDragEnd: (details) {
          if (_isGestureHandled) return;

          final velocity = details.primaryVelocity ?? 0;
          final screenHeight = MediaQuery.of(context).size.height;
          final displacement = _dragCurrentY - _dragStartY;

          // Swipe up detected (negative displacement and velocity means upward)
          // Only trigger request if starting from the bottom 50% of the screen
          if (displacement < -50 &&
              velocity < -200 &&
              _dragStartY > screenHeight * 0.5) {
            debugPrint(
              'Swipe up detected - Displacement: $displacement, Velocity: $velocity',
            );
            _isGestureHandled = true;
            _sendApiRequest();
          }
          // Swipe down detected (positive displacement and velocity means downward)
          // Only trigger history if starting from the top 50% of the screen
          else if (displacement > 50 &&
              velocity > 200 &&
              _dragStartY < screenHeight * 0.5) {
            debugPrint(
              'Swipe down detected - Displacement: $displacement, Velocity: $velocity',
            );
            _isGestureHandled = true;
            _showHistoryDialog();
          }
        },
        child: Stack(
          children: [
            // SVG Background
            Positioned.fill(
              child: SvgPicture.asset(svgImage, fit: BoxFit.cover),
            ),
            // Tap zones overlay - using Positioned.fill to ensure it covers the entire area
            Positioned.fill(
              child: Column(
                children: [
                  // Blue Cap Area - Headers (top ~20%)
                  Expanded(
                    flex: 20,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint('Cap tapped - Headers');
                        _showHeadersDialog();
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Body Area - Request Body (middle ~30%)
                  Expanded(
                    flex: 25,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint('Body tapped - Request Body');
                        _showBodyDialog();
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Basket Area - Method & URL (bottom ~50%)
                  Expanded(
                    flex: 55,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint('Basket tapped - Method & URL');
                        _showMethodUrlDialog();
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
            // Swipe hint at bottom
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_up, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Swipe up to send request',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
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
}

// New dedicated widget for the loading overlay to handle video playback reliably
class _ResponseViewer extends StatefulWidget {
  final String body;
  final String contentType;

  const _ResponseViewer({required this.body, required this.contentType});

  @override
  State<_ResponseViewer> createState() => _ResponseViewerState();
}

class _ResponseViewerState extends State<_ResponseViewer> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isJson = widget.contentType.contains('application/json');
    bool isHtml = widget.contentType.contains('text/html');

    return Column(
      children: [
        Row(
          children: [
            _buildTab(0, 'Formatted'),
            _buildTab(1, 'Raw'),
            if (isHtml) _buildTab(2, 'Preview'),
          ],
        ),
        const Divider(color: Colors.white12),
        Expanded(
          child: _tabIndex == 1
              ? SingleChildScrollView(
                  child: SelectableText(
                    widget.body,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                )
              : _buildFormattedView(isJson, isHtml),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    bool active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Colors.deepPurpleAccent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.deepPurpleAccent : Colors.white70,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedView(bool isJson, bool isHtml) {
    if (_tabIndex == 2 && isHtml) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: HtmlWidget(
            widget.body,
            textStyle: const TextStyle(color: Colors.black87),
          ),
        ),
      );
    }

    if (isJson) {
      // Try to format it for display if it's not already
      String displayBody = widget.body;
      try {
        final jsonData = jsonDecode(widget.body);
        displayBody = const JsonEncoder.withIndent('  ').convert(jsonData);
      } catch (_) {}

      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HighlightView(
            displayBody,
            language: 'json',
            theme: atomOneDarkTheme,
            padding: const EdgeInsets.all(12),
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }

    if (isHtml) {
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HighlightView(
            widget.body,
            language: 'html',
            theme: atomOneDarkTheme,
            padding: const EdgeInsets.all(12),
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: SelectableText(
        widget.body,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LoadingOverlayVideo extends StatefulWidget {
  final VideoPlayerController? controller;
  final String method;
  final String url;

  const _LoadingOverlayVideo({
    required this.controller,
    required this.method,
    required this.url,
  });

  @override
  State<_LoadingOverlayVideo> createState() => _LoadingOverlayVideoState();
}

class _LoadingOverlayVideoState extends State<_LoadingOverlayVideo> {
  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  void _startPlayback() async {
    if (widget.controller != null) {
      if (!widget.controller!.value.isInitialized) {
        await widget.controller!.initialize();
      }
      await widget.controller!.setLooping(true);
      await widget.controller!.play();
      // Force a rebuild once playback starts
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: widget.controller == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : ValueListenableBuilder(
              valueListenable: widget.controller!,
              builder: (context, VideoPlayerValue value, child) {
                if (value.isInitialized) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: value.size.width,
                            height: value.size.height,
                            child: VideoPlayer(widget.controller!),
                          ),
                        ),
                      ),
                      _buildHeaderBar(),
                      _buildOverlayText(),
                    ],
                  );
                } else {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepPurple,
                        ),
                      ),
                      _buildHeaderBar(),
                      _buildOverlayText(),
                    ],
                  );
                }
              },
            ),
    );
  }

  Widget _buildHeaderBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade900, Colors.black],
          ),
        ),
        child: const Center(
          child: Text(
            'POST WOMAN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayText() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sending ${widget.method} request...',
                style: TextStyle(
                  color: Colors.deepPurple.shade100,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.url,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
