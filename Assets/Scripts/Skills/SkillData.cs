using UnityEngine;
using ADLegacy.Units;

namespace ADLegacy.Skills
{
    /// <summary>
    /// ScriptableObject defining a skill/ability with its properties and effects.
    /// Based on FFTA skill system with combat formulas.
    /// </summary>
    [CreateAssetMenu(fileName = "New Skill", menuName = "ADLegacy/Skill Data", order = 2)]
    public class SkillData : ScriptableObject
    {
        [Header("Skill Identity")]
        [SerializeField] private string skillName = "Unnamed Skill";
        [SerializeField] [TextArea(2, 4)] private string description = "Skill description here.";
        [SerializeField] private Sprite skillIcon;
        [SerializeField] private SkillType skillType = SkillType.Physical;

        [Header("Costs")]
        [SerializeField] private int mpCost = 0;
        [SerializeField] private int hpCost = 0;

        [Header("Range")]
        [SerializeField] private int minRange = 1;
        [SerializeField] private int maxRange = 1;
        [SerializeField] private TargetType targetType = TargetType.Enemy;
        [SerializeField] private bool requiresLineOfSight = false;

        [Header("Power & Accuracy")]
        [SerializeField] private float powerMultiplier = 1.0f;
        [SerializeField] [Range(0, 100)] private int baseAccuracy = 90;

        [Header("Area of Effect")]
        [SerializeField] private bool isAOE = false;
        [SerializeField] private int aoeRadius = 0; // 0 = single target, 1+ = radius

        [Header("Effects")]
        [SerializeField] private bool canCrit = true;
        [SerializeField] private bool ignoresDefense = false;
        [SerializeField] private int hitCount = 1; // Multi-hit attacks

        [Header("Status Effects")]
        [SerializeField] private StatusEffectType statusEffect = StatusEffectType.None;
        [SerializeField] [Range(0, 100)] private int statusChance = 0;
        [SerializeField] private int statusDuration = 3;
        [SerializeField] private int statusPotency = 10;

        [Header("Special Properties")]
        [SerializeField] private bool drainHP = false;
        [SerializeField] private bool drainMP = false;
        [SerializeField] [Range(0, 100)] private int drainPercent = 50;
        [SerializeField] private bool revive = false;
        [SerializeField] private bool armorPiercing = false;

        [Header("Visuals & Audio")]
        [SerializeField] private GameObject vfxPrefab;
        [SerializeField] private AudioClip soundEffect;
        [SerializeField] private Color skillColor = Color.white;
        [SerializeField] private float animationDuration = 0.5f;

        #region Properties

        public string SkillName => skillName;
        public string Description => description;
        public Sprite SkillIcon => skillIcon;
        public SkillType Type => skillType;

        public int MPCost => mpCost;
        public int HPCost => hpCost;

        public int MinRange => minRange;
        public int MaxRange => maxRange;
        public TargetType TargetType => targetType;
        public bool RequiresLineOfSight => requiresLineOfSight;

        public float PowerMultiplier => powerMultiplier;
        public int BaseAccuracy => baseAccuracy;

        public bool IsAOE => isAOE;
        public int AOERadius => aoeRadius;

        public bool CanCrit => canCrit;
        public bool IgnoresDefense => ignoresDefense;
        public int HitCount => hitCount;

        public StatusEffectType StatusEffect => statusEffect;
        public int StatusChance => statusChance;
        public int StatusDuration => statusDuration;
        public int StatusPotency => statusPotency;

        public bool DrainHP => drainHP;
        public bool DrainMP => drainMP;
        public int DrainPercent => drainPercent;
        public bool Revive => revive;
        public bool ArmorPiercing => armorPiercing;

        public GameObject VFXPrefab => vfxPrefab;
        public AudioClip SoundEffect => soundEffect;
        public Color SkillColor => skillColor;
        public float AnimationDuration => animationDuration;

        #endregion

        #region Validation

        /// <summary>
        /// Check if caster can use this skill.
        /// </summary>
        public bool CanUse(Unit caster)
        {
            if (caster == null || !caster.IsAlive)
                return false;

            // Check MP cost
            if (caster.Stats.CurrentMP < mpCost)
                return false;

            // Check HP cost (can't kill self)
            if (caster.Stats.CurrentHP <= hpCost)
                return false;

            // Check for status effects that prevent action
            if (caster.HasStatusEffect(StatusEffectType.Sleep) ||
                caster.HasStatusEffect(StatusEffectType.Stun))
                return false;

            return true;
        }

        /// <summary>
        /// Check if target is valid for this skill.
        /// </summary>
        public bool IsValidTarget(Unit caster, Unit target)
        {
            if (caster == null || target == null)
                return false;

            // Check target type
            switch (targetType)
            {
                case TargetType.Enemy:
                    if (target.Team == caster.Team)
                        return false;
                    break;

                case TargetType.Ally:
                    if (target.Team != caster.Team)
                        return false;
                    break;

                case TargetType.Self:
                    if (target != caster)
                        return false;
                    break;

                case TargetType.Any:
                    // All targets valid
                    break;

                case TargetType.DeadAlly:
                    if (target.Team != caster.Team || target.IsAlive)
                        return false;
                    break;
            }

            // Check range
            int distance = caster.GetDistanceTo(target);
            if (distance < minRange || distance > maxRange)
                return false;

            // Check line of sight if required
            if (requiresLineOfSight)
            {
                // TODO: Implement LOS check
            }

            return true;
        }

        #endregion

        #region Damage Calculation

        /// <summary>
        /// Calculate damage for this skill from caster to target.
        /// Based on FFTA damage formulas.
        /// </summary>
        public int CalculateDamage(Unit caster, Unit target)
        {
            if (caster == null || target == null)
                return 0;

            int baseDamage = 0;

            switch (skillType)
            {
                case SkillType.Physical:
                    baseDamage = Mathf.FloorToInt(caster.Stats.Attack * powerMultiplier);
                    if (!ignoresDefense && !armorPiercing)
                        baseDamage -= target.Stats.Defense;
                    else if (armorPiercing)
                        baseDamage -= Mathf.FloorToInt(target.Stats.Defense * 0.5f);
                    break;

                case SkillType.Magical:
                    baseDamage = Mathf.FloorToInt(caster.Stats.Magic * powerMultiplier);
                    if (!ignoresDefense)
                        baseDamage -= target.Stats.Resistance;
                    break;

                case SkillType.Healing:
                    baseDamage = Mathf.FloorToInt(caster.Stats.Magic * powerMultiplier);
                    break;

                case SkillType.True:
                    // True damage ignores all defenses
                    baseDamage = Mathf.FloorToInt(caster.Stats.Attack * powerMultiplier);
                    break;
            }

            // Ensure minimum damage (except healing)
            if (skillType != SkillType.Healing)
                baseDamage = Mathf.Max(1, baseDamage);
            else
                baseDamage = Mathf.Max(0, baseDamage);

            return baseDamage;
        }

        /// <summary>
        /// Calculate hit chance for this skill.
        /// </summary>
        public int CalculateHitChance(Unit caster, Unit target)
        {
            if (caster == null || target == null)
                return baseAccuracy;

            int hitChance = baseAccuracy;

            // Add speed advantage
            int speedDiff = caster.Stats.Speed - target.Stats.Speed;
            hitChance += Mathf.Clamp(speedDiff / 2, -20, 20);

            // Subtract evasion
            hitChance -= target.Stats.Evasion;

            // Apply blind status
            if (caster.HasStatusEffect(StatusEffectType.Blind))
                hitChance -= 30;

            // Clamp between 5% and 100%
            return Mathf.Clamp(hitChance, 5, 100);
        }

        /// <summary>
        /// Check if attack is a critical hit.
        /// </summary>
        public bool RollCritical(Unit caster)
        {
            if (!canCrit || caster == null)
                return false;

            int critChance = caster.Stats.CritChance;
            return Random.Range(0, 100) < critChance;
        }

        /// <summary>
        /// Apply critical damage multiplier.
        /// </summary>
        public int ApplyCritical(int baseDamage, Unit caster)
        {
            float multiplier = caster.Stats.CritDamage / 100f;
            return Mathf.FloorToInt(baseDamage * multiplier);
        }

        #endregion

        #region Utility

        public string GetRangeText()
        {
            if (minRange == maxRange)
                return $"Range: {minRange}";
            else
                return $"Range: {minRange}-{maxRange}";
        }

        public string GetCostText()
        {
            if (mpCost > 0 && hpCost > 0)
                return $"Cost: {mpCost} MP, {hpCost} HP";
            else if (mpCost > 0)
                return $"Cost: {mpCost} MP";
            else if (hpCost > 0)
                return $"Cost: {hpCost} HP";
            else
                return "Cost: None";
        }

        public string GetTargetTypeText()
        {
            switch (targetType)
            {
                case TargetType.Enemy: return "Enemy";
                case TargetType.Ally: return "Ally";
                case TargetType.Self: return "Self";
                case TargetType.Any: return "Any";
                case TargetType.DeadAlly: return "Dead Ally";
                default: return "Unknown";
            }
        }

        #endregion

        #region Validation (Editor)

        private void OnValidate()
        {
            // Ensure valid ranges
            minRange = Mathf.Max(0, minRange);
            maxRange = Mathf.Max(minRange, maxRange);
            aoeRadius = Mathf.Max(0, aoeRadius);

            // Clamp percentages
            baseAccuracy = Mathf.Clamp(baseAccuracy, 0, 100);
            statusChance = Mathf.Clamp(statusChance, 0, 100);
            drainPercent = Mathf.Clamp(drainPercent, 0, 100);

            // Ensure positive costs
            mpCost = Mathf.Max(0, mpCost);
            hpCost = Mathf.Max(0, hpCost);

            // Ensure hit count is at least 1
            hitCount = Mathf.Max(1, hitCount);
        }

        #endregion
    }

    #region Enums

    public enum SkillType
    {
        Physical,   // Uses Attack stat, affected by Defense
        Magical,    // Uses Magic stat, affected by Resistance
        Healing,    // Restores HP
        Support,    // Buffs, debuffs, utility
        True        // Fixed damage, ignores defense
    }

    public enum TargetType
    {
        Enemy,      // Only enemies
        Ally,       // Only allies (including self)
        Self,       // Only self
        Any,        // Any unit
        DeadAlly    // Only dead allies (for revive)
    }

    #endregion
}
