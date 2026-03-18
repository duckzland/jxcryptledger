abstract class CoreBaseModel<ID> {
  ID get uuid;

  Map<String, dynamic> toJson();
}
