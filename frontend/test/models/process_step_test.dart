import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/admin/process_step.dart';

void main() {
  group('ProcessStep Model Tests', () {
    final sampleJson = {
      'id': 'step-uuid-123',
      'name': 'Cutting',
      'stepOrder': 1,
      'isActive': true,
      'createdAt': '2026-09-10T10:00:00.000Z',
      'updatedAt': '2026-09-10T11:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final step = ProcessStep.fromJson(sampleJson);

      expect(step.id, 'step-uuid-123');
      expect(step.name, 'Cutting');
      expect(step.stepOrder, 1);
      expect(step.isActive, isTrue);
      expect(step.createdAt, DateTime.parse('2026-09-10T10:00:00.000Z'));
      expect(step.updatedAt, DateTime.parse('2026-09-10T11:00:00.000Z'));
    });

    test('ISO timestamps parse correctly', () {
      final json = {
        'id': 'step-iso-test',
        'name': 'Welding',
        'stepOrder': 2,
        'isActive': true,
        'createdAt': '2026-01-15T08:30:45.123Z',
        'updatedAt': '2026-01-15T09:45:00.000Z',
      };

      final step = ProcessStep.fromJson(json);

      expect(step.createdAt.isUtc, isTrue);
      expect(step.createdAt.year, 2026);
      expect(step.createdAt.month, 1);
      expect(step.createdAt.day, 15);
      expect(step.createdAt.hour, 8);
      expect(step.createdAt.minute, 30);
      expect(step.createdAt.second, 45);
      expect(step.createdAt.millisecond, 123);

      expect(step.updatedAt.isUtc, isTrue);
      expect(step.updatedAt.hour, 9);
      expect(step.updatedAt.minute, 45);
    });

    test('toJson produces the expected backend field names', () {
      final step = ProcessStep(
        id: 'step-to-json-id',
        name: 'Painting',
        stepOrder: 3,
        isActive: true,
        createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-09-10T12:00:00.000Z'),
      );

      final json = step.toJson();

      expect(json, {
        'id': 'step-to-json-id',
        'name': 'Painting',
        'stepOrder': 3,
        'isActive': true,
        'createdAt': '2026-09-10T10:00:00.000Z',
        'updatedAt': '2026-09-10T12:00:00.000Z',
      });
    });

    test('Active step parses correctly', () {
      final json = {
        'id': 'active-step-id',
        'name': 'Assembly',
        'stepOrder': 4,
        'isActive': true,
        'createdAt': '2026-09-10T10:00:00.000Z',
        'updatedAt': '2026-09-10T10:00:00.000Z',
      };

      final step = ProcessStep.fromJson(json);
      expect(step.isActive, isTrue);
    });

    test('Inactive step parses correctly', () {
      final json = {
        'id': 'inactive-step-id',
        'name': 'Old Priming',
        'stepOrder': 5,
        'isActive': false,
        'createdAt': '2026-08-01T10:00:00.000Z',
        'updatedAt': '2026-08-15T10:00:00.000Z',
      };

      final step = ProcessStep.fromJson(json);
      expect(step.isActive, isFalse);
    });

    test('Round-trip serialization preserves the meaningful values', () {
      final original = ProcessStep(
        id: 'roundtrip-id',
        name: 'Quality Inspection',
        stepOrder: 5,
        isActive: false,
        createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-09-10T14:30:00.000Z'),
      );

      final serialized = original.toJson();
      final deserialized = ProcessStep.fromJson(serialized);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.stepOrder, original.stepOrder);
      expect(deserialized.isActive, original.isActive);
      expect(deserialized.createdAt, original.createdAt);
      expect(deserialized.updatedAt, original.updatedAt);
    });
  });
}
