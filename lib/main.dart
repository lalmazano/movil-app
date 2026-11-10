import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/recordatorios/recordatorios.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nunca lanza errores y no hace nada en web.
  await inicializarRecordatorios();
  runApp(const MovilApp());
}
