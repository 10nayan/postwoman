import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String svgImage = "images/postwoman_bg.svg";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Postwoman',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Postwoman'),
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

  // Show dialog for adding headers
  void _showHeadersDialog() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.1),
        title: const Text('Add Headers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Header Key',
                hintText: 'e.g., Content-Type',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Header Value',
                hintText: 'e.g., application/json',
              ),
            ),
            const SizedBox(height: 16),
            if (headers.isNotEmpty) ...[
              const Text('Current Headers:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...headers.entries.map((e) => Text('${e.key}: ${e.value}')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (keyController.text.isNotEmpty && valueController.text.isNotEmpty) {
                setState(() {
                  headers[keyController.text] = valueController.text;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
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
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text('Add Request Body'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: bodyController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'JSON Body',
              hintText: '{\n  "key": "value"\n}',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                requestBody = bodyController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
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
          backgroundColor: Colors.white.withOpacity(0.9),
          title: const Text('Request Method & URL'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'HTTP Method',
                  ),
                  items: ['GET', 'POST', 'PUT', 'DELETE']
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ))
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
                  decoration: const InputDecoration(
                    labelText: 'Request URL *',
                    hintText: 'https://api.example.com/endpoint',
                    border: OutlineInputBorder(),
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          // SVG Background
          Positioned.fill(
            child: SvgPicture.asset(
              svgImage,
              fit: BoxFit.cover,
            ),
          ),
          // Tap zones overlay - using Positioned.fill to ensure it covers the entire area
          Positioned.fill(
            child: Column(
              children: [
                // Blue Cap Area - Headers (top 20%)
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint('Cap tapped - Headers');
                      _showHeadersDialog();
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                // Body Area - Request Body (middle 40%)
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint('Body tapped - Request Body');
                      _showBodyDialog();
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                // Basket Area - Method & URL (bottom 40%)
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint('Basket tapped - Method & URL');
                      _showMethodUrlDialog();
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
