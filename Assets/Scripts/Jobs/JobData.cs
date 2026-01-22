using System.Collections.Generic;
using UnityEngine;
using ADLegacy.Skills;
using ADLegacy.Units;

namespace ADLegacy.Jobs
{
    /// <summary>
    /// ScriptableObject defining a job/class with its stats, skills, and requirements.
    /// Based on FFTA job system.
    /// </summary>
    [CreateAssetMenu(fileName = "New Job", menuName = "ADLegacy/Job Data", order = 1)]
    public class JobData : ScriptableObject
    {
        [Header("Job Identity")]
        [SerializeField] private string jobName = "Unnamed Job";
        [SerializeField] [TextArea(3, 5)] private string description = "Job description here.";
        [SerializeField] private Sprite jobIcon;
        [SerializeField] private JobTier tier = JobTier.Base;

        [Header("Base Stats (Level 1)")]
        [SerializeField] private int baseHP = 100;
        [SerializeField] private int baseMP = 50;
        [SerializeField] private int baseAttack = 10;
        [SerializeField] private int baseDefense = 10;
        [SerializeField] private int baseMagic = 10;
        [SerializeField] private int baseResistance = 10;
        [SerializeField] private int baseSpeed = 10;

        [Header("Stat Growth (Per Level)")]
        [SerializeField] private StatGrowth statGrowth = new StatGrowth(10, 5, 2, 2, 2, 2, 1);

        [Header("Movement")]
        [SerializeField] private int moveRange = 3;
        [SerializeField] private int jumpHeight = 2;

        [Header("Skills")]
        [SerializeField] private List<SkillData> jobSkills = new List<SkillData>();

        [Header("Job Requirements")]
        [SerializeField] private List<JobRequirement> unlockRequirements = new List<JobRequirement>();

        [Header("Visual")]
        [SerializeField] private Sprite characterSprite;
        [SerializeField] private RuntimeAnimatorController animatorController;
        [SerializeField] private Color jobColor = Color.white;

        [Header("Equipment Slots")]
        [SerializeField] private List<EquipmentType> allowedWeapons = new List<EquipmentType>();
        [SerializeField] private List<ArmorType> allowedArmor = new List<ArmorType>();

        #region Properties

        public string JobName => jobName;
        public string Description => description;
        public Sprite JobIcon => jobIcon;
        public JobTier Tier => tier;

        // Base Stats
        public int BaseHP => baseHP;
        public int BaseMP => baseMP;
        public int BaseAttack => baseAttack;
        public int BaseDefense => baseDefense;
        public int BaseMagic => baseMagic;
        public int BaseResistance => baseResistance;
        public int BaseSpeed => baseSpeed;

        // Growth
        public StatGrowth StatGrowth => statGrowth;

        // Movement
        public int MoveRange => moveRange;
        public int JumpHeight => jumpHeight;

        // Skills
        public List<SkillData> JobSkills => jobSkills;

        // Requirements
        public List<JobRequirement> UnlockRequirements => unlockRequirements;

        // Visuals
        public Sprite CharacterSprite => characterSprite;
        public RuntimeAnimatorController AnimatorController => animatorController;
        public Color JobColor => jobColor;

        // Equipment
        public List<EquipmentType> AllowedWeapons => allowedWeapons;
        public List<ArmorType> AllowedArmor => allowedArmor;

        #endregion

        #region Stats Calculation

        /// <summary>
        /// Calculate stats at a specific level.
        /// </summary>
        public UnitStats GetStatsAtLevel(int level)
        {
            int levelsToAdd = Mathf.Max(0, level - 1);

            UnitStats stats = new UnitStats(
                baseHP + (statGrowth.hpGrowth * levelsToAdd),
                baseMP + (statGrowth.mpGrowth * levelsToAdd),
                baseAttack + (statGrowth.attackGrowth * levelsToAdd),
                baseDefense + (statGrowth.defenseGrowth * levelsToAdd),
                baseMagic + (statGrowth.magicGrowth * levelsToAdd),
                baseResistance + (statGrowth.resistanceGrowth * levelsToAdd),
                baseSpeed + (statGrowth.speedGrowth * levelsToAdd)
            );

            stats.Level = level;

            return stats;
        }

        #endregion

        #region Requirements

        /// <summary>
        /// Check if a unit meets the requirements to unlock this job.
        /// </summary>
        public bool CanUnlock(Unit unit)
        {
            if (unlockRequirements.Count == 0)
                return true; // No requirements

            foreach (JobRequirement requirement in unlockRequirements)
            {
                if (!requirement.IsMet(unit))
                    return false;
            }

            return true;
        }

        /// <summary>
        /// Get a string describing the unlock requirements.
        /// </summary>
        public string GetRequirementsText()
        {
            if (unlockRequirements.Count == 0)
                return "No requirements";

            string text = "";
            for (int i = 0; i < unlockRequirements.Count; i++)
            {
                text += unlockRequirements[i].GetRequirementText();
                if (i < unlockRequirements.Count - 1)
                    text += "\n";
            }

            return text;
        }

        #endregion

        #region Validation

        private void OnValidate()
        {
            // Ensure base stats are positive
            baseHP = Mathf.Max(1, baseHP);
            baseMP = Mathf.Max(0, baseMP);
            baseAttack = Mathf.Max(1, baseAttack);
            baseDefense = Mathf.Max(0, baseDefense);
            baseMagic = Mathf.Max(1, baseMagic);
            baseResistance = Mathf.Max(0, baseResistance);
            baseSpeed = Mathf.Max(1, baseSpeed);

            // Ensure movement is valid
            moveRange = Mathf.Max(1, moveRange);
            jumpHeight = Mathf.Max(0, jumpHeight);
        }

        #endregion
    }

    #region Enums

    public enum JobTier
    {
        Base,       // Starting jobs (Knight, Rogue, Archer, etc.)
        Advanced,   // Unlocked through progression
        Special     // Unique or secret jobs
    }

    public enum EquipmentType
    {
        Sword,
        Greatsword,
        Axe,
        Spear,
        Dagger,
        Bow,
        Staff,
        Rod,
        Fist
    }

    public enum ArmorType
    {
        Heavy,
        Medium,
        Light,
        Robe
    }

    #endregion

    #region Job Requirements

    [System.Serializable]
    public class JobRequirement
    {
        public JobRequirementType requirementType;
        public JobData requiredJob;
        public int requiredLevel;
        public int requiredBattles;

        public bool IsMet(Unit unit)
        {
            switch (requirementType)
            {
                case JobRequirementType.JobUnlocked:
                    return unit.IsJobUnlocked(requiredJob);

                case JobRequirementType.JobLevel:
                    return unit.IsJobUnlocked(requiredJob) && unit.Stats.Level >= requiredLevel;

                case JobRequirementType.UnitLevel:
                    return unit.Stats.Level >= requiredLevel;

                case JobRequirementType.BattlesCompleted:
                    // TODO: Track battles completed
                    return true; // Placeholder

                default:
                    return true;
            }
        }

        public string GetRequirementText()
        {
            switch (requirementType)
            {
                case JobRequirementType.JobUnlocked:
                    return $"Unlock {requiredJob.JobName}";

                case JobRequirementType.JobLevel:
                    return $"{requiredJob.JobName} Lv.{requiredLevel}";

                case JobRequirementType.UnitLevel:
                    return $"Unit Lv.{requiredLevel}";

                case JobRequirementType.BattlesCompleted:
                    return $"{requiredBattles} battles completed";

                default:
                    return "Unknown requirement";
            }
        }
    }

    public enum JobRequirementType
    {
        JobUnlocked,        // Must have another job unlocked
        JobLevel,           // Must have another job at specific level
        UnitLevel,          // Must be at certain character level
        BattlesCompleted    // Must complete X battles
    }

    #endregion
}
