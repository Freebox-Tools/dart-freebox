> This package is only in French because it is only for certain French internet boxes.

Une librairie pour faciliter l'utilisation de l'API de Freebox OS. Facilite l'authentification et l'envoi de requêtes afin de pouvoir intéragir simplement avec une Freebox.

## Fonctionnalités

L'API de Freebox OS est capable d'exécuter de nombreuses actions sur la box, comme la gestion des téléchargements et des fichiers sur le disque interne, ou la gestion des contacts et des appels sur le téléphone fixe. Cependant, l'authentification et la première connexion (register) sont assez complexes. Cette librairie permet de simplifier ces étapes, pour vous offrir une meilleure expérience de développement.


## Utilisation
Importez la librairie
```dart
import 'package:freebox/freebox.dart';
```
### Enregistrement
Cette étape ne doit être effectuée **qu'une seule fois**, et permet d'obtenir un `appToken`. C'est une étape obligatoire pour utiliser l'API de Freebox OS. L'écran d'affichage de la Freebox demandera à l'utilisateur de confirmer l'opération.

```dart
await FreeboxClient.registerFreebox(
  appId: 'fbx.exemple',
  appName: 'Exemple',
  appVersion: '1.0.0',
  deviceName: 'iOS',
  verbose: true, // Optionnel, true par défaut
);
```

### Authentification
L'étape d'authentification permet d'obtenir un token de session, qui est nécessaire pour effectuer des requêtes à l'API.
```dart
var client = FreeboxClient(
    appToken: "<Obtenu lors de l'enregistrement>",
    appId: "fbx.exemple",
    apiDomain: "<Obtenu lors de l'enregistrement>",
    httpsPort: 0, //  "<Obtenu lors de l'enregistrement>"
    verbose: false, // Optionnel, false par défaut
  );

await client.authentificate();
```

### Requêtes
Une fois authentifié, vous pourrez effectuer des requêtes à l'API de Freebox OS.

```dart
var system = await client.fetch(
    url: "v8/system",
    method: "GET", // Optionnel, GET par défaut
    parseJson: true, // Optionnel, true par défaut
);

print(system); // Affiche les informations système de la Freebox
```
> Le header `Content-Type` est automatiquement défini à `application/json` s'il n'est pas déjà défini.

#### Récupérer un fichier
Pour récupérer un fichier, rien de plus simple :
```dart
var audioData = await client.fetch(
  url: "/v10/call/voicemail/$audioId.au/audio_file",
  parseJson: false, // A ne pas oublier !
 ); 

// Créé un fichier audio_file.wav qui va contenir le fichier audio
final file = File('audio_file.wav');
await file.writeAsBytes(audioData);
```

Ici, on récupère un fichier audio de la messagerie vocale, et on le stocke dans un fichier audio_file.wav.


## Informations supplémentaires

- Vous trouverez la liste des endpoints disponibles dans la documentation de l'API de Freebox OS.

Retrouvez tous nos projets pour Freebox sur le [Github de Freebox Tools](https://github.com/Freebox-Tools)