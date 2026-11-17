import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;


String friendlyError(Object error, {String? what}) {
  final reason = _reason(error);
  final base = what == null ? reason : '$what. $reason';
  if (!kDebugMode) return base;

  var detail = '${error.runtimeType}: $error';
  if (detail.length > 140) detail = '${detail.substring(0, 140)}…';
  return '$base\n[debug] $detail';
}

String _reason(Object e) {
  if (e is SocketException || e is http.ClientException) {
    return 'Sin conexión a internet.';
  }
  if (e is TimeoutException) {
    return 'El servidor tardó demasiado en responder.';
  }
  if (e is TlsException) {
    return 'No se pudo establecer una conexión segura.';
  }
  if (e is FormatException) {
    return 'El servicio devolvió una respuesta inesperada.';
  }

  final code = RegExp(r'\b([45]\d\d)\b').firstMatch(e.toString())?.group(1);
  if (code != null) {
    if (code == '429') {
      return 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.';
    }
    if (code.startsWith('5')) {
      return 'El servicio no está disponible ahora. Inténtalo más tarde.';
    }
    return 'El servicio rechazó la solicitud.';
  }
  return 'Ocurrió un problema inesperado.';
}

void logError(String where, Object error, [StackTrace? stack]) {
  if (!kDebugMode) return;
  debugPrint('[$where] $error');
  if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 6);
}