using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using ADLegacy.Units;

namespace ADLegacy
{
    /// <summary>
    /// Manages turn order and initiative for tactical combat.
    /// Handles speed-based turn ordering similar to FFTA.
    /// </summary>
    public class TurnManager : MonoBehaviour
    {
        public static TurnManager Instance { get; private set; }

        [Header("Turn Settings")]
        [SerializeField] private TurnOrderMode turnMode = TurnOrderMode.SpeedBased;
        [SerializeField] private bool showTurnOrder = true;

        [Header("Turn Queue")]
        [SerializeField] private List<Unit> turnQueue = new List<Unit>();
        [SerializeField] private int currentTurnIndex = 0;

        [Header("Debug")]
        [SerializeField] private bool debugMode = false;

        // Turn tracking
        private int globalTurnNumber = 0;
        private Dictionary<Unit, int> unitTurnCounts = new Dictionary<Unit, int>();

        // Events
        public event System.Action<Unit> OnUnitTurnStart;
        public event System.Action<Unit> OnUnitTurnEnd;
        public event System.Action OnRoundComplete;

        #region Properties

        public List<Unit> TurnQueue => turnQueue;
        public Unit CurrentUnit => currentTurnIndex < turnQueue.Count ? turnQueue[currentTurnIndex] : null;
        public int GlobalTurnNumber => globalTurnNumber;

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

        #endregion

        #region Turn Order Initialization

        /// <summary>
        /// Initialize turn order with all battle units.
        /// </summary>
        public void InitializeTurnOrder(List<Unit> allUnits)
        {
            turnQueue.Clear();
            unitTurnCounts.Clear();
            currentTurnIndex = 0;
            globalTurnNumber = 0;

            // Add all living units
            foreach (Unit unit in allUnits)
            {
                if (unit.IsAlive)
                {
                    turnQueue.Add(unit);
                    unitTurnCounts[unit] = 0;
                }
            }

            // Sort based on turn mode
            SortTurnOrder();

            if (debugMode)
                PrintTurnOrder();

            Debug.Log($"Turn order initialized with {turnQueue.Count} units");
        }

        /// <summary>
        /// Sort turn order based on turn mode.
        /// </summary>
        private void SortTurnOrder()
        {
            switch (turnMode)
            {
                case TurnOrderMode.SpeedBased:
                    // Sort by speed (highest first), then by random tiebreaker
                    turnQueue = turnQueue.OrderByDescending(u => u.Stats.Speed)
                                        .ThenBy(u => Random.value)
                                        .ToList();
                    break;

                case TurnOrderMode.TeamBased:
                    // All player units, then all enemy units
                    turnQueue = turnQueue.OrderBy(u => u.Team == UnitTeam.Player ? 0 : 1)
                                        .ThenByDescending(u => u.Stats.Speed)
                                        .ToList();
                    break;

                case TurnOrderMode.Random:
                    // Completely random
                    turnQueue = turnQueue.OrderBy(u => Random.value).ToList();
                    break;
            }
        }

        #endregion

        #region Turn Progression

        /// <summary>
        /// Start the next unit's turn.
        /// </summary>
        public Unit StartNextTurn()
        {
            // Skip dead units
            while (currentTurnIndex < turnQueue.Count && !turnQueue[currentTurnIndex].IsAlive)
            {
                currentTurnIndex++;
            }

            // Check if round is complete
            if (currentTurnIndex >= turnQueue.Count)
            {
                OnRoundComplete?.Invoke();
                StartNewRound();
            }

            Unit currentUnit = CurrentUnit;
            if (currentUnit == null)
            {
                Debug.LogWarning("No valid unit for turn");
                return null;
            }

            // Start this unit's turn
            globalTurnNumber++;
            unitTurnCounts[currentUnit]++;

            currentUnit.StartTurn();
            OnUnitTurnStart?.Invoke(currentUnit);

            if (debugMode)
                Debug.Log($"Turn {globalTurnNumber}: {currentUnit.UnitName}'s turn (Speed: {currentUnit.Stats.Speed})");

            return currentUnit;
        }

        /// <summary>
        /// End the current unit's turn.
        /// </summary>
        public void EndCurrentTurn()
        {
            Unit currentUnit = CurrentUnit;
            if (currentUnit != null)
            {
                currentUnit.EndTurn();
                OnUnitTurnEnd?.Invoke(currentUnit);

                if (debugMode)
                    Debug.Log($"{currentUnit.UnitName}'s turn ended");
            }

            // Move to next unit
            currentTurnIndex++;
        }

        /// <summary>
        /// Start a new round.
        /// </summary>
        private void StartNewRound()
        {
            currentTurnIndex = 0;

            // Remove dead units from queue
            turnQueue.RemoveAll(u => !u.IsAlive);

            // Re-sort for speed-based mode
            if (turnMode == TurnOrderMode.SpeedBased)
            {
                SortTurnOrder();
            }

            Debug.Log($"New round started with {turnQueue.Count} units");
        }

        #endregion

        #region Turn Order Management

        /// <summary>
        /// Add a unit to the turn order (e.g., summoned unit).
        /// </summary>
        public void AddUnitToTurnOrder(Unit unit)
        {
            if (unit == null || !unit.IsAlive)
                return;

            if (turnQueue.Contains(unit))
                return;

            turnQueue.Add(unit);
            unitTurnCounts[unit] = 0;

            // Re-sort if needed
            SortTurnOrder();

            Debug.Log($"Added {unit.UnitName} to turn order");
        }

        /// <summary>
        /// Remove a unit from turn order (e.g., defeated unit).
        /// </summary>
        public void RemoveUnitFromTurnOrder(Unit unit)
        {
            int index = turnQueue.IndexOf(unit);

            turnQueue.Remove(unit);
            unitTurnCounts.Remove(unit);

            // Adjust current index if needed
            if (index < currentTurnIndex)
                currentTurnIndex--;

            Debug.Log($"Removed {unit.UnitName} from turn order");
        }

        /// <summary>
        /// Force a unit to take another turn immediately (haste, etc.).
        /// </summary>
        public void GrantExtraTurn(Unit unit)
        {
            if (unit == null || !turnQueue.Contains(unit))
                return;

            // Insert after current unit
            int insertIndex = currentTurnIndex + 1;
            turnQueue.Insert(insertIndex, unit);

            Debug.Log($"{unit.UnitName} granted an extra turn!");
        }

        /// <summary>
        /// Skip a unit's turn (sleep, stun, etc.).
        /// </summary>
        public void SkipUnitTurn(Unit unit)
        {
            if (CurrentUnit == unit)
            {
                Debug.Log($"{unit.UnitName}'s turn skipped");
                EndCurrentTurn();
            }
        }

        #endregion

        #region Turn Order Preview

        /// <summary>
        /// Get the next N units in turn order.
        /// </summary>
        public List<Unit> GetUpcomingTurns(int count)
        {
            List<Unit> upcoming = new List<Unit>();

            for (int i = currentTurnIndex; i < turnQueue.Count && upcoming.Count < count; i++)
            {
                if (turnQueue[i].IsAlive)
                    upcoming.Add(turnQueue[i]);
            }

            return upcoming;
        }

        /// <summary>
        /// Get how many turns until a specific unit's turn.
        /// </summary>
        public int GetTurnsUntilUnit(Unit unit)
        {
            int turnsUntil = 0;

            for (int i = currentTurnIndex; i < turnQueue.Count; i++)
            {
                if (turnQueue[i] == unit)
                    return turnsUntil;

                if (turnQueue[i].IsAlive)
                    turnsUntil++;
            }

            return -1; // Unit not found or already acted
        }

        #endregion

        #region Speed Manipulation

        /// <summary>
        /// Recalculate turn order when a unit's speed changes.
        /// </summary>
        public void RecalculateTurnOrder()
        {
            SortTurnOrder();

            if (debugMode)
                Debug.Log("Turn order recalculated due to speed change");
        }

        #endregion

        #region Query Methods

        /// <summary>
        /// Check if it's a specific team's turn.
        /// </summary>
        public bool IsTeamTurn(UnitTeam team)
        {
            Unit currentUnit = CurrentUnit;
            return currentUnit != null && currentUnit.Team == team;
        }

        /// <summary>
        /// Get how many times a unit has acted.
        /// </summary>
        public int GetUnitTurnCount(Unit unit)
        {
            return unitTurnCounts.ContainsKey(unit) ? unitTurnCounts[unit] : 0;
        }

        /// <summary>
        /// Get all units that have acted this round.
        /// </summary>
        public List<Unit> GetUnitsWhoActed()
        {
            List<Unit> actedUnits = new List<Unit>();

            for (int i = 0; i < currentTurnIndex && i < turnQueue.Count; i++)
            {
                actedUnits.Add(turnQueue[i]);
            }

            return actedUnits;
        }

        /// <summary>
        /// Get all units yet to act this round.
        /// </summary>
        public List<Unit> GetUnitsYetToAct()
        {
            List<Unit> remainingUnits = new List<Unit>();

            for (int i = currentTurnIndex; i < turnQueue.Count; i++)
            {
                if (turnQueue[i].IsAlive)
                    remainingUnits.Add(turnQueue[i]);
            }

            return remainingUnits;
        }

        #endregion

        #region Debug

        private void PrintTurnOrder()
        {
            Debug.Log("=== Current Turn Order ===");
            for (int i = 0; i < turnQueue.Count; i++)
            {
                Unit unit = turnQueue[i];
                string marker = i == currentTurnIndex ? ">>>" : "   ";
                Debug.Log($"{marker} {i + 1}. {unit.UnitName} (SPD: {unit.Stats.Speed}, Team: {unit.Team})");
            }
        }

        #endregion
    }

    #region Enums

    public enum TurnOrderMode
    {
        SpeedBased,     // Units act based on speed stat (FFTA style)
        TeamBased,      // All player units, then all enemy units
        Random          // Randomized turn order
    }

    #endregion
}
