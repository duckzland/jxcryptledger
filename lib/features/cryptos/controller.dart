// cryptos_controller.dart
import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class CryptosController extends ChangeNotifier {
  final CryptosRepository repo;
  final CryptosService service;

  Map<int, String>? _symbolCache;

  CryptosController(this.repo, this.service);

  Future<void> init() async {
    await repo.init();
    _symbolCache = null;
    notifyListeners();
  }

  List<CryptosModel> get items => repo.getAll();

  Future<void> add(CryptosModel crypto) async {
    await repo.add(crypto);
    _symbolCache = null;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await repo.delete(id);
    _symbolCache = null;
    notifyListeners();
  }

  Future<void> clear() async {
    await repo.clear();
    _symbolCache = null;
    notifyListeners();
  }

  Future<void> flush() async {
    await repo.flush();
    notifyListeners();
  }

  List<CryptosModel> filter(String query) {
    return repo.filter(query);
  }

  bool hasAny() {
    return repo.hasAny();
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) return _symbolCache!;
    _symbolCache = repo.getSymbolMap();
    return _symbolCache!;
  }

  String? getSymbol(int id) {
    return getSymbolMap()[id];
  }

  List<CryptosModel> getAll() {
    return repo.getAll();
  }

  CryptosModel? getById(int id) {
    return repo.getById(id);
  }

  Future<bool> fetch() async {
    try {
      final success = await service.fetch();

      if (success) {
        _symbolCache = null;
        notifyListeners();
      }

      return success;
    } on NetworkingException {
      rethrow;
    } catch (e) {
      throw NetworkingException(
        AppErrorCode.netUnknownFailure,
        "CryptosController fetch failed unexpectedly: $e",
        "Unable to update crypto data due to an unexpected error.",
        details: e,
      );
    }
  }
}
