import 'dart:io';

import 'package:flutter/services.dart';

bool get isDesktopLike =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

void exitApp() {
  if (Platform.isAndroid) {
    SystemNavigator.pop();
  } else {
    exit(0);
  }
}
