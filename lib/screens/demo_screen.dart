// ABOUTME: Main demo screen with tab navigation
// ABOUTME: Container for Connect, Sign, and Encrypt tabs (independent operations)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/demo_provider.dart';
import 'step1_connect.dart';
import 'step2_sign.dart';
import 'step3_encrypt.dart';

class DemoScreen extends ConsumerStatefulWidget {
  const DemoScreen({super.key});

  @override
  ConsumerState<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends ConsumerState<DemoScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final signingMode = ref.watch(signingModeProvider);
    final isConnected = session != null && session.hasRpcAccess;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keycast Flutter Demo'),
        actions: [
          if (isConnected) ...[
            // Mode toggle chips
            ChoiceChip(
              label: const Text('RPC'),
              selected: signingMode == SigningMode.rpc,
              onSelected: (_) => ref.read(signingModeProvider.notifier).setMode(SigningMode.rpc),
              selectedColor: AppTheme.primaryGreen,
              labelStyle: TextStyle(
                color: signingMode == SigningMode.rpc ? Colors.black : AppTheme.textSecondary,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('Bunker'),
              selected: signingMode == SigningMode.bunker,
              onSelected: (_) => ref.read(signingModeProvider.notifier).setMode(SigningMode.bunker),
              selectedColor: AppTheme.primaryGreen,
              labelStyle: TextStyle(
                color: signingMode == SigningMode.bunker ? Colors.black : AppTheme.textSecondary,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            // Connected indicator
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Connected',
                    style: TextStyle(color: AppTheme.successGreen),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: const [
          Step1Connect(),
          Step2Sign(),
          Step3Encrypt(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        backgroundColor: AppTheme.cardBackground,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.login),
            label: 'Connect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Sign',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lock),
            label: 'Encrypt',
          ),
        ],
      ),
    );
  }
}
