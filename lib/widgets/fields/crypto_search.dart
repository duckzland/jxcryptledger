import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../features/cryptos/model.dart';
import '../../features/cryptos/controller.dart';
import '../notify.dart';

class WidgetsFieldsCryptoSearch extends StatefulWidget {
  final Function(int)? onSelected;
  final int? initialValue;
  final String labelText;
  final String hintText;
  final bool enabled;
  final bool allowClean;
  final bool allowCopy;

  const WidgetsFieldsCryptoSearch({
    super.key,
    this.labelText = "Crypto",
    this.hintText = "Search by name, symbol, or ID...",
    this.onSelected,
    this.initialValue,
    this.enabled = true,
    this.allowClean = true,
    this.allowCopy = true,
  });

  @override
  State<WidgetsFieldsCryptoSearch> createState() => _WidgetsFieldsCryptoSearchState();
}

class _WidgetsFieldsCryptoSearchState extends State<WidgetsFieldsCryptoSearch> {
  late TextEditingController _controller;
  late CryptosController _cryptosController;

  bool get _shouldShowSuffix => widget.enabled && (widget.allowClean || widget.allowCopy);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _cryptosController = locator<CryptosController>();
    _cryptosController.addListener(onControllerChange);

    if (widget.initialValue != null) {
      final crypto = _cryptosController.get(widget.initialValue!.toString());
      if (crypto != null) {
        _controller.text = '${crypto.symbol} (#${crypto.uuid})';
      }
    }
  }

  void onControllerChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _cryptosController.removeListener(onControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<CryptosModel>(
          controller: _controller,
          builder: (context, controller, focusNode) {
            return TextFormField(
              enabled: widget.enabled,
              controller: controller,
              focusNode: focusNode,
              validator: _validateFromText,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _shouldShowSuffix
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.allowCopy && _controller.text != "")
                            IconButton(
                              icon: const Icon(Icons.copy),
                              iconSize: 16,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              mouseCursor: SystemMouseCursors.click,
                              tooltip: 'Copy to clipboard',
                              style: ButtonStyle(
                                overlayColor: WidgetStateProperty.all(Colors.transparent),
                                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return AppTheme.action;
                                  }
                                  return AppTheme.textMuted;
                                }),
                                padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
                                minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: _controller.text));
                                widgetsNotifySuccess("${_controller.text} copied to clipboard");
                              },
                            ),

                          if (widget.allowClean && _controller.text != "")
                            IconButton(
                              icon: const Icon(Icons.close),
                              iconSize: 16,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              mouseCursor: SystemMouseCursors.click,
                              tooltip: 'Reset selection',
                              style: ButtonStyle(
                                overlayColor: WidgetStateProperty.all(Colors.transparent),
                                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return AppTheme.error;
                                  }
                                  return AppTheme.textMuted;
                                }),
                                padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
                                minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _controller.text = "";
                                widget.onSelected?.call(-1);
                                setState(() {});
                              },
                            ),

                          const SizedBox(width: 6),
                        ],
                      )
                    : null,
              ),
            );
          },
          suggestionsCallback: (pattern) {
            if (pattern.isEmpty) return [];
            final lowerQuery = pattern.toLowerCase();
            return _cryptosController.filter(lowerQuery);
          },
          itemBuilder: (context, CryptosModel suggestion) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${suggestion.symbol} (#${suggestion.uuid})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    suggestion.name,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
          onSelected: (CryptosModel suggestion) {
            _controller.text = '${suggestion.symbol} (#${suggestion.uuid})';
            widget.onSelected?.call(suggestion.uuid);
          },
          emptyBuilder: (context) {
            return const Padding(padding: EdgeInsets.all(8.0), child: Text('No cryptos found'));
          },
          loadingBuilder: (context) {
            return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator());
          },
          debounceDuration: const Duration(milliseconds: 50),
          hideOnEmpty: true,
          hideOnLoading: false,
          autoFlipDirection: true,
        ),
      ],
    );
  }

  int? extractIdFromText(String text) {
    final match = RegExp(r'\(#(\d+)\)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String? _validateFromText(String? text) {
    if (text == null || text.isEmpty) {
      return 'Crypto is required';
    }

    int? cid = extractIdFromText(text);
    if (cid == null) {
      return 'Invalid crypto';
    }

    if (_cryptosController.getSymbol(cid) == null) {
      return 'Invalid crypto';
    }

    return null;
  }
}
