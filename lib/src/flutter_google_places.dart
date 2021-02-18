library flutter_google_places.src;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart';
import 'package:listenable_stream/listenable_stream.dart';
import 'package:rxdart/rxdart.dart';

class PlacesAutocompleteWidget extends StatefulWidget {
  final String apiKey;
  final String? startText;
  final String? hint;
  final BorderRadius? overlayBorderRadius;
  final Location? location;
  final Location? origin;
  final num? offset;
  final num? radius;
  final String? language;
  final String? sessionToken;
  final List<String>? types;
  final List<Component>? components;
  final bool? strictbounds;
  final String? region;
  final Mode mode;
  final Widget? logo;
  final ValueChanged<PlacesAutocompleteResponse>? onError;
  final Duration? debounce;

  /// optional - sets 'proxy' value in google_maps_webservice
  ///
  /// In case of using a proxy the baseUrl can be set.
  /// The apiKey is not required in case the proxy sets it.
  /// (Not storing the apiKey in the app is good practice)
  final String? proxyBaseUrl;

  /// optional - set 'client' value in google_maps_webservice
  ///
  /// In case of using a proxy url that requires authentication
  /// or custom configuration
  final Client? httpClient;

  PlacesAutocompleteWidget({
    required this.apiKey,
    this.mode = Mode.fullscreen,
    this.hint = "Search",
    this.overlayBorderRadius,
    this.offset,
    this.location,
    this.origin,
    this.radius,
    this.language,
    this.sessionToken,
    this.types,
    this.components,
    this.strictbounds,
    this.region,
    this.logo,
    this.onError,
    Key? key,
    this.proxyBaseUrl,
    this.httpClient,
    this.startText,
    this.debounce,
  }) : super(key: key);

  @override
  State<PlacesAutocompleteWidget> createState() {
    if (mode == Mode.fullscreen) {
      return _PlacesAutocompleteScaffoldState();
    }
    return _PlacesAutocompleteOverlayState();
  }

  static PlacesAutocompleteState of(BuildContext context) =>
      context.findAncestorStateOfType<PlacesAutocompleteState>()!;
}

class _PlacesAutocompleteScaffoldState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(title: AppBarPlacesAutoCompleteTextField());
    final body = PlacesAutocompleteResult(
      onTap: Navigator.of(context).pop,
      logo: widget.logo,
    );
    return Scaffold(appBar: appBar, body: body);
  }
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final headerTopLeftBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.topLeft
        : Radius.circular(2);

    final headerTopRightBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.topRight
        : Radius.circular(2);

    final header = Column(
      children: <Widget>[
        Material(
            color: theme.dialogBackgroundColor,
            borderRadius: BorderRadius.only(
                topLeft: headerTopLeftBorderRadius,
                topRight: headerTopRightBorderRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  color: theme.brightness == Brightness.light
                      ? Colors.black45
                      : null,
                  icon: _iconBack,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Padding(
                    child: _textField(context),
                    padding: const EdgeInsets.only(right: 8.0),
                  ),
                ),
              ],
            )),
        Divider(
            //height: 1.0,
            )
      ],
    );

    final bodyBottomLeftBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.bottomLeft
        : Radius.circular(2);

    final bodyBottomRightBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.bottomRight
        : Radius.circular(2);

    final container = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
      child: Stack(
        children: <Widget>[
          header,
          Padding(
            padding: EdgeInsets.only(top: 48.0),
            child: StreamBuilder<SearchState>(
              stream: state$,
              initialData: state,
              builder: (context, snapshot) {
                final state = snapshot.requireData;

                if (state.isSearching) {
                  return Stack(
                    children: <Widget>[_Loader()],
                    alignment: FractionalOffset.bottomCenter,
                  );
                } else if (state.text.isEmpty ||
                    state.response == null ||
                    state.response!.predictions.isEmpty) {
                  return Material(
                    color: theme.dialogBackgroundColor,
                    child: widget.logo ?? const PoweredByGoogleImage(),
                    borderRadius: BorderRadius.only(
                      bottomLeft: bodyBottomLeftBorderRadius,
                      bottomRight: bodyBottomRightBorderRadius,
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    child: Material(
                      borderRadius: BorderRadius.only(
                        bottomLeft: bodyBottomLeftBorderRadius,
                        bottomRight: bodyBottomRightBorderRadius,
                      ),
                      color: theme.dialogBackgroundColor,
                      child: ListBody(
                        children: state.response?.predictions
                                .map(
                                  (p) => PredictionTile(
                                    prediction: p,
                                    onTap: Navigator.of(context).pop,
                                  ),
                                )
                                .toList(growable: false) ??
                            const <PredictionTile>[],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Padding(padding: EdgeInsets.only(top: 8.0), child: container);
    }
    return container;
  }

  Icon get _iconBack => Theme.of(context).platform == TargetPlatform.iOS
      ? Icon(Icons.arrow_back_ios)
      : Icon(Icons.arrow_back);

  Widget _textField(BuildContext context) => TextField(
        controller: _queryTextController,
        autofocus: true,
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black87
                : null,
            fontSize: 16.0),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black45
                : null,
            fontSize: 16.0,
          ),
          border: InputBorder.none,
        ),
      );
}

class _Loader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(maxHeight: 2.0),
        child: LinearProgressIndicator());
  }
}

class PlacesAutocompleteResult extends StatelessWidget {
  final ValueChanged<Prediction> onTap;
  final Widget? logo;

  PlacesAutocompleteResult({required this.onTap, this.logo});

  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context);

    return StreamBuilder<SearchState>(
      stream: state.state$,
      initialData: state.state,
      builder: (context, snapshot) {
        final state = snapshot.requireData;

        if (state.text.isEmpty ||
            state.response == null ||
            state.response!.predictions.isEmpty) {
          final children = <Widget>[];
          if (state.isSearching) {
            children.add(_Loader());
          }
          children.add(logo ?? const PoweredByGoogleImage());
          return Stack(children: children);
        }
        return PredictionsListView(
          predictions: state.response?.predictions ?? [],
          onTap: onTap,
        );
      },
    );
  }
}

class AppBarPlacesAutoCompleteTextField extends StatefulWidget {
  final InputDecoration? textDecoration;
  final TextStyle? textStyle;

  AppBarPlacesAutoCompleteTextField(
      {Key? key, this.textDecoration, this.textStyle})
      : super(key: key);

  @override
  _AppBarPlacesAutoCompleteTextFieldState createState() =>
      _AppBarPlacesAutoCompleteTextFieldState();
}

class _AppBarPlacesAutoCompleteTextFieldState
    extends State<AppBarPlacesAutoCompleteTextField> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context);

    return Container(
      alignment: Alignment.topLeft,
      margin: EdgeInsets.only(top: 4.0),
      child: TextField(
        controller: state._queryTextController,
        autofocus: true,
        style: widget.textStyle ?? _defaultStyle(),
        decoration:
            widget.textDecoration ?? _defaultDecoration(state.widget.hint),
      ),
    );
  }

  InputDecoration _defaultDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white30
          : Colors.black38,
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.black38
            : Colors.white30,
        fontSize: 16.0,
      ),
      border: InputBorder.none,
    );
  }

  TextStyle _defaultStyle() {
    return TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.black.withOpacity(0.9)
          : Colors.white.withOpacity(0.9),
      fontSize: 16.0,
    );
  }
}

class PoweredByGoogleImage extends StatelessWidget {
  final _poweredByGoogleWhite =
      "packages/flutter_google_places/assets/google_white.png";
  final _poweredByGoogleBlack =
      "packages/flutter_google_places/assets/google_black.png";

  const PoweredByGoogleImage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Padding(
          padding: EdgeInsets.all(16.0),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.light
                ? _poweredByGoogleWhite
                : _poweredByGoogleBlack,
            scale: 2.5,
          ))
    ]);
  }
}

class PredictionsListView extends StatelessWidget {
  final List<Prediction> predictions;
  final ValueChanged<Prediction>? onTap;

  PredictionsListView({required this.predictions, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: predictions
          .map((Prediction p) => PredictionTile(prediction: p, onTap: onTap))
          .toList(growable: false),
    );
  }
}

class PredictionTile extends StatelessWidget {
  final Prediction prediction;
  final ValueChanged<Prediction>? onTap;

  PredictionTile({required this.prediction, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.location_on),
      title: Text(prediction.description),
      onTap: () => onTap?.call(prediction),
    );
  }
}

enum Mode { overlay, fullscreen }

abstract class PlacesAutocompleteState extends State<PlacesAutocompleteWidget> {
  late final TextEditingController _queryTextController =
      TextEditingController(text: widget.startText);
  GoogleMapsPlaces? _places;

  late final Stream<SearchState> state$;
  var state = SearchState(false, null, '');
  StreamSubscription<SearchState>? subscription;

  @override
  void initState() {
    super.initState();

    _initPlaces();

    state$ = _queryTextController
        .toValueStream(replayValue: true)
        .map((event) => event.text)
        .debounceTime(widget.debounce ?? const Duration(milliseconds: 300))
        .where((s) => s.isNotEmpty && _places != null)
        .distinct()
        .switchMap(doSearch)
        .doOnData((event) => state = event)
        .share();
    subscription = state$.listen(null);
  }

  Future<void> _initPlaces() async {
    final headers = await GoogleApiHeaders().getHeaders();
    debugPrint('[flutter_google_places] headers=$headers');

    if (!mounted) {
      return;
    }
    _places = GoogleMapsPlaces(
      apiKey: widget.apiKey,
      baseUrl: widget.proxyBaseUrl,
      httpClient: widget.httpClient,
      apiHeaders: headers,
    );
  }

  Stream<SearchState> doSearch(String value) async* {
    yield SearchState(true, null, value);

    debugPrint(
        '[flutter_google_places] input=$value location=${widget.location} origin=${widget.origin}');
    final res = await _places!.autocomplete(
      value,
      offset: widget.offset,
      location: widget.location,
      radius: widget.radius,
      language: widget.language,
      sessionToken: widget.sessionToken,
      types: widget.types ?? const [],
      components: widget.components ?? const [],
      strictbounds: widget.strictbounds ?? false,
      region: widget.region,
      origin: widget.origin,
    );

    if (res.errorMessage?.isNotEmpty == true ||
        res.status == "REQUEST_DENIED") {
      onResponseError(res);
    }

    final sorted = res.predictions.sortedBy<num>((e) => e.distanceMeters);
    debugPrint(
        '[flutter_google_places] sorted=${sorted.map((e) => e.distanceMeters).toList(growable: false)}');
    yield SearchState(
      false,
      PlacesAutocompleteResponse(
        status: res.status,
        errorMessage: res.errorMessage,
        predictions: sorted,
      ),
      value,
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    subscription = null;
    _queryTextController.dispose();
    _places?.dispose();
    super.dispose();
  }

  @mustCallSuper
  void onResponseError(PlacesAutocompleteResponse res) {
    if (!mounted) return;
    widget.onError?.call(res);
  }

  @mustCallSuper
  void onResponse(PlacesAutocompleteResponse res) {}
}

class SearchState {
  final String text;
  final bool isSearching;
  final PlacesAutocompleteResponse? response;

  SearchState(this.isSearching, this.response, this.text);
}

class PlacesAutocomplete {
  static Future<Prediction?> show({
    required BuildContext context,
    required String apiKey,
    Mode mode = Mode.fullscreen,
    String? hint = "Search",
    BorderRadius? overlayBorderRadius,
    num? offset,
    Location? location,
    num? radius,
    String? language,
    String? sessionToken,
    List<String>? types,
    List<Component>? components,
    bool? strictbounds,
    String? region,
    Widget? logo,
    ValueChanged<PlacesAutocompleteResponse>? onError,
    String? proxyBaseUrl,
    Client? httpClient,
    String? startText = "",
    Duration? debounce,
    Location? origin,
  }) {
    final builder = (BuildContext ctx) => PlacesAutocompleteWidget(
          apiKey: apiKey,
          mode: mode,
          overlayBorderRadius: overlayBorderRadius,
          language: language,
          sessionToken: sessionToken,
          components: components,
          types: types,
          location: location,
          radius: radius,
          strictbounds: strictbounds,
          region: region,
          offset: offset,
          hint: hint,
          logo: logo,
          onError: onError,
          proxyBaseUrl: proxyBaseUrl,
          httpClient: httpClient,
          startText: startText,
          debounce: debounce,
          origin: origin,
        );

    if (mode == Mode.overlay) {
      return showDialog<Prediction>(context: context, builder: builder);
    }
    return Navigator.push<Prediction>(
        context, MaterialPageRoute(builder: builder));
  }
}
