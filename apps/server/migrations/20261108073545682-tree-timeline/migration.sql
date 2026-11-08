BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE INDEX "stories_tree_order_idx" ON "stories" USING btree ("treeId", "status", "dateStart", "datePrecision", "createdAt", "id");

--
-- MIGRATION VERSION FOR tell_me_a_story
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('tell_me_a_story', '20261108073545682-tree-timeline', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261108073545682-tree-timeline', "timestamp" = now();

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
