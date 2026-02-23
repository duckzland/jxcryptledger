import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../core/locator.dart';
import 'model.dart';
import 'repository.dart';

class CryptoSearchField extends FormField<int> {
  CryptoSearchField({
    super.key,
    super.initialValue,
    required Function(int cryptoId) onSelected,
    super.validator,
    String labelText = "Crypto",
    String hintText = "Search by name, symbol, or ID...",
  }) : super(
         builder: (FormFieldState<int> state) {
           return _CryptoSearchFieldBody(
             initialValue: initialValue,
             labelText: labelText,
             hintText: hintText,
             onSelected: (id) {
               state.didChange(id);
               onSelected(id);
             },
             errorText: state.errorText,
           );
         },
       );
}

class _CryptoSearchFieldBody extends StatefulWidget {
  final Function(int) onSelected;
  final int? initialValue;
  final String labelText;
  final String hintText;
  final String? errorText;

  const _CryptoSearchFieldBody({
    required this.onSelected,
    required this.initialValue,
    required this.labelText,
    required this.hintText,
    required this.errorText,
  });

  @override
  State<_CryptoSearchFieldBody> createState() => _CryptoSearchFieldBodyState();
}

class _CryptoSearchFieldBodyState extends State<_CryptoSearchFieldBody> {
  late TextEditingController _controller;
  late CryptosRepository _cryptosRepo;
  List<CryptosModel> _allCryptos = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _cryptosRepo = locator<CryptosRepository>();
    _loadCryptos().then((_) {
      if (widget.initialValue != null) {
        final crypto = _cryptosRepo.getById(widget.initialValue!);
        if (crypto != null) {
          _controller.text = '${crypto.id}|${crypto.symbol} - ${crypto.name}';
        }
      }
    });
  }

  Future<void> _loadCryptos() async {
    final cryptos = _cryptosRepo.getAll();
    setState(() {
      _allCryptos = cryptos;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<CryptosModel>(
          textFieldConfiguration: TextFieldConfiguration(
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          suggestionsCallback: (pattern) async {
            return await _getSearchSuggestions(pattern);
          },
          itemBuilder: (context, CryptosModel suggestion) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('${suggestion.id}|${suggestion.symbol} - ${suggestion.name}'),
            );
          },
          onSuggestionSelected: (CryptosModel suggestion) {
            _controller.text = '${suggestion.id}|${suggestion.symbol} - ${suggestion.name}';
            widget.onSelected(suggestion.id);
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

        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(widget.errorText!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ),
      ],
    );
  }
}
