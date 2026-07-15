import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/telemetry/gt7/gt7_packet.dart';

void main() {
  group('Gt7Packet.isOnTrack with surfaceType', () {
    Gt7Packet packetWith({
      required String surfaceType,
      int simulatorFlags = 0x01,
    }) {
      return Gt7Packet(
        magic: 1,
        posX: 0,
        posY: 0,
        posZ: 0,
        rpm: 0,
        currentFuel: 0,
        fuelCapacity: 0,
        carSpeed: 0,
        tyreTemps: [0, 0, 0, 0],
        packetId: 0,
        currentLap: 0,
        totalLaps: 0,
        bestLapMs: 0,
        lastLapMs: 0,
        currentLapTimeMs: 0,
        steeringAngle: 0,
        currentPosition: 0,
        rpmRevWarning: 0,
        rpmRevLimiter: 0,
        simulatorFlags: simulatorFlags,
        gears: 0,
        throttle: 0,
        brake: 0,
        clutch: 0,
        surfaceType: surfaceType,
      );
    }

    test('TTTT — all on tarmac, returns true', () {
      expect(packetWith(surfaceType: 'TTTT').isOnTrack, isTrue);
    });

    test('TTCC — tarmac + curbs, returns true', () {
      expect(packetWith(surfaceType: 'TTCC').isOnTrack, isTrue);
    });

    test('TTGG — two wheels on grass, still on-track (heuristic < 3)', () {
      expect(packetWith(surfaceType: 'TTGG').isOnTrack, isTrue);
    });

    test('TGGG — three wheels off, returns false', () {
      expect(packetWith(surfaceType: 'TGGG').isOnTrack, isFalse);
    });

    test('GGGG — all wheels off, returns false', () {
      expect(packetWith(surfaceType: 'GGGG').isOnTrack, isFalse);
    });

    group('fallback to simulatorFlags when surface is unknown/malformed', () {
      test('empty string with flag=1, returns true', () {
        expect(packetWith(surfaceType: '', simulatorFlags: 0x01).isOnTrack, isTrue);
      });

      test('empty string with flag=0, returns false', () {
        expect(packetWith(surfaceType: '', simulatorFlags: 0x00).isOnTrack, isFalse);
      });

      test('unknown char "X" with flag=1, returns true', () {
        expect(packetWith(surfaceType: 'XXXX', simulatorFlags: 0x01).isOnTrack, isTrue);
      });

      test('unknown char "X" with flag=0, returns false', () {
        expect(packetWith(surfaceType: 'XXXX', simulatorFlags: 0x00).isOnTrack, isFalse);
      });
    });
  });
}
