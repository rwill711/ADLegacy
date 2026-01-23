using System;
using UnityEngine;

namespace ADLegacy.Units
{
    /// <summary>
    /// Contains all stats for a unit, including HP, MP, combat stats, and status effects.
    /// Based on FFTA-style stat system.
    /// </summary>
    [Serializable]
    public class UnitStats
    {
        [Header("Core Stats")]
        [SerializeField] private int maxHP = 100;
        [SerializeField] private int currentHP = 100;
        [SerializeField] private int maxMP = 50;
        [SerializeField] private int currentMP = 50;

        [Header("Combat Stats")]
        [SerializeField] private int attack = 10;
        [SerializeField] private int defense = 10;
        [SerializeField] private int magic = 10;
        [SerializeField] private int resistance = 10;
        [SerializeField] private int speed = 10;

        [Header("Derived Stats")]
        [SerializeField] private int accuracy = 90;
        [SerializeField] private int evasion = 10;
        [SerializeField] private int critChance = 5;
        [SerializeField] private int critDamage = 150; // Percentage (150 = 1.5x damage)

        [Header("Movement")]
        [SerializeField] private int moveRange = 3;
        [SerializeField] private int jumpHeight = 2; // For height differences

        [Header("Progression")]
        [SerializeField] private int level = 1;
        [SerializeField] private int experience = 0;
        [SerializeField] private int experienceToNextLevel = 100;

        [Header("Status Modifiers")]
        private StatModifiers temporaryModifiers = new StatModifiers();
        private StatModifiers equipmentModifiers = new StatModifiers();

        #region Properties

        // HP/MP
        public int MaxHP => Mathf.Max(1, maxHP + equipmentModifiers.hp + temporaryModifiers.hp);
        public int CurrentHP
        {
            get => currentHP;
            set => currentHP = Mathf.Clamp(value, 0, MaxHP);
        }

        public int MaxMP => Mathf.Max(0, maxMP + equipmentModifiers.mp + temporaryModifiers.mp);
        public int CurrentMP
        {
            get => currentMP;
            set => currentMP = Mathf.Clamp(value, 0, MaxMP);
        }

        public float HPPercent => MaxHP > 0 ? (float)CurrentHP / MaxHP : 0f;
        public float MPPercent => MaxMP > 0 ? (float)CurrentMP / MaxMP : 0f;

        public bool IsAlive => CurrentHP > 0;
        public bool IsDead => CurrentHP <= 0;

        // Combat Stats (with modifiers)
        public int Attack => Mathf.Max(1, attack + equipmentModifiers.attack + temporaryModifiers.attack);
        public int Defense => Mathf.Max(0, defense + equipmentModifiers.defense + temporaryModifiers.defense);
        public int Magic => Mathf.Max(1, magic + equipmentModifiers.magic + temporaryModifiers.magic);
        public int Resistance => Mathf.Max(0, resistance + equipmentModifiers.resistance + temporaryModifiers.resistance);
        public int Speed => Mathf.Max(1, speed + equipmentModifiers.speed + temporaryModifiers.speed);

        // Derived Stats
        public int Accuracy => Mathf.Clamp(accuracy + equipmentModifiers.accuracy + temporaryModifiers.accuracy, 0, 100);
        public int Evasion => Mathf.Clamp(evasion + equipmentModifiers.evasion + temporaryModifiers.evasion, 0, 100);
        public int CritChance => Mathf.Clamp(critChance + equipmentModifiers.critChance + temporaryModifiers.critChance, 0, 100);
        public int CritDamage => Mathf.Max(100, critDamage + equipmentModifiers.critDamage + temporaryModifiers.critDamage);

        // Movement
        public int MoveRange => Mathf.Max(1, moveRange + equipmentModifiers.moveRange + temporaryModifiers.moveRange);
        public int JumpHeight => Mathf.Max(0, jumpHeight + equipmentModifiers.jumpHeight + temporaryModifiers.jumpHeight);

        // Progression
        public int Level
        {
            get => level;
            set => level = Mathf.Max(1, value);
        }

        public int Experience
        {
            get => experience;
            set => experience = Mathf.Max(0, value);
        }

        public int ExperienceToNextLevel => experienceToNextLevel;

        #endregion

        #region Constructor

        public UnitStats()
        {
            // Default stats
        }

        public UnitStats(int hp, int mp, int atk, int def, int mag, int res, int spd)
        {
            maxHP = hp;
            currentHP = hp;
            maxMP = mp;
            currentMP = mp;
            attack = atk;
            defense = def;
            magic = mag;
            resistance = res;
            speed = spd;
        }

        #endregion

        #region Stat Modification

        /// <summary>
        /// Set base stats (used when changing jobs or leveling up).
        /// </summary>
        public void SetBaseStats(int hp, int mp, int atk, int def, int mag, int res, int spd)
        {
            maxHP = hp;
            maxMP = mp;
            attack = atk;
            defense = def;
            magic = mag;
            resistance = res;
            speed = spd;

            // Clamp current values
            CurrentHP = Mathf.Min(CurrentHP, MaxHP);
            CurrentMP = Mathf.Min(CurrentMP, MaxMP);
        }

        /// <summary>
        /// Apply temporary stat modifiers (buffs/debuffs).
        /// </summary>
        public void ApplyTemporaryModifier(StatModifiers modifier)
        {
            temporaryModifiers.Add(modifier);
        }

        /// <summary>
        /// Remove temporary stat modifiers.
        /// </summary>
        public void RemoveTemporaryModifier(StatModifiers modifier)
        {
            temporaryModifiers.Subtract(modifier);
        }

        /// <summary>
        /// Clear all temporary modifiers.
        /// </summary>
        public void ClearTemporaryModifiers()
        {
            temporaryModifiers = new StatModifiers();
        }

        /// <summary>
        /// Apply equipment stat modifiers.
        /// </summary>
        public void ApplyEquipmentModifier(StatModifiers modifier)
        {
            equipmentModifiers.Add(modifier);
        }

        /// <summary>
        /// Remove equipment stat modifiers.
        /// </summary>
        public void RemoveEquipmentModifier(StatModifiers modifier)
        {
            equipmentModifiers.Subtract(modifier);
        }

        /// <summary>
        /// Clear all equipment modifiers.
        /// </summary>
        public void ClearEquipmentModifiers()
        {
            equipmentModifiers = new StatModifiers();
        }

        #endregion

        #region HP/MP Management

        /// <summary>
        /// Heal HP by amount.
        /// </summary>
        public int Heal(int amount)
        {
            int oldHP = CurrentHP;
            CurrentHP += amount;
            return CurrentHP - oldHP; // Return actual healing done
        }

        /// <summary>
        /// Take damage.
        /// </summary>
        public int TakeDamage(int amount)
        {
            int oldHP = CurrentHP;
            CurrentHP -= amount;
            return oldHP - CurrentHP; // Return actual damage taken
        }

        /// <summary>
        /// Restore MP.
        /// </summary>
        public int RestoreMP(int amount)
        {
            int oldMP = CurrentMP;
            CurrentMP += amount;
            return CurrentMP - oldMP;
        }

        /// <summary>
        /// Consume MP.
        /// </summary>
        public bool ConsumeMP(int amount)
        {
            if (CurrentMP >= amount)
            {
                CurrentMP -= amount;
                return true;
            }
            return false;
        }

        /// <summary>
        /// Fully restore HP and MP.
        /// </summary>
        public void FullRestore()
        {
            CurrentHP = MaxHP;
            CurrentMP = MaxMP;
        }

        /// <summary>
        /// Revive unit to percentage HP.
        /// </summary>
        public void Revive(float hpPercent = 0.5f)
        {
            CurrentHP = Mathf.FloorToInt(MaxHP * hpPercent);
        }

        #endregion

        #region Experience & Leveling

        /// <summary>
        /// Add experience points.
        /// </summary>
        /// <returns>True if leveled up</returns>
        public bool AddExperience(int amount)
        {
            experience += amount;

            if (experience >= experienceToNextLevel)
            {
                return true; // Signal level up
            }

            return false;
        }

        /// <summary>
        /// Level up the unit.
        /// </summary>
        public void LevelUp(StatGrowth growth)
        {
            level++;
            experience -= experienceToNextLevel;
            experienceToNextLevel = CalculateExpForNextLevel();

            // Apply stat growth
            maxHP += growth.hpGrowth;
            maxMP += growth.mpGrowth;
            attack += growth.attackGrowth;
            defense += growth.defenseGrowth;
            magic += growth.magicGrowth;
            resistance += growth.resistanceGrowth;
            speed += growth.speedGrowth;

            // Restore HP/MP on level up
            FullRestore();
        }

        private int CalculateExpForNextLevel()
        {
            // Progressive EXP curve
            return 100 + (level * 50);
        }

        #endregion

        #region Utility

        /// <summary>
        /// Clone these stats.
        /// </summary>
        public UnitStats Clone()
        {
            UnitStats clone = new UnitStats
            {
                maxHP = this.maxHP,
                currentHP = this.currentHP,
                maxMP = this.maxMP,
                currentMP = this.currentMP,
                attack = this.attack,
                defense = this.defense,
                magic = this.magic,
                resistance = this.resistance,
                speed = this.speed,
                accuracy = this.accuracy,
                evasion = this.evasion,
                critChance = this.critChance,
                critDamage = this.critDamage,
                moveRange = this.moveRange,
                jumpHeight = this.jumpHeight,
                level = this.level,
                experience = this.experience,
                experienceToNextLevel = this.experienceToNextLevel
            };

            return clone;
        }

        public override string ToString()
        {
            return $"HP:{CurrentHP}/{MaxHP} MP:{CurrentMP}/{MaxMP} ATK:{Attack} DEF:{Defense} MAG:{Magic} RES:{Resistance} SPD:{Speed}";
        }

        #endregion
    }

    #region Support Classes

    /// <summary>
    /// Represents stat modifiers from equipment, buffs, debuffs, etc.
    /// </summary>
    [Serializable]
    public class StatModifiers
    {
        public int hp;
        public int mp;
        public int attack;
        public int defense;
        public int magic;
        public int resistance;
        public int speed;
        public int accuracy;
        public int evasion;
        public int critChance;
        public int critDamage;
        public int moveRange;
        public int jumpHeight;

        public void Add(StatModifiers other)
        {
            hp += other.hp;
            mp += other.mp;
            attack += other.attack;
            defense += other.defense;
            magic += other.magic;
            resistance += other.resistance;
            speed += other.speed;
            accuracy += other.accuracy;
            evasion += other.evasion;
            critChance += other.critChance;
            critDamage += other.critDamage;
            moveRange += other.moveRange;
            jumpHeight += other.jumpHeight;
        }

        public void Subtract(StatModifiers other)
        {
            hp -= other.hp;
            mp -= other.mp;
            attack -= other.attack;
            defense -= other.defense;
            magic -= other.magic;
            resistance -= other.resistance;
            speed -= other.speed;
            accuracy -= other.accuracy;
            evasion -= other.evasion;
            critChance -= other.critChance;
            critDamage -= other.critDamage;
            moveRange -= other.moveRange;
            jumpHeight -= other.jumpHeight;
        }
    }

    /// <summary>
    /// Stat growth rates for leveling up.
    /// </summary>
    [Serializable]
    public class StatGrowth
    {
        public int hpGrowth = 10;
        public int mpGrowth = 5;
        public int attackGrowth = 2;
        public int defenseGrowth = 2;
        public int magicGrowth = 2;
        public int resistanceGrowth = 2;
        public int speedGrowth = 1;

        public StatGrowth() { }

        public StatGrowth(int hp, int mp, int atk, int def, int mag, int res, int spd)
        {
            hpGrowth = hp;
            mpGrowth = mp;
            attackGrowth = atk;
            defenseGrowth = def;
            magicGrowth = mag;
            resistanceGrowth = res;
            speedGrowth = spd;
        }
    }

    #endregion
}
