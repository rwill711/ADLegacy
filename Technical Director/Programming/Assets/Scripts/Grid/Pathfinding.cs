using System.Collections.Generic;
using UnityEngine;

namespace ADLegacy.Grid
{
    /// <summary>
    /// Handles pathfinding calculations for unit movement.
    /// Uses A* algorithm with terrain cost considerations.
    /// </summary>
    public static class Pathfinding
    {
        #region Path Finding (A* Algorithm)

        /// <summary>
        /// Find the shortest path between two tiles considering movement cost and obstacles.
        /// </summary>
        public static List<GridTile> FindPath(GridTile start, GridTile goal, Unit unit, GridManager grid)
        {
            if (start == null || goal == null || grid == null)
                return null;

            // Early exit if goal is unwalkable
            if (!goal.CanBeOccupiedBy(unit))
                return null;

            HashSet<GridTile> closedSet = new HashSet<GridTile>();
            List<PathNode> openSet = new List<PathNode>();
            Dictionary<GridTile, PathNode> allNodes = new Dictionary<GridTile, PathNode>();

            // Create start node
            PathNode startNode = new PathNode
            {
                tile = start,
                gCost = 0,
                hCost = GetHeuristic(start, goal),
                parent = null
            };

            openSet.Add(startNode);
            allNodes[start] = startNode;

            while (openSet.Count > 0)
            {
                // Get node with lowest fCost
                PathNode currentNode = GetLowestFCostNode(openSet);

                // Reached goal
                if (currentNode.tile == goal)
                    return ReconstructPath(currentNode);

                openSet.Remove(currentNode);
                closedSet.Add(currentNode.tile);

                // Check all neighbors
                List<GridTile> neighbors = grid.GetNeighbors(currentNode.tile);
                foreach (GridTile neighbor in neighbors)
                {
                    // Skip if already evaluated
                    if (closedSet.Contains(neighbor))
                        continue;

                    // Skip if unwalkable (unless it's the goal)
                    if (!neighbor.CanBeOccupiedBy(unit) && neighbor != goal)
                        continue;

                    // Calculate tentative gCost
                    float tentativeGCost = currentNode.gCost + neighbor.MovementCost;

                    // Add height penalty if moving uphill
                    int heightDiff = neighbor.Height - currentNode.tile.Height;
                    if (heightDiff > 0)
                        tentativeGCost += heightDiff * 0.5f;

                    // Check if this path to neighbor is better
                    if (!allNodes.ContainsKey(neighbor))
                    {
                        // First time reaching this neighbor
                        PathNode neighborNode = new PathNode
                        {
                            tile = neighbor,
                            gCost = tentativeGCost,
                            hCost = GetHeuristic(neighbor, goal),
                            parent = currentNode
                        };

                        allNodes[neighbor] = neighborNode;
                        openSet.Add(neighborNode);
                    }
                    else if (tentativeGCost < allNodes[neighbor].gCost)
                    {
                        // Found a better path to this neighbor
                        PathNode neighborNode = allNodes[neighbor];
                        neighborNode.gCost = tentativeGCost;
                        neighborNode.parent = currentNode;

                        if (!openSet.Contains(neighborNode))
                            openSet.Add(neighborNode);
                    }
                }
            }

            // No path found
            return null;
        }

        #endregion

        #region Movement Range Calculation

        /// <summary>
        /// Calculate all tiles within movement range using Dijkstra's algorithm.
        /// Returns dictionary of tile -> movement cost.
        /// </summary>
        public static Dictionary<GridTile, float> GetMovementRange(GridTile start, float maxMovement, Unit unit, GridManager grid)
        {
            Dictionary<GridTile, float> reachableTiles = new Dictionary<GridTile, float>();
            HashSet<GridTile> visited = new HashSet<GridTile>();
            List<PathNode> frontier = new List<PathNode>();

            PathNode startNode = new PathNode
            {
                tile = start,
                gCost = 0,
                hCost = 0,
                parent = null
            };

            frontier.Add(startNode);
            reachableTiles[start] = 0;

            while (frontier.Count > 0)
            {
                // Get node with lowest cost
                PathNode current = GetLowestGCostNode(frontier);
                frontier.Remove(current);

                if (visited.Contains(current.tile))
                    continue;

                visited.Add(current.tile);

                // Check neighbors
                List<GridTile> neighbors = grid.GetNeighbors(current.tile);
                foreach (GridTile neighbor in neighbors)
                {
                    if (visited.Contains(neighbor))
                        continue;

                    // Calculate movement cost to this tile
                    float movementCost = current.gCost + neighbor.MovementCost;

                    // Add height penalty
                    int heightDiff = neighbor.Height - current.tile.Height;
                    if (heightDiff > 0)
                        movementCost += heightDiff * 0.5f;

                    // Check if within range
                    if (movementCost <= maxMovement)
                    {
                        // Check if tile can be occupied
                        if (neighbor.CanBeOccupiedBy(unit) || neighbor == start)
                        {
                            // Update if this is a better path or first time reaching
                            if (!reachableTiles.ContainsKey(neighbor) || movementCost < reachableTiles[neighbor])
                            {
                                reachableTiles[neighbor] = movementCost;

                                PathNode neighborNode = new PathNode
                                {
                                    tile = neighbor,
                                    gCost = movementCost,
                                    hCost = 0,
                                    parent = current
                                };

                                frontier.Add(neighborNode);
                            }
                        }
                    }
                }
            }

            return reachableTiles;
        }

        #endregion

        #region Attack Range Calculation

        /// <summary>
        /// Get all tiles within attack range from a position.
        /// Uses simple distance check (no pathfinding needed for attacks).
        /// </summary>
        public static List<GridTile> GetAttackRange(GridTile center, int minRange, int maxRange, GridManager grid)
        {
            List<GridTile> tilesInRange = new List<GridTile>();

            if (center == null || grid == null)
                return tilesInRange;

            // Check all tiles in grid
            foreach (GridTile tile in grid.AllTiles)
            {
                int distance = center.GetManhattanDistanceTo(tile);
                if (distance >= minRange && distance <= maxRange)
                {
                    tilesInRange.Add(tile);
                }
            }

            return tilesInRange;
        }

        /// <summary>
        /// Get attack range from multiple possible positions (for showing attack range after movement).
        /// </summary>
        public static List<GridTile> GetAttackRangeFromMovement(Dictionary<GridTile, float> movementRange, int minRange, int maxRange, GridManager grid)
        {
            HashSet<GridTile> attackTiles = new HashSet<GridTile>();

            foreach (GridTile movePosition in movementRange.Keys)
            {
                List<GridTile> rangeFromPosition = GetAttackRange(movePosition, minRange, maxRange, grid);
                foreach (GridTile tile in rangeFromPosition)
                {
                    attackTiles.Add(tile);
                }
            }

            return new List<GridTile>(attackTiles);
        }

        #endregion

        #region Helper Methods

        private static float GetHeuristic(GridTile from, GridTile to)
        {
            // Manhattan distance heuristic (works well for grid-based games)
            return Mathf.Abs(from.GridPosition.x - to.GridPosition.x) +
                   Mathf.Abs(from.GridPosition.y - to.GridPosition.y);
        }

        private static PathNode GetLowestFCostNode(List<PathNode> nodes)
        {
            PathNode lowest = nodes[0];
            for (int i = 1; i < nodes.Count; i++)
            {
                if (nodes[i].fCost < lowest.fCost)
                    lowest = nodes[i];
            }
            return lowest;
        }

        private static PathNode GetLowestGCostNode(List<PathNode> nodes)
        {
            PathNode lowest = nodes[0];
            for (int i = 1; i < nodes.Count; i++)
            {
                if (nodes[i].gCost < lowest.gCost)
                    lowest = nodes[i];
            }
            return lowest;
        }

        private static List<GridTile> ReconstructPath(PathNode goalNode)
        {
            List<GridTile> path = new List<GridTile>();
            PathNode current = goalNode;

            while (current != null)
            {
                path.Add(current.tile);
                current = current.parent;
            }

            path.Reverse();
            return path;
        }

        #endregion

        #region Line of Sight

        /// <summary>
        /// Check if there's a clear line of sight between two tiles.
        /// Uses Bresenham's line algorithm.
        /// </summary>
        public static bool HasLineOfSight(GridTile from, GridTile to, GridManager grid)
        {
            Vector2Int start = from.GridPosition;
            Vector2Int end = to.GridPosition;

            List<Vector2Int> line = GetLine(start, end);

            // Check each tile in the line (excluding start and end)
            for (int i = 1; i < line.Count - 1; i++)
            {
                GridTile tile = grid.GetTileAt(line[i]);
                if (tile == null || !tile.IsWalkable)
                    return false;

                // Check height difference (can't see over tall obstacles)
                if (tile.Height > from.Height + 1)
                    return false;
            }

            return true;
        }

        /// <summary>
        /// Get all grid positions along a line using Bresenham's algorithm.
        /// </summary>
        private static List<Vector2Int> GetLine(Vector2Int start, Vector2Int end)
        {
            List<Vector2Int> line = new List<Vector2Int>();

            int x = start.x;
            int y = start.y;
            int dx = Mathf.Abs(end.x - start.x);
            int dy = Mathf.Abs(end.y - start.y);
            int sx = start.x < end.x ? 1 : -1;
            int sy = start.y < end.y ? 1 : -1;
            int err = dx - dy;

            while (true)
            {
                line.Add(new Vector2Int(x, y));

                if (x == end.x && y == end.y)
                    break;

                int e2 = 2 * err;
                if (e2 > -dy)
                {
                    err -= dy;
                    x += sx;
                }
                if (e2 < dx)
                {
                    err += dx;
                    y += sy;
                }
            }

            return line;
        }

        #endregion

        #region Area of Effect

        /// <summary>
        /// Get all tiles within an AOE radius from center point.
        /// </summary>
        public static List<GridTile> GetAreaOfEffect(GridTile center, int radius, GridManager grid)
        {
            List<GridTile> tiles = new List<GridTile>();

            if (center == null || grid == null)
                return tiles;

            for (int x = -radius; x <= radius; x++)
            {
                for (int y = -radius; y <= radius; y++)
                {
                    Vector2Int pos = center.GridPosition + new Vector2Int(x, y);

                    // Check if within circular radius (not square)
                    if (Mathf.Abs(x) + Mathf.Abs(y) <= radius)
                    {
                        GridTile tile = grid.GetTileAt(pos);
                        if (tile != null)
                            tiles.Add(tile);
                    }
                }
            }

            return tiles;
        }

        #endregion
    }

    #region Path Node Class

    /// <summary>
    /// Internal class for A* pathfinding nodes.
    /// </summary>
    internal class PathNode
    {
        public GridTile tile;
        public float gCost; // Cost from start
        public float hCost; // Heuristic cost to goal
        public float fCost => gCost + hCost; // Total cost
        public PathNode parent;
    }

    #endregion
}
