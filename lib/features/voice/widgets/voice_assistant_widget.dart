import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/voice_agent_state.dart';
import '../viewmodels/voice_agent_viewmodel.dart';

class VoiceAssistantWidget extends StatelessWidget {
  const VoiceAssistantWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume GLOBAL Provider, do not create new one
    final vm = context.watch<VoiceAgentViewModel>();

    // If IDLE, show FAB. If Active, show OVERLAY.
    bool isActive = vm.state != VoiceAgentState.idle;

    return Stack(
      children: [
        // 1. Full Screen Overlay (When Active)
        if (isActive)
          _VoiceOverlay(vm: vm),

        // 2. Floating Action Button (Always visible but morphs)
        if (!isActive)
          Positioned(
            bottom: 20,
            right: 20,
            child: _VoiceFab(vm: vm),
          ),
      ],
    );
  }
}

class _VoiceFab extends StatelessWidget {
  final VoiceAgentViewModel vm;
  const _VoiceFab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => vm.startSession(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 28),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }
}

class _VoiceOverlay extends StatelessWidget {
  final VoiceAgentViewModel vm;
  const _VoiceOverlay({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Status Text
            Text(
              _getStatusText(vm.state),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(vm.state),
              ),
            ).animate().fadeIn(),
            
            // Error Message
            if (vm.lastError != null && vm.state == VoiceAgentState.error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  vm.lastError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 10),

            // Live Transcript
            if (vm.lastRecognizedText.isNotEmpty)
              Text(
                '"${vm.lastRecognizedText}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(),

            const SizedBox(height: 30),

            // Visualizer / Action Button
            GestureDetector(
              onTap: () {
                if (vm.state == VoiceAgentState.speaking) {
                  vm.stopSpeaking();
                } else {
                  vm.stopSession();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getStatusColor(vm.state).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  vm.state == VoiceAgentState.speaking ? Icons.stop : Icons.mic,
                  color: _getStatusColor(vm.state),
                  size: 40,
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 800.ms),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Voice Settings
            if (vm.state == VoiceAgentState.idle || vm.state == VoiceAgentState.listening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    // Wake Word Toggle
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over, size: 20, color: Colors.indigo),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Wake Word ("Hey Rurboo")',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Switch.adaptive(
                          value: vm.wakeWordEnabled,
                          onChanged: (val) => vm.toggleWakeWord(val),
                          activeTrackColor: Colors.indigo,
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    // Continuous Mode Toggle
                    Row(
                      children: [
                        const Icon(Icons.loop, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Continuous Conversation',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Switch.adaptive(
                          value: vm.continuousModeEnabled,
                          onChanged: (val) => vm.toggleContinuousMode(val),
                          activeTrackColor: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => vm.stopSession(),
              child: const Text("Close", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ).animate().slide(begin: const Offset(0, 1), duration: 300.ms, curve: Curves.easeOut),
    );
  }

  String _getStatusText(VoiceAgentState state) {
    switch (state) {
      case VoiceAgentState.listening: return "सुन रहा हूं... (Listening)";
      case VoiceAgentState.processing: return "सोच रहा हूं... (Thinking)";
      case VoiceAgentState.speaking: return "बोल रहा हूं... (Speaking)";
      case VoiceAgentState.sosActivated: return "⚠️ SOS ACTIVATED";
      case VoiceAgentState.error: return "❌ Error - Retrying...";
      case VoiceAgentState.booking: return "🚗 Booking Ride...";
      case VoiceAgentState.confirmingFare: return "💰 Confirm Fare?";
      default: return "Ready";
    }
  }

  Color _getStatusColor(VoiceAgentState state) {
     switch (state) {
      case VoiceAgentState.listening: return Colors.redAccent;
      case VoiceAgentState.processing: return Colors.orange;
      case VoiceAgentState.speaking: return Colors.blue;
      case VoiceAgentState.sosActivated: return Colors.red[900]!;
      default: return Colors.indigo;
    }
  }
}
