// Oggetto già inviato a SAP dal pianificatore: il backend risponde 409
// `{ error, inviatoSap: true }` a status, note, esito e riassegnazione.
// Non è un errore da ritentare: la copia che conta ormai è quella in SAP.

import 'package:dio/dio.dart';

import 'failures.dart';

const kMessaggioInviatoSap =
    'Già inviato a SAP dal pianificatore: non è più modificabile dal tablet.';

bool eInviatoSap(Object e) {
  if (e is! DioException || e.response?.statusCode != 409) return false;
  final data = e.response?.data;
  return data is Map && data['inviatoSap'] == true;
}

InviatoSapFailure inviatoSapFailure(DioException e) {
  final data = e.response?.data;
  final msg = data is Map && data['error'] != null
      ? data['error'].toString()
      : kMessaggioInviatoSap;
  return InviatoSapFailure(msg);
}
