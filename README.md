# ETIKPRO

**Étiquettes de traçabilité & documents commerciaux** — application Flutter (Android, Windows, Web) proposée en SaaS par **OMZAKREVO INFORMATIQUE** — *Toujours une solution !*

Conçue pour les entreprises qui conditionnent et livrent des produits (abattoirs de poulets, boucheries, poissonneries, traiteurs…) : chaque colis reçoit une petite étiquette avec les informations de traçabilité, et l'entreprise gère ses devis, factures, bordereaux et décharges dans la même application.

---

## 1. Étiquettes

Sur chaque étiquette :

- nom de l'entreprise (sur bande noire) et numéro(s) de téléphone ;
- nom du produit ;
- **date d'abattage** (libellé modifiable : fabrication, production, pêche…) ;
- **date de péremption** — calculée automatiquement (date d'abattage + durée), modifiable ;
- **température de conservation** (ex. 0 °C à +4 °C) ;
- **durée de conservation** (ex. 5 jours) ;
- en option : n° de lot (généré automatiquement), poids, prix, mention (Halal…), QR code de traçabilité.

Marges de 1 mm : l'étiquette se colle directement sur le sachet. Les lignes trop longues sont réduites automatiquement, jamais coupées.

### Formats d'impression

| Type | Formats | Impression |
|---|---|---|
| Imprimante d'étiquettes Bluetooth (TSPL : Xprinter, HPRT, Gprinter, TSC…) | 40×30, 50×30, 50×40, 60×40, 70×50 mm | Directe depuis Android / Windows |
| Imprimante ticket thermique (ESC/POS) | 58 mm, 80 mm (papier adhésif) | Directe depuis Android / Windows |
| Planches A4 autocollantes | 14, 21, 24 ou 40 étiquettes par feuille | Imprimante classique (PDF) |

- Nombre de copies au choix (1, 5, 10, 20, 50…).
- Planches A4 entamées : on indique le nombre de cases déjà utilisées.
- Réglages imprimante : densité, vitesse, espace entre étiquettes, seuil noir/blanc, inversion.
- Historique d'impression (traçabilité : produit, dates, lot, quantité, heure).
- Sur le Web : impression par la boîte d'impression du navigateur (pilote de l'imprimante d'étiquettes) ou PDF.

## 2. Documents commerciaux

- **Devis**, **facture proforma**, **facture définitive**, **bordereau de livraison**, **décharge**.
- Transformation en un clic : devis → proforma → facture → bordereau → décharge (le document d'origine garde la trace « converti en … »).
- Numérotation automatique par type et par année : `DV-2026-0001`, `PF-…`, `FA-…`, `BL-…`, `DC-…` (préfixes modifiables).
- Remise par ligne et remise globale, TVA, total **en toutes lettres** (« Arrêtée la présente facture à la somme de … francs CFA »).
- **En-tête en image** et **pied de page en image** (répétés sur chaque page), ou bloc texte avec logo.
- Clients enregistrés, statut (brouillon, envoyé, payé…), duplication, partage / impression PDF A4.

### Modèles

- 6 modèles intégrés (Classique bleu, Moderne vert, Minimal noir, Élégant bordeaux, Dynamique orange, Bordereau simple) et 4 styles d'étiquettes.
- Modèle par défaut au choix pour chaque type de document.
- **Import de modèles en JSON** (fichier ou copier-coller) et export de n'importe quel modèle.
- Exemple complet : [`modeles/exemple_modeles.json`](modeles/exemple_modeles.json).

Format d'un modèle de document :

```json
{
  "kind": "document",
  "id": "boucherie_rouge",
  "name": "Boucherie rouge",
  "docTypes": ["devis", "proforma", "facture"],
  "primaryColor": "#B22222",
  "accentColor": "#FBECEC",
  "font": "helvetica",
  "tableStyle": "striped",
  "titleStyle": "band",
  "titleAlign": "right",
  "showAmountInWords": true,
  "signatureLeft": "Le client",
  "signatureRight": "Le gérant",
  "footerText": "Merci pour votre confiance !"
}
```

| Champ | Valeurs |
|---|---|
| `docTypes` | `devis`, `proforma`, `facture`, `bordereau`, `decharge` (vide = tous) |
| `font` | `helvetica`, `times`, `courier` |
| `tableStyle` | `striped`, `grid`, `minimal` |
| `titleStyle` | `band`, `underline`, `plain` |
| `titleAlign` | `left`, `center`, `right` |
| autres | `showLogo`, `showCompanyBlock`, `showSignatures`, `headerMaxHeightMm`, `footerMaxHeightMm`, `marginMm`, `fontSize`, `textColor` |

Format d'un style d'étiquette : `"kind": "etiquette"` avec `companyBand`, `showPhone`, `showQr`, `showBorder`, `showWeight`, `showLot`, `showPrice`, `fontScale`, `expiryLabel`, `tempLabel`, `durationLabel`.

Un fichier peut contenir un modèle seul, une liste, ou `{ "modeles": [ … ] }`.

## 3. Licences (SaaS gérées par GitHub — sans base de données)

Chaque entreprise cliente reçoit une **clé de licence** (`ETK-XXXX-XXXX-XXXX-XXXX`). L'application la vérifie dans un fichier `licences.json` publié dans un dépôt GitHub **public** :

```
https://raw.githubusercontent.com/omzakrevo/etikpro-licences/main/licences.json
```

(adresse modifiable dans `lib/core/licence.dart` › `LicenceConfig.url`)

- Le fichier ne contient que l'**empreinte SHA-256** des clés : publier le fichier ne révèle aucune clé.
- Pour chaque licence : entreprise, date d'expiration, formule (`complet` ou `etiquettes`), actif/suspendu, et éventuellement la liste des appareils autorisés.
- Hors connexion, l'application reste utilisable **15 jours** après la dernière vérification (jamais au-delà de l'expiration).
- L'identifiant de l'appareil est affiché sur l'écran de licence et dans Réglages : il sert à limiter une licence à certains appareils.

### Gérer les licences

**Depuis le téléphone :** ouvrez `licences/admin.html` (par exemple publié sur GitHub Pages du dépôt `etikpro-licences`). La page génère la clé et le bloc JSON à coller dans `licences.json` via l'éditeur GitHub.

**Depuis le PC :**

```bash
dart run tools/licence_admin.dart nouvelle "Volaille du Faso" 2027-10-31 complet
dart run tools/licence_admin.dart prolonger ETK-XXXX-XXXX-XXXX-XXXX 2028-10-31
dart run tools/licence_admin.dart suspendre ETK-XXXX-XXXX-XXXX-XXXX
dart run tools/licence_admin.dart reactiver ETK-XXXX-XXXX-XXXX-XXXX
dart run tools/licence_admin.dart appareil  ETK-XXXX-XXXX-XXXX-XXXX 3F9A12BC
dart run tools/licence_admin.dart liste
```

Puis poussez `licences/licences.json` dans le dépôt `etikpro-licences`. Les applications prennent le changement en compte à leur prochaine ouverture.

## 4. Données

Les données de chaque entreprise (produits, clients, documents, modèles, historique) restent **sur ses appareils** (stockage local Hive, aussi sur le Web). Réglages › Sauvegarde permet d'exporter / restaurer toutes les données dans un fichier JSON.

## 5. Compilation

GitHub Actions (`.github/workflows/build.yml`) compile à chaque push sur `main` :

- **APK Android** → artefact `ETIKPRO-android` ;
- **Windows** → artefact `ETIKPRO-windows` (zip) ;
- **Web** → publié sur GitHub Pages (Settings › Pages › Source : *GitHub Actions*).

Un tag `v1.0.0` crée une *Release* avec l'APK et le zip Windows.

En local :

```bash
flutter pub get
flutter test
flutter run -d windows   # ou -d chrome, ou un téléphone Android
```

## 6. Structure

```
lib/
  core/        modèles, stockage, licence GitHub, polices PDF, montants en lettres
  label/       rendu des étiquettes, commandes TSPL / ESC/POS, Bluetooth
  docs/        génération PDF des documents commerciaux
  ui/          écrans (étiquettes, documents, clients, réglages, licence)
tools/         outil d'administration des licences
licences/      licences.json + page admin.html (à mettre dans le dépôt etikpro-licences)
modeles/       exemples de modèles JSON
assets/fonts/  polices Liberation (licence SIL OFL)
```
