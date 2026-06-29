# JSON Schemas

Schemas for eval, grading, and benchmark data produced by skill-creator scripts.
All schemas are harness-agnostic (OpenCode, Codex, Copilot).

---

## evals.json

Defines eval cases for a skill. Located at `evals/evals.json` within the skill directory.

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's example prompt",
      "expected_output": "Description of expected result",
      "files": ["evals/files/sample1.txt"],
      "expectations": [
        "The output includes X",
        "The skill used script Y"
      ]
    }
  ]
}
```

**Fields:**
- `skill_name`: Name matching the skill's frontmatter
- `evals[].id`: Unique integer identifier
- `evals[].prompt`: The task to execute
- `evals[].expected_output`: Human-readable description of success
- `evals[].files`: Optional list of input file paths (relative to skill root)
- `evals[].expectations`: List of verifiable statements to grade against

---

## grading.json

Output from grading an eval run. Located at `<run-dir>/grading.json`.

```json
{
  "expectations": [
    {
      "text": "The output includes the name 'John Smith'",
      "passed": true,
      "evidence": "Found in output line 12: 'Extracted names: John Smith, Sarah Johnson'"
    },
    {
      "text": "A CSV file was created",
      "passed": false,
      "evidence": "No CSV file found in outputs directory"
    }
  ],
  "summary": {
    "passed": 2,
    "failed": 1,
    "total": 3,
    "pass_rate": 0.67
  },
  "execution_metrics": {
    "tool_calls": 15,
    "total_steps": 6,
    "errors_encountered": 0,
    "output_chars": 12450
  },
  "timing": {
    "total_duration_seconds": 23.3
  }
}
```

**Fields:**
- `expectations[]`: Graded expectations with pass/fail and evidence
- `summary`: Aggregate pass/fail counts and pass rate
- `execution_metrics`: Tool usage and output size
- `timing`: Wall clock timing

---

## metrics.json

Execution metrics from a single eval run. Located at `<run-dir>/outputs/metrics.json`.

```json
{
  "tool_calls": 18,
  "total_steps": 6,
  "files_created": ["output.md", "data.json"],
  "errors_encountered": 0,
  "output_chars": 12450
}
```

**Fields:**
- `tool_calls`: Total tool invocations during execution
- `total_steps`: Number of major execution steps
- `files_created`: List of output files created
- `errors_encountered`: Number of errors during execution
- `output_chars`: Total character count of output

---

## timing.json

Wall clock timing for a run. Located at `<run-dir>/timing.json`.

```json
{
  "start_time": "2026-01-15T10:30:00Z",
  "end_time": "2026-01-15T10:32:45Z",
  "total_duration_seconds": 165.0
}
```

**Fields:**
- `start_time`: ISO 8601 timestamp when execution started
- `end_time`: ISO 8601 timestamp when execution completed
- `total_duration_seconds`: Wall clock seconds

---

## benchmark.json

Aggregated benchmark results. Located at `benchmarks/<timestamp>/benchmark.json`.

```json
{
  "metadata": {
    "skill_name": "example-skill",
    "skill_path": "/path/to/skill",
    "timestamp": "2026-01-15T10:30:00Z",
    "evals_run": [1, 2, 3],
    "runs_per_configuration": 3
  },
  "runs": [
    {
      "eval_id": 1,
      "configuration": "with_skill",
      "run_number": 1,
      "result": {
        "pass_rate": 0.85,
        "passed": 6,
        "failed": 1,
        "total": 7,
        "time_seconds": 42.5
      }
    }
  ],
  "run_summary": {
    "with_skill": {
      "pass_rate": { "mean": 0.85, "stddev": 0.05, "min": 0.80, "max": 0.90 },
      "time_seconds": { "mean": 45.0, "stddev": 12.0, "min": 32.0, "max": 58.0 }
    },
    "without_skill": {
      "pass_rate": { "mean": 0.35, "stddev": 0.08, "min": 0.28, "max": 0.45 },
      "time_seconds": { "mean": 32.0, "stddev": 8.0, "min": 24.0, "max": 42.0 }
    },
    "delta": {
      "pass_rate": "+0.50",
      "time_seconds": "+13.0"
    }
  },
  "notes": [
    "Skill adds 13s average execution time but improves pass rate by 50%"
  ]
}
```

**Fields:**
- `metadata`: Information about the benchmark run
  - `skill_name`: Name of the skill
  - `timestamp`: When the benchmark was run
  - `evals_run`: List of eval IDs included
  - `runs_per_configuration`: Number of runs per config (e.g., 3)
- `runs[]`: Individual run results
  - `eval_id`: Numeric eval identifier
  - `configuration`: `"with_skill"` or `"without_skill"`
  - `run_number`: Integer run number (1, 2, 3...)
  - `result`: Nested object with `pass_rate`, `passed`, `failed`, `total`, `time_seconds`
- `run_summary`: Statistical aggregates per configuration
  - Each contains objects with `mean`, `stddev`, `min`, `max`
  - `delta`: Difference strings like `"+0.50"`
- `notes`: Freeform observations

---

## history.json

Tracks iteration progression during improvement mode. Located at workspace root.

```json
{
  "started_at": "2026-01-15T10:30:00Z",
  "skill_name": "example-skill",
  "current_best": "v2",
  "iterations": [
    {
      "version": "v0",
      "parent": null,
      "expectation_pass_rate": 0.65,
      "grading_result": "baseline",
      "is_current_best": false
    },
    {
      "version": "v1",
      "parent": "v0",
      "expectation_pass_rate": 0.75,
      "grading_result": "won",
      "is_current_best": false
    },
    {
      "version": "v2",
      "parent": "v1",
      "expectation_pass_rate": 0.85,
      "grading_result": "won",
      "is_current_best": true
    }
  ]
}
```

**Fields:**
- `started_at`: ISO timestamp of when improvement started
- `skill_name`: Name of the skill being improved
- `current_best`: Version identifier of the best performer
- `iterations[].version`: Version identifier (v0, v1, ...)
- `iterations[].parent`: Parent version this was derived from
- `iterations[].expectation_pass_rate`: Pass rate from grading
- `iterations[].grading_result`: `"baseline"`, `"won"`, `"lost"`, or `"tie"`
- `iterations[].is_current_best`: Whether this is the current best version
