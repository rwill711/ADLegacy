using UnityEngine;
using UnityEngine.SceneManagement;
using ADLegacy.Units;
using ADLegacy.Grid;

namespace ADLegacy
{
    /// <summary>
    /// Main game manager handling overall game state, scene management, and global systems.
    /// Singleton pattern for global access.
    /// </summary>
    public class GameManager : MonoBehaviour
    {
        public static GameManager Instance { get; private set; }

        [Header("Game State")]
        [SerializeField] private GameState currentState = GameState.MainMenu;
        [SerializeField] private GameMode currentMode = GameMode.Normal;

        [Header("Settings")]
        [SerializeField] private bool debugMode = true;
        [SerializeField] private float gameSpeed = 1.0f;

        [Header("Player Data")]
        [SerializeField] private PlayerData playerData;

        // Events
        public event System.Action<GameState> OnGameStateChanged;
        public event System.Action<Unit> OnUnitSelected;
        public event System.Action<GridTile> OnTileSelected;

        // Selected objects
        private Unit selectedUnit;
        private GridTile selectedTile;

        #region Properties

        public GameState CurrentState => currentState;
        public GameMode CurrentMode => currentMode;
        public bool IsDebugMode => debugMode;
        public float GameSpeed => gameSpeed;
        public PlayerData PlayerData => playerData;

        public Unit SelectedUnit => selectedUnit;
        public GridTile SelectedTile => selectedTile;

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
            DontDestroyOnLoad(gameObject);

            Initialize();
        }

        private void Start()
        {
            // Start in appropriate state based on scene
            string sceneName = SceneManager.GetActiveScene().name;
            if (sceneName.Contains("Battle"))
            {
                ChangeGameState(GameState.Battle);
            }
            else if (sceneName.Contains("Menu"))
            {
                ChangeGameState(GameState.MainMenu);
            }
        }

        private void Update()
        {
            // Debug shortcuts
            if (debugMode)
            {
                // Toggle debug panel with D key
                if (Input.GetKeyDown(KeyCode.D))
                {
                    // TODO: Toggle debug UI
                }

                // Speed controls
                if (Input.GetKeyDown(KeyCode.Plus) || Input.GetKeyDown(KeyCode.Equals))
                {
                    SetGameSpeed(gameSpeed + 0.5f);
                }
                if (Input.GetKeyDown(KeyCode.Minus))
                {
                    SetGameSpeed(gameSpeed - 0.5f);
                }
            }
        }

        #endregion

        #region Initialization

        private void Initialize()
        {
            // Initialize player data if not exists
            if (playerData == null)
            {
                playerData = new PlayerData();
            }

            // Initialize game systems
            Time.timeScale = gameSpeed;

            Debug.Log("GameManager initialized");
        }

        #endregion

        #region State Management

        /// <summary>
        /// Change the current game state.
        /// </summary>
        public void ChangeGameState(GameState newState)
        {
            if (currentState == newState)
                return;

            Debug.Log($"Game State: {currentState} -> {newState}");

            // Exit current state
            ExitState(currentState);

            // Enter new state
            currentState = newState;
            EnterState(newState);

            // Notify listeners
            OnGameStateChanged?.Invoke(newState);
        }

        private void EnterState(GameState state)
        {
            switch (state)
            {
                case GameState.MainMenu:
                    Time.timeScale = 1f;
                    break;

                case GameState.Battle:
                    // Battle manager will handle battle initialization
                    break;

                case GameState.Victory:
                    Time.timeScale = 1f;
                    break;

                case GameState.Defeat:
                    Time.timeScale = 1f;
                    break;

                case GameState.Paused:
                    Time.timeScale = 0f;
                    break;
            }
        }

        private void ExitState(GameState state)
        {
            switch (state)
            {
                case GameState.Paused:
                    Time.timeScale = gameSpeed;
                    break;
            }
        }

        #endregion

        #region Game Mode

        /// <summary>
        /// Set the current game mode.
        /// </summary>
        public void SetGameMode(GameMode mode)
        {
            currentMode = mode;
            Debug.Log($"Game Mode set to: {mode}");
        }

        #endregion

        #region Selection Management

        /// <summary>
        /// Called when a unit is clicked.
        /// </summary>
        public void OnUnitClicked(Unit unit)
        {
            selectedUnit = unit;
            OnUnitSelected?.Invoke(unit);

            Debug.Log($"Unit selected: {unit.UnitName}");

            // Notify battle manager
            if (BattleManager.Instance != null)
                BattleManager.Instance.OnUnitSelected(unit);
        }

        /// <summary>
        /// Called when a grid tile is clicked.
        /// </summary>
        public void OnGridTileSelected(GridTile tile)
        {
            selectedTile = tile;
            OnTileSelected?.Invoke(tile);

            // Notify battle manager
            if (BattleManager.Instance != null)
                BattleManager.Instance.OnTileSelected(tile);
        }

        /// <summary>
        /// Clear current selection.
        /// </summary>
        public void ClearSelection()
        {
            selectedUnit = null;
            selectedTile = null;
        }

        #endregion

        #region Game Controls

        /// <summary>
        /// Pause the game.
        /// </summary>
        public void PauseGame()
        {
            ChangeGameState(GameState.Paused);
        }

        /// <summary>
        /// Resume the game.
        /// </summary>
        public void ResumeGame()
        {
            ChangeGameState(GameState.Battle);
        }

        /// <summary>
        /// Set game speed multiplier.
        /// </summary>
        public void SetGameSpeed(float speed)
        {
            gameSpeed = Mathf.Clamp(speed, 0.5f, 3f);
            if (currentState != GameState.Paused)
                Time.timeScale = gameSpeed;

            Debug.Log($"Game speed set to: {gameSpeed}x");
        }

        #endregion

        #region Scene Management

        /// <summary>
        /// Load a scene by name.
        /// </summary>
        public void LoadScene(string sceneName)
        {
            Debug.Log($"Loading scene: {sceneName}");
            SceneManager.LoadScene(sceneName);
        }

        /// <summary>
        /// Reload current scene.
        /// </summary>
        public void ReloadCurrentScene()
        {
            Scene currentScene = SceneManager.GetActiveScene();
            SceneManager.LoadScene(currentScene.name);
        }

        /// <summary>
        /// Return to main menu.
        /// </summary>
        public void ReturnToMainMenu()
        {
            ChangeGameState(GameState.MainMenu);
            LoadScene("MainMenu");
        }

        #endregion

        #region Save/Load

        /// <summary>
        /// Save game data.
        /// </summary>
        public void SaveGame()
        {
            // TODO: Implement save system
            Debug.Log("Game saved");
        }

        /// <summary>
        /// Load game data.
        /// </summary>
        public void LoadGame()
        {
            // TODO: Implement load system
            Debug.Log("Game loaded");
        }

        #endregion

        #region Utility

        /// <summary>
        /// Quit the application.
        /// </summary>
        public void QuitGame()
        {
            Debug.Log("Quitting game");

            #if UNITY_EDITOR
                UnityEditor.EditorApplication.isPlaying = false;
            #else
                Application.Quit();
            #endif
        }

        #endregion
    }

    #region Enums

    public enum GameState
    {
        MainMenu,
        Battle,
        Victory,
        Defeat,
        Paused,
        Loading
    }

    public enum GameMode
    {
        Normal,     // Single battle
        Endless,    // Wave-based survival
        Campaign    // Story missions (future)
    }

    #endregion

    #region Player Data

    [System.Serializable]
    public class PlayerData
    {
        public int gold = 1000;
        public int battlesWon = 0;
        public int battlesLost = 0;
        public int highestWave = 0; // For endless mode

        public PlayerData()
        {
            gold = 1000;
            battlesWon = 0;
            battlesLost = 0;
            highestWave = 0;
        }
    }

    #endregion
}
