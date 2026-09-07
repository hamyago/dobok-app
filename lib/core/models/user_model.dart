class UserModel {
  final int id;
  final String nom;
  final String prenom;
  final String telephone;
  final String role;
  final int? clubId;
  final String? clubNom;
  final String? token;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.role,
    this.clubId,
    this.clubNom,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String role, String token) {
    return UserModel(
      id: json['id'],
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      role: role,
      clubId: json['club_id'] ?? json['club']?['id'],
      clubNom: json['club']?['nom'],
      token: token,
    );
  }

  String get fullName => '$nom $prenom';
}
