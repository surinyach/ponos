import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/models/focus_area.dart';
import 'state/focus_areas_controller.dart';

Future<bool> restoreArchivedFocusArea(
  BuildContext context,
  WidgetRef ref,
  FocusArea area,
) async {
  final success = await ref.read(focusAreasProvider.notifier).restore(area.id);
  if (!success && context.mounted) {
    _showFailure(context, ref.read(focusAreasProvider).error);
  }
  return success;
}

Future<bool> deleteArchivedFocusArea(
  BuildContext context,
  WidgetRef ref,
  FocusArea area, {
  required bool blockedByTimer,
}) async {
  if (blockedByTimer) {
    _showFailure(
      context,
      const _ArchivedActionException(
        'This Focus Area cannot be deleted while its timer is active or paused.',
      ),
    );
    return false;
  }

  final firstConfirmation = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Permanently delete ${area.name}?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete permanently'),
        ),
      ],
    ),
  );
  if (firstConfirmation != true || !context.mounted) return false;

  final controller = ref.read(focusAreasProvider.notifier);
  try {
    final hasHistory = await controller.hasHistoricalWork(area.id);
    if (!context.mounted) return false;
    var confirmedHistory = false;
    if (hasHistory) {
      confirmedHistory =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete historical work too?'),
              content: const Text(
                'This Focus Area has recorded work. Its target history, manual entries, and timer executions will also be permanently deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep Focus Area'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete all permanently'),
                ),
              ],
            ),
          ) ==
          true;
      if (!confirmedHistory) return false;
    }

    final success = await controller.permanentlyDelete(
      area.id,
      confirmHistoricalWork: confirmedHistory,
    );
    if (!success && context.mounted) {
      _showFailure(context, ref.read(focusAreasProvider).error);
    }
    return success;
  } catch (error) {
    if (context.mounted) _showFailure(context, error);
    return false;
  }
}

void _showFailure(BuildContext context, Object? error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(_errorMessage(error))),
  );
}

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ArchivedActionException exception => exception.message,
  _ => 'The archived Focus Area action could not be completed.',
};

class _ArchivedActionException implements Exception {
  const _ArchivedActionException(this.message);

  final String message;
}
