enum Environment { debug, profile, production }

class ApiEndpoints {
  static Environment currentEnvironment = Environment.debug;

  static const String _testDomain = "<Your Local Domain>";
  static const String _liveDomain = "<Your Server Domain>";


  static String get mainDomain {
    return currentEnvironment == Environment.production ? _liveDomain : _testDomain;
  }

  static String get login => "$mainDomain/api/login/";
  static String get refresh => "$mainDomain/api/login/";



}
