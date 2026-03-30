import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../features/cryptos/model.dart';
import '../../features/cryptos/controller.dart';
import '../notify.dart';

class WidgetsFieldsCryptoSearch extends FormField<int> {
  WidgetsFieldsCryptoSearch({
    super.key,
    super.initialValue,
    super.validator,
    bool? enabled,
    bool allowClean = true,
    bool allowCopy = true,
    Function(int cryptoId)? onSelected,
    String labelText = "Crypto",
    String hintText = "Search by name, symbol, or ID...",
  }) : super(
         builder: (FormFieldState<int> state) {
           return _WidgetsFieldsCryptoSearchBody(
             initialValue: initialValue,
             labelText: labelText,
             hintText: hintText,
             enabled: enabled,
             allowClean: allowClean,
             allowCopy: allowCopy,
             onSelected: (id) {
               state.didChange(id);
               if (onSelected != null) {
                 onSelected(id);
               }
             },
             validator: validator,
           );
         },
       );
}

class _WidgetsFieldsCryptoSearchBody extends StatefulWidget {
  final Function(int)? onSelected;
  final int? initialValue;
  final String labelText;
  final String hintText;
  final bool? enabled;
  final bool allowClean;
  final bool allowCopy;
  final FormFieldValidator<int>? validator;

  const _WidgetsFieldsCryptoSearchBody({
    required this.onSelected,
    required this.initialValue,
    required this.labelText,
    required this.hintText,
    required this.enabled,
    required this.validator,
    this.allowClean = true,
    this.allowCopy = true,
  });

  @override
  State<_WidgetsFieldsCryptoSearchBody> createState() => _WidgetsFieldsCryptoSearchBodyState();
}

class _WidgetsFieldsCryptoSearchBodyState extends State<_WidgetsFieldsCryptoSearchBody> {
  late TextEditingController _controller;
  late CryptosController _cryptosController;
  List<CryptosModel> _allCryptos = [];

  bool get _shouldShowSuffix => widget.enabled ?? true && (widget.allowClean || widget.allowCopy);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _cryptosController = locator<CryptosController>();
    _cryptosController.addListener(_loadCryptos);

    _loadCryptos().then((_) {
      if (widget.initialValue != null) {
        final crypto = _cryptosController.get(widget.initialValue!.toString());
        if (crypto != null) {
          _controller.text = '${crypto.symbol} (#${crypto.uuid})';
        }
      }
    });
  }

  Future<void> _loadCryptos() async {
    setState(() {
      _allCryptos = _cryptosController.items;
    });
  }

  Future<List<CryptosModel>> _getSearchSuggestions(String query) async {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _allCryptos.where((crypto) => crypto.searchKey.contains(lowerQuery)).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cryptosController.removeListener(_loadCryptos);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadFormField<CryptosModel>(
          textFieldConfiguration: TextFieldConfiguration(
            enabled: widget.enabled ?? true,
            controller: _controller,
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
          ),
          validator: _validateFromText,
          suggestionsCallback: (pattern) async {
            return await _getSearchSuggestions(pattern);
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
          onSuggestionSelected: (CryptosModel suggestion) {
            _controller.text = '${suggestion.symbol} (#${suggestion.uuid})';
            if (widget.onSelected != null) {
              widget.onSelected!.call(suggestion.uuid);
            }
          },

          noItemsFoundBuilder: (context) {
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
