class AthleteModel {
  final int id;
  final int clubId;
  final String nom;
  final String prenom;
  final String? telephone;
  final String? email;
  final String? dateNaissance;
  final String? lieuNaissance;
  final String? nationalite;
  final String? sexe;
  final String ceinture;
  final String? numeroLicence;
  final String? licenceQr;
  final String? passeportNumero;
  final String? assuranceStatut;
  final String? assuranceSaison;
  final String? autorisationParentaleStatut;
  final bool? saisonValidee;
  final String? saisonAnnee;
  final bool actif;
  final String? photoUrl;

  AthleteModel({
    required this.id, required this.clubId, required this.nom, required this.prenom,
    this.telephone, this.email, this.dateNaissance, this.lieuNaissance,
    this.nationalite, this.sexe, required this.ceinture, this.numeroLicence,
    this.licenceQr, this.passeportNumero, this.assuranceStatut, this.assuranceSaison,
    this.autorisationParentaleStatut, this.saisonValidee, this.saisonAnnee,
    this.actif = true, this.photoUrl,
  });

  factory AthleteModel.fromJson(Map<String, dynamic> j) => AthleteModel(
    id: j['id'], clubId: j['club_id'], nom: j['nom'] ?? '', prenom: j['prenom'] ?? '',
    telephone: j['telephone'], email: j['email'], dateNaissance: j['date_naissance'],
    lieuNaissance: j['lieu_naissance'], nationalite: j['nationalite'], sexe: j['sexe'],
    ceinture: j['ceinture_actuelle'] ?? 'blanche', numeroLicence: j['numero_licence'],
    licenceQr: j['licence_qr'], passeportNumero: j['passeport_numero'],
    assuranceStatut: j['assurance_statut'], assuranceSaison: j['assurance_saison'],
    autorisationParentaleStatut: j['autorisation_parentale_statut'],
    saisonValidee: j['saison_sportive_validee'], saisonAnnee: j['saison_sportive_annee'],
    actif: j['actif'] ?? true, photoUrl: j['photo_url'],
  );

  String get fullName => '$nom $prenom'.trim();
  String get initiale => nom.isNotEmpty ? nom[0].toUpperCase() : '?';
}
