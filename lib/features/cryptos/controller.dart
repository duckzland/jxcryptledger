import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class CryptosController extends ChangeNotifier {
  final CryptosRepository _repo;
  final CryptosService _service;

  CryptosController(this._repo, this._service);

  bool get isFetching => _service.isFetching;

  Future<void> init() async {
    await _repo.init();
    load();
  }

  List<CryptosModel> _items = [];
  List<CryptosModel> get items => _items;

  void start() {
    _items = _repo.getAll();
  }

  void load() {
    start();
    notifyListeners();
  }

  Future<void> add(CryptosModel crypto) async {
    await _repo.add(crypto);
    load();
  }

  Future<void> deleteById(int id) async {
    await _repo.deleteById(id);
    load();
  }

  Future<void> clear() async {
    await _repo.clear();
    load();
  }

  Future<void> flush() async {
    await _repo.flush();
    load();
  }

  List<CryptosModel> filter(String query) {
    return _repo.filter(query);
  }

  bool isEmpty() {
    return _repo.isEmpty();
  }

  Map<int, String> getSymbolMap() {
    return _repo.getSymbolMap();
  }

  String? getSymbol(int id) {
    return _repo.getSymbol(id);
  }

  List<CryptosModel> extract() {
    return items;
  }

  CryptosModel? getById(int id) {
    return _repo.getById(id);
  }

  Future<bool> fetch() async {
    try {
      final success = await _service.fetch();

      if (success) {
        load();
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
