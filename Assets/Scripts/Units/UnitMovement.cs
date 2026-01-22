using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using ADLegacy.Grid;

namespace ADLegacy.Units
{
    /// <summary>
    /// Handles unit movement animations and logic.
    /// Moves units along paths smoothly with visual feedback.
    /// </summary>
    public class UnitMovement : MonoBehaviour
    {
        [Header("Movement Settings")]
        [SerializeField] private float moveSpeed = 5f;
        [SerializeField] private float jumpHeight = 0.3f;
        [SerializeField] private float rotationSpeed = 10f;

        [Header("References")]
        [SerializeField] private Unit unit;
        [SerializeField] private Transform visualTransform;

        // Movement state
        private bool isMoving = false;
        private List<GridTile> currentPath;
        private Coroutine moveCoroutine;

        #region Properties

        public bool IsMoving => isMoving;

        #endregion

        #region Unity Lifecycle

        private void Awake()
        {
            if (unit == null)
                unit = GetComponent<Unit>();

            if (visualTransform == null)
                visualTransform = transform;
        }

        #endregion

        #region Movement Commands

        /// <summary>
        /// Move unit along a path.
        /// </summary>
        public void MoveAlongPath(List<GridTile> path)
        {
            if (path == null || path.Count == 0)
            {
                Debug.LogWarning("Cannot move: path is null or empty");
                return;
            }

            if (isMoving)
            {
                Debug.LogWarning("Unit is already moving");
                return;
            }

            currentPath = path;

            if (moveCoroutine != null)
                StopCoroutine(moveCoroutine);

            moveCoroutine = StartCoroutine(MoveCoroutine());
        }

        /// <summary>
        /// Instantly teleport unit to a tile.
        /// </summary>
        public void TeleportTo(GridTile tile)
        {
            if (tile == null) return;

            StopMovement();
            unit.CurrentTile = tile;
            transform.position = tile.WorldPosition + Vector3.up * 0.5f;
        }

        /// <summary>
        /// Stop current movement.
        /// </summary>
        public void StopMovement()
        {
            if (moveCoroutine != null)
            {
                StopCoroutine(moveCoroutine);
                moveCoroutine = null;
            }

            isMoving = false;
        }

        #endregion

        #region Movement Coroutine

        private IEnumerator MoveCoroutine()
        {
            isMoving = true;

            // Skip first tile (current position)
            for (int i = 1; i < currentPath.Count; i++)
            {
                GridTile targetTile = currentPath[i];
                Vector3 startPos = transform.position;
                Vector3 targetPos = targetTile.WorldPosition + Vector3.up * 0.5f;

                // Calculate height difference for jump
                float heightDiff = targetTile.Height - currentPath[i - 1].Height;
                float jumpArc = Mathf.Abs(heightDiff) * jumpHeight;

                // Face movement direction
                Vector3 direction = (targetPos - startPos).normalized;
                if (direction.magnitude > 0.1f)
                {
                    Quaternion targetRotation = Quaternion.LookRotation(direction);
                    visualTransform.rotation = Quaternion.Slerp(visualTransform.rotation, targetRotation, rotationSpeed * Time.deltaTime);
                }

                // Move to target
                float elapsed = 0f;
                float distance = Vector3.Distance(startPos, targetPos);
                float duration = distance / moveSpeed;

                while (elapsed < duration)
                {
                    elapsed += Time.deltaTime;
                    float t = elapsed / duration;

                    // Linear position
                    Vector3 pos = Vector3.Lerp(startPos, targetPos, t);

                    // Add jump arc
                    if (jumpArc > 0)
                    {
                        float arcProgress = Mathf.Sin(t * Mathf.PI);
                        pos.y += arcProgress * jumpArc;
                    }

                    transform.position = pos;

                    yield return null;
                }

                // Snap to final position
                transform.position = targetPos;

                // Update unit's current tile
                unit.CurrentTile = targetTile;

                // Play footstep sound/effect
                OnFootstep(targetTile);
            }

            // Movement complete
            isMoving = false;
            OnMovementComplete();
        }

        #endregion

        #region Events

        private void OnFootstep(GridTile tile)
        {
            // TODO: Play footstep sound based on terrain
            // TODO: Spawn dust/water splash VFX based on terrain
        }

        private void OnMovementComplete()
        {
            // Mark unit as having moved
            if (unit != null)
                unit.HasMoved = true;

            // Notify battle manager
            if (BattleManager.Instance != null)
                BattleManager.Instance.OnUnitMovementComplete(unit);

            Debug.Log($"{unit.UnitName} movement complete at {unit.CurrentTile.GridPosition}");
        }

        #endregion

        #region Animation Helpers

        /// <summary>
        /// Play a bump animation (for blocked movement).
        /// </summary>
        public IEnumerator BumpAnimation(Vector3 direction)
        {
            Vector3 startPos = transform.position;
            Vector3 bumpPos = startPos + direction * 0.2f;

            // Move forward
            float elapsed = 0f;
            while (elapsed < 0.1f)
            {
                elapsed += Time.deltaTime;
                transform.position = Vector3.Lerp(startPos, bumpPos, elapsed / 0.1f);
                yield return null;
            }

            // Move back
            elapsed = 0f;
            while (elapsed < 0.1f)
            {
                elapsed += Time.deltaTime;
                transform.position = Vector3.Lerp(bumpPos, startPos, elapsed / 0.1f);
                yield return null;
            }

            transform.position = startPos;
        }

        /// <summary>
        /// Play a knockback animation.
        /// </summary>
        public IEnumerator KnockbackAnimation(Vector3 direction, float distance, float duration)
        {
            Vector3 startPos = transform.position;
            Vector3 endPos = startPos + direction * distance;

            float elapsed = 0f;
            while (elapsed < duration)
            {
                elapsed += Time.deltaTime;
                float t = elapsed / duration;

                // Ease out curve
                t = 1f - Mathf.Pow(1f - t, 3f);

                transform.position = Vector3.Lerp(startPos, endPos, t);
                yield return null;
            }

            transform.position = endPos;
        }

        #endregion

        #region Preview & Validation

        /// <summary>
        /// Check if unit can move to target tile.
        /// </summary>
        public bool CanMoveTo(GridTile target)
        {
            if (target == null || unit == null)
                return false;

            if (!target.CanBeOccupiedBy(unit))
                return false;

            // Check if within movement range
            GridManager grid = GridManager.Instance;
            if (grid == null) return false;

            Dictionary<GridTile, float> reachableTiles = Pathfinding.GetMovementRange(
                unit.CurrentTile,
                unit.Stats.MoveRange,
                unit,
                grid
            );

            return reachableTiles.ContainsKey(target);
        }

        /// <summary>
        /// Get the path to a target tile.
        /// </summary>
        public List<GridTile> GetPathTo(GridTile target)
        {
            if (unit == null || unit.CurrentTile == null || target == null)
                return null;

            GridManager grid = GridManager.Instance;
            if (grid == null) return null;

            return Pathfinding.FindPath(unit.CurrentTile, target, unit, grid);
        }

        /// <summary>
        /// Show movement range preview.
        /// </summary>
        public void ShowMovementRange()
        {
            if (unit == null || unit.CurrentTile == null) return;

            GridManager grid = GridManager.Instance;
            if (grid == null) return;

            grid.HighlightMovementRange(unit.CurrentTile, unit.Stats.MoveRange, unit);
        }

        /// <summary>
        /// Hide movement range preview.
        /// </summary>
        public void HideMovementRange()
        {
            GridManager grid = GridManager.Instance;
            if (grid != null)
                grid.ClearHighlights();
        }

        #endregion
    }
}
