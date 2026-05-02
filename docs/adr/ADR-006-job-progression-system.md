# ADR-006: Job Progression System (FFTA-Style)

## Status
**Accepted** — implementation in progress.

## Context
Alpha proved the 3-job system works mechanically. The next step is giving
players a reason to keep fighting: **job progression**. We're modeling this
directly on Final Fantasy Tactics Advance (FFTA) because that system is
well-proven, designer-friendly, and maps cleanly onto our existing
JobData / SkillData / Unit architecture.

### FFTA Reference Model
1. Each job has a fixed list of **learnable abilities**.
2. **AP (Ability Points)** are earned at the end of every battle.
3. AP accumulates per-ability: each ability has an AP cost to master.
4. **Mastered abilities are permanent** — they persist across job changes.
5. New jobs **unlock** when a unit masters enough abilities from prerequisite jobs.
6. Units can equip a **secondary ability set** from any job they've unlocked, giving
   access to mastered skills from that job alongside their current job's skills.

## Decision

### New Concepts

| Concept | Implementation |
|---|---|
| **AP (Ability Points)** | Flat amount awarded to every living unit at battle end. Default: 10 AP. Tunable via `JobProgression.AP_PER_BATTLE`. |
| **Learnable Skills** | Each `JobData` gains a `learnable_skill_names` array — the full set of abilities that job can teach. Starting skills are a subset; the rest unlock as AP accumulates. |
| **AP Cost per Skill** | New field on `SkillData`: `ap_cost: int`. 0 = innate (always known, no AP needed). Typical range: 50–300 AP. |
| **Mastery** | A skill is "mastered" when cumulative AP earned (while that job is active) meets or exceeds the skill's `ap_cost`. Mastered skills are permanently available. |
| **Job Prerequisites** | Each `JobData` gains a `prerequisites: Dictionary` — maps `job_name → abilities_mastered_count`. A unit can switch to a job only when all prereqs are met. Starter jobs have empty prereqs. |
| **Secondary Ability Set** | Each unit gains a `secondary_job_name` slot. When set, all mastered skills from that job are available alongside the primary job's skills. |
| **JobProgression Resource** | New `JobProgressionData` resource stored per-unit. Tracks: which jobs are unlocked, AP accumulated per skill per job, which skills are mastered. |

### Stat Flow on Job Switch
```
Unit.change_job(new_job_name)
  → job = JobLibrary.get_job(new_job_name)
  → base_attributes = job.base_attributes.duplicate()  (base resets to new job's array)
  → stats = StatFormulas.derive(base_attributes, job.move_range, job.jump)
  → skills = merge(primary_job_skills, secondary_job_mastered_skills)
```
Attributes are job-defined (your STR/DEX/etc change when you change class,
just like FFTA). Equipment modifiers layer on top as before.

### Job Unlock Tree (Initial)
```
SQUIRE (starter)           WHITE MAGE (starter)        ROGUE (starter)
 ├─ Soldier (2 Squire)      ├─ Bishop (2 WM)            ├─ Assassin (2 Rogue)
 ├─ Knight (3 Squire)       ├─ Time Mage (2 WM)         ├─ Ninja (3 Rogue)
 └─ Paladin (2 Knight,      └─ Sage (3 WM, 2 TM)        └─ Shadow (2 Assassin,
     2 WM)                                                    2 Ninja)
```

### AP Economy Targets
- **AP per battle:** 10 (flat, all living units)
- **Starter skill AP costs:** 50–100 (mastered in 5–10 battles)
- **Advanced skill AP costs:** 150–300 (mastered in 15–30 battles)
- **Typical job has 5 learnable skills**
- **Unlock threshold:** 2–3 mastered abilities from a prerequisite job

### File Map

| File | Change |
|---|---|
| `scripts/jobs/job_progression.gd` | NEW — per-unit progression tracking |
| `scripts/jobs/job_data.gd` | ADD `learnable_skill_names`, `prerequisites` |
| `scripts/jobs/job_library.gd` | ADD new jobs, prerequisite trees, learnable lists |
| `scripts/skills/skill_data.gd` | ADD `ap_cost` field |
| `scripts/skills/skill_library.gd` | ADD AP costs to all skills, add new skills |
| `scripts/units/unit.gd` | ADD `progression`, `secondary_job_name`, job-switch API |

## Consequences

### Positive
- Players have meaningful long-term progression that rewards continued play.
- Job switching adds replayability and squad-building depth.
- Secondary ability sets create combinatorial build variety.
- Data-driven: new jobs/skills are just new entries, not new code paths.
- FOIL system benefits — more player choices = richer behavioral profile.

### Negative
- Save/load must now persist `JobProgressionData` per unit (not yet built).
- UI work needed: job switch screen, ability equip screen, AP display.
- Balance complexity increases — more skills × more jobs × secondary sets.
- Must coordinate with Creative Director on pacing (AP economy tuning).

### Risks
- AP grind feel: if costs are too high, progression feels stalled. Mitigate
  with tunable constants and a balance pass.
- Secondary ability abuse: overpowered combos. Mitigate by limiting secondary
  to one set and keeping reaction/support slots for later phases.

## Dependencies
- Requires ADR-004 (BaseAttributes) — ✅ already shipped.
- Requires ADR-005 (Equipment) — ✅ already shipped.
- UI implementation deferred — API is ready, UI Developer picks it up.
- Save/Load system needed before progression is persistent across sessions.
