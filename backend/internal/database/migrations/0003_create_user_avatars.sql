-- Avatar each user customized for the plans map. Users without a row get a
-- default avatar derived from their id. Values are ids from catalogs defined
-- in Go, validated there, so the schema does not repeat them.
CREATE TABLE user_avatars (
    user_id    text PRIMARY KEY,
    skin       text NOT NULL,
    body_color text NOT NULL,
    skin_tone  text NOT NULL,
    accessory  text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
