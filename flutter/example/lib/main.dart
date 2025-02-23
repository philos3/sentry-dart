import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:feedback/feedback.dart' as feedback;
import 'package:provider/provider.dart';
import 'user_feedback_dialog.dart';

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const String _exampleDsn =
    'https://9934c532bf8446ef961450973c898537@o447951.ingest.sentry.io/5428562';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = _exampleDsn;
      options.tracesSampleRate = 1.0;
      options.reportPackages = false;
    },
    // Init your App.
    appRunner: () => runApp(MyApp()),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return feedback.BetterFeedback(
      child: ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorObservers: [
              SentryNavigatorObserver(),
            ],
            theme: Provider.of<ThemeProvider>(context).theme,
            home: const MainScaffold(),
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var icon = Icons.light_mode;
    var theme = ThemeData.light();
    if (themeProvider.theme.brightness == Brightness.light) {
      icon = Icons.dark_mode;
      theme = ThemeData.dark();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentry Flutter Example'),
        actions: [
          IconButton(
            onPressed: () {
              themeProvider.theme = theme;
            },
            icon: Icon(icon),
          ),
          IconButton(
            onPressed: () {
              themeProvider.updatePrimatryColor(Colors.orange);
            },
            icon: Icon(Icons.circle, color: Colors.orange),
          ),
          IconButton(
            onPressed: () {
              themeProvider.updatePrimatryColor(Colors.green);
            },
            icon: Icon(Icons.circle, color: Colors.lime),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Center(child: Text('Trigger an action:\n')),
            RaisedButton(
              child: const Text('Open another Scaffold'),
              onPressed: () => SecondaryScaffold.openSecondaryScaffold(context),
            ),
            RaisedButton(
              child: const Text('Dart: try catch'),
              onPressed: () => tryCatch(),
            ),
            RaisedButton(
              child: const Text('Flutter error : Scaffold.of()'),
              onPressed: () => Scaffold.of(context).showBottomSheet<dynamic>(
                  (context) => const Text('Scaffold error')),
            ),
            RaisedButton(
              child: const Text('Dart: throw onPressed'),
              // Warning : not captured if a debugger is attached
              // https://github.com/flutter/flutter/issues/48972
              onPressed: () => throw Exception('Throws onPressed'),
            ),
            RaisedButton(
              child: const Text('Dart: assert'),
              onPressed: () {
                // Only relevant in debug builds
                // Warning : not captured if a debugger is attached
                // https://github.com/flutter/flutter/issues/48972
                assert(false, 'assert failure');
              },
            ),
            // Calling the SDK with an appRunner will handle errors from Futures
            // in SDKs runZonedGuarded onError handler
            RaisedButton(
                child: const Text('Dart: async throws'),
                onPressed: () async => asyncThrows()),
            RaisedButton(
              child: const Text('Dart: Fail in microtask.'),
              onPressed: () async => {
                await Future.microtask(
                  () => throw StateError('Failure in a microtask'),
                )
              },
            ),
            RaisedButton(
              child: const Text('Dart: Fail in compute'),
              onPressed: () async => {await compute(loop, 10)},
            ),
            RaisedButton(
              child: const Text('Throws in Future.delayed'),
              onPressed: () => Future.delayed(Duration(milliseconds: 100),
                  () => throw Exception('Throws in Future.delayed')),
            ),
            RaisedButton(
              child: const Text('Capture from FlutterError.onError'),
              onPressed: () {
                // modeled after a real exception
                FlutterError.onError?.call(FlutterErrorDetails(
                  exception: Exception('A really bad exception'),
                  silent: false,
                  context: DiagnosticsNode.message('while handling a gesture'),
                  library: 'gesture',
                  informationCollector: () => [
                    DiagnosticsNode.message(
                        'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                    DiagnosticsNode.message(
                        'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                    DiagnosticsNode.message(
                        'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                  ],
                ));
              },
            ),
            RaisedButton(
              child: const Text('Dart: Web request'),
              onPressed: () => makeWebRequest(context),
            ),
            RaisedButton(
              child: const Text('Record print() as breadcrumb'),
              onPressed: () {
                print('A print breadcrumb');
                Sentry.captureMessage('A message with a print() Breadcrumb');
              },
            ),
            RaisedButton(
              child:
                  const Text('Capture message with scope with additional tag'),
              onPressed: () {
                Sentry.captureMessage(
                  'This event has an extra tag',
                  withScope: (scope) {
                    scope.setTag('foo', 'bar');
                  },
                );
              },
            ),
            RaisedButton(
              child: const Text('Capture transaction'),
              onPressed: () async {
                final transaction = Sentry.getSpan() ??
                    Sentry.startTransaction(
                      'myNewTrWithError3',
                      'myNewOp',
                      description: 'myTr myOp',
                    );
                transaction.setTag('myTag', 'myValue');
                transaction.setData('myExtra', 'myExtraValue');

                await Future.delayed(Duration(milliseconds: 50));

                final span = transaction.startChild(
                  'childOfMyOp',
                  description: 'childOfMyOp span',
                );
                span.setTag('myNewTag', 'myNewValue');
                span.setData('myNewData', 'myNewDataValue');

                await Future.delayed(Duration(milliseconds: 70));

                await span.finish(status: SpanStatus.resourceExhausted());

                await Future.delayed(Duration(milliseconds: 90));

                final spanChild = span.startChild(
                  'childOfChildOfMyOp',
                  description: 'childOfChildOfMyOp span',
                );

                await Future.delayed(Duration(milliseconds: 110));

                spanChild.startChild(
                  'unfinishedChild',
                  description: 'I wont finish',
                );

                await spanChild.finish(status: SpanStatus.internalError());

                await Future.delayed(Duration(milliseconds: 50));

                await transaction.finish(status: SpanStatus.ok());
              },
            ),
            RaisedButton(
              child: const Text('Capture message with attachment'),
              onPressed: () {
                Sentry.captureMessage(
                  'This message has an attachment',
                  withScope: (scope) {
                    final txt = 'Lorem Ipsum dolar sit amet';
                    scope.addAttachment(
                      SentryAttachment.fromIntList(
                        utf8.encode(txt),
                        'foobar.txt',
                        contentType: 'text/plain',
                      ),
                    );
                  },
                );
              },
            ),
            RaisedButton(
              child: const Text('Capture message with image attachment'),
              onPressed: () {
                feedback.BetterFeedback.of(context)
                    .show((feedback.UserFeedback feedback) {
                  Sentry.captureMessage(
                    feedback.text,
                    withScope: (scope) {
                      final entries = feedback.extra?.entries;
                      if (entries != null) {
                        for (final extra in entries) {
                          scope.setExtra(extra.key, extra.value);
                        }
                      }
                      scope.addAttachment(
                        SentryAttachment.fromUint8List(
                          feedback.screenshot,
                          'feedback.png',
                          contentType: 'image/png',
                        ),
                      );
                    },
                  );
                });
              },
            ),
            RaisedButton(
              child: const Text('Capture User Feedback'),
              onPressed: () async {
                final id = await Sentry.captureMessage('UserFeedback');
                await showDialog(
                  context: context,
                  builder: (context) {
                    return UserFeedbackDialog(eventId: id);
                  },
                );
              },
            ),
            RaisedButton(
              child: const Text('Show UserFeedback Dialog without event'),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) {
                    return UserFeedbackDialog(eventId: SentryId.newId());
                  },
                );
              },
            ),
            if (UniversalPlatform.isIOS || UniversalPlatform.isMacOS)
              const CocoaExample(),
            if (UniversalPlatform.isAndroid) const AndroidExample(),
          ],
        ),
      ),
    );
  }
}

class AndroidExample extends StatelessWidget {
  const AndroidExample({Key? key}) : super(key: key);

  // ignore: avoid_field_initializers_in_const_classes
  final channel = const MethodChannel('example.flutter.sentry.io');

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RaisedButton(
        child: const Text('Kotlin Throw unhandled exception'),
        onPressed: () async {
          await execute('throw');
        },
      ),
      RaisedButton(
        child: const Text('Kotlin Capture Exception'),
        onPressed: () async {
          await execute('capture');
        },
      ),
      RaisedButton(
        // ANR is disabled by default, enable it to test it
        child: const Text('ANR: UI blocked 6 seconds'),
        onPressed: () async {
          await execute('anr');
        },
      ),
      RaisedButton(
        child: const Text('C++ Capture message'),
        onPressed: () async {
          await execute('cpp_capture_message');
        },
      ),
      RaisedButton(
        child: const Text('C++ SEGFAULT'),
        onPressed: () async {
          await execute('crash');
        },
      ),
    ]);
  }

  Future<void> execute(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } catch (error, stackTrace) {
      await Sentry.captureException(error, stackTrace: stackTrace);
    }
  }
}

Future<void> tryCatch() async {
  try {
    throw StateError('try catch');
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

Future<void> asyncThrows() async {
  throw StateError('async throws');
}

class CocoaExample extends StatelessWidget {
  const CocoaExample({Key? key}) : super(key: key);

  final channel = const MethodChannel('example.flutter.sentry.io');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RaisedButton(
          child: const Text('Swift fatalError'),
          onPressed: () async {
            await channel.invokeMethod<void>('fatalError');
          },
        ),
        RaisedButton(
          child: const Text('Swift Capture NSException'),
          onPressed: () async {
            await channel.invokeMethod<void>('capture');
          },
        ),
        RaisedButton(
          child: const Text('Swift Capture message'),
          onPressed: () async {
            await channel.invokeMethod<void>('capture_message');
          },
        ),
        RaisedButton(
          child: const Text('Objective-C Throw unhandled exception'),
          onPressed: () async {
            await channel.invokeMethod<void>('throw');
          },
        ),
        RaisedButton(
          child: const Text('Objective-C SEGFAULT'),
          onPressed: () async {
            await channel.invokeMethod<void>('crash');
          },
        ),
      ],
    );
  }
}

/// compute can only take a top-level function, but not instance or static methods.
// Top-level functions are functions declared not inside a class and not inside another function
int loop(int val) {
  var count = 0;
  for (var i = 1; i <= val; i++) {
    count += i;
  }

  throw StateError('from a compute isolate $count');
}

class SecondaryScaffold extends StatelessWidget {
  static Future<void> openSecondaryScaffold(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings:
            const RouteSettings(name: 'SecondaryScaffold', arguments: 'foobar'),
        builder: (context) {
          return SecondaryScaffold();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecondaryScaffold'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text(
              'You have added a navigation event '
              'to the crash reports breadcrumbs.',
            ),
            MaterialButton(
              child: const Text('Go back'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            MaterialButton(
              child: const Text('throw uncaught exception'),
              onPressed: () {
                throw Exception('Exception from SecondaryScaffold');
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> makeWebRequest(BuildContext context) async {
  final transaction = Sentry.getSpan() ??
      Sentry.startTransaction(
        'flutterwebrequest',
        'request',
        bindToScope: true,
      );

  final client = SentryHttpClient(
    captureFailedRequests: true,
    networkTracing: true,
    failedRequestStatusCodes: [SentryStatusCode.range(400, 500)],
  );
  // We don't do any exception handling here.
  // In case of an exception, let it get caught and reported to Sentry
  final response = await client.get(Uri.parse('https://flutter.dev/'));

  await transaction.finish(status: SpanStatus.ok());

  await showDialog<void>(
    context: context,
    // gets tracked if using SentryNavigatorObserver
    routeSettings: RouteSettings(
      name: 'flutter.dev dialog',
    ),
    builder: (context) {
      return AlertDialog(
        title: Text('Response ${response.statusCode}'),
        content: SingleChildScrollView(
          child: Text(response.body),
        ),
        actions: [
          MaterialButton(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      );
    },
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeData _theme = ThemeData.light();

  ThemeData get theme => _theme;

  set theme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  void updatePrimatryColor(MaterialColor color) {
    if (theme.brightness == Brightness.light) {
      theme = ThemeData(primarySwatch: color, brightness: theme.brightness);
    } else {
      theme = ThemeData(primarySwatch: color, brightness: theme.brightness);
    }
  }
}
