import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/needs_provider.dart';
import 'providers/task_provider.dart';
import 'providers/volunteer_provider.dart';
import 'providers/map_provider.dart';
import 'providers/prediction_provider.dart';
import 'services/notification_service.dart';
import 'models/need_model.dart';
import 'screens/admin/assign_volunteer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init();
  runApp(const CrisisConnectApp());
}

class CrisisConnectApp extends StatelessWidget {
  const CrisisConnectApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NeedsProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => VolunteerProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => PredictionProvider()),
      ],
      child: MaterialApp(
        title: 'CrisisConnect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
          onGenerateRoute: (settings) {
       if (settings.name == AppRoutes.assignVolunteer) {
      final need = settings.arguments as NeedModel;
      return MaterialPageRoute(
        builder: (_) => AssignVolunteerScreen(need: need));
    }
    return null;
  },
      ),
    );
  }
}