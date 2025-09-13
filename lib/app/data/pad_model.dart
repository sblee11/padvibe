class Pad {
  final String name;
  final int? color;
  final String? path;

  const Pad({
    required this.name,
    this.path,
    this.color = 0xFFB0BEC5, // grey
  });

  Pad copyWith({String? name, String? path, int? color}) {
    return Pad(
      name: name ?? this.name,
      path: path ?? this.path,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'path': path, 'color': color};

  factory Pad.fromJson(Map<String, dynamic> json) {
    return Pad(
      name: (json['name'] as String?) ?? 'Pad',
      path: json['path'] as String?,
      color: (json['color'] as int?) ?? 0xFFB0BEC5,
    );
  }
}
