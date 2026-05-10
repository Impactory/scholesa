import 'package:flutter/material.dart';
import '../theme/scholesa_theme.dart';

/// Loading indicator widget
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (message != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.schTextSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
