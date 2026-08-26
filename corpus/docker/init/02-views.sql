-- Views. Each one answers a question the raw tables can only be interrogated
-- for, and each is the query you would otherwise write badly at 2am.

-- How long does a known-unresolved thing stay unresolved?
--
-- The interesting column is `laps_open`, not `state`. A thread carried across
-- six entries is not the same object as one carried across one, even though
-- both read as "open" in the record.
CREATE VIEW v_thread_age AS
SELECT t.thread_id,
       t.opened_by,
       t.closed_by,
       t.state,
       COALESCE(t.lifespan,
                (SELECT COUNT(*) FROM iteration i WHERE i.iteration_id > t.opened_by)
       ) AS laps_open,
       t.carried_count,
       left(t.body, 160) AS gist
FROM thread t
ORDER BY laps_open DESC, t.thread_id;

-- Calibration. Every doubt the author recorded, with whether a LATER lap
-- mentions its subject again.
--
-- The join is lexical and it is a proxy, not a proof: a later entry naming the
-- same distinctive term is evidence the doubt was revisited, not evidence it
-- was resolved. Stated here rather than hidden, because a view called
-- "calibration" that silently guesses is worse than no view.
CREATE VIEW v_calibration AS
SELECT c.claim_id,
       c.iteration_id AS raised_in,
       c.hedged,
       c.body,
       EXISTS (
           SELECT 1
           FROM thread t
           WHERE t.opened_by = c.iteration_id
             AND t.state = 'closed'
       ) AS lap_closed_something,
       (SELECT MIN(i.iteration_id)
          FROM iteration i
         WHERE i.iteration_id > c.iteration_id
           AND i.body ILIKE '%' || split_part(trim(both '*' from left(c.body, 40)), ' ', 1) || '%'
       ) AS revisited_in
FROM claim c
WHERE c.section = 'could_not_verify';

-- What keeps going wrong. A term appearing in three separate laps is a thing
-- the author kept re-learning, which is the single most useful thing a
-- development corpus can point at.
CREATE VIEW v_recurring_trouble AS
SELECT term, iterations, occurrences, first_seen, last_seen, example
FROM term_recurrence
WHERE iterations >= 3
ORDER BY iterations DESC, occurrences DESC;

-- Cost and shape of the back and forth, per session.
CREATE VIEW v_session_shape AS
SELECT s.session_id,
       s.git_branch,
       s.turn_count,
       COUNT(*) FILTER (WHERE t.role = 'user')      AS user_turns,
       COUNT(*) FILTER (WHERE t.role = 'assistant') AS assistant_turns,
       SUM(t.output_tokens)                         AS output_tokens,
       SUM(t.thinking_chars)                        AS thinking_chars,
       (SELECT COUNT(*) FROM tool_call tc
          JOIN turn t2 ON t2.turn_id = tc.turn_id
         WHERE t2.session_id = s.session_id)        AS tool_calls
FROM session s
LEFT JOIN turn t ON t.session_id = s.session_id
GROUP BY s.session_id, s.git_branch, s.turn_count;

-- The deliverable. One SELECT away from a JSONL export.
--
-- weight is not a guess at quality: it is how RARE the kind is. Ordinary
-- exchanges are abundant everywhere; a recorded doubt with an outcome attached
-- is not, and a sampler that treats them equally will drown the signal that
-- made this corpus worth assembling.
CREATE VIEW v_training_set AS
SELECT example_id, kind, prompt, completion, weight, metadata
FROM training_example
ORDER BY kind, example_id;
