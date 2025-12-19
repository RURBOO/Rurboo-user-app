import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  StreamSubscription<List<ConnectivityResult>>? subscription;
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_updateStatus);
    subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    if (offline != isOffline && mounted) {
      setState(() => isOffline = offline);
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (isOffline)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 40,
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text("No Internet Connection", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}