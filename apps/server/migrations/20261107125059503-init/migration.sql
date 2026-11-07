BEGIN;

--
-- Function: gen_random_uuid_v7()
-- Source: https://gist.github.com/kjmph/5bd772b2c2df145aa645b837da7eca74
-- License: MIT (copyright notice included on the generator source code).
--
create or replace function gen_random_uuid_v7()
returns uuid
as $$
begin
  -- use random v4 uuid as starting point (which has the same variant we need)
  -- then overlay timestamp
  -- then set version 7 by flipping the 2 and 1 bit in the version 4 string
  return encode(
    set_bit(
      set_bit(
        overlay(uuid_send(gen_random_uuid())
                placing substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3)
                from 1 for 6
        ),
        52, 1
      ),
      53, 1
    ),
    'hex')::uuid;
end
$$
language plpgsql
volatile;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "blob_deletions" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "key" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attempts" bigint NOT NULL DEFAULT 0
);

-- Indexes
CREATE INDEX "blob_deletions_created_idx" ON "blob_deletions" USING btree ("createdAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "families" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "treeId" uuid NOT NULL,
    "parentId" uuid,
    "name" text NOT NULL,
    "branchYear" bigint,
    "originStoryId" uuid,
    "coverKey" text,
    "createdById" uuid,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" timestamp without time zone
);

-- Indexes
CREATE INDEX "families_tree_idx" ON "families" USING btree ("treeId");
CREATE UNIQUE INDEX "families_id_tree_uidx" ON "families" USING btree ("id", "treeId");
CREATE INDEX "families_parent_idx" ON "families" USING btree ("parentId");
CREATE INDEX "families_origin_story_idx" ON "families" USING btree ("originStoryId");
CREATE INDEX "families_deleted_at_idx" ON "families" USING btree ("deletedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "invites" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "familyId" uuid NOT NULL,
    "personId" uuid,
    "email" text,
    "tokenHash" text NOT NULL,
    "invitedById" uuid,
    "acceptedById" uuid,
    "acceptedAt" timestamp without time zone,
    "revokedAt" timestamp without time zone,
    "expiresAt" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "invites_token_hash_uidx" ON "invites" USING btree ("tokenHash");
CREATE INDEX "invites_family_created_idx" ON "invites" USING btree ("familyId", "createdAt");
CREATE INDEX "invites_person_idx" ON "invites" USING btree ("personId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "memberships" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "familyId" uuid NOT NULL,
    "userId" uuid NOT NULL,
    "role" text NOT NULL DEFAULT 'member'::text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "memberships_family_user_uidx" ON "memberships" USING btree ("familyId", "userId");
CREATE INDEX "memberships_user_idx" ON "memberships" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "people" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "familyId" uuid NOT NULL,
    "treeId" uuid NOT NULL,
    "userId" uuid,
    "name" text NOT NULL,
    "relationship" text,
    "email" text,
    "about" text,
    "avatarKey" text,
    "passedAway" boolean NOT NULL DEFAULT false,
    "createdById" uuid,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "people_tree_user_uidx" ON "people" USING btree ("treeId", "userId");
CREATE INDEX "people_family_name_idx" ON "people" USING btree ("familyId", "name");
CREATE INDEX "people_tree_name_idx" ON "people" USING btree ("treeId", "name");
CREATE INDEX "people_user_idx" ON "people" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "photos" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "storyId" uuid NOT NULL,
    "uploaderId" uuid,
    "originalKey" text NOT NULL,
    "editedKey" text,
    "editVersion" bigint NOT NULL DEFAULT 0,
    "sortOrder" bigint NOT NULL DEFAULT 0,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX "photos_story_sort_idx" ON "photos" USING btree ("storyId", "sortOrder");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "places" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "familyId" uuid NOT NULL,
    "label" text NOT NULL,
    "address" text NOT NULL,
    "lat" double precision NOT NULL,
    "lng" double precision NOT NULL,
    "mapboxPlaceId" text,
    "isFavorite" boolean NOT NULL DEFAULT false,
    "lastUsedAt" timestamp without time zone
);

-- Indexes
CREATE INDEX "places_family_label_idx" ON "places" USING btree ("familyId", "label");
CREATE UNIQUE INDEX "places_family_mapbox_uidx" ON "places" USING btree ("familyId", "mapboxPlaceId");
CREATE INDEX "places_family_last_used_idx" ON "places" USING btree ("familyId", "lastUsedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "stories" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "familyId" uuid NOT NULL,
    "authorId" uuid,
    "title" text,
    "body" text,
    "status" text NOT NULL DEFAULT 'draft'::text,
    "dateStart" timestamp without time zone,
    "dateEnd" timestamp without time zone,
    "datePrecision" bigint,
    "placeId" uuid,
    "publishedAt" timestamp without time zone,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX "stories_family_order_idx" ON "stories" USING btree ("familyId", "status", "dateStart", "datePrecision", "createdAt", "id");
CREATE INDEX "stories_author_status_idx" ON "stories" USING btree ("authorId", "status");
CREATE INDEX "stories_family_published_at_idx" ON "stories" USING btree ("familyId", "publishedAt");
CREATE INDEX "stories_place_idx" ON "stories" USING btree ("placeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "story_notes" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "storyId" uuid NOT NULL,
    "authorId" uuid,
    "kind" text NOT NULL,
    "body" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX "story_notes_story_kind_created_idx" ON "story_notes" USING btree ("storyId", "kind", "createdAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "story_people" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "storyId" uuid NOT NULL,
    "personId" uuid NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "story_people_story_person_uidx" ON "story_people" USING btree ("storyId", "personId");
CREATE INDEX "story_people_person_idx" ON "story_people" USING btree ("personId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "trees" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "users" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "authUserId" uuid NOT NULL,
    "displayName" text,
    "avatarKey" text,
    "about" text,
    "birthDate" timestamp without time zone,
    "birthPrecision" bigint,
    "birthVisibility" text NOT NULL DEFAULT 'hidden'::text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "users_auth_user_uidx" ON "users" USING btree ("authUserId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "families"
    ADD CONSTRAINT "families_fk_0"
    FOREIGN KEY("treeId")
    REFERENCES "trees"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "families"
    ADD CONSTRAINT "families_fk_1"
    FOREIGN KEY("parentId")
    REFERENCES "families"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "families"
    ADD CONSTRAINT "families_fk_2"
    FOREIGN KEY("originStoryId")
    REFERENCES "stories"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "families"
    ADD CONSTRAINT "families_fk_3"
    FOREIGN KEY("createdById")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "invites"
    ADD CONSTRAINT "invites_fk_0"
    FOREIGN KEY("familyId")
    REFERENCES "families"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "invites"
    ADD CONSTRAINT "invites_fk_1"
    FOREIGN KEY("personId")
    REFERENCES "people"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "invites"
    ADD CONSTRAINT "invites_fk_2"
    FOREIGN KEY("invitedById")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "invites"
    ADD CONSTRAINT "invites_fk_3"
    FOREIGN KEY("acceptedById")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "memberships"
    ADD CONSTRAINT "memberships_fk_0"
    FOREIGN KEY("familyId")
    REFERENCES "families"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "memberships"
    ADD CONSTRAINT "memberships_fk_1"
    FOREIGN KEY("userId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "people"
    ADD CONSTRAINT "people_fk_0"
    FOREIGN KEY("familyId")
    REFERENCES "families"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "people"
    ADD CONSTRAINT "people_fk_1"
    FOREIGN KEY("userId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "people"
    ADD CONSTRAINT "people_fk_2"
    FOREIGN KEY("createdById")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "photos"
    ADD CONSTRAINT "photos_fk_0"
    FOREIGN KEY("storyId")
    REFERENCES "stories"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "photos"
    ADD CONSTRAINT "photos_fk_1"
    FOREIGN KEY("uploaderId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "places"
    ADD CONSTRAINT "places_fk_0"
    FOREIGN KEY("familyId")
    REFERENCES "families"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "stories"
    ADD CONSTRAINT "stories_fk_0"
    FOREIGN KEY("familyId")
    REFERENCES "families"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "stories"
    ADD CONSTRAINT "stories_fk_1"
    FOREIGN KEY("authorId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "stories"
    ADD CONSTRAINT "stories_fk_2"
    FOREIGN KEY("placeId")
    REFERENCES "places"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "story_notes"
    ADD CONSTRAINT "story_notes_fk_0"
    FOREIGN KEY("storyId")
    REFERENCES "stories"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "story_notes"
    ADD CONSTRAINT "story_notes_fk_1"
    FOREIGN KEY("authorId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "story_people"
    ADD CONSTRAINT "story_people_fk_0"
    FOREIGN KEY("storyId")
    REFERENCES "stories"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "story_people"
    ADD CONSTRAINT "story_people_fk_1"
    FOREIGN KEY("personId")
    REFERENCES "people"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_fk_0"
    FOREIGN KEY("authUserId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR tell_me_a_story
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('tell_me_a_story', '20261107125059503-init', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261107125059503-init', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20261015164015382', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015164015382', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
