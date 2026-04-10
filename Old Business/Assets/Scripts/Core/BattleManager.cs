using System.Collections.Generic;
using UnityEngine;
using ADLegacy.Units;
using ADLegacy.Grid;
using ADLegacy.Skills;

namespace ADLegacy
{
    /// <summary>
    /// Manages battle flow, turn order, and combat resolution.
    /// Coordinates between units, grid, and game systems.
    /// </summary>
    public class BattleManager : MonoBehaviour
    {
        public static BattleManager Instance { get; private set; }

        [Header("Battle Setup")]
        [SerializeField] private BattlefieldTemplate battlefieldTemplate = BattlefieldTemplate.RandomBattlefield;
        [SerializeField] private bool startBattleOnLoad = true;

        [Header("Units")]
        [SerializeField] private List<Unit> playerUnits = new List<Unit>();
        [SerializeField] private List<Unit> enemyUnits = new List<Unit>();
        [SerializeField] private List<Unit> allUnits = new List<Unit>();

        [Header("Turn Management")]
        [SerializeField] private BattlePhase currentPhase = BattlePhase.Setup;
        [SerializeField] private Unit activeUnit;
        [SerializeField] private int turnNumber = 1;

        // Battle state
        private bool battleActive = false;
        private Unit selectedUnit;
        private List<GridTile> validMoveTiles = new List<GridTile>();
        private List<GridTile> validAttackTiles = new List<GridTile>();

        // Action state
        private ActionState currentAction = ActionState.None;
        private SkillData selectedSkill;

        // Events
        public event System.Action<BattlePhase> OnPhaseChanged;
        public event System.Action<Unit> OnUnitTurnStart;
        public event System.Action<Unit> OnUnitTurnEnd;
        public event System.Action OnBattleStart;
        public event System.Action<bool> OnBattleEnd; // true = victory, false = defeat

        #region Properties

        public BattlePhase CurrentPhase => currentPhase;
        public Unit ActiveUnit => activeUnit;
        public int TurnNumber => turnNumber;
        public bool IsBattleActive => battleActive;

        public List<Unit> PlayerUnits => playerUnits;
        public List<Unit> EnemyUnits => enemyUnits;
        public List<Unit> AllUnits => allUnits;

        #endregion

        #region Unity Lifecycle

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
        }

        private void Start()
        {
            if (startBattleOnLoad)
            {
                // Give time for grid to generate
                Invoke(nameof(StartBattle), 0.5f);
            }
        }

        #endregion

        #region Battle Setup

        /// <summary>
        /// Start the battle.
        /// </summary>
        public void StartBattle()
        {
            Debug.Log("=== Battle Start ===");

            battleActive = true;
            turnNumber = 1;
            ChangePhase(BattlePhase.BattleStart);

            // Gather all units
            RefreshUnitLists();

            // Initialize turn order
            SortUnitsBySpeed();

            // Start first turn
            Invoke(nameof(StartPlayerTurn), 1f);

            OnBattleStart?.Invoke();
        }

        /// <summary>
        /// End the battle.
        /// </summary>
        public void EndBattle(bool victory)
        {
            Debug.Log($"=== Battle End: {(victory ? "VICTORY" : "DEFEAT")} ===");

            battleActive = false;
            ChangePhase(victory ? BattlePhase.Victory : BattlePhase.Defeat);

            // Update game state
            if (GameManager.Instance != null)
            {
                if (victory)
                {
                    GameManager.Instance.ChangeGameState(GameState.Victory);
                    GameManager.Instance.PlayerData.battlesWon++;
                }
                else
                {
                    GameManager.Instance.ChangeGameState(GameState.Defeat);
                    GameManager.Instance.PlayerData.battlesLost++;
                }
            }

            OnBattleEnd?.Invoke(victory);
        }

        #endregion

        #region Phase Management

        private void ChangePhase(BattlePhase newPhase)
        {
            if (currentPhase == newPhase)
                return;

            Debug.Log($"Battle Phase: {currentPhase} -> {newPhase}");

            currentPhase = newPhase;
            OnPhaseChanged?.Invoke(newPhase);

            // Handle phase-specific logic
            switch (newPhase)
            {
                case BattlePhase.PlayerTurn:
                    // Player turn starts
                    break;

                case BattlePhase.EnemyTurn:
                    // AI will take over
                    ProcessEnemyTurn();
                    break;

                case BattlePhase.Victory:
                case BattlePhase.Defeat:
                    // Battle over
                    break;
            }
        }

        #endregion

        #region Turn Management

        /// <summary>
        /// Start player turn phase.
        /// </summary>
        public void StartPlayerTurn()
        {
            Debug.Log($"--- Turn {turnNumber}: Player Phase ---");

            ChangePhase(BattlePhase.PlayerTurn);

            // Reset all player units' turn state
            foreach (Unit unit in playerUnits)
            {
                if (unit.IsAlive)
                {
                    unit.StartTurn();
                }
            }

            // Select first available unit
            SelectFirstAvailableUnit();
        }

        /// <summary>
        /// End player turn and start enemy turn.
        /// </summary>
        public void EndPlayerTurn()
        {
            Debug.Log("Player turn ended");

            ClearSelection();
            ChangePhase(BattlePhase.EnemyTurn);
        }

        /// <summary>
        /// Start enemy turn phase.
        /// </summary>
        public void StartEnemyTurn()
        {
            Debug.Log($"--- Turn {turnNumber}: Enemy Phase ---");

            ChangePhase(BattlePhase.EnemyTurn);

            // Reset all enemy units' turn state
            foreach (Unit unit in enemyUnits)
            {
                if (unit.IsAlive)
                {
                    unit.StartTurn();
                }
            }
        }

        /// <summary>
        /// Process enemy AI turns.
        /// </summary>
        private void ProcessEnemyTurn()
        {
            // TODO: Implement AI logic
            // For now, just end enemy turn after a delay

            Invoke(nameof(EndEnemyTurn), 2f);
        }

        /// <summary>
        /// End enemy turn and start next round.
        /// </summary>
        public void EndEnemyTurn()
        {
            Debug.Log("Enemy turn ended");

            turnNumber++;
            CheckVictoryConditions();

            if (battleActive)
            {
                StartPlayerTurn();
            }
        }

        #endregion

        #region Unit Management

        /// <summary>
        /// Add a unit to the battle.
        /// </summary>
        public void AddUnit(Unit unit)
        {
            if (unit == null) return;

            if (unit.Team == UnitTeam.Player)
            {
                if (!playerUnits.Contains(unit))
                    playerUnits.Add(unit);
            }
            else if (unit.Team == UnitTeam.Enemy)
            {
                if (!enemyUnits.Contains(unit))
                    enemyUnits.Add(unit);
            }

            if (!allUnits.Contains(unit))
                allUnits.Add(unit);

            Debug.Log($"Unit added to battle: {unit.UnitName} ({unit.Team})");
        }

        /// <summary>
        /// Remove a unit from battle.
        /// </summary>
        public void RemoveUnit(Unit unit)
        {
            playerUnits.Remove(unit);
            enemyUnits.Remove(unit);
            allUnits.Remove(unit);
        }

        /// <summary>
        /// Refresh unit lists.
        /// </summary>
        private void RefreshUnitLists()
        {
            allUnits.Clear();
            allUnits.AddRange(playerUnits);
            allUnits.AddRange(enemyUnits);

            Debug.Log($"Battle has {playerUnits.Count} player units and {enemyUnits.Count} enemy units");
        }

        /// <summary>
        /// Sort units by speed for turn order.
        /// </summary>
        private void SortUnitsBySpeed()
        {
            allUnits.Sort((a, b) => b.Stats.Speed.CompareTo(a.Stats.Speed));
        }

        /// <summary>
        /// Get all living units of a team.
        /// </summary>
        public List<Unit> GetLivingUnits(UnitTeam team)
        {
            List<Unit> units = new List<Unit>();

            foreach (Unit unit in allUnits)
            {
                if (unit.IsAlive && unit.Team == team)
                    units.Add(unit);
            }

            return units;
        }

        #endregion

        #region Unit Selection & Actions

        /// <summary>
        /// Called when a unit is selected.
        /// </summary>
        public void OnUnitSelected(Unit unit)
        {
            if (currentPhase != BattlePhase.PlayerTurn)
                return;

            // Can only select player units on player turn
            if (unit.Team != UnitTeam.Player)
            {
                // Selecting enemy unit during attack?
                if (currentAction == ActionState.SelectingTarget && selectedSkill != null)
                {
                    TryUseSkillOnTarget(unit);
                }
                return;
            }

            // Select this unit
            SelectUnit(unit);
        }

        /// <summary>
        /// Select a unit for action.
        /// </summary>
        private void SelectUnit(Unit unit)
        {
            if (selectedUnit == unit)
                return;

            // Deselect previous
            ClearSelection();

            // Select new unit
            selectedUnit = unit;
            activeUnit = unit;

            Debug.Log($"Selected: {unit.UnitName}");

            // Show movement range if unit can move
            if (unit.CanMove)
            {
                ShowMovementRange(unit);
                currentAction = ActionState.SelectingMovement;
            }
            else if (unit.CanAct)
            {
                // Can only act
                currentAction = ActionState.SelectingAction;
            }

            OnUnitTurnStart?.Invoke(unit);
        }

        /// <summary>
        /// Select first available player unit.
        /// </summary>
        private void SelectFirstAvailableUnit()
        {
            foreach (Unit unit in playerUnits)
            {
                if (unit.IsAlive && (unit.CanMove || unit.CanAct))
                {
                    SelectUnit(unit);
                    return;
                }
            }

            // No units can act, end player turn
            EndPlayerTurn();
        }

        /// <summary>
        /// Called when a tile is selected.
        /// </summary>
        public void OnTileSelected(GridTile tile)
        {
            if (currentPhase != BattlePhase.PlayerTurn || selectedUnit == null)
                return;

            switch (currentAction)
            {
                case ActionState.SelectingMovement:
                    TryMoveToTile(tile);
                    break;

                case ActionState.SelectingTarget:
                    TryUseSkillOnTile(tile);
                    break;
            }
        }

        /// <summary>
        /// Clear current selection.
        /// </summary>
        private void ClearSelection()
        {
            selectedUnit = null;
            selectedSkill = null;
            currentAction = ActionState.None;

            GridManager.Instance?.ClearHighlights();

            validMoveTiles.Clear();
            validAttackTiles.Clear();
        }

        #endregion

        #region Movement

        private void ShowMovementRange(Unit unit)
        {
            if (GridManager.Instance == null || unit.CurrentTile == null)
                return;

            UnitMovement movement = unit.GetComponent<UnitMovement>();
            if (movement != null)
            {
                movement.ShowMovementRange();
            }
        }

        private void TryMoveToTile(GridTile targetTile)
        {
            if (selectedUnit == null || targetTile == null)
                return;

            UnitMovement movement = selectedUnit.GetComponent<UnitMovement>();
            if (movement == null)
                return;

            // Check if can move to this tile
            if (movement.CanMoveTo(targetTile))
            {
                // Get path and move
                List<GridTile> path = movement.GetPathTo(targetTile);
                if (path != null && path.Count > 0)
                {
                    GridManager.Instance?.ClearHighlights();
                    GridManager.Instance?.HighlightPath(path);

                    movement.MoveAlongPath(path);
                    currentAction = ActionState.Moving;
                }
            }
        }

        /// <summary>
        /// Called when unit movement completes.
        /// </summary>
        public void OnUnitMovementComplete(Unit unit)
        {
            Debug.Log($"{unit.UnitName} movement complete");

            // Unit can now act
            if (unit.CanAct)
            {
                currentAction = ActionState.SelectingAction;
                // TODO: Show action menu
            }
            else
            {
                // Unit is done for this turn
                EndUnitTurn(unit);
            }
        }

        #endregion

        #region Combat & Skills

        /// <summary>
        /// Use a skill.
        /// </summary>
        public void UseSkill(SkillData skill)
        {
            if (selectedUnit == null || skill == null)
                return;

            if (!skill.CanUse(selectedUnit))
            {
                Debug.LogWarning($"{selectedUnit.UnitName} cannot use {skill.SkillName}");
                return;
            }

            selectedSkill = skill;
            currentAction = ActionState.SelectingTarget;

            // Show valid targets
            ShowSkillRange(skill);
        }

        private void ShowSkillRange(SkillData skill)
        {
            if (GridManager.Instance == null || selectedUnit.CurrentTile == null)
                return;

            validAttackTiles = Pathfinding.GetAttackRange(
                selectedUnit.CurrentTile,
                skill.MinRange,
                skill.MaxRange,
                GridManager.Instance
            );

            GridManager.Instance.ClearHighlights();
            GridManager.Instance.HighlightTiles(validAttackTiles, HighlightState.AttackRange);
        }

        private void TryUseSkillOnTile(GridTile targetTile)
        {
            if (targetTile.OccupyingUnit != null)
            {
                TryUseSkillOnTarget(targetTile.OccupyingUnit);
            }
        }

        private void TryUseSkillOnTarget(Unit target)
        {
            if (selectedUnit == null || selectedSkill == null || target == null)
                return;

            // Validate target
            if (!selectedSkill.IsValidTarget(selectedUnit, target))
            {
                Debug.LogWarning("Invalid target");
                return;
            }

            // Execute skill
            ExecuteSkill(selectedUnit, target, selectedSkill);

            // End unit's turn
            selectedUnit.HasActed = true;
            EndUnitTurn(selectedUnit);
        }

        /// <summary>
        /// Execute a skill from caster to target.
        /// </summary>
        private void ExecuteSkill(Unit caster, Unit target, SkillData skill)
        {
            Debug.Log($"{caster.UnitName} uses {skill.SkillName} on {target.UnitName}");

            // Consume costs
            caster.Stats.ConsumeMP(skill.MPCost);
            if (skill.HPCost > 0)
                caster.TakeDamage(skill.HPCost);

            // Calculate hit
            int hitChance = skill.CalculateHitChance(caster, target);
            bool hit = Random.Range(0, 100) < hitChance;

            if (!hit)
            {
                Debug.Log("Attack missed!");
                // TODO: Show miss effect
                return;
            }

            // Calculate damage
            int damage = skill.CalculateDamage(caster, target);

            // Check for critical
            bool isCrit = skill.RollCritical(caster);
            if (isCrit)
            {
                damage = skill.ApplyCritical(damage, caster);
                Debug.Log("Critical hit!");
            }

            // Apply damage or healing
            if (skill.Type == SkillType.Healing)
            {
                int healed = target.Heal(damage);
                Debug.Log($"{target.UnitName} healed for {healed} HP");
            }
            else
            {
                bool isMagical = skill.Type == SkillType.Magical;
                int damageDealt = target.TakeDamage(damage, isMagical, skill.CanCrit);
                Debug.Log($"{target.UnitName} took {damageDealt} damage");
            }

            // Apply status effects
            if (skill.StatusEffect != StatusEffectType.None)
            {
                if (Random.Range(0, 100) < skill.StatusChance)
                {
                    StatusEffect status = new StatusEffect
                    {
                        Type = skill.StatusEffect,
                        Duration = skill.StatusDuration,
                        Potency = skill.StatusPotency
                    };
                    target.ApplyStatusEffect(status);
                    Debug.Log($"{target.UnitName} is now {skill.StatusEffect}!");
                }
            }

            // TODO: Play VFX and sound effects
        }

        #endregion

        #region Unit Events

        /// <summary>
        /// Called when a unit is defeated.
        /// </summary>
        public void OnUnitDefeated(Unit unit)
        {
            Debug.Log($"{unit.UnitName} defeated!");

            // Check victory conditions
            CheckVictoryConditions();
        }

        /// <summary>
        /// Called when a unit levels up.
        /// </summary>
        public void OnUnitLevelUp(Unit unit)
        {
            Debug.Log($"{unit.UnitName} leveled up to {unit.Stats.Level}!");
            // TODO: Show level up UI
        }

        /// <summary>
        /// End a unit's turn.
        /// </summary>
        private void EndUnitTurn(Unit unit)
        {
            unit.EndTurn();
            OnUnitTurnEnd?.Invoke(unit);

            ClearSelection();

            // Check if any player units can still act
            bool anyCanAct = false;
            foreach (Unit u in playerUnits)
            {
                if (u.IsAlive && (u.CanMove || u.CanAct))
                {
                    anyCanAct = true;
                    break;
                }
            }

            if (anyCanAct)
            {
                // Select next unit
                SelectFirstAvailableUnit();
            }
            else
            {
                // All units done, end player turn
                EndPlayerTurn();
            }
        }

        #endregion

        #region Victory Conditions

        private void CheckVictoryConditions()
        {
            // Check if all enemies defeated
            bool allEnemiesDefeated = true;
            foreach (Unit unit in enemyUnits)
            {
                if (unit.IsAlive)
                {
                    allEnemiesDefeated = false;
                    break;
                }
            }

            if (allEnemiesDefeated)
            {
                EndBattle(true);
                return;
            }

            // Check if all players defeated
            bool allPlayersDefeated = true;
            foreach (Unit unit in playerUnits)
            {
                if (unit.IsAlive)
                {
                    allPlayersDefeated = false;
                    break;
                }
            }

            if (allPlayersDefeated)
            {
                EndBattle(false);
                return;
            }
        }

        #endregion
    }

    #region Enums

    public enum BattlePhase
    {
        Setup,
        BattleStart,
        PlayerTurn,
        EnemyTurn,
        Victory,
        Defeat
    }

    public enum ActionState
    {
        None,
        SelectingMovement,
        Moving,
        SelectingAction,
        SelectingTarget,
        ExecutingAction
    }

    #endregion
}
