using System.Collections.Generic;
using UnityEngine;

namespace ADLegacy.Grid
{
    /// <summary>
    /// Manages the tactical battle grid, tile generation, and grid interactions.
    /// Singleton pattern for easy global access.
    /// </summary>
    public class GridManager : MonoBehaviour
    {
        public static GridManager Instance { get; private set; }

        [Header("Grid Settings")]
        [SerializeField] private int gridWidth = 12;
        [SerializeField] private int gridHeight = 12;
        [SerializeField] private float tileSize = 1f;
        [SerializeField] private Vector3 gridOrigin = Vector3.zero;

        [Header("Prefabs")]
        [SerializeField] private GameObject tilePrefab;
        [SerializeField] private Sprite grassSprite;
        [SerializeField] private Sprite stoneSprite;
        [SerializeField] private Sprite forestSprite;
        [SerializeField] private Sprite waterSprite;

        [Header("Generation Settings")]
        [SerializeField] private BattlefieldTemplate currentTemplate = BattlefieldTemplate.RandomBattlefield;
        [SerializeField] private bool generateOnStart = true;

        // Grid data
        private GridTile[,] grid;
        private Dictionary<Vector2Int, GridTile> tileMap = new Dictionary<Vector2Int, GridTile>();
        private List<GridTile> allTiles = new List<GridTile>();

        // Interaction state
        private GridTile hoveredTile;
        private GridTile selectedTile;
        private List<GridTile> highlightedTiles = new List<GridTile>();

        #region Properties

        public int Width => gridWidth;
        public int Height => gridHeight;
        public GridTile[,] Grid => grid;
        public List<GridTile> AllTiles => allTiles;
        public GridTile SelectedTile => selectedTile;
        public GridTile HoveredTile => hoveredTile;

        #endregion

        #region Unity Lifecycle

        private void Awake()
        {
            // Singleton pattern
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
        }

        private void Start()
        {
            if (generateOnStart)
            {
                GenerateGrid(currentTemplate);
            }
        }

        #endregion

        #region Grid Generation

        /// <summary>
        /// Generate the battle grid based on selected template.
        /// </summary>
        public void GenerateGrid(BattlefieldTemplate template)
        {
            ClearGrid();

            grid = new GridTile[gridWidth, gridHeight];
            tileMap.Clear();
            allTiles.Clear();

            // Create parent object for organization
            Transform gridParent = new GameObject("Grid").transform;
            gridParent.SetParent(transform);

            // Generate tiles
            for (int x = 0; x < gridWidth; x++)
            {
                for (int y = 0; y < gridHeight; y++)
                {
                    Vector3 worldPos = GetWorldPosition(x, y);
                    GridTile tile = CreateTile(x, y, worldPos, gridParent);

                    // Determine terrain based on template
                    TerrainType terrain = GetTerrainForTemplate(template, x, y);
                    tile.Initialize(new Vector2Int(x, y), terrain);

                    grid[x, y] = tile;
                    tileMap[new Vector2Int(x, y)] = tile;
                    allTiles.Add(tile);
                }
            }

            Debug.Log($"Generated {gridWidth}x{gridHeight} grid with {allTiles.Count} tiles using template: {template}");
        }

        private GridTile CreateTile(int x, int y, Vector3 position, Transform parent)
        {
            GameObject tileObj;

            if (tilePrefab != null)
            {
                tileObj = Instantiate(tilePrefab, position, Quaternion.identity, parent);
            }
            else
            {
                // Create basic tile if no prefab provided
                tileObj = GameObject.CreatePrimitive(PrimitiveType.Quad);
                tileObj.transform.position = position;
                tileObj.transform.rotation = Quaternion.Euler(90, 0, 0); // Flat on ground
                tileObj.transform.localScale = Vector3.one * tileSize * 0.95f; // Small gap between tiles
                tileObj.transform.SetParent(parent);

                // Add sprite renderer
                SpriteRenderer sr = tileObj.GetComponent<SpriteRenderer>();
                if (sr == null)
                {
                    Destroy(tileObj.GetComponent<MeshRenderer>());
                    Destroy(tileObj.GetComponent<MeshFilter>());
                    sr = tileObj.AddComponent<SpriteRenderer>();
                }
            }

            tileObj.name = $"Tile_{x}_{y}";
            GridTile tile = tileObj.GetComponent<GridTile>();

            if (tile == null)
                tile = tileObj.AddComponent<GridTile>();

            // Add collider for mouse interaction
            BoxCollider collider = tileObj.GetComponent<BoxCollider>();
            if (collider == null)
                collider = tileObj.AddComponent<BoxCollider>();

            return tile;
        }

        private Vector3 GetWorldPosition(int x, int y)
        {
            // For isometric feel, offset Y based on grid position
            float worldX = gridOrigin.x + (x * tileSize);
            float worldY = gridOrigin.y;
            float worldZ = gridOrigin.z + (y * tileSize);

            return new Vector3(worldX, worldY, worldZ);
        }

        private void ClearGrid()
        {
            if (grid != null)
            {
                for (int x = 0; x < gridWidth; x++)
                {
                    for (int y = 0; y < gridHeight; y++)
                    {
                        if (grid[x, y] != null)
                            Destroy(grid[x, y].gameObject);
                    }
                }
            }

            // Also clear organizational parent
            Transform gridParent = transform.Find("Grid");
            if (gridParent != null)
                Destroy(gridParent.gameObject);

            highlightedTiles.Clear();
            selectedTile = null;
            hoveredTile = null;
        }

        #endregion

        #region Terrain Generation Templates

        private TerrainType GetTerrainForTemplate(BattlefieldTemplate template, int x, int y)
        {
            // Use seed based on position for consistent randomness
            System.Random random = new System.Random((x * gridHeight + y) * 1000);

            switch (template)
            {
                case BattlefieldTemplate.RandomBattlefield:
                    return GetRandomBattlefieldTerrain(x, y, random);

                case BattlefieldTemplate.DenseForest:
                    return GetDenseForestTerrain(x, y, random);

                case BattlefieldTemplate.VolcanicWasteland:
                    return GetVolcanicWastelandTerrain(x, y, random);

                case BattlefieldTemplate.Lakeside:
                    return GetLakesideTerrain(x, y, random);

                case BattlefieldTemplate.OpenPlains:
                    return GetOpenPlainsTerrain(x, y, random);

                case BattlefieldTemplate.AncientRuins:
                    return GetAncientRuinsTerrain(x, y, random);

                default:
                    return TerrainType.Grass;
            }
        }

        private TerrainType GetRandomBattlefieldTerrain(int x, int y, System.Random random)
        {
            float roll = (float)random.NextDouble();

            if (roll < 0.6f) return TerrainType.Grass;
            if (roll < 0.75f) return TerrainType.Forest;
            if (roll < 0.85f) return TerrainType.Stone;
            if (roll < 0.95f) return TerrainType.Water;
            return TerrainType.Mountain;
        }

        private TerrainType GetDenseForestTerrain(int x, int y, System.Random random)
        {
            float roll = (float)random.NextDouble();

            if (roll < 0.7f) return TerrainType.Forest;
            if (roll < 0.85f) return TerrainType.Grass;
            if (roll < 0.95f) return TerrainType.Water;
            return TerrainType.Stone;
        }

        private TerrainType GetVolcanicWastelandTerrain(int x, int y, System.Random random)
        {
            float roll = (float)random.NextDouble();

            if (roll < 0.4f) return TerrainType.Stone;
            if (roll < 0.6f) return TerrainType.Grass;
            if (roll < 0.75f) return TerrainType.Lava;
            if (roll < 0.9f) return TerrainType.Fire;
            return TerrainType.Mountain;
        }

        private TerrainType GetLakesideTerrain(int x, int y, System.Random random)
        {
            // Create a lake in the center
            int centerX = gridWidth / 2;
            int centerY = gridHeight / 2;
            float distanceFromCenter = Vector2.Distance(new Vector2(x, y), new Vector2(centerX, centerY));

            if (distanceFromCenter < 3)
                return TerrainType.DeepWater;

            if (distanceFromCenter < 4.5f)
                return TerrainType.Water;

            float roll = (float)random.NextDouble();
            if (roll < 0.7f) return TerrainType.Grass;
            if (roll < 0.85f) return TerrainType.Stone;
            return TerrainType.Forest;
        }

        private TerrainType GetOpenPlainsTerrain(int x, int y, System.Random random)
        {
            float roll = (float)random.NextDouble();

            if (roll < 0.85f) return TerrainType.Grass;
            if (roll < 0.95f) return TerrainType.Stone;
            return TerrainType.Forest;
        }

        private TerrainType GetAncientRuinsTerrain(int x, int y, System.Random random)
        {
            float roll = (float)random.NextDouble();

            if (roll < 0.5f) return TerrainType.Stone;
            if (roll < 0.75f) return TerrainType.Grass;
            if (roll < 0.85f) return TerrainType.Fire;
            return TerrainType.Mountain;
        }

        #endregion

        #region Tile Access

        /// <summary>
        /// Get tile at grid coordinates.
        /// </summary>
        public GridTile GetTileAt(int x, int y)
        {
            if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight)
                return null;

            return grid[x, y];
        }

        /// <summary>
        /// Get tile at Vector2Int position.
        /// </summary>
        public GridTile GetTileAt(Vector2Int position)
        {
            return GetTileAt(position.x, position.y);
        }

        /// <summary>
        /// Get tile at world position (raycast from mouse).
        /// </summary>
        public GridTile GetTileAtWorldPosition(Vector3 worldPos)
        {
            Ray ray = Camera.main.ScreenPointToRay(worldPos);
            if (Physics.Raycast(ray, out RaycastHit hit))
            {
                return hit.collider.GetComponent<GridTile>();
            }
            return null;
        }

        /// <summary>
        /// Get neighboring tiles (4-directional: up, down, left, right).
        /// </summary>
        public List<GridTile> GetNeighbors(GridTile tile)
        {
            List<GridTile> neighbors = new List<GridTile>();

            Vector2Int pos = tile.GridPosition;

            // Four cardinal directions
            AddNeighborIfValid(pos.x + 1, pos.y, neighbors); // Right
            AddNeighborIfValid(pos.x - 1, pos.y, neighbors); // Left
            AddNeighborIfValid(pos.x, pos.y + 1, neighbors); // Up
            AddNeighborIfValid(pos.x, pos.y - 1, neighbors); // Down

            return neighbors;
        }

        /// <summary>
        /// Get all neighbors including diagonals (8-directional).
        /// </summary>
        public List<GridTile> GetNeighbors8(GridTile tile)
        {
            List<GridTile> neighbors = new List<GridTile>();
            Vector2Int pos = tile.GridPosition;

            for (int x = -1; x <= 1; x++)
            {
                for (int y = -1; y <= 1; y++)
                {
                    if (x == 0 && y == 0) continue; // Skip center
                    AddNeighborIfValid(pos.x + x, pos.y + y, neighbors);
                }
            }

            return neighbors;
        }

        private void AddNeighborIfValid(int x, int y, List<GridTile> list)
        {
            GridTile tile = GetTileAt(x, y);
            if (tile != null)
                list.Add(tile);
        }

        #endregion

        #region Highlighting & Selection

        public void ClearHighlights()
        {
            foreach (GridTile tile in highlightedTiles)
            {
                tile.ClearHighlight();
            }
            highlightedTiles.Clear();
        }

        public void HighlightTiles(List<GridTile> tiles, HighlightState state)
        {
            foreach (GridTile tile in tiles)
            {
                tile.SetHighlight(state);
                if (!highlightedTiles.Contains(tile))
                    highlightedTiles.Add(tile);
            }
        }

        public void HighlightMovementRange(GridTile centerTile, float movementRange, Unit unit)
        {
            ClearHighlights();

            Dictionary<GridTile, float> reachableTiles = Pathfinding.GetMovementRange(centerTile, movementRange, unit, this);
            HighlightTiles(new List<GridTile>(reachableTiles.Keys), HighlightState.MoveRange);
        }

        public void HighlightAttackRange(GridTile centerTile, int minRange, int maxRange)
        {
            ClearHighlights();

            List<GridTile> attackTiles = Pathfinding.GetAttackRange(centerTile, minRange, maxRange, this);
            HighlightTiles(attackTiles, HighlightState.AttackRange);
        }

        public void HighlightPath(List<GridTile> path)
        {
            foreach (GridTile tile in path)
            {
                tile.SetHighlight(HighlightState.Path);
            }
        }

        #endregion

        #region Mouse Interaction Callbacks

        public void OnTileHoverEnter(GridTile tile)
        {
            hoveredTile = tile;

            // Show hover highlight if not already highlighted
            if (tile.GetComponent<SpriteRenderer>() != null)
            {
                // Additional hover feedback can be added here
            }
        }

        public void OnTileHoverExit(GridTile tile)
        {
            if (hoveredTile == tile)
                hoveredTile = null;
        }

        public void OnTileClicked(GridTile tile)
        {
            selectedTile = tile;

            // Notify game/battle manager of tile selection
            if (GameManager.Instance != null)
                GameManager.Instance.OnGridTileSelected(tile);

            Debug.Log($"Tile clicked: {tile.GridPosition} | Terrain: {tile.Terrain} | Walkable: {tile.IsWalkable}");
        }

        #endregion

        #region Debug

        private void OnDrawGizmos()
        {
            if (!Application.isPlaying || grid == null)
                return;

            // Draw grid bounds
            Gizmos.color = Color.yellow;
            Vector3 size = new Vector3(gridWidth * tileSize, 0.1f, gridHeight * tileSize);
            Vector3 center = gridOrigin + size / 2f;
            Gizmos.DrawWireCube(center, size);
        }

        #endregion
    }

    #region Enums

    public enum BattlefieldTemplate
    {
        RandomBattlefield,
        DenseForest,
        VolcanicWasteland,
        Lakeside,
        OpenPlains,
        AncientRuins
    }

    #endregion
}
