import 'dart:convert';
import 'dart:io';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';

void main() async {
  final credentialsJson = await File('assets/credentials.json').readAsString();
  final credentials = ServiceAccountCredentials.fromJson(json.decode(credentialsJson));

  final scopes = [sheets.SheetsApi.spreadsheetsScope];
  final client = await clientViaServiceAccount(credentials, scopes);

  final api = sheets.SheetsApi(client);
  final spreadsheetId = '1GRfFvVYrTUP3HVsxPXemdv5n9hJl4ZYm5a2Lgzp1yHU';
  
  try {
    final doc = await api.spreadsheets.get(spreadsheetId);
    for (var sheet in doc.sheets ?? []) {
      print('Sheet name: "${sheet.properties?.title}"');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
