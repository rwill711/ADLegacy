using UnityEngine;

namespace ADLegacy.Grid
{
    /// <summary>
    /// Represents a single tile in the tactical grid.
    /// Handles tile data, visuals, and interactions.
    /// </summary>
    public class GridTile : MonoBehaviour
    {
        [Header("Tile Properties")]
        [SerializeField] private Vector2Int gridPosition;
        [SerializeField] private int height = 0; // Elevation for height-based gameplay
        [SerializeField] private TerrainType terrainType = TerrainType.Grass;
        [SerializeField] private bool isWalkable = true;

        [Header("Visuals")]
        [SerializeField] private SpriteRenderer spriteRenderer;
        [SerializeField] private SpriteRenderer highlightRenderer;
        [SerializeField] private Color normalColor = Color.white;
        [SerializeField] private Color hoverColor = new Color(1f, 1f, 0.5f, 1f);
        [SerializeField] private Color moveRangeColor = new Color(0.5f, 0.5f, 1f, 0.6f);
        [SerializeField] private Color attackRangeColor = new Color(1f, 0.5f, 0.5f, 0.6f);
        [SerializeField] private Color pathColor = new Color(0.3f, 1f, 0.3f, 0.8f);

        [Header("Occupancy")]
        [SerializeField] private Unit occupyingUnit;
        [SerializeField] private GameObject occupyingObject; // For obstacles, chests, etc.

        // Movement cost based on terrain
        private float movementCost = 1f;
        private bool isDangerous = false; // For lava, fire, etc.
        private int damagePerTurn = 0;

        // Tile state
        private HighlightState currentHighlightState = HighlightState.None;

        #region Properties

        public Vector2Int GridPosition
        {
            get => gridPosition;
            set => gridPosition = value;
        }

        public int Height
        {
            get => height;
            set => height = value;
        }

        public TerrainType Terrain
        {
            get => terrainType;
            set => SetTerrainType(value);
        }

        public bool IsWalkable => isWalkable && occupyingUnit == null && occupyingObject == null;

        public float MovementCost => movementCost;

        public bool IsDangerous => isDangerous;

        public int DamagePerTurn => damagePerTurn;

        public Unit OccupyingUnit
        {
            get => occupyingUnit;
            set => occupyingUnit = value;
        }

        public GameObject OccupyingObject
        {
            get => occupyingObject;
            set => occupyingObject = value;
        }

        public Vector3 WorldPosition => transform.position;

        #endregion

        #region Unity Lifecycle

        private void Awake()
        {
            if (spriteRenderer == null)
                spriteRenderer = GetComponent<SpriteRenderer>();

            // Create highlight renderer if it doesn't exist
            if (highlightRenderer == null)
            {
                GameObject highlightObj = new GameObject("Highlight");
                highlightObj.transform.SetParent(transform);
                highlightObj.transform.localPosition = Vector3.up * 0.01f; // Slightly above tile
                highlightRenderer = highlightObj.AddComponent<SpriteRenderer>();
                highlightRenderer.sortingOrder = spriteRenderer.sortingOrder + 1;
                highlightRenderer.enabled = false;
            }
        }

        private void OnMouseEnter()
        {
            if (GridManager.Instance != null)
                GridManager.Instance.OnTileHoverEnter(this);
        }

        private void OnMouseExit()
        {
            if (GridManager.Instance != null)
                GridManager.Instance.OnTileHoverExit(this);
        }

        private void OnMouseDown()
        {
            if (GridManager.Instance != null)
                GridManager.Instance.OnTileClicked(this);
        }

        #endregion

        #region Initialization

        public void Initialize(Vector2Int position, TerrainType terrain, int elevation = 0)
        {
            gridPosition = position;
            height = elevation;
            SetTerrainType(terrain);

            // Set sorting order based on position (for proper layering)
            if (spriteRenderer != null)
            {
                spriteRenderer.sortingLayerName = "Terrain";
                spriteRenderer.sortingOrder = -(position.y * 100 + position.x);
            }
        }

        #endregion

        #region Terrain Management

        public void SetTerrainType(TerrainType type)
        {
            terrainType = type;

            switch (type)
            {
                case TerrainType.Grass:
                    movementCost = 1f;
                    isWalkable = true;
                    isDangerous = false;
                    break;

                case TerrainType.Stone:
                    movementCost = 1f;
                    isWalkable = true;
                    isDangerous = false;
                    break;

                case TerrainType.Forest:
                    movementCost = 1.5f;
                    isWalkable = true;
                    isDangerous = false;
                    break;

                case TerrainType.Mountain:
                    movementCost = 2f;
                    isWalkable = true;
                    isDangerous = false;
                    break;

                case TerrainType.Water:
                    movementCost = 1f;
                    isWalkable = false; // Most units can't walk on water
                    isDangerous = false;
                    break;

                case TerrainType.DeepWater:
                    movementCost = 1f;
                    isWalkable = false;
                    isDangerous = false;
                    break;

                case TerrainType.Lava:
                    movementCost = 1f;
                    isWalkable = true;
                    isDangerous = true;
                    damagePerTurn = 10;
                    break;

                case TerrainType.Fire:
                    movementCost = 1f;
                    isWalkable = true;
                    isDangerous = true;
                    damagePerTurn = 5;
                    break;

                case TerrainType.Void:
                    movementCost = 1f;
                    isWalkable = false;
                    isDangerous = false;
                    break;
            }

            UpdateVisuals();
        }

        private void UpdateVisuals()
        {
            if (spriteRenderer == null) return;

            // Set color based on terrain (placeholder until you add actual sprites)
            Color terrainColor = GetTerrainColor();
            spriteRenderer.color = terrainColor;
        }

        private Color GetTerrainColor()
        {
            switch (terrainType)
            {
                case TerrainType.Grass: return new Color(0.4f, 0.8f, 0.4f);
                case TerrainType.Stone: return new Color(0.6f, 0.6f, 0.6f);
                case TerrainType.Forest: return new Color(0.2f, 0.5f, 0.2f);
                case TerrainType.Mountain: return new Color(0.5f, 0.4f, 0.3f);
                case TerrainType.Water: return new Color(0.3f, 0.5f, 0.8f);
                case TerrainType.DeepWater: return new Color(0.2f, 0.3f, 0.6f);
                case TerrainType.Lava: return new Color(1f, 0.3f, 0f);
                case TerrainType.Fire: return new Color(1f, 0.5f, 0f);
                case TerrainType.Void: return Color.black;
                default: return Color.white;
            }
        }

        #endregion

        #region Highlight Management

        public void SetHighlight(HighlightState state)
        {
            currentHighlightState = state;

            if (highlightRenderer == null) return;

            switch (state)
            {
                case HighlightState.None:
                    highlightRenderer.enabled = false;
                    break;

                case HighlightState.Hover:
                    highlightRenderer.enabled = true;
                    highlightRenderer.color = hoverColor;
                    break;

                case HighlightState.MoveRange:
                    highlightRenderer.enabled = true;
                    highlightRenderer.color = moveRangeColor;
                    break;

                case HighlightState.AttackRange:
                    highlightRenderer.enabled = true;
                    highlightRenderer.color = attackRangeColor;
                    break;

                case HighlightState.Path:
                    highlightRenderer.enabled = true;
                    highlightRenderer.color = pathColor;
                    break;
            }
        }

        public void ClearHighlight()
        {
            SetHighlight(HighlightState.None);
        }

        #endregion

        #region Utility

        public float GetDistanceTo(GridTile other)
        {
            return Vector2Int.Distance(gridPosition, other.gridPosition);
        }

        public int GetManhattanDistanceTo(GridTile other)
        {
            return Mathf.Abs(gridPosition.x - other.gridPosition.x) +
                   Mathf.Abs(gridPosition.y - other.gridPosition.y);
        }

        public bool IsAdjacentTo(GridTile other)
        {
            return GetManhattanDistanceTo(other) == 1;
        }

        public bool CanBeOccupiedBy(Unit unit)
        {
            if (!isWalkable) return false;
            if (occupyingUnit != null && occupyingUnit != unit) return false;
            if (occupyingObject != null) return false;

            // Add special cases (e.g., flying units can cross water)
            // This will be expanded when we implement unit abilities

            return true;
        }

        #endregion

        #region Debug

        private void OnDrawGizmos()
        {
            // Draw height indicator in editor
            if (height > 0)
            {
                Gizmos.color = Color.cyan;
                Vector3 heightPos = transform.position + Vector3.up * (height * 0.5f);
                Gizmos.DrawWireCube(heightPos, Vector3.one * 0.1f);
            }

            // Draw walkability indicator
            if (!isWalkable)
            {
                Gizmos.color = Color.red;
                Gizmos.DrawWireCube(transform.position, Vector3.one * 0.5f);
            }
        }

        #endregion
    }

    #region Enums

    public enum TerrainType
    {
        Grass,
        Stone,
        Forest,
        Mountain,
        Water,
        DeepWater,
        Lava,
        Fire,
        Void
    }

    public enum HighlightState
    {
        None,
        Hover,
        MoveRange,
        AttackRange,
        Path
    }

    #endregion
}
