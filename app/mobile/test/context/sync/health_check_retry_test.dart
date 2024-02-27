import 'dart:async';

import 'package:exnota/src/context/sync/health_check_retry.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import 'health_check_retry_test.mocks.dart';

abstract class MyFunction {
  void call();
}

class MyFunctionMock extends Mock implements MyFunction {}

@GenerateMocks([http.Client])
void main() {
  group('HealthCheckRetry', () {
    group('Given the server is down', () {
      group('When called with default args', () {
        test('Then it should retry indefinitely', () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenThrow(TimeoutException('timeout exception'));
            final onSuccess = MyFunctionMock();

            final retry = HealthCheckRetry(
                client: client,
                onSuccess: onSuccess,
                uri: Uri.parse('http://localhost:8080/healthcheck'));
            retry.start();

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
            verifyNever(onSuccess());
          });
        });
      });
      group('When called with maxDelay=5', () {
        test('Then it should retry with max delay of 5 seconds', () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenThrow(TimeoutException('timeout exception'));
            final onSuccess = MyFunctionMock();

            final retry = HealthCheckRetry(
                client: client,
                onSuccess: onSuccess,
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                maxDelay: 5);
            retry.start();

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
            verifyNever(onSuccess());
          });
        });
      });
      group('When called with maxDuration=120', () {
        test('Then it should retry for 120 seconds then call onExpire', () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenThrow(TimeoutException('timeout exception'));
            final onSuccess = MyFunctionMock();
            final onExpire = MyFunctionMock();

            final retry = HealthCheckRetry(
                client: client,
                onSuccess: onSuccess,
                onExpire: onExpire,
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                maxDuration: 120);
            retry.start();

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
            verifyNever(onSuccess());
            verify(onExpire()).called(1);
          });
        });
      });
      group('When called with a maxDuration and onExpire is not provided', () {
        test(
            'Then on expire it should not throw an error trying to call onExpire',
            () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenThrow(TimeoutException('timeout exception'));
            final onSuccess = MyFunctionMock();

            final retry = HealthCheckRetry(
                client: client,
                onSuccess: onSuccess,
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                maxDuration: 10);
            retry.start();

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
          });
        });
      });
      group('When called with both a maxDelay=5 and maxDuration=60', () {
        test(
            'Then it should retry with max delay of 5 seconds and stop after 60 seconds, calling onExpire',
            () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenThrow(TimeoutException('timeout exception'));
            final onSuccess = MyFunctionMock();
            final onExpire = MyFunctionMock();

            final retry = HealthCheckRetry(
                client: client,
                onSuccess: onSuccess,
                onExpire: onExpire,
                uri: Uri.parse('http://localhost:8080/healthcheck'),
                maxDelay: 5,
                maxDuration: 60);
            retry.start();

            // Calls
            // 1. Immediate
            // 2. 1s
            // 3. 2s
            // 4. 4s
            // 5. 5s
            // 6. 5s
            // 7. 5s (subtotal = 22s)
            // 8. 5s (subtotal = 27s)
            // 9. 5s (subtotal = 32s)
            // 10. 5s (subtotal = 37s)
            // 11. 5s (subtotal = 42s)
            // 12. 5s (subtotal = 47s)
            // 13. 5s (subtotal = 52s)
            // 14. 5s (subtotal = 57s)
            // 15. 5s (subtotal = 62s) <- Exceeds maxDuration so this timer NOT set
            async.elapse(const Duration(seconds: 120));

            verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .called(14);
            verifyNever(onSuccess());
            verify(onExpire()).called(1);
          });
        });
      });
    });
    group('Given the server responds with an unexpected status code', () {
      group('When called with default args', () {
        test('Then it should retry indefinitely', () {
          fakeAsync((async) {
            final client = MockClient();
            when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                .thenAnswer((_) async => http.Response('Uh oh', 500));
            final onSuccess = MyFunctionMock();

            final retry = HealthCheckRetry(
                client: client,
                onSuccess: onSuccess,
                uri: Uri.parse('http://localhost:8080/healthcheck'));
            retry.start();

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
            verifyNever(onSuccess());
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

          final retry = HealthCheckRetry(
              client: client,
              onSuccess: onSuccess,
              uri: Uri.parse('http://localhost:8080/healthcheck'));
          retry.start();

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

          final retry = HealthCheckRetry(
              client: client,
              onSuccess: onSuccess,
              uri: Uri.parse('http://localhost:8080/healthcheck'));
          retry.start();

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

          final retry = HealthCheckRetry(
              client: client,
              onSuccess: onSuccess,
              maxDuration: 12,
              uri: Uri.parse('http://localhost:8080/healthcheck'));
          retry.start();

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

          final retry = HealthCheckRetry(
              client: client,
              onSuccess: onSuccess,
              onExpire: onExpire,
              maxDuration: 10,
              uri: Uri.parse('http://localhost:8080/healthcheck'));
          retry.start();

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
                when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                    .thenThrow(TimeoutException('timeout exception'));
                final onSuccess = MyFunctionMock();
                final onExpire = MyFunctionMock();

                final retry = HealthCheckRetry(
                    client: client,
                    onSuccess: onSuccess,
                    onExpire: onExpire,
                    uri: Uri.parse('http://localhost:8080/healthcheck'));
                retry.start();

                // Calls
                // 1. Immediate
                // 2. 1s
                async.elapse(const Duration(seconds: 1));
                retry.stop();

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
                when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                    .thenThrow(TimeoutException('timeout exception'));
                final onSuccess = MyFunctionMock();

                final retry = HealthCheckRetry(
                    client: client,
                    onSuccess: onSuccess,
                    uri: Uri.parse('http://localhost:8080/healthcheck'));
                retry.start();

                // Calls
                // 1. Immediate
                // 2. 1s
                // 3. 2s (running total = 3s)
                // 4. 4s (running total = 7s)
                async.elapse(const Duration(seconds: 4));
                retry.stop();
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
                when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                    .thenAnswer((_) async {
                  // On 3rd call, wait 3 seconds
                  if (callCount++ == 2) {
                    await Future.delayed(const Duration(seconds: 3));
                  }
                  throw TimeoutException('timeout exception');
                });
                final onSuccess = MyFunctionMock();

                final retry = HealthCheckRetry(
                    client: client,
                    onSuccess: onSuccess,
                    uri: Uri.parse('http://localhost:8080/healthcheck'));
                retry.start();

                // Calls
                // 1. Immediate
                // 2. 1s
                // 3. 2s (running total = 3s) <-- Call takes 3s, finishing at 6s
                // 4. 4s (running total = 10s)
                async.elapse(const Duration(seconds: 4));
                retry.stop();
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
      // TODO: Have not validated these yet
      group('Given a HealthCheckRetry object', () {
        group('When stop is called before start', () {
          test('Then it should not make any requests', () {
            fakeAsync((async) {
              final client = MockClient();
              final onSuccess = MyFunctionMock();

              final retry = HealthCheckRetry(
                  client: client,
                  onSuccess: onSuccess,
                  uri: Uri.parse('http://localhost:8080/healthcheck'));
              retry.stop();

              verifyNever(
                  client.get(Uri.parse('http://localhost:8080/healthcheck')));
              verifyNever(onSuccess());
            });
          });
        });
        group('When it is started, stopped, and started again', () {
          test('Then the retry backoff should be reset', () {
            fakeAsync((async) {
              final client = MockClient();
              when(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .thenThrow(TimeoutException('timeout exception'));
              final onSuccess = MyFunctionMock();

              final retry = HealthCheckRetry(
                  client: client,
                  onSuccess: onSuccess,
                  uri: Uri.parse('http://localhost:8080/healthcheck'));
              retry.start();

              // Calls
              // 1. Immediate
              // 2. 1s
              async.elapse(const Duration(seconds: 1));
              retry.stop();

              // Start again
              retry.start();

              // Calls
              // 3. Immediate (subtotal = 0s; total = 1s)
              // 4. 1s (subtotal = 1s; total = 2s)
              // 5. 2s (subtotal = 3s; total = 4s)
              async.elapse(const Duration(seconds: 3));

              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(5);
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

              final retry = HealthCheckRetry(
                  client: client,
                  onSuccess: onSuccess,
                  uri: Uri.parse('http://localhost:8080/healthcheck'));
              retry.start();

              // Calls
              // 1. Immediate
              // 2. 1s
              // 3. 2s (running total = 3s)
              // 4. 4s (running total = 7s)
              // 5. 8s (running total = 15s)
              async.elapse(const Duration(seconds: 15));
              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(5);

              // Start again
              retry.start();

              // Calls
              // 6. 16s (subtotal = 16s; total = 31s)
              // 7. 32s (subtotal = 48s; total = 63s)
              async.elapse(const Duration(seconds: 48));
              verify(client.get(Uri.parse('http://localhost:8080/healthcheck')))
                  .called(2);
              verifyNever(onSuccess());
            });
          });
        });
      });
    });
  });
}
