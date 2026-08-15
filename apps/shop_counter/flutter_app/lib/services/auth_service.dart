import 'package:supabase_flutter/supabase_flutter.dart';
class AuthService {
 final SupabaseClient client=Supabase.instance.client;
 Future<void> signIn(String email,String password) async { await client.auth.signInWithPassword(email:email,password:password); }
 Future<void> signOut()=>client.auth.signOut();
 User? get user=>client.auth.currentUser; Session? get session=>client.auth.currentSession;
}
