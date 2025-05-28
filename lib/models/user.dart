class User {
  final String id;
  final String name;
  final String email;
  final int notesCount;
  final int foldersCount;
  final String? avatar;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.notesCount = 0,
    this.foldersCount = 0,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      notesCount: json['notesCount'] ?? 0,
      foldersCount: json['foldersCount'] ?? 0,
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'notesCount': notesCount,
      'foldersCount': foldersCount,
      'avatar': avatar,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    int? notesCount,
    int? foldersCount,
    String? avatar,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      notesCount: notesCount ?? this.notesCount,
      foldersCount: foldersCount ?? this.foldersCount,
      avatar: avatar ?? this.avatar,
    );
  }
}