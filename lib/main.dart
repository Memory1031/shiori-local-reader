import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app/production_app.dart';
export 'app/app.dart' show ShioriApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'WHATWG Encoding indexes',
    ], await rootBundle.loadString('assets/licenses/whatwg-encoding.txt'));
    yield LicenseEntryWithLineBreaks([
      'archive bundled components',
    ], await rootBundle.loadString('assets/licenses/archive-other.txt'));
  });
  runApp(const ProductionApp());
}
