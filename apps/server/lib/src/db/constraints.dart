import '../generated/serverpod.dart';

/// Applies [constraintsSql] after Serverpod has run its migrations.
///
/// Each index and constraint is created only if no object with its name
/// exists, so editing an existing definition has no effect on databases that
/// already have it. To change one, add it under a new name and drop the old
/// name in the same SQL.
Future<void> applyConstraints(Serverpod pod) async {
  final session = await pod.createSession();
  try {
    await session.db.unsafeSimpleExecute(constraintsSql);
  } finally {
    await session.close();
  }
}

/// Constraints Serverpod models cannot express. Idempotent; run after
/// migrations on every boot and in test setup.
const constraintsSql = r'''
-- Invariants Serverpod model YAML cannot express. Idempotent: safe to run on
-- every server start after Serverpod has applied its migrations.
-- Definitions are immutable by name: each is created only if absent by name,
-- so editing one in place never reaches existing databases. To change one,
-- add it under a new name and drop the old name in this same SQL.
-- Column names are Serverpod's quoted camelCase field names.
-- DatePrecision is serialized byIndex: 0 = year, 1 = month, 2 = day.

-- One owner per family (partial unique index).
CREATE UNIQUE INDEX IF NOT EXISTS memberships_one_owner_uidx
  ON memberships ("familyId")
  WHERE "role" = 'owner';

-- Retired names. A changed definition gets a new name below; its old name is
-- dropped here so databases created before the change converge.
ALTER TABLE families DROP CONSTRAINT IF EXISTS families_branch_year_range;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_birth_midnight;

DO $constraints$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT * FROM (VALUES
      -- families -----------------------------------------------------------
      ('families', 'families_parent_not_self',
        $$CHECK ("parentId" IS NULL OR "parentId" <> "id")$$),
      ('families', 'families_name_not_blank',
        $$CHECK (btrim("name") <> '')$$),
      ('families', 'families_branch_year_1000_9999',
        $$CHECK ("branchYear" IS NULL OR "branchYear" BETWEEN 1000 AND 9999)$$),
      -- A branch's parent must be in the same tree (needs families_id_tree_uidx).
      ('families', 'families_parent_same_tree_fk',
        $$FOREIGN KEY ("parentId", "treeId") REFERENCES families ("id", "treeId")
          ON DELETE SET NULL ("parentId")$$),
      -- The origin story must be in the same tree (needs stories_id_tree_uidx).
      ('families', 'families_origin_tree_fk',
        $$FOREIGN KEY ("originStoryId", "treeId") REFERENCES stories ("id", "treeId")
          ON DELETE SET NULL ("originStoryId")$$),
      -- memberships --------------------------------------------------------
      ('memberships', 'memberships_role_valid',
        $$CHECK ("role" IN ('owner', 'coOwner', 'member'))$$),
      -- people -------------------------------------------------------------
      -- The home family must be in the person's tree (needs families_id_tree_uidx).
      ('people', 'people_home_family_tree_fk',
        $$FOREIGN KEY ("homeFamilyId", "treeId") REFERENCES families ("id", "treeId")
          ON DELETE RESTRICT$$),
      ('people', 'people_name_not_blank',
        $$CHECK (btrim("name") <> '')$$),
      ('people', 'people_about_len',
        $$CHECK ("about" IS NULL OR char_length("about") <= 500)$$),
      ('people', 'people_email_normalized',
        $$CHECK ("email" IS NULL OR ("email" <> '' AND "email" = lower(btrim("email"))))$$),
      -- Life dates: UTC midnight aligned to precision, years 1000..9999.
      ('people', 'people_birth_pair',
        $$CHECK (("birthDate" IS NULL) = ("birthPrecision" IS NULL))$$),
      ('people', 'people_birth_shape',
        $$CHECK ("birthDate" IS NULL OR (
          "birthDate" = date_trunc('day', "birthDate")
          AND extract(year FROM "birthDate") BETWEEN 1000 AND 9999
          AND ("birthPrecision" = 2
            OR ("birthPrecision" = 1 AND "birthDate" = date_trunc('month', "birthDate"))
            OR ("birthPrecision" = 0 AND "birthDate" = date_trunc('year', "birthDate")))))$$),
      ('people', 'people_death_pair',
        $$CHECK (("deathDate" IS NULL) = ("deathPrecision" IS NULL))$$),
      ('people', 'people_death_shape',
        $$CHECK ("deathDate" IS NULL OR (
          "deathDate" = date_trunc('day', "deathDate")
          AND extract(year FROM "deathDate") BETWEEN 1000 AND 9999
          AND ("deathPrecision" = 2
            OR ("deathPrecision" = 1 AND "deathDate" = date_trunc('month', "deathDate"))
            OR ("deathPrecision" = 0 AND "deathDate" = date_trunc('year', "deathDate")))))$$),
      ('people', 'people_death_needs_passed_away',
        $$CHECK ("deathDate" IS NULL OR "passedAway")$$),
      -- Years only, so a coarse birth can't reject a finer death in the same year.
      ('people', 'people_death_after_birth',
        $$CHECK ("deathDate" IS NULL OR "birthDate" IS NULL
          OR extract(year FROM "deathDate") >= extract(year FROM "birthDate"))$$),
      -- users --------------------------------------------------------------
      ('users', 'users_about_len',
        $$CHECK ("about" IS NULL OR char_length("about") <= 500)$$),
      ('users', 'users_birth_pair',
        $$CHECK (("birthDate" IS NULL) = ("birthPrecision" IS NULL))$$),
      ('users', 'users_birth_shape',
        $$CHECK ("birthDate" IS NULL OR (
          "birthDate" = date_trunc('day', "birthDate")
          AND extract(year FROM "birthDate") BETWEEN 1000 AND 9999
          AND ("birthPrecision" = 2
            OR ("birthPrecision" = 1 AND "birthDate" = date_trunc('month', "birthDate"))
            OR ("birthPrecision" = 0 AND "birthDate" = date_trunc('year', "birthDate")))))$$),
      ('users', 'users_birth_visibility_valid',
        $$CHECK ("birthVisibility" IN ('hidden', 'year', 'yearMonth', 'full'))$$),
      -- stories ------------------------------------------------------------
      -- treeId copies the family's tree; the place must be in that tree.
      ('stories', 'stories_family_tree_fk',
        $$FOREIGN KEY ("familyId", "treeId") REFERENCES families ("id", "treeId")
          ON DELETE CASCADE$$),
      ('stories', 'stories_place_tree_fk',
        $$FOREIGN KEY ("placeId", "treeId") REFERENCES places ("id", "treeId")
          ON DELETE SET NULL ("placeId")$$),
      -- Dates are all-null (undated draft) or a well-formed year/month/day span.
      ('stories', 'stories_date_shape',
        $$CHECK (
          ("dateStart" IS NULL AND "dateEnd" IS NULL AND "datePrecision" IS NULL)
          OR (
            "dateStart" IS NOT NULL AND "dateEnd" IS NOT NULL AND "datePrecision" IS NOT NULL
            AND "dateStart" = date_trunc('day', "dateStart")
            AND extract(year FROM "dateStart") BETWEEN 1000 AND 9999
            AND (
              ("datePrecision" = 2 AND "dateEnd" = "dateStart")
              OR ("datePrecision" = 1
                  AND "dateStart" = date_trunc('month', "dateStart")
                  AND "dateEnd" = date_trunc('month', "dateStart") + interval '1 month' - interval '1 day')
              OR ("datePrecision" = 0
                  AND "dateStart" = date_trunc('year', "dateStart")
                  AND "dateEnd" = date_trunc('year', "dateStart") + interval '1 year' - interval '1 day')
            )
          )
        )$$),
      ('stories', 'stories_published_needs_date',
        $$CHECK ("status" <> 'published' OR ("dateStart" IS NOT NULL AND "publishedAt" IS NOT NULL))$$),
      ('stories', 'stories_status_valid',
        $$CHECK ("status" IN ('draft', 'published'))$$),
      -- story_people ---------------------------------------------------------
      -- A tag's story and person share the tag's treeId.
      ('story_people', 'story_people_story_tree_fk',
        $$FOREIGN KEY ("storyId", "treeId") REFERENCES stories ("id", "treeId")
          ON DELETE CASCADE$$),
      ('story_people', 'story_people_person_tree_fk',
        $$FOREIGN KEY ("personId", "treeId") REFERENCES people ("id", "treeId")
          ON DELETE CASCADE$$),
      -- photos -------------------------------------------------------------
      ('photos', 'photos_edit_version_nonnegative',
        $$CHECK ("editVersion" >= 0)$$),
      ('photos', 'photos_edited_needs_version',
        $$CHECK ("editedKey" IS NULL OR "editVersion" > 0)$$),
      -- story_notes --------------------------------------------------------
      ('story_notes', 'story_notes_body_not_blank',
        $$CHECK (btrim("body") <> '')$$),
      ('story_notes', 'story_notes_kind_valid',
        $$CHECK ("kind" IN ('comment', 'perspective'))$$),
      -- invites ------------------------------------------------------------
      -- treeId copies the family's tree; the invited person must be in it.
      ('invites', 'invites_family_tree_fk',
        $$FOREIGN KEY ("familyId", "treeId") REFERENCES families ("id", "treeId")
          ON DELETE CASCADE$$),
      ('invites', 'invites_person_tree_fk',
        $$FOREIGN KEY ("personId", "treeId") REFERENCES people ("id", "treeId")
          ON DELETE SET NULL ("personId")$$),
      ('invites', 'invites_token_hash_shape',
        $$CHECK ("tokenHash" ~ '^[0-9a-f]{64}$')$$),
      ('invites', 'invites_email_normalized',
        $$CHECK ("email" IS NULL OR ("email" <> '' AND "email" = lower(btrim("email"))))$$),
      -- acceptedById may be nulled later by account deletion, so one direction only.
      ('invites', 'invites_accepted_by_needs_at',
        $$CHECK ("acceptedById" IS NULL OR "acceptedAt" IS NOT NULL)$$),
      ('invites', 'invites_not_accepted_and_revoked',
        $$CHECK ("acceptedAt" IS NULL OR "revokedAt" IS NULL)$$),
      ('invites', 'invites_expiry_after_create',
        $$CHECK ("expiresAt" > "createdAt")$$),
      -- kinships ---------------------------------------------------------------
      -- Both ends in the edge's tree; no self edges; partnerOf stored once.
      ('kinships', 'kinships_from_tree_fk',
        $$FOREIGN KEY ("fromPersonId", "treeId") REFERENCES people ("id", "treeId")
          ON DELETE CASCADE$$),
      ('kinships', 'kinships_to_tree_fk',
        $$FOREIGN KEY ("toPersonId", "treeId") REFERENCES people ("id", "treeId")
          ON DELETE CASCADE$$),
      ('kinships', 'kinships_not_self',
        $$CHECK ("fromPersonId" <> "toPersonId")$$),
      ('kinships', 'kinships_kind_valid',
        $$CHECK ("kind" IN ('parentOf', 'partnerOf'))$$),
      ('kinships', 'kinships_partner_canonical',
        $$CHECK ("kind" <> 'partnerOf' OR "fromPersonId" < "toPersonId")$$)
    ) AS t(tbl, name, def)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = c.name AND conrelid = c.tbl::regclass
    ) THEN
      EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I %s', c.tbl, c.name, c.def);
    END IF;
  END LOOP;
END
$constraints$;
''';
