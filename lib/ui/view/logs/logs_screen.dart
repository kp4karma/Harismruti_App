import 'package:flutter/material.dart';
import 'package:harismruti/helper/log_helper.dart'  show SecureLogger;


class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  String _logContent = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await SecureLogger.readLogs();
    setState(() {
      _logContent = logs.isEmpty ? 'No logs yet.' : logs;
    });
  }

  Future<void> _clearLogs() async {
    await SecureLogger.clearLogs();
    await _loadLogs();
  }

  Future<void> _writeSampleLog() async {
    await SecureLogger.write('🧪 Simulated error for testing');
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Encrypted Log Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: "Refresh Logs",
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: "Clear Logs",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: SelectableText(
            _logContent,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _writeSampleLog,
        label: const Text('Add Test Log'),
        icon: const Icon(Icons.bug_report),
      ),
    );
  }
}
