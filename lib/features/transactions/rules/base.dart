import '../model.dart';
import '../repository.dart';

abstract class TransactionsRulesBase {
  final TransactionsModel tx;
  final TransactionsRepository txRepo;
  final bool silent;

  TransactionsRulesBase(this.tx, this.txRepo, this.silent);

  Future<bool> validate();
}
