-- Plans last a while; people can join until they end. Existing plans get the
-- default duration of one hour.
ALTER TABLE plans
    ADD COLUMN duration_minutes integer NOT NULL DEFAULT 60
        CHECK (duration_minutes BETWEEN 15 AND 720);

-- Zone each participant chose to show to others. It references the zone
-- catalog defined in Go. Existing participants get the plan's zone.
ALTER TABLE plan_participants ADD COLUMN zone_id text;
UPDATE plan_participants pp SET zone_id = p.zone_id FROM plans p WHERE p.id = pp.plan_id;
ALTER TABLE plan_participants ALTER COLUMN zone_id SET NOT NULL;
