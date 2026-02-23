import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../core/locator.dart';
import 'model.dart';
import 'repository.dart';

class CryptoSearchField extends StatefulWidget {
  final Function(int cryptoId) onSelected;
  final int? initialValue;
  final String labelText;
  final String hintText;

  const CryptoSearchField({
    super.key,
    required this.onSelected,
    this.initialValue,
    this.labelText = "Crypto",
    this.hintText = "Search by name, symbol, or ID...",
  });

  @override
  State<CryptoSearchField> createState() => _CryptoSearchFieldState();
}

class _CryptoSearchFieldState extends State<CryptoSearchField> {
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
    final cryptos = await _cryptosRepo.getAll();
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
    return TypeAheadField<CryptosModel>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          // Triggers search automatically with debounce
        },
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
        return Padding(padding: const EdgeInsets.all(8.0), child: Text('No cryptos found'));
      },
      loadingBuilder: (context) {
        return Padding(padding: const EdgeInsets.all(8.0), child: CircularProgressIndicator());
      },
      debounceDuration: const Duration(milliseconds: 50),
      hideOnEmpty: true,
      hideOnLoading: false,
      autoFlipDirection: true,
    );
  }
}
