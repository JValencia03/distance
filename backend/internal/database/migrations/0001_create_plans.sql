CREATE TABLE plans (
    id               text PRIMARY KEY,
    -- Activity and zone ids reference catalogs defined in Go.
    activity_id      text NOT NULL,
    title            text NOT NULL,
    description      text,
    zone_id          text NOT NULL,
    place            text NOT NULL,
    starts_at        timestamptz NOT NULL,
    -- NULL means no participant limit.
    max_participants integer CHECK (max_participants BETWEEN 2 AND 50),
    creator_id       text NOT NULL,
    status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    created_at       timestamptz NOT NULL DEFAULT now()
);

-- Discovery reads upcoming active plans.
CREATE INDEX plans_upcoming_idx ON plans (starts_at) WHERE status = 'active';

CREATE TABLE plan_participants (
    plan_id   text NOT NULL REFERENCES plans (id) ON DELETE CASCADE,
    user_id   text NOT NULL,
    joined_at timestamptz NOT NULL DEFAULT now(),
    -- A user participates in a plan at most once, even if application
    -- checks were bypassed.
    PRIMARY KEY (plan_id, user_id)
);
