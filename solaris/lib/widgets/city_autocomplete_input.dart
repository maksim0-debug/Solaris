import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/services/geocoding_service.dart';

class CityAutocompleteInput extends StatefulWidget {
  final GeocodingService geocodingService;
  final bool hasMapboxToken;
  final String? customToken;
  final ValueChanged<CitySearchResult> onCitySelected;
  final TextEditingController? controller;

  const CityAutocompleteInput({
    super.key,
    required this.geocodingService,
    required this.hasMapboxToken,
    this.customToken,
    required this.onCitySelected,
    this.controller,
  });

  @override
  State<CityAutocompleteInput> createState() => _CityAutocompleteInputState();
}

class _CityAutocompleteInputState extends State<CityAutocompleteInput> {
  TextEditingController? _internalController;
  TextEditingController get _cityController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<CitySearchResult> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _cityController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(CityAutocompleteInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _cityController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _cityController.removeListener(_onTextChanged);
    _focusNode.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      final query = _cityController.text;
      if (query.trim().length >= 2) {
        if (_suggestions.isNotEmpty) {
          _showOverlay();
        }
        _onQueryChanged(query);
      }
    } else if (!_isSelecting) {
      _debounceTimer?.cancel();
      _removeOverlay();
    }
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || !_focusNode.hasFocus) return;
      setState(() {
        _isLoading = true;
      });
      _showOverlay();

      final currentLang = Localizations.localeOf(context).languageCode;
      final results = await widget.geocodingService.searchPlaces(
        query,
        language: currentLang,
        customToken: widget.customToken,
      );
      if (!mounted ||
          !_focusNode.hasFocus ||
          _cityController.text.trim() != query.trim())
        return;

      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
      _updateOverlay();
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? Size.zero;
        final l10n = AppLocalizations.of(context)!;
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Material(
              elevation: 12,
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black54,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: const Color(0xFF181825),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFDBA74).withOpacity(0.3),
                  ),
                ),
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFDBA74),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.searchingCities,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          l10n.noCitiesFound,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          return Listener(
                            onPointerDown: (_) {
                              _isSelecting = true;
                            },
                            onPointerCancel: (_) {
                              _isSelecting = false;
                            },
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                LucideIcons.mapPin,
                                size: 16,
                                color: Color(0xFFFDBA74),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                item.fullAddress,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _cityController.text = item.name;
                                _removeOverlay();
                                _focusNode.unfocus();
                                widget.onCitySelected(item);
                                _isSelecting = false;
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = widget.hasMapboxToken;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.searchCity,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            focusNode: _focusNode,
            enabled: enabled,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchCityHint,
              hintStyle: TextStyle(
                color: enabled ? Colors.white24 : Colors.white38,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                enabled ? LucideIcons.search : LucideIcons.lock,
                size: 16,
                color: enabled ? Colors.white54 : Colors.orangeAccent,
              ),
              suffixIcon: _cityController.text.isNotEmpty && enabled
                  ? IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        size: 14,
                        color: Colors.white38,
                      ),
                      onPressed: () {
                        _cityController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: enabled
                  ? Colors.black26
                  : Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.orangeAccent.withOpacity(0.2),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (!enabled) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 12,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.citySearchDisabledNoToken,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
