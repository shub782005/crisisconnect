import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/need_model.dart';
import '../../providers/map_provider.dart';
import '../../providers/needs_provider.dart';
import '../../services/map_marker_service.dart';
import '../../widgets/urgency_badge.dart';

class CrisisMapScreen extends StatefulWidget {
  const CrisisMapScreen({super.key});

  @override
  State<CrisisMapScreen> createState() => _CrisisMapScreenState();
}

class _CrisisMapScreenState extends State<CrisisMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _heatCircles = {};
  bool _rebuildScheduled = false;

  // India centre — good default for demo
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);
  static const double _defaultZoom = 5.0;

  late AnimationController _legendController;
  late Animation<double> _legendAnimation;

  @override
  void initState() {
    super.initState();

    _legendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _legendAnimation = CurvedAnimation(
      parent: _legendController,
      curve: Curves.easeInOut,
    );
    _legendController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = context.read<MapProvider>();
      mapProvider.startListening();
      mapProvider.loadVolunteers();
      context.read<NeedsProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _legendController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Debounced marker rebuild
  Future<void> _scheduleRebuild(MapProvider mapProvider) async {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    await Future.microtask(() async {
      _rebuildScheduled = false;
      await _rebuildMarkers(mapProvider);
    });
  }

  Future<void> _rebuildMarkers(MapProvider mapProvider) async {
    final newMarkers = <Marker>{};
    final newCircles = <Circle>{};

    // ── Need markers ──────────────────────────────────────────────────────
    if (mapProvider.showMarkers) {
      for (final need in mapProvider.filteredNeeds) {
        if (need.lat == 0 && need.lng == 0) continue;

        final icon = await MapMarkerService.buildNeedMarker(
          urgencyLevel: need.urgencyLevel,
          needType: need.type,
          priorityScore: need.priorityScore,
          isSelected: mapProvider.selectedNeed?.id == need.id,
        );

        newMarkers.add(Marker(
          markerId: MarkerId('need_${need.id}'),
          position: LatLng(need.lat, need.lng),
          icon: icon,
          onTap: () => _onMarkerTap(need),
          zIndexInt: need.urgencyLevel == 'high' ? 3 :
                  need.urgencyLevel == 'medium' ? 2 : 1,
        ));
      }
    }

    // ── Volunteer markers ─────────────────────────────────────────────────
    if (mapProvider.showVolunteers) {
      final volunteerIcon = await MapMarkerService.buildVolunteerMarker();
      for (final vol in mapProvider.volunteers) {
        if (vol.lat == 0 && vol.lng == 0) continue;
        newMarkers.add(Marker(
          markerId: MarkerId('vol_${vol.id}'),
          position: LatLng(vol.lat, vol.lng),
          icon: volunteerIcon,
          infoWindow: InfoWindow(
            title: vol.name,
            snippet: '${vol.completedTasks} tasks done · ${vol.skills.take(2).join(", ")}',
          ),
          zIndexInt: 0,
        ));
      }
    }

    // ── Heatmap circles ───────────────────────────────────────────────────
    if (mapProvider.showHeatmap) {
      for (final need in mapProvider.heatmapNeeds) {
        if (need.lat == 0 && need.lng == 0) continue;

        final color = AppColors.urgencyColor(need.urgencyLevel);
        final intensity = need.priorityScore;
        final radius = 3000.0 + (need.peopleAffected * 50.0).clamp(0, 15000);

        // Outer glow
        newCircles.add(Circle(
          circleId: CircleId('heat_outer_${need.id}'),
          center: LatLng(need.lat, need.lng),
          radius: radius,
          fillColor: color.withValues(alpha: 0.05 * intensity),
          strokeColor: Colors.transparent,
          strokeWidth: 0,
        ));
        // Inner core
        newCircles.add(Circle(
          circleId: CircleId('heat_inner_${need.id}'),
          center: LatLng(need.lat, need.lng),
          radius: radius * 0.5,
          fillColor: color.withValues(alpha: 0.13 * intensity),
          strokeColor: color.withValues(alpha: 0.25),
          strokeWidth: 1,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _heatCircles = newCircles;
      });
    }
  }

  void _onMarkerTap(NeedModel need) {
    context.read<MapProvider>().selectNeed(need);
    _showNeedBottomSheet(need);
  }

  void _showNeedBottomSheet(NeedModel need) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _NeedDetailSheet(need: need),
    ).whenComplete(() {
      if (mounted) context.read<MapProvider>().clearSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        _scheduleRebuild(mapProvider);

        return Scaffold(
          body: Stack(
            children: [
              // ── Google Map ──────────────────────────────────────────
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: _defaultZoom,
                ),
                style: '''[
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
      {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d1ff"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f7fa"}]}
    ]''',
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                markers: _markers,
                circles: _heatCircles,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
                onTap: (_) => mapProvider.clearSelection(),
              ),

              // ── App Bar ─────────────────────────────────────────────
              const Positioned(
                top: 0, left: 0, right: 0,
                child: _MapTopBar(),
              ),

              // ── Filter chips ────────────────────────────────────────
              Positioned(
                top: 86, left: 0, right: 0,
                child: _FilterBar(mapProvider: mapProvider),
              ),

              // ── Legend ──────────────────────────────────────────────
              Positioned(
                top: 138, right: 12,
                child: FadeTransition(
                  opacity: _legendAnimation,
                  child: _UrgencyLegend(mapProvider: mapProvider),
                ),
              ),

              // ── Layer toggle panel ───────────────────────────────────
              Positioned(
                bottom: 112, right: 12,
                child: _LayerControls(mapProvider: mapProvider),
              ),

              // ── Re-centre FAB ────────────────────────────────────────
              Positioned(
                bottom: 52, right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'recentre',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 3,
                  onPressed: () => _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_defaultCenter, _defaultZoom)),
                  child: const Icon(Icons.my_location, size: 20),
                ),
              ),

              // ── Loading indicator ─────────────────────────────────────
              if (mapProvider.isLoading)
                const Positioned(
                  top: 86, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: AppColors.primary,
                    minHeight: 2,
                  ),
                ),

              // ── Stats bar ─────────────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _StatsBar(mapProvider: mapProvider),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _MapTopBar extends StatelessWidget {
  const _MapTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Icon(Icons.public, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Crisis Map', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Live urgency heatmap', style: TextStyle(
                    color: Colors.white60, fontSize: 10)),
                ],
              ),
            ),
            // LIVE badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('LIVE', style: TextStyle(
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
              ]),
            ),
            const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  FILTER BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _FilterBar extends StatelessWidget {
  final MapProvider mapProvider;
  const _FilterBar({required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Chip(label: 'All', selected: mapProvider.urgencyFilter == UrgencyFilter.all,
            color: AppColors.primary,
            onTap: () => mapProvider.setUrgencyFilter(UrgencyFilter.all)),
          _Chip(label: '🔴 High', selected: mapProvider.urgencyFilter == UrgencyFilter.high,
            color: AppColors.urgencyHigh,
            onTap: () => mapProvider.setUrgencyFilter(UrgencyFilter.high)),
          _Chip(label: '🟠 Medium', selected: mapProvider.urgencyFilter == UrgencyFilter.medium,
            color: AppColors.urgencyMedium,
            onTap: () => mapProvider.setUrgencyFilter(UrgencyFilter.medium)),
          _Chip(label: '🟢 Low', selected: mapProvider.urgencyFilter == UrgencyFilter.low,
            color: AppColors.urgencyLow,
            onTap: () => mapProvider.setUrgencyFilter(UrgencyFilter.low)),
          Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            color: Colors.grey.shade300),
          _Chip(label: '🍲 Food', selected: mapProvider.typeFilter == TypeFilter.food,
            color: AppColors.primary, onTap: () => mapProvider.setTypeFilter(TypeFilter.food)),
          _Chip(label: '🏥 Medical', selected: mapProvider.typeFilter == TypeFilter.medical,
            color: AppColors.primary, onTap: () => mapProvider.setTypeFilter(TypeFilter.medical)),
          _Chip(label: '🏠 Shelter', selected: mapProvider.typeFilter == TypeFilter.shelter,
            color: AppColors.primary, onTap: () => mapProvider.setTypeFilter(TypeFilter.shelter)),
          _Chip(label: '💧 Water', selected: mapProvider.typeFilter == TypeFilter.water,
            color: AppColors.primary, onTap: () => mapProvider.setTypeFilter(TypeFilter.water)),
          _Chip(label: '👕 Clothing', selected: mapProvider.typeFilter == TypeFilter.clothing,
            color: AppColors.primary, onTap: () => mapProvider.setTypeFilter(TypeFilter.clothing)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: Text(label, style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  LEGEND
// ═══════════════════════════════════════════════════════════════════════════════
class _UrgencyLegend extends StatelessWidget {
  final MapProvider mapProvider;
  const _UrgencyLegend({required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('URGENCY', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold,
            letterSpacing: 1, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _LRow(color: AppColors.urgencyHigh,   label: 'High',   count: mapProvider.highCount),
          const SizedBox(height: 4),
          _LRow(color: AppColors.urgencyMedium, label: 'Medium', count: mapProvider.mediumCount),
          const SizedBox(height: 4),
          _LRow(color: AppColors.urgencyLow,    label: 'Low',    count: mapProvider.lowCount),
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 6),
          _LRow(color: AppColors.secondary, label: 'Volunteers',
            count: mapProvider.volunteers.length, circle: true),
        ],
      ),
    );
  }
}

class _LRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool circle;
  const _LRow({required this.color, required this.label,
    required this.count, this.circle = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
      const SizedBox(width: 6),
      Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  LAYER CONTROLS
// ═══════════════════════════════════════════════════════════════════════════════
class _LayerControls extends StatelessWidget {
  final MapProvider mapProvider;
  const _LayerControls({required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _LToggle(icon: Icons.grain, label: 'Heat',
          active: mapProvider.showHeatmap,
          color: AppColors.urgencyHigh,
          onTap: mapProvider.toggleHeatmap),
        Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.shade200),
        _LToggle(icon: Icons.place, label: 'Pins',
          active: mapProvider.showMarkers,
          color: AppColors.primary,
          onTap: mapProvider.toggleMarkers),
        Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.shade200),
        _LToggle(icon: Icons.people, label: 'Vols',
          active: mapProvider.showVolunteers,
          color: AppColors.secondary,
          onTap: mapProvider.toggleVolunteers),
      ]),
    );
  }
}

class _LToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _LToggle({required this.icon, required this.label,
    required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: active ? color : Colors.grey.shade400),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 8,
            color: active ? color : Colors.grey.shade400,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STATS BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _StatsBar extends StatelessWidget {
  final MapProvider mapProvider;
  const _StatsBar({required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(value: '${mapProvider.filteredNeeds.length}',
            label: 'Active Needs', color: AppColors.primary),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _Stat(value: '${mapProvider.highCount}',
            label: 'High Urgency', color: AppColors.urgencyHigh),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _Stat(value: '${mapProvider.totalPeopleAffected}',
            label: 'People Affected', color: AppColors.secondary),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _Stat(value: '${mapProvider.volunteers.length}',
            label: 'Volunteers', color: AppColors.urgencyLow),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(
        fontSize: 9, color: AppColors.textSecondary)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NEED DETAIL BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _NeedDetailSheet extends StatelessWidget {
  final NeedModel need;
  const _NeedDetailSheet({required this.need});

  @override
  Widget build(BuildContext context) {
    final uc = AppColors.urgencyColor(need.urgencyLevel);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),

        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: uc.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(need.type), color: uc, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  UrgencyBadge(level: need.urgencyLevel),
                  const SizedBox(width: 8),
                  Text(need.type.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 2),
                Text(need.description, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            )),
            const SizedBox(width: 8),
            // AI score badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text((need.priorityScore * 100).toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
                const Text('AI Score', style: TextStyle(
                  fontSize: 8, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade100, height: 1),
        const SizedBox(height: 12),

        // Detail stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _DStat(icon: Icons.people, value: '${need.peopleAffected}',
              label: 'Affected', color: AppColors.primary),
            _DStat(icon: Icons.location_on,
              value: need.address.split(',').first,
              label: 'Location', color: AppColors.secondary),
            _DStat(icon: Icons.schedule,
              value: _timeAgo(need.createdAt),
              label: 'Reported', color: AppColors.textSecondary),
          ]),
        ),

        const SizedBox(height: 14),

        // Priority progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                const Text('AI Priority Score', style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
                const Spacer(),
                Text('${(need.priorityScore * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: need.priorityScore,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(uc),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Status chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Status:', style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            _statusChip(need.status),
          ]),
        ),

        const SizedBox(height: 14),

        // CTA button
        if (need.status == 'pending')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.assignVolunteer, arguments: need);
                },
                icon: const Icon(Icons.person_search, size: 16),
                label: const Text('AI Match Volunteer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'pending': color = AppColors.pending; break;
      case 'assigned': color = AppColors.assigned; break;
      case 'in_progress': color = AppColors.inProgress; break;
      case 'completed': color = AppColors.completed; break;
      default: color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'medical': return Icons.local_hospital;
      case 'food': return Icons.restaurant;
      case 'shelter': return Icons.home;
      case 'water': return Icons.water_drop;
      case 'clothing': return Icons.checkroom;
      default: return Icons.help_outline;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _DStat({required this.icon, required this.value,
    required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 2),
      SizedBox(
        width: 80,
        child: Text(value,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
    ]);
  }
}
