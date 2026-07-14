/// Demo camera metadata for the Security tab's grid (Section 5). Real
/// build: populated from Frigate's camera list (Section 8).
class SecurityCamera {
  const SecurityCamera({required this.name, required this.hasMotion});
  final String name;
  final bool hasMotion;
}

const demoCameras = [
  SecurityCamera(name: 'Front Door', hasMotion: false),
  SecurityCamera(name: 'Barn North', hasMotion: true),
  SecurityCamera(name: 'Driveway', hasMotion: false),
  SecurityCamera(name: 'Shop Bay', hasMotion: false),
  SecurityCamera(name: 'Cabin Trail', hasMotion: false),
  SecurityCamera(name: 'East Gate', hasMotion: false),
];
