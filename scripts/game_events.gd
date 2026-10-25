extends Node

## Global event bus (autoload).
##
## Cross-system communication without direct references: enemies announce
## their death, the gem system drops EXP, the run director accumulates it.
## Systems only need to know the signal names, never each other.
##
## The signals below are the bus's entire API: they are emitted and
## connected from other scripts, never inside this one, which is why each
## carries an explicit warning ignore.

# Emitted when an enemy finishes dying. `exp_value` is the scaled EXP the
# enemy is worth; the gem system listens and spawns a pickup for it.
@warning_ignore("unused_signal")
signal enemy_died(enemy: Node2D, exp_value: int)

# Emitted when a gem reaches the player and is consumed.
@warning_ignore("unused_signal")
signal exp_collected(amount: int)

# Emitted right after an upgrade's effects were applied to the player.
@warning_ignore("unused_signal")
signal upgrade_applied(upgrade: Resource)

# Emitted when the player's health reaches zero.
@warning_ignore("unused_signal")
signal player_died
