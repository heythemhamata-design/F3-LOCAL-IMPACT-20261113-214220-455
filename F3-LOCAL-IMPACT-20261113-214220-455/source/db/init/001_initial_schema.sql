-- MONSTER AI COMMAND CENTER - initial PostgreSQL schema
-- This file runs only when Docker initializes a brand-new empty data volume.
-- Do not use docker compose down -v; that would delete the database volume.

CREATE TABLE IF NOT EXISTS schema_migrations (
    version     text PRIMARY KEY,
    name        text NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agents (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    role        text NOT NULL,
    domain      text NOT NULL,
    model_id    text NOT NULL,
    status      text NOT NULL DEFAULT 'not_configured'
                CHECK (status IN ('not_configured', 'ready', 'busy', 'error')),
    configured  boolean NOT NULL DEFAULT false,
    connected   boolean NOT NULL DEFAULT false,
    enabled     boolean NOT NULL DEFAULT true,
    config      jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title       text,
    metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS messages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role            text NOT NULL CHECK (role IN ('system', 'user', 'assistant', 'tool')),
    content         text NOT NULL DEFAULT '',
    agent_id        text REFERENCES agents(id) ON DELETE SET NULL,
    model_id        text,
    tool_name       text,
    tool_call_id    text,
    metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memories (
    id          uuid PRIMARY KEY,
    title       varchar(200) NOT NULL CHECK (length(trim(title)) > 0),
    content     text NOT NULL CHECK (length(trim(content)) > 0 AND length(content) <= 10000),
    category    text NOT NULL CHECK (length(trim(category)) > 0),
    tags        text[] NOT NULL DEFAULT ARRAY[]::text[],
    created_at  timestamptz NOT NULL,
    updated_at  timestamptz NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS memories_title_category_uq
    ON memories (lower(title), lower(category));
CREATE INDEX IF NOT EXISTS memories_category_updated_idx
    ON memories (category, updated_at DESC);
CREATE INDEX IF NOT EXISTS memories_tags_gin_idx
    ON memories USING gin (tags);

CREATE TABLE IF NOT EXISTS tasks (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid REFERENCES conversations(id) ON DELETE SET NULL,
    parent_task_id  uuid REFERENCES tasks(id) ON DELETE SET NULL,
    agent_id        text REFERENCES agents(id) ON DELETE RESTRICT,
    task_type       text NOT NULL DEFAULT 'agent_task',
    input           text NOT NULL,
    status          text NOT NULL DEFAULT 'queued'
                    CHECK (status IN ('blocked', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    priority        integer NOT NULL DEFAULT 100,
    attempt_count   integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts    integer NOT NULL DEFAULT 3 CHECK (max_attempts > 0),
    result          jsonb,
    error           text,
    metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
    run_id          uuid,
    locked_by       text,
    locked_at       timestamptz,
    heartbeat_at    timestamptz,
    available_at    timestamptz NOT NULL DEFAULT now(),
    started_at      timestamptz,
    completed_at    timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tasks_queue_pick_idx
    ON tasks (priority ASC, available_at ASC, created_at ASC)
    WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS tasks_status_updated_idx
    ON tasks (status, updated_at DESC);
CREATE INDEX IF NOT EXISTS tasks_conversation_created_idx
    ON tasks (conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tasks_agent_status_idx
    ON tasks (agent_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS task_dependencies (
    task_id             uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    depends_on_task_id  uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    created_at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, depends_on_task_id),
    CHECK (task_id <> depends_on_task_id)
);
CREATE INDEX IF NOT EXISTS task_dependencies_prerequisite_idx
    ON task_dependencies (depends_on_task_id);

CREATE TABLE IF NOT EXISTS task_events (
    id              bigserial PRIMARY KEY,
    task_id         uuid REFERENCES tasks(id) ON DELETE SET NULL,
    run_id          uuid,
    correlation_id  text,
    agent_id        text REFERENCES agents(id) ON DELETE SET NULL,
    event_type      text NOT NULL,
    severity        text NOT NULL DEFAULT 'info'
                    CHECK (severity IN ('debug', 'info', 'warning', 'error')),
    tool_name       text,
    success         boolean,
    details         jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS task_events_task_created_idx
    ON task_events (task_id, created_at ASC);
CREATE INDEX IF NOT EXISTS task_events_run_created_idx
    ON task_events (run_id, created_at ASC);
CREATE INDEX IF NOT EXISTS task_events_type_created_idx
    ON task_events (event_type, created_at DESC);

INSERT INTO agents (id, name, role, domain, model_id)
VALUES
    ('chief_of_staff', 'Chief of Staff', 'Central coordinator', 'Orchestration', 'agy/claude-opus-4-6-thinking'),
    ('memory', 'Memory', 'Context and memory', 'Knowledge', 'agy/claude-sonnet-4-6'),
    ('strategist', 'Strategist', 'Planning and strategy', 'Strategy', 'agy/claude-opus-4-6-thinking'),
    ('researcher', 'Researcher', 'Research and discovery', 'Research', 'agy/claude-opus-4-6-thinking'),
    ('finance', 'Finance', 'Financial analysis', 'Finance', 'agy/claude-sonnet-4-6'),
    ('editor', 'Editor', 'Writing and editing', 'Content', 'agy/claude-sonnet-4-6'),
    ('sales', 'Sales', 'Sales operations', 'Business', 'agy/claude-sonnet-4-6'),
    ('marketing', 'Marketing', 'Marketing strategy', 'Business', 'agy/claude-sonnet-4-6'),
    ('ops', 'Operations', 'Operational workflows', 'Operations', 'agy/claude-sonnet-4-6'),
    ('social_media', 'Social Media', 'Social media operations', 'Marketing', 'agy/gemini-3.8-flash-tiered'),
    ('engineering', 'Engineering', 'Systems engineering', 'Technology', 'codex/gpt-6-luna'),
    ('design', 'Design', 'Design and UX', 'Creative', 'agy/claude-sonnet-4-6'),
    ('developer', 'Developer', 'Software development', 'Technology', 'codex/gpt-6-luna'),
    ('analytics', 'Analytics', 'Data analysis', 'Analytics', 'codex/gpt-6-luna'),
    ('crm', 'CRM', 'Customer relationship management', 'Business', 'agy/gemini-3.8-flash-tiered'),
    ('calendar', 'Calendar', 'Calendar management', 'Productivity', 'agy/gemini-3.8-flash-tiered'),
    ('email', 'Email', 'Email operations', 'Productivity', 'agy/gemini-3.8-flash-tiered'),
    ('drive', 'Drive', 'File and document operations', 'Productivity', 'agy/claude-sonnet-4-6')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    domain = EXCLUDED.domain,
    model_id = EXCLUDED.model_id,
    updated_at = now();

INSERT INTO schema_migrations (version, name)
VALUES ('001', 'initial_monster_schema')
ON CONFLICT (version) DO NOTHING;
