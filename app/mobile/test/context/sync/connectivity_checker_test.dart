import 'dart:async';

import 'package:exnota/src/context/sync/connectivity_checker.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import 'connectivity_checker_test.mocks.dart';

abstract class MyFunction {
  void call();
}

class MyFunctionMock extends Mock implements MyFunction {}

@GenerateMocks([http.Client])
void main() {
  group('ConnectivityChecker', () {
    group('Given the server is down', () {
      group('When the unlimited retry strategy is used', () {
        group('And no maxInterval is provided', () {
          test('Then it should retry indefinitely', () {
            fakeAsync((async) {
              final client = MockClient();
              when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .thenThrow(TimeoutException('timeout exception'));
              final onOnline = MyFunctionMock();

              final checker = ConnectivityChecker(
                strategy: CheckerStrategy.unlimitedRetry(
                  onOnline: onOnline,
                ),
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                client: client,
                label: 'test',
              );
              checker.start();

              // Calls
              // 1. Immediate
              // 2. 1s
              // 3. 2s
              // 4. 4s
              // 5. 8s
              // 6. 16s
              // 7. 32s
              // 8. 64s
              // 9. 128s
              // 10. 256s
              // Total = 511s
              async.elapse(const Duration(seconds: 511));

              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(10);
              verifyNever(onOnline());
            });
          });
        });
        group('And maxInterval=5 is provided', () {
          test('Then it should retry with max delay of 5 seconds', () {
            fakeAsync((async) {
              final client = MockClient();
              when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .thenThrow(TimeoutException('timeout exception'));
              final onOnline = MyFunctionMock();

              final checker = ConnectivityChecker(
                strategy: CheckerStrategy.unlimitedRetry(
                  maxInterval: 5,
                  onOnline: onOnline,
                ),
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                client: client,
                label: 'test',
              );
              checker.start();

              // Calls
              // 1. Immediate
              // 2. 1s
              // 3. 2s
              // 4. 4s
              // 5. 5s
              // 6. 5s
              // 7. 5s
              // Total = 22s
              async.elapse(const Duration(seconds: 22));

              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(7);
              verifyNever(onOnline());
            });
          });
        });
      });
      group('When the duration retry strategy is used', () {
        group('And maxDuration=120 is provided', () {
          test('Then it should retry for 120 seconds then call onExpire', () {
            fakeAsync((async) {
              final client = MockClient();
              when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .thenThrow(TimeoutException('timeout exception'));
              final onOnline = MyFunctionMock();
              final onExpire = MyFunctionMock();

              final checker = ConnectivityChecker(
                strategy: CheckerStrategy.durationRetry(
                  maxDuration: 120,
                  onOnline: onOnline,
                  onExpire: onExpire,
                ),
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                client: client,
                label: 'test',
              );
              checker.start();

              // Calls
              // 1. Immediate
              // 2. 1s
              // 3. 2s
              // 4. 4s
              // 5. 8s
              // 6. 16s
              // 7. 32s (running total = 63s)
              // 8. 64s (running total = 127s) <- Exceeds maxDuration so 64s timer NOT set
              async.elapse(const Duration(seconds: 512));

              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(7);
              verifyNever(onOnline());
              verify(onExpire()).called(1);
            });
          });
        });
      });
      group('Given the server responds with an unexpected status code', () {
        group('When called with the unlimited retry strategy', () {
          test('Then it should retry indefinitely', () {
            fakeAsync((async) {
              final client = MockClient();
              when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .thenAnswer((_) async => http.Response('Uh oh', 500));
              final onOnline = MyFunctionMock();

              final checker = ConnectivityChecker(
                strategy: CheckerStrategy.unlimitedRetry(
                  onOnline: onOnline,
                ),
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                client: client,
                label: 'test',
              );
              checker.start();

              // Calls
              // 1. Immediate
              // 2. 1s
              // 3. 2s
              // 4. 4s
              // 5. 8s
              // 6. 16s
              // 7. 32s
              // 8. 64s
              // 9. 128s
              // 10. 256s
              // Total = 511s
              async.elapse(const Duration(seconds: 511));

              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(10);
              verifyNever(onOnline());
            });
          });
        });
      });
      group('Given the server responds with 200 immediately', () {
        test('Then only one request should be made', () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenAnswer((_) async => http.Response('OK', 200));
            final onSuccess = MyFunctionMock();

            final checker = ConnectivityChecker(
              strategy: CheckerStrategy.unlimitedRetry(
                onOnline: onSuccess,
              ),
              uri: Uri.parse('http://localhost:8080/healthcheck'),
              client: client,
              label: 'test',
            );
            checker.start();

            // Calls
            // 1. Immediate
            async.elapse(const Duration(seconds: 10));

            verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .called(1);
            verify(onSuccess()).called(1);
          });
        });
      });
      group('Given the server responds with 200 after two retries', () {
        test('Then it should call onSuccess and make no further requests', () {
          fakeAsync((async) {
            final client = MockClient();
            var callCount = 0;
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenAnswer((_) async {
              // On 3rd call, return 200
              if (callCount++ < 2) {
                throw TimeoutException('timeout exception');
              }
              return http.Response('OK', 200);
            });

            final onSuccess = MyFunctionMock();

            final checker = ConnectivityChecker(
              strategy: CheckerStrategy.unlimitedRetry(
                onOnline: onSuccess,
              ),
              uri: Uri.parse('http://localhost:8080/healthcheck'),
              client: client,
              label: 'test',
            );
            checker.start();

            // Calls
            // 1. Immediate
            // 2. 1s
            async.elapse(const Duration(seconds: 60));

            verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .called(3);
            verify(onSuccess()).called(1);
          });
        });
      });
      group('Given the server responds with 200 before maxDuration', () {
        test('Then it should call onSuccess and make no futher requests', () {
          fakeAsync((async) {
            final client = MockClient();
            var callCount = 0;
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenAnswer((_) async {
              // On 4th call, return 200
              if (callCount++ < 3) {
                throw TimeoutException('timeout exception');
              }
              return http.Response('OK', 200);
            });
            final onSuccess = MyFunctionMock();

            final checker = ConnectivityChecker(
              strategy: CheckerStrategy.durationRetry(
                maxDuration: 12,
                onOnline: onSuccess,
                onExpire: () {},
              ),
              uri: Uri.parse('http://localhost:8080/healthcheck'),
              client: client,
              label: 'test',
            );
            checker.start();

            // Calls
            // 1. Immediate
            // 2. 1s
            // 3. 2s (running total = 3s)
            // 4. 4s (running total = 7s)
            async.elapse(const Duration(seconds: 60));

            verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .called(4);
            verify(onSuccess()).called(1);
          });
        });
      });
      group('Given the server responds with 200 after maxDuration', () {
        test('Then it should call onExpire and not call onSuccess', () {
          fakeAsync((async) {
            final client = MockClient();
            var callCount = 0;
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenAnswer((_) async {
              // On 5th call, return 200
              if (callCount++ < 4) {
                throw TimeoutException('timeout exception');
              }
              return http.Response('OK', 200);
            });
            final onSuccess = MyFunctionMock();
            final onExpire = MyFunctionMock();

            final checker = ConnectivityChecker(
              strategy: CheckerStrategy.durationRetry(
                maxDuration: 10,
                onOnline: onSuccess,
                onExpire: onExpire,
              ),
              uri: Uri.parse('http://localhost:8080/healthcheck'),
              client: client,
              label: 'test',
            );
            checker.start();

            // Calls
            // 1. Immediate
            // 2. 1s
            // 3. 2s
            // 4. 4s (running total = 7s)
            // 5. 8s (running total = 15s) <- Exceeds maxDuration so 8s timer NOT set
            async.elapse(const Duration(seconds: 60));

            verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .called(4);
            verifyNever(onSuccess());
            verify(onExpire()).called(1);
          });
        });
      });
      group('Stop', () {
        group('Given the server is down', () {
          group('When called with default args', () {
            group('and stop is called', () {
              test('Then it should not call onExpire or onSuccess', () {
                fakeAsync((async) {
                  final client = MockClient();
                  when(client
                          .get(Uri.parse('http://localhost:8080/healthcheck')))
                      .thenThrow(TimeoutException('timeout exception'));
                  final onSuccess = MyFunctionMock();
                  final onExpire = MyFunctionMock();

                  final checker = ConnectivityChecker(
                    strategy: CheckerStrategy.unlimitedRetry(
                      onOnline: onSuccess,
                    ),
                    uri: Uri.parse('http://localhost:8080/healthcheck'),
                    client: client,
                    label: 'test',
                  );
                  checker.start();

                  // Calls
                  // 1. Immediate
                  // 2. 1s
                  async.elapse(const Duration(seconds: 1));
                  checker.stop();

                  verify(client
                          .get(Uri.parse('http://localhost:8080/healthcheck')))
                      .called(2);
                  verifyNever(onSuccess());
                  verifyNever(onExpire());
                });
              });
            });
            group(
                'and stop is called in the delay bewteen the third and fourth request',
                () {
              test('Then it should not make a fourth request', () {
                fakeAsync((async) {
                  final client = MockClient();
                  when(client
                          .get(Uri.parse('http://localhost:8080/healthcheck')))
                      .thenThrow(TimeoutException('timeout exception'));
                  final onSuccess = MyFunctionMock();

                  final checker = ConnectivityChecker(
                    strategy: CheckerStrategy.unlimitedRetry(
                      onOnline: onSuccess,
                    ),
                    uri: Uri.parse('http://localhost:8080/healthcheck'),
                    client: client,
                    label: 'test',
                  );
                  checker.start();

                  // Calls
                  // 1. Immediate
                  // 2. 1s
                  // 3. 2s (running total = 3s)
                  // 4. 4s (running total = 7s)
                  async.elapse(const Duration(seconds: 4));
                  checker.stop();
                  async.elapse(const Duration(seconds: 60));

                  verify(client
                          .get(Uri.parse('http://localhost:8080/healthcheck')))
                      .called(3);
                  verifyNever(onSuccess());
                });
              });
            });
            group('and stop is called during the third request', () {
              test('Then it should not make a fourth request', () {
                // This tests the block with 'Cancelled during request'
                fakeAsync((async) {
                  final client = MockClient();
                  var callCount = 0;
                  when(client
                          .get(Uri.parse('http://localhost:8080/healthcheck')))
                      .thenAnswer((_) async {
                    // On 3rd call, wait 3 seconds
                    if (callCount++ == 2) {
                      await Future.delayed(const Duration(seconds: 3));
                    }
                    throw TimeoutException('timeout exception');
                  });
                  final onSuccess = MyFunctionMock();

                  final checker = ConnectivityChecker(
                    strategy: CheckerStrategy.unlimitedRetry(
                      onOnline: onSuccess,
                    ),
                    uri: Uri.parse('http://localhost:8080/healthcheck'),
                    client: client,
                    label: 'test',
                  );
                  checker.start();

                  // Calls
                  // 1. Immediate
                  // 2. 1s
                  // 3. 2s (running total = 3s) <-- Call takes 3s, finishing at 6s
                  // 4. 4s (running total = 10s)
                  async.elapse(const Duration(seconds: 4));
                  checker.stop();
                  async.elapse(const Duration(seconds: 60));

                  verify(client
                          .get(Uri.parse('http://localhost:8080/healthcheck')))
                      .called(3);
                  verifyNever(onSuccess());
                });
              });
            });
          });
        });
        group('Given a HealthCheckRetry object', () {
          group('When stop is called before start', () {
            test('Then it should not make any requests', () {
              fakeAsync((async) {
                final client = MockClient();
                final onSuccess = MyFunctionMock();

                final checker = ConnectivityChecker(
                  strategy: CheckerStrategy.unlimitedRetry(
                    onOnline: onSuccess,
                  ),
                  uri: Uri.parse('http://localhost:8080/healthcheck'),
                  client: client,
                  label: 'test',
                );
                checker.stop();

                verifyNever(
                    client.get(Uri.parse('http://localhost:8080/healthcheck')));
                verifyNever(onSuccess());
              });
            });
          });
          group('When it is started, stopped, and started again', () {
            test('Then it should not make any further retries', () {
              fakeAsync((async) {
                final client = MockClient();
                when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                    .thenThrow(TimeoutException('timeout exception'));
                final onSuccess = MyFunctionMock();

                final checker = ConnectivityChecker(
                  strategy: CheckerStrategy.unlimitedRetry(
                    onOnline: onSuccess,
                  ),
                  uri: Uri.parse('http://localhost:8080/healthcheck'),
                  client: client,
                  label: 'test',
                );
                checker.start();

                // Calls
                // 1. Immediate
                // 2. 1s
                async.elapse(const Duration(seconds: 1));
                checker.stop();

                // Start again
                checker.start();

                // Calls (that would be expected)
                // 3. Immediate (subtotal = 0s; total = 1s)
                // 4. 1s (subtotal = 1s; total = 2s)
                // 5. 2s (subtotal = 3s; total = 4s)
                async.elapse(const Duration(seconds: 3));

                verify(client
                        .get(Uri.parse('http://localhost:8080/healthcheck')))
                    .called(2);
                verifyNever(onSuccess());
              });
            });
          });
          group('When start is called while already running', () {
            test('Then the original request backoff should continue', () {
              fakeAsync((async) {
                final client = MockClient();
                when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                    .thenThrow(TimeoutException('timeout exception'));
                final onSuccess = MyFunctionMock();

                final checker = ConnectivityChecker(
                  strategy: CheckerStrategy.unlimitedRetry(
                    onOnline: onSuccess,
                  ),
                  uri: Uri.parse('http://localhost:8080/healthcheck'),
                  client: client,
                  label: 'test',
                );
                checker.start();

                // Calls
                // 1. Immediate
                // 2. 1s
                // 3. 2s (running total = 3s)
                // 4. 4s (running total = 7s)
                // 5. 8s (running total = 15s)
                async.elapse(const Duration(seconds: 15));
                verify(client
                        .get(Uri.parse('http://localhost:8080/healthcheck')))
                    .called(5);

                // Start again
                checker.start();

                // Calls
                // 6. 16s (subtotal = 16s; total = 31s)
                // 7. 32s (subtotal = 48s; total = 63s)
                async.elapse(const Duration(seconds: 48));
                verify(client
                        .get(Uri.parse('http://localhost:8080/healthcheck')))
                    .called(2);
                verifyNever(onSuccess());
              });
            });
          });
        });
      });
    });
  });
}
