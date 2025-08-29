import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hands_app/widgets/responsive_appbar_title.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/ui/upgrade_location_sheet.dart';

class LocationWizard extends StatefulWidget {
  final String organizationId;
  final String? locationId; // If provided, edit mode
  final Map<String, dynamic>? initialData; // For editing
  final VoidCallback? onCompleted;
  const LocationWizard({super.key, required this.organizationId, this.locationId, this.initialData, this.onCompleted});

  @override
  State<LocationWizard> createState() => _LocationWizardState();
}

class _LocationWizardState extends State<LocationWizard> {
  int _currentStep = 0;
  bool _loading = false;
  int _subscriptionQuantity = 0;
  int _existingLocationCount = 0;
  bool _initialized = false;

  // For edit mode, only one draft
  late final List<_LocationDraft> _drafts;

  @override
  void initState() {
    super.initState();
    // Always reset _currentStep to 0 on init
    _currentStep = 0;
    if (widget.locationId != null && widget.initialData != null) {
      // Edit mode: prefill draft from initialData
      final d = _LocationDraft();
      d.nameController.text = widget.initialData!['locationName'] ?? '';
      var address = widget.initialData!['address'];
      if (address is Map) {
        // Join address fields if stored as a map
        d.addressController.text = [
          address['street'],
          address['city'],
          address['state'],
          address['zipCode'] ?? address['zip'],
        ].where((v) => v != null && v.toString().isNotEmpty).join(', ');
      } else if (address is String) {
        d.addressController.text = address;
      } else {
        d.addressController.text = '';
      }
      d.selectedPlaceId = widget.initialData!['placeId'];
      d.formattedAddress = widget.initialData!['formattedAddress'];
      d.lat = (widget.initialData!['lat'] as num?)?.toDouble();
      d.lng = (widget.initialData!['lng'] as num?)?.toDouble();
      d.addressComponents = widget.initialData!['addressComponents'] as Map<String, dynamic>?;
      _drafts = [d];
    } else {
      _drafts = [_LocationDraft()];
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final sub = await StripeService.getSubscriptionData(widget.organizationId);
      _subscriptionQuantity = (sub?['quantity'] as int?) ?? 1;

      final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId).get();
      _existingLocationCount = (orgDoc.data()?['locationCount'] as int?) ?? 0;

      if (_existingLocationCount == 0) {
        final locSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
                .collection('locations')
                .get();
        _existingLocationCount = locSnap.size;
      }
    } catch (e) {
      debugPrint('[LocationWizard] Init error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initialized = true;
          _loading = false;
        });
      }
    }
  }

  int get _remainingSlots => (_subscriptionQuantity - _existingLocationCount).clamp(0, 100000);

  bool get _canAddMoreRows => _remainingSlots == 0 ? false : _drafts.length < _remainingSlots;

  bool _validateDrafts() {
    for (final d in _drafts) {
      if (d.nameController.text.trim().isEmpty || d.addressController.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _finish() async {
    if (!_validateDrafts()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill in all location names and addresses')));
      return;
    }

    setState(() => _loading = true);
    try {
      final orgRef = FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId);
      final locationsRef = orgRef.collection('locations');
      final d = _drafts.first;
      final payload = <String, dynamic>{
        'locationName': d.nameController.text.trim(),
        'address': d.addressController.text.trim(),
        'placeId': d.selectedPlaceId,
        'organizationId': widget.organizationId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (d.formattedAddress != null && d.formattedAddress!.isNotEmpty) {
        payload['formattedAddress'] = d.formattedAddress;
      }
      if (d.lat != null) payload['lat'] = d.lat;
      if (d.lng != null) payload['lng'] = d.lng;
      if (d.addressComponents != null) payload['addressComponents'] = d.addressComponents;

      if (widget.locationId != null) {
        // Edit mode: update existing doc
        await locationsRef.doc(widget.locationId).set(payload, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Location updated'), backgroundColor: Colors.green));
        }
      } else {
        // Add mode: create new doc
        payload['isPrimary'] = _existingLocationCount == 0;
        payload['createdAt'] = FieldValue.serverTimestamp();
        await locationsRef.doc().set(payload);
        await orgRef
            .update({'locationCount': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()})
            .catchError((_) {});
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Location added'), backgroundColor: Colors.green));
        }
      }

      // If a parent supplies onCompleted it is responsible for closing the dialog / route.
      // Previously we always called Navigator.pop() here AND most callers (e.g. admin dashboard)
      // also popped inside their onCompleted callback, resulting in a double pop that
      // triggered GoRouter's `currentConfiguration.isNotEmpty` assertion and subsequent
      // setState-after-dispose errors when async loads completed on the disposed page.
      final hasExternalCompletionHandler = widget.onCompleted != null;
      try {
        widget.onCompleted?.call();
      } catch (e) {
        debugPrint('[LocationWizard] onCompleted handler threw: $e');
      }
      if (!hasExternalCompletionHandler && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[LocationWizard] Error saving locations: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving locations: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleOverQuota() async {
    if (_subscriptionQuantity >= 5) {
      await showDialog(context: context, builder: (ctx) => const _SalesDialog());
    } else {
      // Offer in-app quantity upgrade
      await _openUpgradeQuantitySheet();
    }
  }

  Future<void> _openUpgradeQuantitySheet() async {
    try {
      final sub = await StripeService.getSubscriptionData(widget.organizationId);
      final subscriptionId = sub?['subscriptionId'] as String?;
      final currentQty = (sub?['quantity'] as int?) ?? _subscriptionQuantity;
      if (subscriptionId == null) {
        // Fallback to billing portal if we can't find subscriptionId
        await StripeService.openBillingPortal(widget.organizationId);
        return;
      }
      final newQty = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder:
            (ctx) => UpgradeLocationSheet(
              orgId: widget.organizationId,
              subscriptionId: subscriptionId,
              currentQuantity: currentQty,
            ),
      );
      if (newQty != null && mounted) {
        setState(() {
          _subscriptionQuantity = newQty;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan updated to $newQty location(s)')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open upgrade flow: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: ResponsiveAppBarTitle(widget.locationId != null ? 'Edit Location' : 'Add Location')),
      body:
          !_initialized || _loading
              ? const Center(child: CircularProgressIndicator())
              : Stepper(
                currentStep: _currentStep,
                onStepCancel:
                    widget.locationId != null
                        ? null
                        : (_currentStep == 0 ? null : () => setState(() => _currentStep -= 1)),
                onStepContinue:
                    widget.locationId != null
                        ? () async {
                          // In edit mode, just save
                          await _finish();
                        }
                        : () async {
                          if (_currentStep == 1) {
                            if (!_validateDrafts()) return;
                          }
                          if (_currentStep == 2) {
                            await _finish();
                          } else {
                            setState(() => _currentStep += 1);
                          }
                        },
                controlsBuilder: (context, details) {
                  final isLast = _currentStep == 2 || widget.locationId != null;
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        ElevatedButton(onPressed: details.onStepContinue, child: Text(isLast ? 'Finish' : 'Next')),
                        const SizedBox(width: 12),
                        if (_currentStep > 0 && widget.locationId == null)
                          TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                      ],
                    ),
                  );
                },
                steps:
                    widget.locationId != null
                        ? [
                          Step(
                            title: const Text('Edit Location'),
                            isActive: true,
                            content: _LocationRow(draft: _drafts.first),
                          ),
                        ]
                        : [
                          Step(
                            title: const Text('Overview'),
                            isActive: _currentStep >= 0,
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Plan capacity: $_subscriptionQuantity location(s)'),
                                Text('Existing: $_existingLocationCount'),
                                Text('Remaining: $_remainingSlots'),
                                const SizedBox(height: 8),
                                const Text(
                                  'You can add new locations here. We use your billing plan’s quantity to limit how many you can create.',
                                ),
                                if (_remainingSlots == 0) ...[
                                  const SizedBox(height: 12),
                                  const Text('No remaining slots on your plan.'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          if (_subscriptionQuantity >= 5) {
                                            await showDialog(context: context, builder: (ctx) => const _SalesDialog());
                                          } else {
                                            await _openUpgradeQuantitySheet();
                                          }
                                        },
                                        child: const Text('Upgrade Plan'),
                                      ),
                                      const SizedBox(width: 8),
                                      if (_subscriptionQuantity >= 5) const _SalesButtonInline(),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Step(
                            title: const Text('Locations'),
                            isActive: _currentStep >= 1,
                            content: Column(
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _drafts.length,
                                  itemBuilder: (context, index) {
                                    final draft = _drafts[index];
                                    return _LocationRow(
                                      key: ValueKey('loc_row_$index'),
                                      draft: draft,
                                      onRemove:
                                          _drafts.length == 1
                                              ? null
                                              : () => setState(() {
                                                _drafts.removeAt(index);
                                              }),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _canAddMoreRows
                                            ? () {
                                              if (_existingLocationCount + _drafts.length + 1 > _subscriptionQuantity) {
                                                _handleOverQuota();
                                                return;
                                              }
                                              setState(() => _drafts.add(_LocationDraft()));
                                            }
                                            : null,
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      'Add another (${_remainingSlots - _drafts.length >= 0 ? _remainingSlots - _drafts.length : 0} left)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Step(
                            title: const Text('Review'),
                            isActive: _currentStep >= 2,
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New locations to create:'),
                                const SizedBox(height: 8),
                                ..._drafts.map(
                                  (d) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.home_work_outlined),
                                    title: Text(
                                      d.nameController.text.trim().isEmpty ? '(No name)' : d.nameController.text.trim(),
                                    ),
                                    subtitle: Text(
                                      d.addressController.text.trim().isEmpty
                                          ? '(No address)'
                                          : d.addressController.text.trim(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('Will create ${_drafts.length} and update organization count.'),
                              ],
                            ),
                          ),
                        ],
              ),
    );
  }
}

class _LocationDraft {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String? selectedPlaceId;
  // Structured fields populated from Places Details (New)
  String? formattedAddress;
  double? lat;
  double? lng;
  Map<String, dynamic>? addressComponents;

  void dispose() {
    nameController.dispose();
    addressController.dispose();
  }
}

class _LocationRow extends StatefulWidget {
  final _LocationDraft draft;
  final VoidCallback? onRemove;
  const _LocationRow({super.key, required this.draft, this.onRemove});

  @override
  State<_LocationRow> createState() => _LocationRowState();
}

class _LocationRowState extends State<_LocationRow> {
  final _addrFocus = FocusNode();
  Timer? _debounce;
  List<_PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  String? _sessionToken; // Places API (New) session token
  String? _autoStatus; // Debug/status hint for web autocomplete
  bool _attemptedAutocomplete = false; // Show attribution even if no suggestions

  @override
  void initState() {
    super.initState();
    widget.draft.addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.draft.addressController.removeListener(_onAddressChanged);
    _addrFocus.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(widget.draft.addressController.text.trim());
    });
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _suggestions = [];
        _autoStatus = null;
        _attemptedAutocomplete = false;
      });
      return;
    }
    _attemptedAutocomplete = true;
    setState(() => _loading = true);
    try {
      // Ensure we have a session token for this typing session
      _sessionToken ??= _newSessionToken();

      // Locale hints
      final locale = Localizations.maybeLocaleOf(context);
      final languageCode = locale?.languageCode;
      final regionCode = (locale?.countryCode?.isNotEmpty ?? false) ? locale!.countryCode : null;

      Map<String, dynamic>? data;
      if (kIsWeb) {
        // Use HTTP proxy endpoint with CORS enabled
        try {
          final uri = Uri.parse(
            'https://us-central1-${DefaultFirebaseOptions.web.projectId}.cloudfunctions.net/placesAutocompleteHttp',
          );
          final resp = await http.post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'input': input,
              'sessionToken': _sessionToken,
              if (languageCode != null) 'languageCode': languageCode,
              if (regionCode != null) 'regionCode': regionCode,
            }),
          );
          if (resp.statusCode == 200) {
            data = json.decode(resp.body) as Map<String, dynamic>;
            _autoStatus = null;
          } else {
            debugPrint('[Places] proxy HTTP ${resp.statusCode}: ${resp.body}');
            _autoStatus = 'Autocomplete unavailable';
          }
        } catch (e) {
          debugPrint('[Places] proxy error: $e');
          _autoStatus = 'Autocomplete unavailable';
        }
      } else {
        if (kGooglePlacesApiKey.isEmpty) {
          setState(() {
            _suggestions = [];
            _autoStatus = null;
          });
          return;
        }
        final uri = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
        final body = <String, dynamic>{
          'input': input,
          'sessionToken': _sessionToken,
          if (languageCode != null) 'languageCode': languageCode,
          if (regionCode != null) 'regionCode': regionCode,
        };
        final resp = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Goog-Api-Key': kGooglePlacesApiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,suggestions.placePrediction.place,suggestions.placePrediction.text',
            if (_sessionToken != null) 'X-Goog-Maps-Session-Token': _sessionToken!,
          },
          body: jsonEncode(body),
        );
        if (resp.statusCode == 200) {
          data = json.decode(resp.body) as Map<String, dynamic>;
        } else {
          debugPrint('[Places] autocomplete HTTP ${resp.statusCode}: ${resp.body}');
        }
      }

      if (data != null) {
        final suggestionsRaw = (data['suggestions'] as List<dynamic>? ?? []);
        final preds =
            suggestionsRaw
                .map((e) => _PlaceSuggestion.fromPlacesNew(e as Map<String, dynamic>))
                .where((s) => s != null)
                .cast<_PlaceSuggestion>()
                .toList();
        setState(() {
          _suggestions = preds.take(5).toList();
          // If no suggestions but no error, show a gentle hint
          if (_suggestions.isEmpty && _autoStatus == null && input.isNotEmpty) {
            _autoStatus = 'No suggestions';
          }
        });
      } else {
        setState(() {
          _suggestions = [];
          _autoStatus ??= 'Autocomplete unavailable';
        });
      }
    } catch (e) {
      debugPrint('[Places] error: $e');
      setState(() {
        _suggestions = [];
        _autoStatus = 'Autocomplete error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Select a suggestion: fetch Place Details (New) and populate structured fields
  Future<void> _selectSuggestion(_PlaceSuggestion s) async {
    widget.draft.addressController.text = s.description;
    widget.draft.selectedPlaceId = s.placeId;
    setState(() => _suggestions = []);

    if (s.placeId.isEmpty) return;

    try {
      final locale = Localizations.maybeLocaleOf(context);
      final languageCode = locale?.languageCode;
      final regionCode = (locale?.countryCode?.isNotEmpty ?? false) ? locale!.countryCode : null;

      Map<String, dynamic>? data;
      if (kIsWeb) {
        try {
          final uri = Uri.parse(
            'https://us-central1-${DefaultFirebaseOptions.web.projectId}.cloudfunctions.net/placeDetailsHttp',
          );
          final resp = await http.post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'placeId': s.placeId,
              'sessionToken': _sessionToken,
              if (languageCode != null) 'languageCode': languageCode,
              if (regionCode != null) 'regionCode': regionCode,
            }),
          );
          if (resp.statusCode == 200) {
            data = json.decode(resp.body) as Map<String, dynamic>;
          } else {
            debugPrint('[Places] details proxy HTTP ${resp.statusCode}: ${resp.body}');
          }
        } catch (e) {
          debugPrint('[Places] details proxy error: $e');
        }
      } else {
        if (kGooglePlacesApiKey.isEmpty) return;
        // v1 Places Details. Accept placeId either as raw place id or resource name.
        final resourceName = s.placeId.startsWith('places/') ? s.placeId : 'places/${s.placeId}';
        final uri = Uri.parse('https://places.googleapis.com/v1/$resourceName');
        final headers = <String, String>{
          'X-Goog-Api-Key': kGooglePlacesApiKey,
          // Field mask per Places API (New)
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,addressComponents',
          if (_sessionToken != null) 'X-Goog-Maps-Session-Token': _sessionToken!,
        };
        final qs = <String, String>{
          if (languageCode != null) 'languageCode': languageCode,
          if (regionCode != null) 'regionCode': regionCode,
        };
        final detailsUri = uri.replace(queryParameters: qs.isEmpty ? null : qs);
        final resp = await http.get(detailsUri, headers: headers);
        if (resp.statusCode == 200) {
          data = json.decode(resp.body) as Map<String, dynamic>;
        } else {
          debugPrint('[Places] details HTTP ${resp.statusCode}: ${resp.body}');
        }
      }

      if (data != null) {
        final formattedAddress = data['formattedAddress'] as String?;
        final location = data['location'] as Map<String, dynamic>?;
        final lat = (location?['latitude'] as num?)?.toDouble();
        final lng = (location?['longitude'] as num?)?.toDouble();
        final components = data['addressComponents'] as List<dynamic>?;

        widget.draft.formattedAddress = formattedAddress ?? widget.draft.addressController.text;
        widget.draft.lat = lat;
        widget.draft.lng = lng;
        if (components != null) {
          widget.draft.addressComponents = {'components': components};
        }
      }
    } catch (e) {
      debugPrint('[Places] details error: $e');
    } finally {
      // Per-session token must be reset after a selection
      _sessionToken = null;
    }
  }

  String _newSessionToken() {
    Random r;
    try {
      r = Random.secure();
    } catch (_) {
      r = Random();
    }
    // Use a safe upper bound for web (avoid 1 << 32 causing RangeError in JS backends)
    const int upper = 1 << 31; // 2^31
    final ts = DateTime.now().microsecondsSinceEpoch;
    final a = r.nextInt(upper).toRadixString(36);
    final b = r.nextInt(upper).toRadixString(36);
    return '${ts.toRadixString(36)}_${a}_$b';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: widget.draft.nameController,
              decoration: const InputDecoration(labelText: 'Location Name', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.draft.addressController,
              focusNode: _addrFocus,
              decoration: InputDecoration(
                labelText: 'Address',
                border: const OutlineInputBorder(),
                suffixIcon:
                    _loading
                        ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                        : null,
              ),
              textInputAction: TextInputAction.done,
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ..._suggestions.map(
                      (s) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(s.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectSuggestion(s),
                      ),
                    ),
                    const Divider(height: 1),
                    const _GoogleAttribution(),
                  ],
                ),
              ),
            if (_suggestions.isEmpty && _autoStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_autoStatus!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
              ),
            // Always show attribution when user is typing/attempting autocomplete, even if no suggestions
            if (_suggestions.isEmpty && _attemptedAutocomplete)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(opacity: 0.9, child: const _GoogleAttribution()),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.onRemove != null)
                  TextButton.icon(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  final String description;
  final String placeId;
  _PlaceSuggestion({required this.description, required this.placeId});
  // ignore: unused_element
  factory _PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      _PlaceSuggestion(description: json['description'] as String? ?? '', placeId: json['place_id'] as String? ?? '');

  // Parser for Places API (New) autocomplete suggestion
  // Expected shape: { "placePrediction": { "placeId": "..." | "place": "places/...", "text": { "text": "..." } } }
  static _PlaceSuggestion? fromPlacesNew(Map<String, dynamic> json) {
    final placePrediction = json['placePrediction'] as Map<String, dynamic>?;
    if (placePrediction == null) return null;
    String? desc;
    final textObj = placePrediction['text'] as Map<String, dynamic>?;
    if (textObj != null) {
      desc = textObj['text'] as String?;
    }
    // Try both placeId and resource name
    String? pid = placePrediction['placeId'] as String?;
    pid ??= placePrediction['place'] as String?; // e.g., "places/ChIJ..."
    if (pid != null && pid.startsWith('places/')) {
      pid = pid.substring('places/'.length);
    }
    if ((desc == null || desc.isEmpty) && json['suggestion'] is String) {
      desc = json['suggestion'] as String; // fallback
    }
    if (pid == null || (desc == null || desc.isEmpty)) return null;
    return _PlaceSuggestion(description: desc, placeId: pid);
  }
}

class _SalesDialog extends StatelessWidget {
  const _SalesDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Sales'),
      content: const Text('For 5 or more locations, please contact our sales team for a customized plan.'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

class _SalesButtonInline extends StatelessWidget {
  const _SalesButtonInline();
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showDialog(context: context, builder: (_) => const _SalesDialog()),
      icon: const Icon(Icons.support_agent),
      label: const Text('Contact Sales'),
    );
  }
}

/// Required attribution for Google Places Autocomplete results.
/// See: https://developers.google.com/maps/documentation/places/web-service/policies#attribution
class _GoogleAttribution extends StatelessWidget {
  const _GoogleAttribution();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimal, compliant “Powered by Google” mark.
          // Prefer using the official asset; fall back to text if it fails to load.
          // Prefer a text fallback to avoid cross-origin fetches for the attribution asset on web
          const Text('Powered by Google', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

Future<void> maybeLaunchLocationWizard(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    final orgId = userDoc.data()?['organizationId'] as String?;
    if (orgId == null || orgId.isEmpty) return;

    final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(orgId).get();
    final count = (orgDoc.data()?['locationCount'] as int?) ?? 0;
    if (count > 0) return;

    final locSnap =
        await FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('locations').limit(1).get();
    if (locSnap.docs.isNotEmpty) return;

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocationWizard(organizationId: orgId)));
  } catch (e) {
    debugPrint('[LocationWizard] maybeLaunch error: $e');
  }
}
