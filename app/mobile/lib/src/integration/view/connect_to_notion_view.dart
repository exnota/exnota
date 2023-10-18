import 'dart:async';

import 'package:Exnota/src/integration/notion_settings.dart';
import 'package:Exnota/src/integration/service/notion_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

/// Initiates Notion auth process.
class ConnectToNotionView extends ConsumerStatefulWidget {
  const ConnectToNotionView({super.key});

  @override
  ConsumerState<ConnectToNotionView> createState() => _ConnectToNotionView();
}

// TODO: Remove if not necessary: with SingleTickerProviderStateMixin
class _ConnectToNotionView extends ConsumerState<ConnectToNotionView>
    with SingleTickerProviderStateMixin {
  Uri? _latestUri;
  // String? codeFromRedirect;
  Object? _errFromRedirect;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
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
                AsyncError() => const Text('error'),
                AsyncLoading() => const CircularProgressIndicator(),
                AsyncData(:final value) => switch (value) {
                    NotionSettingsEmpty() => OutlinedButton(
                        onPressed: () async {
                          await _launch();
                        },
                        child: const Text('Start')),
                    NotionSettingsCode() => Text('Code: ${value.code}'),
                    NotionSettingsAccessToken() =>
                      Text('Access token: ${value.accessToken}')
                  },
                AsyncValue() => throw Exception('Unhandled value')
              },
              if (_latestUri != null) Text('uri=${_latestUri?.path}'),
              if (_errFromRedirect != null) Text('err=$_errFromRedirect'),
              if (_latestUri == null && _errFromRedirect == null)
                const Text('both are null')
            ],
          )),
    );
  }

  /// Handle incoming links - the ones that the app will recieve from the OS
  /// while already started.
  void _handleIncomingLinks() {
    // It will handle app links while the app is already started - be it in
    // the foreground or in the background.
    _sub = uriLinkStream.listen((Uri? uri) {
      if (!mounted) return;
      print('got uri: $uri');
      setState(() {
        _latestUri = uri;
        _errFromRedirect = null;
      });
    }, onError: (Object err) {
      if (!mounted) return;
      print('got err: $err');
      setState(() {
        _latestUri = null;
        if (err is FormatException) {
          _errFromRedirect = err;
        } else {
          _errFromRedirect = null;
        }
      });
    });
  }

  Future<void> _launch() async {
    // If we don't have OAuth2 credentials yet, we need to get the resource owner
    // to authorize us. We're assuming here that we're a command-line application.
    final authorizeBaseUri =
        Uri.parse('https://api.notion.com/v1/oauth/authorize');
    final tokenUri = Uri.parse('https://exnota.com');
    final redirectUri = Uri.parse('https://exnota.com');
    var grant = oauth2.AuthorizationCodeGrant(
        '398d2a32-5c3f-476a-8951-ee9a426981c4', authorizeBaseUri, tokenUri);

    // A URL on the authorization server (authorizationEndpoint with some additional
    // query parameters). Scopes and state can optionally be passed into this method.
    var authorizeUri = grant.getAuthorizationUrl(redirectUri);

    // Redirect the resource owner to the authorization URL. Once the resource
    // owner has authorized, they'll be redirected to `redirectUrl` with an
    // authorization code. The `redirect` should cause the browser to redirect to
    // another URL which should also have a listener.
    //
    // `redirect` and `listen` are not shown implemented here. See below for the
    // details.
    await _redirect(authorizeUri);
    // var responseUrl = listen(redirectUri);

    // Once the user is redirected to `redirectUrl`, pass the query parameters to
    // the AuthorizationCodeGrant. It will validate them and extract the
    // authorization code to create a new Client.
    // return await grant.handleAuthorizationResponse(responseUrl.queryParameters);
  }

  Future<void> _redirect(Uri authorizeUri) async {
    if (await canLaunchUrl(authorizeUri)) {
      print('can launch ${authorizeUri.path}');
      await launchUrl(authorizeUri);
    } else {
      print('cannot launch ${authorizeUri.path}');
    }
  }
}
