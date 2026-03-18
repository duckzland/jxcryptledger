import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class CryptosController extends ChangeNotifier {
  final CryptosRepository repo;
  final CryptosService service;

  CryptosController(this.repo, this.service);

  bool get isFetching => service.isFetching;

  Future<void> init() async {
    await repo.init();
    notifyListeners();
  }

  List<CryptosModel> _items = [];
  List<CryptosModel> get items => _items;

  Future<void> load() async {
    _items = await repo.getAll();
    notifyListeners();
  }

  Future<void> add(CryptosModel crypto) async {
    await repo.add(crypto);
    await load();
  }

  Future<void> deleteById(int id) async {
    await repo.deleteById(id);
    await load();
  }

  Future<void> clear() async {
    await repo.clear();
    await load();
  }

  Future<void> flush() async {
    await repo.flush();
    await load();
  }

  List<CryptosModel> filter(String query) {
    return repo.filter(query);
  }

  bool isEmpty() {
    return repo.isEmpty();
  }

  Map<int, String> getSymbolMap() {
    return repo.getSymbolMap();
  }

  String? getSymbol(int id) {
    return repo.getSymbol(id);
  }

  Future<List<CryptosModel>> getAll() async {
    return await repo.getAll();
  }

  List<CryptosModel> extract() {
    return items;
  }

  CryptosModel? getById(int id) {
    return repo.getById(id);
  }

  Future<bool> fetch() async {
    try {
      final success = await service.fetch();

      if (success) {
        await load();
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
