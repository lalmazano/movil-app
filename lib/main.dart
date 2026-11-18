import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final servicios = await crearServicios();
  runApp(
    ClubDelFrijolApp(repository: servicios.repository, auth: servicios.auth),
  );
}
