CREATE TABLE legal_consents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tc_version text NOT NULL,
  privacy_version text NOT NULL,
  cookie_consent boolean NOT NULL DEFAULT false,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  ip_address inet,
  user_agent text,
  platform text
);

ALTER TABLE legal_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own consents"
  ON legal_consents FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own consents"
  ON legal_consents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE legal_consents IS 'Immutable consent record. No UPDATE or DELETE by users.';
COMMENT ON COLUMN legal_consents.tc_version IS 'T&C version accepted, e.g. 3.0';
COMMENT ON COLUMN legal_consents.privacy_version IS 'Privacy Policy version, e.g. 1.0';
COMMENT ON COLUMN legal_consents.platform IS 'web | ios | android';
