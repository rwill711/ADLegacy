using System.Collections.Generic;
using UnityEngine;
using ADLegacy.Grid;
using ADLegacy.Jobs;
using ADLegacy.Skills;

namespace ADLegacy.Units
{
    /// <summary>
    /// Main unit class representing a character in battle.
    /// Handles stats, position, status effects, and actions.
    /// </summary>
    public class Unit : MonoBehaviour
    {
        [Header("Unit Identity")]
        [SerializeField] private string unitName = "Unnamed Unit";
        [SerializeField] private UnitTeam team = UnitTeam.Player;
        [SerializeField] private int unitID = -1;

        [Header("Job & Stats")]
        [SerializeField] private JobData currentJob;
        [SerializeField] private UnitStats stats;
        [SerializeField] private List<JobData> unlockedJobs = new List<JobData>();

        [Header("Skills")]
        [SerializeField] private List<SkillData> availableSkills = new List<SkillData>();
        [SerializeField] private List<SkillData> equippedSkills = new List<SkillData>();

        [Header("Visuals")]
        [SerializeField] private SpriteRenderer spriteRenderer;
        [SerializeField] private Animator animator;
        [SerializeField] private Transform healthBarTransform;

        [Header("Grid Position")]
        [SerializeField] private GridTile currentTile;
        [SerializeField] private Vector2Int gridPosition;

        [Header("Turn State")]
        [SerializeField] private bool hasMoved = false;
        [SerializeField] private bool hasActed = false;
        [SerializeField] private bool isPlayerControlled = true;

        // Status effects
        private List<StatusEffect> activeStatusEffects = new List<StatusEffect>();

        // Turn tracking
        private int turnsSinceAction = 0;

        #region Properties

        public string UnitName
        {
            get => unitName;
            set => unitName = value;
        }

        public UnitTeam Team => team;

        public int UnitID
        {
            get => unitID;
            set => unitID = value;
        }

        public JobData CurrentJob
        {
            get => currentJob;
            set => SetJob(value);
        }

        public UnitStats Stats => stats;

        public List<SkillData> AvailableSkills => availableSkills;
        public List<SkillData> EquippedSkills => equippedSkills;

        public GridTile CurrentTile
        {
            get => currentTile;
            set
            {
                if (currentTile != null)
                    currentTile.OccupyingUnit = null;

                currentTile = value;

                if (currentTile != null)
                {
                    currentTile.OccupyingUnit = this;
                    gridPosition = currentTile.GridPosition;
                    transform.position = currentTile.WorldPosition + Vector3.up * 0.5f;
                }
            }
        }

        public Vector2Int GridPosition => gridPosition;

        public bool HasMoved
        {
            get => hasMoved;
            set => hasMoved = value;
        }

        public bool HasActed
        {
            get => hasActed;
            set => hasActed = value;
        }

        public bool CanAct => !hasActed && stats.IsAlive;
        public bool CanMove => !hasMoved && stats.IsAlive;

        public bool IsAlive => stats.IsAlive;
        public bool IsDead => stats.IsDead;

        public bool IsPlayerControlled => isPlayerControlled;

        public List<StatusEffect> ActiveStatusEffects => activeStatusEffects;

        #endregion

        #region Unity Lifecycle

        private void Awake()
        {
            if (spriteRenderer == null)
                spriteRenderer = GetComponentInChildren<SpriteRenderer>();

            if (animator == null)
                animator = GetComponentInChildren<Animator>();

            if (stats == null)
                stats = new UnitStats();
        }

        private void Start()
        {
            UpdateVisuals();
            UpdateSortingOrder();
        }

        private void OnMouseDown()
        {
            if (GameManager.Instance != null)
                GameManager.Instance.OnUnitClicked(this);
        }

        #endregion

        #region Initialization

        /// <summary>
        /// Initialize unit with job and starting position.
        /// </summary>
        public void Initialize(string name, JobData job, GridTile startTile, UnitTeam unitTeam, bool playerControlled = true)
        {
            unitName = name;
            team = unitTeam;
            isPlayerControlled = playerControlled;

            SetJob(job);
            CurrentTile = startTile;

            stats.FullRestore();
            ResetTurnState();
            UpdateVisuals();
        }

        /// <summary>
        /// Initialize unit with specific stats (for custom units).
        /// </summary>
        public void InitializeWithStats(string name, UnitStats customStats, GridTile startTile, UnitTeam unitTeam)
        {
            unitName = name;
            team = unitTeam;
            stats = customStats.Clone();
            CurrentTile = startTile;

            stats.FullRestore();
            ResetTurnState();
            UpdateVisuals();
        }

        #endregion

        #region Job Management

        /// <summary>
        /// Set the unit's current job.
        /// </summary>
        public void SetJob(JobData job)
        {
            if (job == null) return;

            currentJob = job;

            // Apply job base stats
            if (stats == null)
                stats = new UnitStats();

            stats.SetBaseStats(
                job.BaseHP,
                job.BaseMP,
                job.BaseAttack,
                job.BaseDefense,
                job.BaseMagic,
                job.BaseResistance,
                job.BaseSpeed
            );

            // Update available skills
            availableSkills.Clear();
            availableSkills.AddRange(job.JobSkills);

            // Unlock job if not already unlocked
            if (!unlockedJobs.Contains(job))
                unlockedJobs.Add(job);

            Debug.Log($"{unitName} is now a {job.JobName}");
        }

        /// <summary>
        /// Unlock a new job.
        /// </summary>
        public void UnlockJob(JobData job)
        {
            if (!unlockedJobs.Contains(job))
            {
                unlockedJobs.Add(job);
                Debug.Log($"{unitName} unlocked job: {job.JobName}");
            }
        }

        /// <summary>
        /// Check if a job is unlocked.
        /// </summary>
        public bool IsJobUnlocked(JobData job)
        {
            return unlockedJobs.Contains(job);
        }

        #endregion

        #region Turn Management

        /// <summary>
        /// Start this unit's turn.
        /// </summary>
        public void StartTurn()
        {
            ResetTurnState();
            ProcessStatusEffects();

            // Natural MP regeneration
            if (stats.CurrentMP < stats.MaxMP)
            {
                int mpRegen = Mathf.CeilToInt(stats.MaxMP * 0.05f); // 5% per turn
                stats.RestoreMP(mpRegen);
            }

            // Dangerous terrain damage
            if (currentTile != null && currentTile.IsDangerous)
            {
                int damage = currentTile.DamagePerTurn;
                TakeDamage(damage);
                Debug.Log($"{unitName} took {damage} damage from {currentTile.Terrain}!");
            }

            UpdateVisuals();
        }

        /// <summary>
        /// End this unit's turn.
        /// </summary>
        public void EndTurn()
        {
            turnsSinceAction++;
            UpdateVisuals();
        }

        /// <summary>
        /// Reset turn state (can move and act again).
        /// </summary>
        public void ResetTurnState()
        {
            hasMoved = false;
            hasActed = false;
            turnsSinceAction = 0;
        }

        #endregion

        #region Combat

        /// <summary>
        /// Take damage from an attack.
        /// </summary>
        public int TakeDamage(int amount, bool isMagical = false, bool canCrit = true)
        {
            // Calculate actual damage after defense
            int damageReduction = isMagical ? stats.Resistance : stats.Defense;
            int actualDamage = Mathf.Max(1, amount - damageReduction);

            // Apply damage
            int damageTaken = stats.TakeDamage(actualDamage);

            // Check for death
            if (stats.IsDead)
            {
                OnDeath();
            }

            UpdateVisuals();
            return damageTaken;
        }

        /// <summary>
        /// Heal this unit.
        /// </summary>
        public int Heal(int amount)
        {
            int actualHealing = stats.Heal(amount);
            UpdateVisuals();
            return actualHealing;
        }

        /// <summary>
        /// Restore MP to this unit.
        /// </summary>
        public int RestoreMP(int amount)
        {
            int actualRestore = stats.RestoreMP(amount);
            UpdateVisuals();
            return actualRestore;
        }

        /// <summary>
        /// Called when unit dies.
        /// </summary>
        private void OnDeath()
        {
            Debug.Log($"{unitName} has been defeated!");

            // Clear tile occupancy
            if (currentTile != null)
                currentTile.OccupyingUnit = null;

            // Play death animation
            if (animator != null)
                animator.SetTrigger("Death");

            // Notify battle manager
            if (BattleManager.Instance != null)
                BattleManager.Instance.OnUnitDefeated(this);

            // TODO: Show death effect, corpse timer, etc.
        }

        /// <summary>
        /// Revive this unit.
        /// </summary>
        public void Revive(float hpPercent = 0.5f)
        {
            if (stats.IsAlive) return;

            stats.Revive(hpPercent);
            ResetTurnState();
            UpdateVisuals();

            Debug.Log($"{unitName} has been revived with {stats.CurrentHP} HP!");
        }

        #endregion

        #region Status Effects

        /// <summary>
        /// Apply a status effect to this unit.
        /// </summary>
        public void ApplyStatusEffect(StatusEffect effect)
        {
            // Check if already has this status
            StatusEffect existing = activeStatusEffects.Find(e => e.Type == effect.Type);

            if (existing != null)
            {
                // Refresh duration
                existing.Duration = Mathf.Max(existing.Duration, effect.Duration);
            }
            else
            {
                activeStatusEffects.Add(effect);
                effect.OnApply(this);
            }

            UpdateVisuals();
        }

        /// <summary>
        /// Remove a status effect.
        /// </summary>
        public void RemoveStatusEffect(StatusEffectType type)
        {
            StatusEffect effect = activeStatusEffects.Find(e => e.Type == type);
            if (effect != null)
            {
                effect.OnRemove(this);
                activeStatusEffects.Remove(effect);
            }

            UpdateVisuals();
        }

        /// <summary>
        /// Process status effects at start of turn.
        /// </summary>
        private void ProcessStatusEffects()
        {
            List<StatusEffect> effectsToRemove = new List<StatusEffect>();

            foreach (StatusEffect effect in activeStatusEffects)
            {
                effect.OnTurnStart(this);
                effect.Duration--;

                if (effect.Duration <= 0)
                    effectsToRemove.Add(effect);
            }

            foreach (StatusEffect effect in effectsToRemove)
            {
                effect.OnRemove(this);
                activeStatusEffects.Remove(effect);
            }
        }

        /// <summary>
        /// Check if unit has a specific status effect.
        /// </summary>
        public bool HasStatusEffect(StatusEffectType type)
        {
            return activeStatusEffects.Exists(e => e.Type == type);
        }

        #endregion

        #region Experience & Leveling

        /// <summary>
        /// Gain experience points.
        /// </summary>
        public void GainExperience(int amount)
        {
            bool leveledUp = stats.AddExperience(amount);

            if (leveledUp && currentJob != null)
            {
                LevelUp();
            }
        }

        /// <summary>
        /// Level up the unit.
        /// </summary>
        private void LevelUp()
        {
            stats.LevelUp(currentJob.StatGrowth);
            Debug.Log($"{unitName} leveled up to level {stats.Level}!");

            // TODO: Show level up UI
            if (BattleManager.Instance != null)
                BattleManager.Instance.OnUnitLevelUp(this);
        }

        #endregion

        #region Visuals

        private void UpdateVisuals()
        {
            if (spriteRenderer == null) return;

            // Update sprite color based on team
            if (team == UnitTeam.Player)
                spriteRenderer.color = new Color(0.5f, 0.5f, 1f); // Blue tint
            else if (team == UnitTeam.Enemy)
                spriteRenderer.color = new Color(1f, 0.5f, 0.5f); // Red tint

            // Gray out if can't act
            if (!CanAct || IsDead)
                spriteRenderer.color = Color.gray;

            UpdateSortingOrder();
        }

        private void UpdateSortingOrder()
        {
            if (spriteRenderer == null || currentTile == null) return;

            // Sort based on Y position (units closer to camera render on top)
            spriteRenderer.sortingLayerName = "Units";
            spriteRenderer.sortingOrder = -(currentTile.GridPosition.y * 100 + currentTile.GridPosition.x);
        }

        #endregion

        #region Utility

        /// <summary>
        /// Get distance to another unit.
        /// </summary>
        public int GetDistanceTo(Unit other)
        {
            if (currentTile == null || other.CurrentTile == null)
                return 999;

            return currentTile.GetManhattanDistanceTo(other.CurrentTile);
        }

        /// <summary>
        /// Check if unit is adjacent to another unit.
        /// </summary>
        public bool IsAdjacentTo(Unit other)
        {
            return GetDistanceTo(other) == 1;
        }

        public override string ToString()
        {
            return $"{unitName} ({currentJob?.JobName ?? "No Job"}) Lv.{stats.Level} | {stats}";
        }

        #endregion
    }

    #region Enums

    public enum UnitTeam
    {
        Player,
        Enemy,
        Neutral
    }

    #endregion

    #region Status Effect System

    [System.Serializable]
    public class StatusEffect
    {
        public StatusEffectType Type;
        public int Duration; // In turns
        public int Potency; // Strength of effect

        public virtual void OnApply(Unit unit) { }
        public virtual void OnRemove(Unit unit) { }
        public virtual void OnTurnStart(Unit unit) { }
    }

    public enum StatusEffectType
    {
        None,
        Poison,
        Burn,
        Slow,
        Haste,
        Sleep,
        Stun,
        Blind,
        Protect,
        Shell,
        Regen,
        Doom
    }

    #endregion
}
