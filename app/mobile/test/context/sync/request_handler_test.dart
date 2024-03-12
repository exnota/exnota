import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

abstract class MyFunction {
  void call();
}

class MyFunctionMock extends Mock implements MyFunction {}

@GenerateMocks([http.Client])
void main() {
  // TODO:
}
