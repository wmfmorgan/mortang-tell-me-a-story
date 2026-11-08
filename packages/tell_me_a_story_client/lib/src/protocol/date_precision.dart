/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Precision of a calendar date span. byIndex ON PURPOSE: the stored bigint
/// (0 year, 1 month, 2 day) sorts coarse→fine like the old Postgres enum.
/// APPEND-ONLY. Never reorder or remove values.
enum DatePrecision implements _isc.SerializableModel {
  year,
  month,
  day;

  static DatePrecision fromJson(int index) {
    switch (index) {
      case 0:
        return DatePrecision.year;
      case 1:
        return DatePrecision.month;
      case 2:
        return DatePrecision.day;
      default:
        throw ArgumentError(
          'Value "$index" cannot be converted to "DatePrecision"',
        );
    }
  }

  @override
  int toJson() => index;

  @override
  String toString() => name;
}
