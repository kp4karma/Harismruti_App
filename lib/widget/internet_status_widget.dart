import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Tracks connectivity without placing a modal barrier over the application.
class InternetStatusWidget extends StatefulWidget {
  const InternetStatusWidget({super.key});

  static final ValueNotifier<bool> isConnected = ValueNotifier<bool>(true);

  @override
  State<InternetStatusWidget> createState() => InternetStatusWidgetState();
}

class InternetStatusWidgetState extends State<InternetStatusWidget> {
  late final Stream<List<ConnectivityResult>> _internetStream;

  @override
  void initState() {
    super.initState();
    _internetStream = Connectivity().onConnectivityChanged;
    Connectivity().checkConnectivity().then(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    InternetStatusWidget.isConnected.value =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _internetStream,
      builder: (context, snapshot) {
        final results = snapshot.data;
        if (results != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateStatus(results);
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}
