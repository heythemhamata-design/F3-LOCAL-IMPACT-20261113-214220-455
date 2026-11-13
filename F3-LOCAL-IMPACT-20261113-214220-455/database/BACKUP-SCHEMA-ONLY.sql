--
-- PostgreSQL database dump
--

\restrict i6JqETa76EBzzWQaYMcSLEaxQAPA4eX2r4kkN9gB8exSyfN2SksvL6eRdK3sqH3

-- Dumped from database version 18.6 (Debian 18.6-1.pgdg12+2)
-- Dumped by pg_dump version 18.6 (Debian 18.6-1.pgdg12+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id text NOT NULL,
    name text NOT NULL,
    role text NOT NULL,
    domain text NOT NULL,
    model_id text NOT NULL,
    status text DEFAULT 'not_configured'::text NOT NULL,
    configured boolean DEFAULT false NOT NULL,
    connected boolean DEFAULT false NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agents_status_check CHECK ((status = ANY (ARRAY['not_configured'::text, 'ready'::text, 'busy'::text, 'error'::text])))
);


--
-- Name: api_rate_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_rate_limits (
    bucket_key text NOT NULL,
    window_started_at timestamp with time zone NOT NULL,
    request_count integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT api_rate_limits_request_count_check CHECK ((request_count >= 0))
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: memories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memories (
    id uuid NOT NULL,
    title character varying(200) NOT NULL,
    content text NOT NULL,
    category text NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[] NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT memories_category_check CHECK ((length(TRIM(BOTH FROM category)) > 0)),
    CONSTRAINT memories_content_check CHECK (((length(TRIM(BOTH FROM content)) > 0) AND (length(content) <= 10000))),
    CONSTRAINT memories_title_check CHECK ((length(TRIM(BOTH FROM title)) > 0))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    role text NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    agent_id text,
    model_id text,
    tool_name text,
    tool_call_id text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_role_check CHECK ((role = ANY (ARRAY['system'::text, 'user'::text, 'assistant'::text, 'tool'::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    name text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: task_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_dependencies (
    task_id uuid NOT NULL,
    depends_on_task_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT task_dependencies_check CHECK ((task_id <> depends_on_task_id))
);


--
-- Name: task_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_events (
    id bigint NOT NULL,
    task_id uuid,
    run_id uuid,
    correlation_id text,
    agent_id text,
    event_type text NOT NULL,
    severity text DEFAULT 'info'::text NOT NULL,
    tool_name text,
    success boolean,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT task_events_severity_check CHECK ((severity = ANY (ARRAY['debug'::text, 'info'::text, 'warning'::text, 'error'::text])))
);


--
-- Name: task_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_events_id_seq OWNED BY public.task_events.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid,
    parent_task_id uuid,
    agent_id text,
    task_type text DEFAULT 'agent_task'::text NOT NULL,
    input text NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 3 NOT NULL,
    result jsonb,
    error text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    run_id uuid,
    locked_by text,
    locked_at timestamp with time zone,
    heartbeat_at timestamp with time zone,
    available_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tasks_attempt_count_check CHECK ((attempt_count >= 0)),
    CONSTRAINT tasks_max_attempts_check CHECK ((max_attempts > 0)),
    CONSTRAINT tasks_status_check CHECK ((status = ANY (ARRAY['blocked'::text, 'queued'::text, 'running'::text, 'completed'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: task_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events ALTER COLUMN id SET DEFAULT nextval('public.task_events_id_seq'::regclass);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: api_rate_limits api_rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_rate_limits
    ADD CONSTRAINT api_rate_limits_pkey PRIMARY KEY (bucket_key);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: memories memories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memories
    ADD CONSTRAINT memories_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: task_dependencies task_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_pkey PRIMARY KEY (task_id, depends_on_task_id);


--
-- Name: task_events task_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT task_events_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: idx_api_rate_limits_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_api_rate_limits_updated_at ON public.api_rate_limits USING btree (updated_at);


--
-- Name: memories_category_updated_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memories_category_updated_idx ON public.memories USING btree (category, updated_at DESC);


--
-- Name: memories_tags_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memories_tags_gin_idx ON public.memories USING gin (tags);


--
-- Name: memories_title_category_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX memories_title_category_uq ON public.memories USING btree (lower((title)::text), lower(category));


--
-- Name: task_dependencies_prerequisite_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_dependencies_prerequisite_idx ON public.task_dependencies USING btree (depends_on_task_id);


--
-- Name: task_events_run_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_events_run_created_idx ON public.task_events USING btree (run_id, created_at);


--
-- Name: task_events_task_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_events_task_created_idx ON public.task_events USING btree (task_id, created_at);


--
-- Name: task_events_type_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_events_type_created_idx ON public.task_events USING btree (event_type, created_at DESC);


--
-- Name: tasks_agent_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_agent_status_idx ON public.tasks USING btree (agent_id, status, created_at DESC);


--
-- Name: tasks_conversation_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_conversation_created_idx ON public.tasks USING btree (conversation_id, created_at DESC);


--
-- Name: tasks_queue_pick_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_queue_pick_idx ON public.tasks USING btree (priority, available_at, created_at) WHERE (status = 'queued'::text);


--
-- Name: tasks_status_updated_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_status_updated_idx ON public.tasks USING btree (status, updated_at DESC);


--
-- Name: messages messages_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.agents(id) ON DELETE SET NULL;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: task_dependencies task_dependencies_depends_on_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_depends_on_task_id_fkey FOREIGN KEY (depends_on_task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_dependencies task_dependencies_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_events task_events_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT task_events_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.agents(id) ON DELETE SET NULL;


--
-- Name: task_events task_events_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT task_events_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.agents(id) ON DELETE RESTRICT;


--
-- Name: tasks tasks_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_parent_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_parent_task_id_fkey FOREIGN KEY (parent_task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict i6JqETa76EBzzWQaYMcSLEaxQAPA4eX2r4kkN9gB8exSyfN2SksvL6eRdK3sqH3

