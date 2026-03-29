abstract class CoreModelBase<ID> {
  ID get uuid;

  Map<String, dynamic> toJson();
}
