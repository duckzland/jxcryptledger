abstract class BaseModel<ID> {
  ID get uuid;

  Map<String, dynamic> toJson();
}
