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

  bool get isFetching => service.isFetching;

  Future<void> init() async {
    await repo.init();
    notifyListeners();
  }

  List<CryptosModel> get items => repo.getAll();

  Future<void> add(CryptosModel crypto) async {
    await repo.add(crypto);
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await repo.delete(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await repo.clear();
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
    return repo.getSymbolMap();
  }

  String? getSymbol(int id) {
    return repo.getSymbol(id);
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
