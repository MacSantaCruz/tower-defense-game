local NetworkMessages = {
    -- Server -> Client messages
    -- Needs to remain synced with Server Constants 
    SERVER = {
        INITIALIZATION = "initialization",
        TOWER_PLACED = "towerPlaced",
        ENEMY_SPAWNED = "enemySpawned",
        ENEMY_DIED = "enemyDied",
        GAME_UPDATES = "gameUpdates",
        ENEMY_ATTACK = "enemyAttack",
        ENEMY_START_ATTACK = "enemyStartAttack",
        BASE_TAKE_DAMAGE = "baseTakeDamage",
        BASE_DESTROYED = "baseDestroyed"
    },
    
    -- Client -> Server messages
    CLIENT = {
        PLACE_TOWER = "placeTower",
        SPAWN_ENEMY = "spawnEnemy"
    },
    
    -- Update types (used within GAME_UPDATES)
    UPDATE = {
        TOWER_ATTACK = "attack",
        ENEMY_DAMAGE = "damage",
        ENEMY_DEATH = "enemyDied"
    }
}

-- Make the table read-only to prevent accidental modifications
return setmetatable({}, {
    __index = NetworkMessages,
    __newindex = function()
        error("Attempt to modify read-only network messages")
    end
})