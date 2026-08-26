-- PSCorpus schema.
--
-- WHAT THIS IS FOR, because it decides every table below.
--
-- The raw material is not "some conversations". It is a LOOP that ran seven
-- times in this repository and left a machine-readable trace of every lap:
--
--     prompt -> implementation -> self-assessment -> correction
--
-- Four signals fall out of that, and three of them are rare:
--
--   1. exchange     (prompt, response). Ordinary supervised data.
--   2. calibration  a claim the author made about the LIMITS of their own work,
--                   written before anyone checked, plus whether a later lap
--                   resolved it. Predictions about one's own reliability with
--                   ground truth attached are almost absent from public corpora.
--   3. critique     the author criticising the INSTRUCTION they were given, and
--                   whether the next instruction accepted the criticism. A
--                   preference pair where the model is the critic.
--   4. handoff      advice written to the author's next self, in the second
--                   person, about what to check first and what they got wrong.
--
-- Every table exists to make one of those four extractable with a query rather
-- than with a parser. training_example is the output; everything above it is
-- the evidence that produced a row, kept so a row can be argued with.

CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------------------
-- Provenance. Nothing enters this database without a file and a hash behind it.
-- ---------------------------------------------------------------------------
CREATE TABLE corpus_source (
    source_id    TEXT PRIMARY KEY,
    kind         TEXT        NOT NULL CHECK (kind IN ('transcript', 'ledger', 'pattern')),
    path         TEXT        NOT NULL,
    sha256       TEXT        NOT NULL,
    bytes        BIGINT      NOT NULL,
    -- Whether the ingester's redaction pass ran. A corpus assembled from a
    -- developer's own machine carries their home directory and their email in
    -- almost every absolute path, and a training set is the worst possible
    -- place to discover that later.
    redacted     BOOLEAN     NOT NULL DEFAULT TRUE,
    ingested_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- The back and forth.
-- ---------------------------------------------------------------------------
CREATE TABLE session (
    session_id  TEXT PRIMARY KEY,
    source_id   TEXT REFERENCES corpus_source (source_id) ON DELETE CASCADE,
    project     TEXT,
    git_branch  TEXT,
    started_at  TIMESTAMPTZ,
    ended_at    TIMESTAMPTZ,
    turn_count  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE turn (
    turn_id           BIGSERIAL PRIMARY KEY,
    session_id        TEXT    NOT NULL REFERENCES session (session_id) ON DELETE CASCADE,
    ordinal           INTEGER NOT NULL,
    uuid              TEXT,
    parent_uuid       TEXT,
    role              TEXT    NOT NULL CHECK (role IN ('user', 'assistant')),
    model             TEXT,
    -- Visible text only. Reasoning blocks are counted, never stored: their
    -- length is a useful feature and their content is not ours to redistribute.
    text              TEXT,
    thinking_chars    INTEGER NOT NULL DEFAULT 0,
    input_tokens      INTEGER,
    output_tokens     INTEGER,
    cache_read_tokens INTEGER,
    at                TIMESTAMPTZ,
    UNIQUE (session_id, ordinal)
);

CREATE TABLE tool_call (
    tool_call_id  BIGSERIAL PRIMARY KEY,
    turn_id       BIGINT NOT NULL REFERENCES turn (turn_id) ON DELETE CASCADE,
    ordinal       INTEGER NOT NULL,
    tool_name     TEXT   NOT NULL,
    -- A summary, not the payload. The full input of a Write is an entire file;
    -- storing it would make the corpus a second copy of the repository.
    input_summary TEXT,
    is_error      BOOLEAN,
    result_chars  INTEGER
);

-- ---------------------------------------------------------------------------
-- The record of work. One row per lap of the loop.
-- ---------------------------------------------------------------------------
CREATE TABLE iteration (
    iteration_id  TEXT PRIMARY KEY,          -- '0007'
    source_id     TEXT REFERENCES corpus_source (source_id) ON DELETE CASCADE,
    tag           TEXT,
    entry_date    DATE,
    title         TEXT,
    -- The author's own restatement of what they were asked for. Deliberately a
    -- restatement rather than a quotation: a restatement that misses the point
    -- is itself a label.
    prompt_intent TEXT,
    personas      TEXT[],
    body          TEXT
);

-- A thread is an admitted loose end with an identity, so its LIFESPAN is
-- measurable. "How long does a known-unresolved thing stay unresolved" is a
-- question almost no corpus can answer, and it is answerable here by
-- subtraction.
CREATE TABLE thread (
    thread_id     TEXT PRIMARY KEY,          -- '0003-t1'
    opened_by     TEXT REFERENCES iteration (iteration_id) ON DELETE CASCADE,
    closed_by     TEXT REFERENCES iteration (iteration_id),
    carried_count INTEGER NOT NULL DEFAULT 0,
    lifespan      INTEGER,                   -- laps from open to close; NULL while open
    state         TEXT NOT NULL CHECK (state IN ('open', 'closed')),
    body          TEXT
);

-- One bullet from one section of one entry. Sections are kept apart because
-- they are different speech acts: 'changed' is a report, 'learned' is a
-- generalisation, and 'could_not_verify' is a prediction about the author's own
-- reliability - which is the only one with ground truth waiting for it.
CREATE TABLE claim (
    claim_id     BIGSERIAL PRIMARY KEY,
    iteration_id TEXT    NOT NULL REFERENCES iteration (iteration_id) ON DELETE CASCADE,
    section      TEXT    NOT NULL CHECK (section IN ('changed', 'learned', 'could_not_verify', 'reflection')),
    ordinal      INTEGER NOT NULL,
    body         TEXT    NOT NULL,
    -- Whether the sentence hedges. An unhedged claim in could_not_verify is
    -- usually a finding wearing a doubt's clothes.
    hedged       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE pattern (
    pattern_id   TEXT PRIMARY KEY,           -- '0004-could-not-check-is-not-passed'
    iteration_id TEXT REFERENCES iteration (iteration_id) ON DELETE CASCADE,
    tag          TEXT,
    -- Never 1. A shape seen twice and named once is not a law, and a corpus
    -- that records certainty it did not have teaches exactly that.
    confidence   NUMERIC CHECK (confidence > 0 AND confidence <= 1),
    scales       TEXT[]  NOT NULL,
    statement    TEXT,
    handoff      TEXT,
    CHECK (array_length(scales, 1) >= 2)
);

-- The author criticising the instruction they were given. Extracted from the
-- transcript rather than the ledger, because it is addressed to the person who
-- wrote the instruction and never survives into the record of work.
CREATE TABLE critique (
    critique_id  BIGSERIAL PRIMARY KEY,
    iteration_id TEXT REFERENCES iteration (iteration_id) ON DELETE CASCADE,
    session_id   TEXT REFERENCES session (session_id) ON DELETE SET NULL,
    turn_id      BIGINT REFERENCES turn (turn_id) ON DELETE SET NULL,
    body         TEXT NOT NULL,
    -- NULL until a later instruction is read and shown to accept or reject it.
    -- Left null rather than guessed: "could not check" is not "checked and
    -- passed", and a default of false would silently assert rejection.
    accepted     BOOLEAN
);

-- Lexical recurrence across laps. Not semantics - a term that keeps coming
-- back is a thing that keeps going wrong, and counting is enough to surface it.
CREATE TABLE term_recurrence (
    term        TEXT PRIMARY KEY,
    iterations  INTEGER NOT NULL,
    occurrences INTEGER NOT NULL,
    first_seen  TEXT,
    last_seen   TEXT,
    example     TEXT
);

-- ---------------------------------------------------------------------------
-- The output.
-- ---------------------------------------------------------------------------
CREATE TABLE training_example (
    example_id BIGSERIAL PRIMARY KEY,
    kind       TEXT  NOT NULL CHECK (kind IN ('exchange', 'calibration', 'critique', 'handoff')),
    prompt     TEXT  NOT NULL,
    completion TEXT  NOT NULL,
    weight     REAL  NOT NULL DEFAULT 1.0,
    -- Every row keeps a pointer back to the rows that produced it. A training
    -- example nobody can trace to its evidence is one nobody can retract.
    metadata   JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- 1024 suits several common embedding sizes. Left null by the ingester:
    -- embedding is a separate pass with a separate cost and a separate model,
    -- and baking one in here would freeze that choice into the schema.
    embedding  vector(1024)
);

CREATE INDEX turn_session_idx        ON turn (session_id, ordinal);
CREATE INDEX tool_call_name_idx      ON tool_call (tool_name);
CREATE INDEX claim_section_idx       ON claim (section);
CREATE INDEX thread_state_idx        ON thread (state);
CREATE INDEX training_kind_idx       ON training_example (kind);
CREATE INDEX training_metadata_idx   ON training_example USING gin (metadata);
