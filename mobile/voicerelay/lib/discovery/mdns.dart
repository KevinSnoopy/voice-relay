import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

class DiscoveredMac {
  const DiscoveredMac({required this.name, required this.host, required this.port, this.mid});

  final String name;
  final String host;
  final int port;
  final String? mid;
}

/// Best-effort Bonjour discovery for `_voicerelay._tcp`.
/// Corporate Wi-Fi may block multicast; the UI keeps manual IP as fallback.
class MdnsDiscovery {
  Future<List<DiscoveredMac>> discover({Duration timeout = const Duration(seconds: 3)}) async {
    final client = MDnsClient();
    await client.start();
    final found = <String, DiscoveredMac>{};
    try {
      final pointers = client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('_voicerelay._tcp.local'));
      await for (final pointer in pointers.timeout(timeout, onTimeout: (sink) => sink.close())) {
        final name = pointer.domainName.split('.').first;
        await for (final service in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(pointer.domainName)).timeout(
          const Duration(seconds: 2),
          onTimeout: (sink) => sink.close(),
        )) {
          var host = service.target;
          await for (final address in client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(service.target)).timeout(
            const Duration(seconds: 1),
            onTimeout: (sink) => sink.close(),
          )) {
            host = address.address.address;
            break;
          }
          found['$host:${service.port}'] = DiscoveredMac(
            name: name,
            host: host,
            port: service.port,
          );
        }
      }
    } on TimeoutException {
      // Normal: mDNS keeps the PTR stream open.
    } catch (_) {
      // Multicast can be blocked; manual connection remains available.
    } finally {
      client.stop();
    }
    return found.values.toList();
  }
}
