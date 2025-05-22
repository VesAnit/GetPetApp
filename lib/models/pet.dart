class Pet {
  final int id;
  final String animalType;
  final String? name;
  final String gender;
  final int? age;
  final String? breed;
  final String? color;

  Pet({
    required this.id,
    required this.animalType,
    this.name,
    required this.gender,
    this.age,
    this.breed,
    this.color,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    print('Parsing Pet JSON: $json'); // Отладка
    return Pet(
      id: json['id'] as int? ?? 0,
      animalType: json['animal_type'] as String? ?? '',
      name: json['name'] as String?,
      gender: json['gender'] as String? ?? '',
      age: json['age'] as int?,
      breed: json['breed'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'animal_type': animalType,
        'name': name,
        'gender': gender,
        'age': age,
        'breed': breed,
        'color': color,
      };
}
