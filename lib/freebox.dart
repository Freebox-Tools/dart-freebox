// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

// Créez une instance de HttpClient qui ignore les erreurs de certificat
HttpClient createHttpClient() {
  var client = HttpClient();
  client.badCertificateCallback =
      (X509Certificate cert, String host, int port) => true;
  return client;
}

// Utilisez cette instance pour créer un IOClient personnalisé
final ioClient = IOClient(createHttpClient());

class FreeboxClient {
  bool verbose;
  String apiDomain;
  int? httpsPort;
  String appId;
  String appToken;
  String apiBaseUrl;
  HttpClient httpClient;
  String? sessionToken;

  FreeboxClient({
    this.verbose = false,
    this.apiDomain = 'mafreebox.freebox.fr',
    this.httpsPort,
    required this.appId,
    required this.appToken,
    this.apiBaseUrl = '/api/',
  }) : httpClient = HttpClient() {
    // Désactiver la vérification des certificats
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    if (verbose) print('Freebox client initialized!');
  }

  static Future<dynamic> registerFreebox({
    bool verbose = true,
    String appId = 'fbx.example',
    String appName = 'Exemple',
    String appVersion = '1.0.0',
    String deviceName = 'DartClient',
  }) async {
    var client = HttpClient();

    // Désactiver la vérification des certificats
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    // Vérifier la connexion au serveur
    var request = await client
        .getUrl(Uri.parse('http://mafreebox.freebox.fr/api/v8/api_version'));
    var response = await request.close();

    if (response.statusCode != 200) {
      if (verbose) {
        print(
            'Impossible de joindre le serveur de votre Freebox (mafreebox.freebox.fr). Êtes-vous bien connecté au même réseau que votre Freebox ?');
      }
      return 'UNREACHABLE';
    }

    var responseBody = await response.transform(utf8.decoder).join();
    var freebox = jsonDecode(responseBody);

    if (freebox['api_base_url'] == null || freebox['box_model'] == null) {
      if (verbose) {
        print(
            'Impossible de récupérer les informations de votre Freebox. ${freebox['msg'] ?? freebox}');
      }
      return 'CANNOT_GET_INFOS';
    }
    if (verbose) {
      print(
          "Un message s'affichera dans quelques instants sur l'écran de votre Freebox Server pour permettre l'autorisation.");
    }
    var authorizeRequest = await ioClient.post(
      Uri.parse('https://mafreebox.freebox.fr/api/v8/login/authorize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'app_id': appId,
        'app_name': appName,
        'app_version': appVersion,
        'device_name': deviceName
      }),
    );
    if (authorizeRequest.statusCode != 200) {
      if (verbose) {
        print('Impossible de demander l\'autorisation à votre Freebox.');
      }
      return 'CANNOT_ASK_AUTHORIZATION';
    }

    var register = jsonDecode(authorizeRequest.body);

    if (register?['success'] != true) {
      if (verbose) {
        print(
            'Impossible de demander l\'autorisation à votre Freebox. ${register['msg']}');
      }
      return 'CANNOT_ASK_AUTHORIZATION';
    }

    // Obtenir le token
    var appToken = register['result']?['app_token'];
    if (appToken == null) {
      if (verbose) {
        print('Impossible de récupérer le token de votre Freebox.');
      }
      return 'CANNOT_GET_TOKEN';
    }
    var status = 'pending';
    while (status == 'pending') {
      await Future.delayed(const Duration(seconds: 2));
      var statusRequest = await ioClient.get(
        Uri.parse(
            'https://mafreebox.freebox.fr/api/v8/login/authorize/${register['result']?['track_id']}'),
      );

      if (statusRequest.statusCode != 200) {
        if (verbose) {
          print('Impossible de récupérer le statut de l\'autorisation.');
        }
        return 'CANNOT_GET_AUTHORIZATION_STATUS';
      }
      var statusResponse = jsonDecode(statusRequest.body);
      status = statusResponse['result']?['status'];
    }

    if (status != 'granted') {
      if (verbose) {
        print(
            "Impossible de se connecter à votre Freebox. L'accès ${status == 'timeout' ? 'a expiré' : status == 'denied' ? "a été refusé par l'utilisateur" : ''}.");
      }
      return "ACCESS_NOT_GRANTED_BY_USER";
    }

    if (verbose) {
      print('Vous êtes maintenant connecté à votre Freebox !');
    }
    return print({
      'appToken': appToken,
      'appId': appId,
      'apiDomain': freebox['api_domain'],
      'httpsPort': freebox['https_port'],
    });
  }

  Future<dynamic> fetch({
    required String url,
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
    bool parseJson = true,
  }) async {
    if (!url.startsWith('http')) {
      if (url.startsWith("/")) url = url.substring(1);
      url =
          'https://$apiDomain${httpsPort != null ? ':$httpsPort' : ''}$apiBaseUrl$url';
    }
    if (verbose) print('Request URL: $url');

    var uri = Uri.parse(url);
    var requestHeaders = {
      'Content-Type': 'application/json',
      if (sessionToken != null) 'X-Fbx-App-Auth': sessionToken!,
      ...?headers
    };

    // Création d'un client HTTP qui ignore la vérification des certificats
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    IOClient ioClient = IOClient(httpClient);

    // Timeout de 7 secondes
    try {
      http.BaseRequest request;
      if (method == 'GET') {
        request = http.Request(method, uri);
      } else {
        request = http.Request(method, uri)..body = jsonEncode(body);
      }
      request.headers.addAll(requestHeaders);

      var streamedResponse = await ioClient.send(request).timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          if (verbose) print('Request timed out');
          throw TimeoutException('Error: Timeout');
        },
      );

      if (streamedResponse.statusCode != 200) {
        String responseBody = await streamedResponse.stream.bytesToString();
        dynamic json;
        try {
          json = jsonDecode(responseBody);
        } catch (err) {
          json = {};
        }

        // Si on essayait de s'authentifier
        if (verbose) print("Fetch error: ${json['error']}");
        if (url.endsWith("login/session")) {
          return print({
            "success": false,
            "msg": json['error'] ?? streamedResponse.reasonPhrase
          });
        }

        // Si l'erreur n'est pas liée à l'authentification
        if (json['error_code'] == 'auth_required') {
          return print({"success": false, "msg": "Authentification requise"});
        }

        // On s'authentifie
        if (verbose) print("Réhautentification...");
        var auth = await authentificate();
        if (auth?['success'] != true) return print(auth);

        // On refait la requête
        if (verbose) print("Nouvelle requête...");
        return fetch(url: url, method: method, headers: headers, body: body);
      } else {
        if (!parseJson) {
          return await streamedResponse.stream.toBytes();
        } else {
          String responseBody = await streamedResponse.stream.bytesToString();
          try {
            return jsonDecode(responseBody);
          } catch (e) {
            if (verbose) print('Error decoding JSON: $e');
            return responseBody;
          }
        }
      }
    } catch (e) {
      if (verbose) print('Error during fetch: $e');
      return {"success": false, "msg": e.toString()};
    } finally {
      ioClient.close();
      httpClient.close();
    }
  }

  Future authentificate() async {
    dynamic freebox;
    // Obtenir le challenge
    var challenge = await fetch(url: 'v8/login/', method: 'GET');

    if (verbose)
      print(
          "Challenge: ${challenge?['result']?['challenge'] ?? challenge?['msg'] ?? challenge}");
    if (challenge?['success'] != true) return print(challenge);

    // Si on a pas de challenge
    if (challenge['result']?['challenge'] == null) {
      // Si on est déjà connecté
      if (challenge['result']?['logged_in'] == true) {
        // On fait une requête qui nécessite d'être connecté
        if (verbose)
          print("Vous avez l'air d'être déjà connecté, 2e vérification...");

        var freeboxSystem = await fetch(url: 'v8/system');
        if (verbose) print("Freebox system: $freeboxSystem");

        // Si ça a fonctonné, on est connecté
        if (freeboxSystem?['success'] == true) {
          return print({"success": true, "freebox": freebox});
        }

        // Sinon on dit que le challenge n'a pas fonctionné
        return print({
          "success": false,
          "msg":
              "Impossible de récupérer le challenge pour une raison inconnue ${challenge['msg'] ?? challenge['message'] ?? challenge['result']?['msg'] ?? challenge['result']?['message'] ?? challenge['status_code']}"
        });
      }
    }

    var passwordHash = Hmac(sha1, utf8.encode(appToken))
        .convert(utf8.encode(challenge['result']?['challenge']))
        .toString();

    if (verbose) print("Password hash: $passwordHash");

    // S'authentifier
    var auth = await fetch(
      url: 'v8/login/session',
      method: 'POST',
      body: {'app_id': appId, 'password': passwordHash},
    );

    if (verbose)
      print(
          "Auth: ${auth?['success']} ${auth?['result']?['session_token'] ?? auth?['msg'] ?? auth}");
    if (auth?['success'] != true) return print(auth);

    // On définit le token de session
    if (verbose) print("Authentification réussie !");
    sessionToken = auth['result']?['session_token'];

    // On récupère les infos de la Freebox
    freebox = await fetch(url: 'v8/api_version');

    if (verbose) print("Infos de la freebox obtenus: $freebox");
    return {"success": true, "freebox": freebox};
  }
}
