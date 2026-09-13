import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/api_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

/// Handler pour les messages reçus en arrière-plan (top-level obligatoire)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être initialisé même en background
  await Firebase.initializeApp();
  // Pas besoin d'afficher une notif ici : FCM le fait automatiquement
  // quand l'app est en arrière-plan ou fermée.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 1. Initialiser Firebase
  await Firebase.initializeApp();

  // 2. Enregistrer le handler background (doit être fait avant runApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Initialiser le client API (token stocké en secure storage)
  await ApiClient().init();

  // 4. Initialiser le service de notifications (permissions + FCM token)
  await NotificationService().init();

  runApp(const ProviderScope(child: DobokApp()));
}

class DobokApp extends ConsumerWidget {
  const DobokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Do-Bok CI',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
