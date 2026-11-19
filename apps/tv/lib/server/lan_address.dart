import 'dart:io';

// Windows names adapters "Wi-Fi", "Ethernet" and Hyper-V/WSL "vEthernet (...)".
const _preferred = ['wlan', 'wi-fi', 'eth', 'en'];
const _skipped = ['docker', 'vbox', 'utun', 'tun', 'bridge', 'vethernet'];

bool _isPrivate(String a) {
  final p = a.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.contains(null)) return false;
  final (a0, a1) = (p[0]!, p[1]!);
  return a0 == 10 ||
      (a0 == 172 && a1 >= 16 && a1 <= 31) ||
      (a0 == 192 && a1 == 168);
}

/// First private IPv4 address on a LAN-looking interface, or null.
String? pickLanAddress(List<NetworkInterface> ifaces) {
  String? first(Iterable<NetworkInterface> list) {
    for (final i in list) {
      for (final a in i.addresses) {
        if (a.type == InternetAddressType.IPv4 &&
            !a.isLoopback &&
            !a.isLinkLocal &&
            _isPrivate(a.address)) {
          return a.address;
        }
      }
    }
    return null;
  }

  final ok = ifaces.where((i) => !_skipped.any(i.name.toLowerCase().contains));
  return first(ok.where((i) => _preferred.any(i.name.toLowerCase().startsWith))) ??
      first(ok);
}
