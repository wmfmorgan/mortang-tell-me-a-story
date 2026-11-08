import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

/// Date-only values (story dates, birth and death dates) travel as UTC
/// midnight of the calendar day, the server's stored shape.
DateTime? toWireDate(DateTime? day) =>
    day == null ? null : DateTime.utc(day.year, day.month, day.day);

/// The local calendar day of a wire date, the shape the client models hold.
DateTime? fromWireDate(DateTime? wire) {
  if (wire == null) return null;
  final utc = wire.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// The client's role strings (`owner`, `co_owner`, `member`).
String roleName(server.MembershipRole role) => switch (role) {
  server.MembershipRole.owner => 'owner',
  server.MembershipRole.coOwner => 'co_owner',
  server.MembershipRole.member => 'member',
};

server.MembershipRole roleFromName(String name) => switch (name) {
  'owner' => server.MembershipRole.owner,
  'co_owner' => server.MembershipRole.coOwner,
  'member' => server.MembershipRole.member,
  _ => throw ArgumentError.value(name, 'role', 'unknown membership role'),
};

/// The client's precision strings (`year`, `month`, `day`).
String precisionName(server.DatePrecision precision) => precision.name;

/// Null stays null. `decade` was dropped (D9) and is refused.
server.DatePrecision? precisionFromName(String? name) => switch (name) {
  null => null,
  'year' => server.DatePrecision.year,
  'month' => server.DatePrecision.month,
  'day' => server.DatePrecision.day,
  _ => throw ArgumentError.value(name, 'precision', 'unknown date precision'),
};
