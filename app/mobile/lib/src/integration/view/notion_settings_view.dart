import 'dart:async';

import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/integration/service/notion_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

// TODO: Refector into controller pattern? (is that a thing) to simplify this widget?
/// Initiates Notion auth process.
class NotionSettingsView extends ConsumerStatefulWidget {
  const NotionSettingsView({super.key});

  @override
  ConsumerState<NotionSettingsView> createState() => _NotionSettingsView();
}

class _NotionSettingsView extends ConsumerState<NotionSettingsView> {
  bool _requestingToken = false;
  Uri? _latestUri;
  // String? codeFromRedirect;
  // TODO: Error handling?
  Object? _errFromRedirect;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    print('disposed');
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notionSettings = ref.watch(notionSettingsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.integration_connectToNotion),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              switch (notionSettings) {
                AsyncError(:final error) => Text('error=$error'),
                AsyncLoading() => const CircularProgressIndicator(),
                AsyncData(:final value) => Column(
                    children: [
                      switch (value) {
                        NotionSettingsEmpty() => Row(
                            children: [
                              OutlinedButton(
                                  onPressed: () async {
                                    await _launch();
                                  },
                                  child: const Text('Step 1: Get code'))
                            ],
                          ),
                        NotionSettingsCode() => Row(
                            children: [
                              OutlinedButton(
                                  onPressed: _requestingToken
                                      ? null
                                      : () async {
                                          await _requestAccessToken();
                                        },
                                  child: Text(!_requestingToken
                                      ? 'Step 2: Use code to get token'
                                      : 'Requesting...')),
                              OutlinedButton(
                                  onPressed: () async {
                                    await _launch();
                                  },
                                  child: const Text('Restart at Step 1')),
                            ],
                          ),
                        NotionSettingsAccessToken() => Row(
                            children: [
                              OutlinedButton(
                                  onPressed: () async {
                                    await _launch();
                                  },
                                  child: const Text('Restart at Step 1')),
                            ],
                          ),
                      },
                      switch (value) {
                        NotionSettingsEmpty() => const Text('Empty'),
                        NotionSettingsCode() => Text('Code: ${value.code}'),
                        NotionSettingsAccessToken() => Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 24.0,
                                    semanticLabel: 'Successfully connected',
                                  ),
                                  Text('Successfully connected')
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Access token: ${value.accessToken}'),
                            ],
                          )
                      }
                    ],
                  ),
                AsyncValue() => throw Exception('Unhandled value')
              }
            ],
          )),
    );
  }

  void _handleIncomingLinks() {
    _sub = uriLinkStream.listen((Uri? uri) {
      if (!mounted) return;
      print('xyz about _saveCode');
      _saveCode(uri);
      print('xyz about to set state on listen');
      setState(() {
        _latestUri = uri;
        _errFromRedirect = null;
      });
    }, onError: (Object err) {
      if (!mounted) return;
      print('xyz error handling link');
      setState(() {
        _latestUri = null;
        if (err is FormatException) {
          _errFromRedirect = err;
        } else {
          _errFromRedirect = null;
        }
      });
    }, onDone: () {});
  }

  void _saveCode(Uri? uri) {
    final code = uri?.queryParameters["code"];
    if (code != null) {
      print('xyz about to .saveCode');
      ref.read(notionSettingsServiceProvider.notifier).saveCode(code);
    }
    // TODO: If code is null, show an error
  }

  Future<void> _launch() async {
    final authorizeBaseUri =
        Uri.parse('https://api.notion.com/v1/oauth/authorize');
    // TODO: Is this even needed? Should we replace existing implementation with this?
    // Or just leave a note that it's not used? See commented-out code below.
    final tokenUri = Uri.parse('https://exnota.com');
    final redirectUri = Uri.parse(
        'https://exnota.com/api/integration/notion/mobile-code-redirect');
    var grant = oauth2.AuthorizationCodeGrant(
        '398d2a32-5c3f-476a-8951-ee9a426981c4', authorizeBaseUri, tokenUri);

    var authorizeUri = grant.getAuthorizationUrl(redirectUri);

    print('xyz about to_redirect');
    await _redirect(authorizeUri);
    // var responseUrl = listen(redirectUri);

    // Once the user is redirected to `redirectUrl`, pass the query parameters to
    // the AuthorizationCodeGrant. It will validate them and extract the
    // authorization code to create a new Client.
    // return await grant.handleAuthorizationResponse(responseUrl.queryParameters);
  }

  Future<void> _redirect(Uri authorizeUri) async {
    if (await canLaunchUrl(authorizeUri)) {
      print('xyz about launchUrl');
      await launchUrl(authorizeUri);
    } else {
      // TODO: Show error?
    }
  }

  Future<void> _requestAccessToken() async {
    setState(() {
      _requestingToken = true;
    });
    await ref.read(notionSettingsServiceProvider.notifier).fetchToken();
    setState(() {
      _requestingToken = false;
    });
  }
}
