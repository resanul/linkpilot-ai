-- Apply only to an existing PostgreSQL database from an earlier LinkPilot MVP.
-- Back up first; review against the actual schema before applying.
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS billing_cycle VARCHAR(20) NOT NULL DEFAULT 'monthly';
CREATE TABLE IF NOT EXISTS staff_admins (
  id VARCHAR(36) PRIMARY KEY, email VARCHAR(320) NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMP NOT NULL
);
CREATE TABLE IF NOT EXISTS oauth_states (
  state_hash VARCHAR(64) PRIMARY KEY, user_id VARCHAR(36) NOT NULL REFERENCES users(id),
  expires_at TIMESTAMP NOT NULL, created_at TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_oauth_states_user_id ON oauth_states(user_id);
CREATE TABLE IF NOT EXISTS linkedin_connections (
  id VARCHAR(36) PRIMARY KEY, user_id VARCHAR(36) NOT NULL UNIQUE REFERENCES users(id),
  person_urn VARCHAR(255) NOT NULL, access_token_encrypted TEXT NOT NULL,
  expires_at TIMESTAMP, created_at TIMESTAMP NOT NULL, updated_at TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_linkedin_connections_user_id ON linkedin_connections(user_id);
