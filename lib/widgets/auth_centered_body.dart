import 'package:flutter/material.dart';

import 'auth_form_layout.dart';

/// Keeps [core] on the vertical center; [header] above and [footer] below.
class AuthCenteredBody extends StatelessWidget {
  const AuthCenteredBody({
    super.key,
    required this.header,
    required this.core,
    required this.footer,
    this.maxWidth = 400,
    this.horizontalPadding = 24,
  });

  final Widget header;
  final Widget core;
  final Widget footer;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            32,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: AuthFormLayout(
              maxWidth: maxWidth,
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: header,
                    ),
                  ),
                  core,
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: footer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
