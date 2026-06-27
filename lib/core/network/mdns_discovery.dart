import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

class MdnsDiscovery {
  MdnsDiscovery._();

  static Future<String?> discoverMediCaixa({Duration timeout = const Duration(seconds: 10)}) async {
    final client = MDnsClient();
    try {
      await client.start();
    } catch (e) {
      debugPrint("Error starting mDNS client: $e");
      return null;
    }

    String? deviceIp;
    final completer = Completer<String?>();

    Timer(timeout, () {
      if (!completer.isCompleted) {
        client.stop();
        completer.complete(null);
      }
    });

    try {
      final ptrQuery = ResourceRecordQuery.serverPointer('_http._tcp');
      await for (final ptr in client.lookup<PtrResourceRecord>(ptrQuery)) {
        if (completer.isCompleted) break;

        final srvQuery = ResourceRecordQuery.service(ptr.domainName);
        await for (final srv in client.lookup<SrvResourceRecord>(srvQuery)) {
          if (completer.isCompleted) break;

          final targetLower = srv.target.toLowerCase();
          if (targetLower.contains('medicaixa')) {
            final ipQuery = ResourceRecordQuery.addressIPv4(srv.target);
            await for (final ip in client.lookup<IPAddressResourceRecord>(ipQuery)) {
              deviceIp = ip.address.address;
              if (deviceIp != null) {
                if (!completer.isCompleted) {
                  client.stop();
                  completer.complete('http://$deviceIp');
                }
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error during mDNS lookup: $e");
    } finally {
      if (!completer.isCompleted) {
        client.stop();
        completer.complete(null);
      }
    }

    return completer.future;
  }
}
