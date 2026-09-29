import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/export_provider.dart';

/// Starts the export when shown and pops with the final [ExportState].
class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  var _cancelling = false;

  @override
  void initState() {
    super.initState();
    // Start after the first frame so the listener below sees every change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(exportProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(exportProvider, (previous, next) {
      final wasRunning = previous?.status == ExportStatus.running;
      if (wasRunning && next.status != ExportStatus.running) {
        Navigator.of(context).pop(next);
      }
    });
    final state = ref.watch(exportProvider);
    final running = state.status == ExportStatus.running;
    final progress = state.total == 0 ? null : state.done / state.total;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_cancelling ? 'キャンセルしています' : '書き出し中'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${state.done} / ${state.total}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: running ? progress : null),
            const SizedBox(height: 12),
            Text(
              '元の解像度で1枚ずつ処理しています',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelling || !running
                ? null
                : () {
                    setState(() => _cancelling = true);
                    ref.read(exportProvider.notifier).cancel();
                  },
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }
}
