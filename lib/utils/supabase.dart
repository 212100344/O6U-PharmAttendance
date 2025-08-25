import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = '';
  static const String anonKey = ''; // Your anon key

  //static const String serviceRoleKey = ''; // Your service role key

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,

      headers: { //for correct Authentication
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey', //add here the correct header key!.
      },
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}