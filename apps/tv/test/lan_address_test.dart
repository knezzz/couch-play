import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv/server/lan_address.dart';

class _Addr implements InterfaceAddress {
  _Addr(this.address, {this.isLoopback = false, this.isLinkLocal = false});
  @override
  final String address;
  @override
  final bool isLoopback;
  @override
  final bool isLinkLocal;
  @override
  InternetAddressType get type => InternetAddressType.IPv4;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Iface implements NetworkInterface {
  _Iface(this.name, this.addresses);
  @override
  final String name;
  @override
  final List<InterfaceAddress> addresses;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('picks_wlan_private_ipv4', () {
    final ifaces = [
      _Iface('docker0', [_Addr('172.17.0.1')]),
      _Iface('wlan0', [_Addr('192.168.1.20')]),
      _Iface('lo', [_Addr('127.0.0.1', isLoopback: true)]),
    ];
    expect(pickLanAddress(ifaces), '192.168.1.20');
  });

  test('returns_null_without_lan', () {
    expect(
        pickLanAddress([
          _Iface('lo', [_Addr('127.0.0.1', isLoopback: true)])
        ]),
        isNull);
  });

  test('skips_public_linklocal_and_vpn', () {
    final ifaces = [
      _Iface('utun3', [_Addr('10.8.0.2')]),
      _Iface('en0', [_Addr('169.254.1.1', isLinkLocal: true)]),
      _Iface('en1', [_Addr('8.8.8.8')]),
      _Iface('eth0', [_Addr('172.20.5.9')]),
    ];
    expect(pickLanAddress(ifaces), '172.20.5.9');
  });

  test('windows_picks_wifi_over_hyperv_switch', () {
    final ifaces = [
      _Iface('vEthernet (Default Switch)', [_Addr('172.27.16.1')]),
      _Iface('Wi-Fi', [_Addr('192.168.1.31')]),
    ];
    expect(pickLanAddress(ifaces), '192.168.1.31');
  });
}
