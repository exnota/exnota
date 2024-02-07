// import 'dart:async';

// import 'package:app_links/app_links.dart';
// import 'package:exnota/src/account/settings/uri_service.dart';
// import 'package:exnota/src/integration/notion_settings.dart';
// import 'package:exnota/src/integration/service/notion_settings_service.dart';
// import 'package:exnota/src/integration/screen/alternate_notion_settings_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:oauth2/oauth2.dart' as oauth2;

// // TODO: Refector into controller pattern? (is that a thing) to simplify this widget?
// /// Initiates Notion auth process.
// class NotionSettingsScreen extends ConsumerStatefulWidget {
//   const NotionSettingsScreen({super.key});

//   @override
//   ConsumerState<NotionSettingsScreen> createState() => _NotionSettingsScreen();
// }

// enum LaunchingBrowserStatus { notLaunched, launched, returned }

// class _NotionSettingsScreen extends ConsumerState<NotionSettingsScreen>
//     with WidgetsBindingObserver {
//   final double _verticalColumnSpace = 20;

//   LaunchingBrowserStatus _launchingBrowser = LaunchingBrowserStatus.notLaunched;
//   bool _receivedCode = false;
//   bool _couldNotRequestCode = false;
//   late AppLinks _appLinks = AppLinks();
//   late StreamSubscription<Uri> _linkSubscription;

//   bool _requestingToken = false;
//   bool _requestingTokenError = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _handleIncomingLinks();
//   }

//   @override
//   void dispose() {
//     _appLinks = AppLinks();
//     _linkSubscription.cancel();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     switch (state) {
//       case AppLifecycleState.resumed:
//         // Catch the user's return in case it isn't caught via redirect
//         if (_launchingBrowser == LaunchingBrowserStatus.launched) {
//           setState(() {
//             _launchingBrowser = LaunchingBrowserStatus.returned;
//           });
//         }
//         break;
//       default:
//         break;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final notionSettings = ref.watch(notionSettingsServiceProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: TitleThatCanOpenAlternateNotionSettings(
//             onAlternateSettingsOpened: () {
//           setState(() {
//             _couldNotRequestCode = false;
//           });
//         }),
//       ),
//       body: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               switch (notionSettings) {
//                 AsyncError(:final error) =>
//                   Center(child: Text('error: $error')),
//                 AsyncLoading() =>
//                   const Center(child: CircularProgressIndicator()),
//                 AsyncData(:final value) => Center(
//                       child: switch (value) {
//                     NotionSettingsEmpty() => Column(children: [
//                         const Text(
//                             "A browser will open. Select one page to give Notion access to.",
//                             textAlign: TextAlign.center),
//                         SizedBox(
//                           height: _verticalColumnSpace,
//                         ),
//                         FilledButton(
//                           onPressed: () async {
//                             await _requestCode();
//                           },
//                           child: const Text('Step 1: Get code'),
//                         ),
//                         SizedBox(
//                           height: _verticalColumnSpace,
//                         ),
//                         if (_showCodeError())
//                           const Row(
//                             children: [
//                               Icon(
//                                 Icons.error,
//                                 color: Colors.red,
//                                 size: 24.0,
//                                 semanticLabel: 'Error getting token',
//                               ),
//                               Text("Couldn't get a code. Please try again.")
//                             ],
//                           )
//                       ]),
//                     NotionSettingsCode() => Column(
//                         children: [
//                           FilledButton(
//                             onPressed: _requestingToken
//                                 ? null
//                                 : () async {
//                                     await _requestToken();
//                                   },
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 if (_requestingToken)
//                                   const CircularProgressIndicator(),
//                                 Text(!_requestingToken
//                                     ? 'Step 2: Use code to get token'
//                                     : 'Requesting...')
//                               ],
//                             ),
//                           ),
//                           SizedBox(
//                             height: _verticalColumnSpace,
//                           ),
//                           OutlinedButton(
//                               onPressed: () async {
//                                 await _requestCode();
//                               },
//                               child: const Text('Restart at Step 1')),
//                           SizedBox(
//                             height: _verticalColumnSpace,
//                           ),
//                           if (_showCodeError())
//                             const Row(
//                               children: [
//                                 Icon(
//                                   Icons.error,
//                                   color: Colors.red,
//                                   size: 24.0,
//                                   semanticLabel: 'Error getting token',
//                                 ),
//                                 SizedBox(width: 10),
//                                 Text("Couldn't get a code. Please try again.")
//                               ],
//                             ),
//                           if (_showTokenError())
//                             const Row(
//                               children: [
//                                 Icon(
//                                   Icons.error,
//                                   color: Colors.red,
//                                   size: 24.0,
//                                   semanticLabel: 'Error getting token',
//                                 ),
//                                 SizedBox(width: 10),
//                                 Expanded(
//                                     child: Text(
//                                         "Couldn't get a token. Please try again or restart at step 1 to get a new token.")),
//                               ],
//                             )
//                         ],
//                       ),
//                     NotionSettingsAccessToken() => Column(children: [
//                         const Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(
//                                 Icons.check,
//                                 color: Colors.green,
//                                 size: 48.0,
//                                 semanticLabel: 'Connected to Notion',
//                               ),
//                               SizedBox(width: 10),
//                               Text("Connected",
//                                   style: TextStyle(
//                                     fontSize: 24.0,
//                                   ))
//                             ]),
//                         SizedBox(
//                           height: _verticalColumnSpace,
//                         ),
//                         TextButton(
//                             onPressed: () async {
//                               await _requestCode();
//                             },
//                             child: const Text('Reconnect or update pages')),
//                         SizedBox(
//                           height: _verticalColumnSpace,
//                         ),
//                         if (_showCodeError())
//                           const Row(
//                             children: [
//                               Icon(
//                                 Icons.error,
//                                 color: Colors.red,
//                                 size: 24.0,
//                                 semanticLabel: 'Error getting code',
//                               ),
//                               SizedBox(width: 10),
//                               Text("Couldn't get a code. Please try again.")
//                             ],
//                           ),
//                       ]),
//                   }),
//                 AsyncValue() => throw Exception('Unhandled value')
//               }
//             ],
//           )),
//     );
//   }

//   bool _showCodeError() {
//     return _couldNotRequestCode ||
//         (_launchingBrowser == LaunchingBrowserStatus.returned &&
//             !_receivedCode);
//   }

//   bool _showTokenError() {
//     return _requestingTokenError;
//   }

//   Future<void> _requestCode() async {
//     setState(() {
//       _receivedCode = false;
//       _couldNotRequestCode = false;
//       _requestingTokenError = false;
//     });
//     final authorizeBaseUri =
//         Uri.parse('https://api.notion.com/v1/oauth/authorize');
//     // TODO: Is this tokenUri even needed? Should we replace the manual request
//     // for a token in the relevant service with the implementation from the
//     // oauth package? Or just leave a note that it's not used?
//     final tokenUri = ref.read(uriServiceLegacyProvider());
//     // Don't use UriServiceLegacyProvider because Notion can't redirect to localhost
//     final redirectUri = Uri.parse(
//         'https://exnota.com/api/integration/notion/mobile-code-redirect');
//     var grant = oauth2.AuthorizationCodeGrant(
//         '398d2a32-5c3f-476a-8951-ee9a426981c4', authorizeBaseUri, tokenUri);

//     var authorizeUri = grant.getAuthorizationUrl(redirectUri);

//     if (await canLaunchUrl(authorizeUri)) {
//       setState(() {
//         _launchingBrowser = LaunchingBrowserStatus.launched;
//       });

//       // Defaults to web view. If `mode: LaunchMode.externalApplication` is used
//       // instead it would avoid requiring Notion login for users already logged
//       // in in their default browser. However after finishing auth, it will ask
//       // "Open this page in "Exnota"" before going back to the app. Might be
//       // able to avoid this if we used universal links instead of deep links.
//       await launchUrl(authorizeUri);
//     } else {
//       setState(() {
//         _couldNotRequestCode = true;
//       });
//     }
//   }

//   void _handleIncomingLinks() {
//     _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
//       if (!mounted) return;
//       _saveCode(uri);
//       setState(() {
//         _launchingBrowser = LaunchingBrowserStatus.returned;
//         _receivedCode = true;
//         _couldNotRequestCode = false;
//       });

//       // Close manually, otherwise browser stays open in iOS
//       closeInAppWebView();

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Got a code from Notion'),
//           duration: const Duration(milliseconds: 3000),
//           action: SnackBarAction(
//             label: 'Dismiss',
//             onPressed: () {
//               ScaffoldMessenger.of(context).hideCurrentSnackBar();
//             },
//           ),
//         ),
//       );
//     }, onError: (Object err) {
//       if (!mounted) return;
//       if (err is FormatException) {
//         // TODO: Log
//       } else {
//         // TODO: Log
//       }
//       setState(() {
//         _launchingBrowser = LaunchingBrowserStatus.returned;
//         _receivedCode = false;
//         _couldNotRequestCode = true;
//       });
//     });
//   }

//   void _saveCode(Uri? uri) {
//     final code = uri?.queryParameters["code"];
//     if (code != null) {
//       ref.read(notionSettingsServiceProvider.notifier).saveCode(code);
//     } else {
//       setState(() {
//         _couldNotRequestCode = true;
//       });
//     }
//   }

//   Future<void> _requestToken() async {
//     setState(() {
//       _requestingToken = true;
//       _requestingTokenError = false;
//     });
//     final success =
//         await ref.read(notionSettingsServiceProvider.notifier).fetchToken();
//     setState(() {
//       _requestingToken = false;
//       _requestingTokenError = !success;
//     });
//   }
// }

// class TitleThatCanOpenAlternateNotionSettings extends ConsumerStatefulWidget {
//   final Function() onAlternateSettingsOpened;
//   const TitleThatCanOpenAlternateNotionSettings(
//       {super.key, required this.onAlternateSettingsOpened});

//   @override
//   ConsumerState<TitleThatCanOpenAlternateNotionSettings> createState() =>
//       _TitleThatCanOpenAlternateNotionSettingsState();
// }

// class _TitleThatCanOpenAlternateNotionSettingsState
//     extends ConsumerState<TitleThatCanOpenAlternateNotionSettings> {
//   Timer? timer;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       child: Text(AppLocalizations.of(context)!.integration_connectToNotion),
//       onLongPressDown: (details) {
//         timer ??= Timer(const Duration(seconds: 5), () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => const AlternateNotionSettingsScreen()),
//           );
//         });
//       },
//       onLongPressUp: () {
//         timer?.cancel();
//         timer = null;
//       },
//       onLongPressCancel: () {
//         timer?.cancel();
//         timer = null;
//       },
//     );
//   }
// }
