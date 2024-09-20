import 'dart:io';

import 'package:freebox/freebox.dart';

void main() async {
  // await FreeboxClient.registerFreebox(
  //   appId: 'fbx.test',
  //   appName: 'Test',
  //   appVersion: '1.0.0',
  //   deviceName: 'DartClient',
  //   verbose: false, // Optionnel, true par défaut
  // );

  // // Connexion
  var client = FreeboxClient(
    appToken: "y8H6scZE5nfWSzkrrtL5v/enYDWRQEIljyo4mx+aM4yP5MOj33fBpuakc+PKvOzp",
    appId: "fbx.test",
    apiDomain: "por3sikw.fbxos.fr",
    httpsPort: 20587,
    verbose: false,
  );

  await client.authentificate();

  var audioData = await client.fetch(
    url: "/v10/call/voicemail/20240819_192643_r0379434986.au/audio_file",
    parseJson: false,
  );
  final file = File('audio_file.wav');
  await file.writeAsBytes(audioData);
}

// 20240819_192643_r0379434986.au