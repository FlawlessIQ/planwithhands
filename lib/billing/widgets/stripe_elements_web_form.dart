// Web-only: Hosts Stripe Elements with separate number/expiry/cvc fields
// Use dart:ui_web for platformViewRegistry on Flutter Web
import 'dart:ui_web' as ui; // for platformViewRegistry
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

typedef CompletionChanged = void Function(bool complete);

class StripeElementsWebForm extends StatefulWidget {
  final String publishableKey;
  final CompletionChanged onChanged;
  final EdgeInsets padding;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final String? clientSecretToConfirm; // optional, if provided we can confirm

  const StripeElementsWebForm({
    super.key,
    required this.publishableKey,
    required this.onChanged,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = const Color(0xFFF6F7F9),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.clientSecretToConfirm,
  });

  @override
  State<StripeElementsWebForm> createState() => _StripeElementsWebFormState();
}

class _StripeElementsWebFormState extends State<StripeElementsWebForm> {
  late final String _viewType;
  late final String _containerId;

  @override
  void initState() {
    super.initState();
    assert(kIsWeb, 'StripeElementsWebForm should only be used on web');
    _viewType = 'hands-stripe-elements-${DateTime.now().millisecondsSinceEpoch}';
    _containerId = '$_viewType-container';

    // Register a view factory for HtmlElementView (web only)
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper =
          html.DivElement()
            ..style.width = '100%'
            ..style.height = '64px'
            ..style.backgroundColor = 'transparent';

      final container =
          html.DivElement()
            ..id = _containerId
            ..style.width = '100%'
            ..style.height = '64px';

      wrapper.children = [container];

      // Mount Stripe Elements once attached to DOM
      _mountElements();
      return wrapper;
    });
  }

  void _mountElements() {
    // Use JS helpers injected in web/index.html
    // ignore: avoid_dynamic_calls
    (html.window as dynamic).handsStripe.mount(
      _containerId,
      // publishable key
      widget.publishableKey,
      {'theme': 'stripe'},
    );

    // Register change listener to propagate completion
    // ignore: avoid_dynamic_calls
    (html.window as dynamic).handsStripe.onChange(_containerId, (bool complete) {
      widget.onChanged(complete);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: widget.borderRadius,
        border: widget.border,
      ),
      padding: widget.padding,
      child: SizedBox(height: 64, child: HtmlElementView(viewType: _viewType)),
    );
  }
}
