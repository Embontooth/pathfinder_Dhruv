class AuthDet {
  // final String _baseUrl = "http://192.168.95.119:3000"; //vyshnav
  // final String _baseUrl = "http://192.168.95.242:3000"; //Nandu
  // final String _baseUrl = "http://192.168.90.165:3000"; //Dhruv
  final String _baseUrl = "https://pathfinder-production-0493.up.railway.app";
  final String _supaBaseUrl = 'https://zttcqbheotutkxaqljvf.supabase.co';
  final String _supaBaseAnon =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0dGNxYmhlb3R1dGt4YXFsanZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMwNzQ4ODAsImV4cCI6MjA1ODY1MDg4MH0._LikwV4TS1IXI76Jsz0El8P6rsFwL6LiGohiEt9Wexw';

  String get baseUrl => _baseUrl;
  String get supaBaseUrl => _supaBaseUrl;
  String get supaBaseAnon => _supaBaseAnon;
}
