extends Node

## Headless smoke test for the survival systems. Instances the real
## survival scene and drives it: map generation, pools, spawner, gems,
## the level-up flow, and the death flow. Run with:
##   godot --headless res://tests/smoke_test.tscn
## Exits 0 on success, 1 on any failure.

var _failures: Array[String] = []
var _survival: Node
var _finished := false


func _ready() -> void:
	# Watchdog: a crashed test coroutine must fail the run, not hang it.
	get_tree().create_timer(120.0).timeout.connect(_on_watchdog)
	await get_tree().process_frame
	var survival_scene: PackedScene = load("res://scenes/survival.tscn")
	_survival = survival_scene.instantiate()
	add_child(_survival)
	await get_tree().process_frame
	await get_tree().process_frame

	await _test_map_generation()
	_test_pool()
	await _test_stats_and_upgrades()
	# Unkillable test player: contact ticks must be exercisable without the
	# horde ending the run halfway through the suite. Applied as a real
	# upgrade so stat recalculations never wipe it.
	var invincibility := UpgradeDefinition.new()
	invincibility.id = &"test_invincibility"
	invincibility.max_applications = 1
	invincibility.effects = [StatEffect.new(&"max_health", StatEffect.Op.ADD, 999900.0)]
	_survival.get_node("%player/PlayerStats").apply_upgrade(invincibility)
	_survival.get_node("%player").health = _survival.get_node("%player/PlayerStats").get_stat(&"max_health")
	await _test_spawner_and_gems()
	await _test_combat_contact()
	await _test_attack_outranges_contact()
	await _test_pause_frozen_corpse()
	await _test_auto_attack()
	await _test_level_up_flow()
	await _test_death_flow()

	_finished = true
	if _failures.is_empty():
		print("SMOKE TEST: ALL PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("SMOKE FAIL: " + failure)
		print("SMOKE TEST: %d FAILURES" % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _on_watchdog() -> void:
	if not _failures.is_empty() or _finished:
		return
	printerr("SMOKE TEST: TIMED OUT (a test step never completed)")
	get_tree().paused = false
	get_tree().quit(2)


func _director() -> RunDirector:
	return _survival as RunDirector


func _wait_physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _test_map_generation() -> void:
	var map: MapGenerator = _survival.get_node("%MapGenerator")
	var ground: TileMapLayer = map.get_node("ground")
	_check(map.config != null, "map config loaded")
	_check(ground.get_used_cells().size() > 0, "ground layer painted")
	_check(map.is_walkable(Vector2.ZERO), "spawn area walkable")

	# Loading screen lifecycle: up during the initial build, gone after.
	var loading: CanvasLayer = _survival.get_node("LoadingScreen")
	if not loading.has_finished_load():
		_check(loading.visible, "loading screen shown while map generates")
	var waited := 0
	while loading.visible and waited < 240:
		await get_tree().process_frame
		waited += 1
	_check(not loading.visible, "loading screen cleared after generation")
	_check(map.is_initial_build_done(), "initial chunk build completed")

	# Every chunk must contain at least one blocked-or-free cell bookkeeping
	# entry, and any blocked cell must report unwalkable in world space.
	var found_blocked := false
	var props: TileMapLayer = map.get_node("props")
	for chunk in map._chunks:
		var occupied: PackedByteArray = map._chunks[chunk]
		var size := map.config.chunk_size
		for index in occupied.size():
			if occupied[index] == map.CELL_BLOCKED:
				var local := Vector2i(index % size, floori(index / float(size)))
				var world: Vector2 = props.map_to_local(chunk * size + local)
				_check(not map.is_walkable(world), "blocked cell at %s reports unwalkable" % world)
				found_blocked = true
				break
		if found_blocked:
			break
	_check(found_blocked, "at least one prop was placed in loaded chunks")


func _test_pool() -> void:
	var pool := ObjectPool.new()
	pool.scene = load("res://scenes/exp_gem.tscn")
	pool.max_size = 5
	add_child(pool)
	var first := pool.acquire()
	_check(first != null, "pool acquire returns instance")
	_check(first.visible, "acquired node visible")
	_check(pool.active_count == 1, "active count tracked")
	pool.release(first)
	_check(pool.active_count == 0, "release resets active count")
	_check(not first.visible, "released node hidden")
	var second := pool.acquire()
	_check(second == first, "pool reuses the same instance")
	for i in 10:
		pool.release(pool.acquire())
	_check(pool.active_count == 1, "max_size respected (5 children, 1 active)")
	pool.queue_free()


func _test_stats_and_upgrades() -> void:
	var stats: PlayerStats = _survival.get_node("%player/PlayerStats")
	_check(stats.get_stat(&"max_health") == 100.0, "base max health")
	_check(stats.get_stat(&"damage") == 20.0, "base damage")

	var upgrade := UpgradeDefinition.new()
	upgrade.id = &"test_upgrade"
	upgrade.max_applications = 2
	upgrade.effects = [
		StatEffect.new(&"damage", StatEffect.Op.ADD, 5.0),
		StatEffect.new(&"damage", StatEffect.Op.MULTIPLY, 2.0),
	]
	_check(stats.apply_upgrade(upgrade), "first application accepted")
	# Add applies before multiply: (20 + 5) * 2 = 50.
	_check(stats.get_stat(&"damage") == 50.0, "add-then-multiply order")
	_check(stats.apply_upgrade(upgrade), "second application accepted")
	_check(not stats.apply_upgrade(upgrade), "max_applications blocks third")
	_check(stats.get_upgrade_count(&"test_upgrade") == 2, "upgrade count tracked")
	_check(stats.get_stat(&"unknown_stat") == 0.0, "unknown stat returns 0")


func _test_spawner_and_gems() -> void:
	var spawner: EnemySpawner = _survival.get_node("%EnemySpawner")
	var player: Node2D = _survival.get_node("%player")
	var gem_container: Node2D = _survival.get_node("%GemContainer")
	var director := _director()

	# Wait past the first spawn interval (1.6s) plus margin.
	await _wait_physics(150)
	await _ensure_unpaused()
	_check(spawner.total_alive() > 0, "spawner produced enemies")
	_check(spawner.total_alive() <= spawner.difficulty.max_alive_at(spawner.minutes()),
		"alive count within cap")

	var gems_before := _visible_gem_count(gem_container)
	var enemy: Node2D = _first_alive_enemy(spawner)
	_check(enemy != null, "found a live enemy to kill")
	if enemy != null:
		var enemy_exp: int = enemy.exp_value
		enemy.take_damage(999999.0)
		_check(enemy._dying, "enemy dying after lethal damage")
		await _wait_physics(3)
		_check(_visible_gem_count(gem_container) == gems_before + 1, "gem dropped on death")
		_check(director.kills >= 1, "kill counted")

		# Magnet: drop a gem next to the player and let it fly in.
		var gem: Node2D = _newest_gem(gem_container)
		if gem != null:
			var exp_before: int = director.exp_current
			gem.global_position = player.global_position + Vector2(30, 0)
			gem.start_magnet(player)
			await _wait_physics(20)
			_check(director.exp_current >= exp_before + enemy_exp,
				"gem collection credited EXP (%d -> %d)" % [exp_before, director.exp_current])
			_check(not gem.visible, "collected gem returned to pool")


func _visible_gem_count(container: Node2D) -> int:
	var count := 0
	for pool in container.get_children():
		for gem in pool.get_children():
			if gem.visible:
				count += 1
	return count


func _first_alive_enemy(spawner: EnemySpawner) -> Node2D:
	for pool in spawner._pools.values():
		for enemy in pool.get_children():
			if enemy.visible and not enemy._dying:
				return enemy
	return null


func _newest_gem(container: Node2D) -> Node2D:
	var children := container.get_children()
	for i in range(children.size() - 1, -1, -1):
		var pool := children[i]
		for gem in pool.get_children():
			if gem.visible:
				return gem
	return null


## Exercises the real contact-damage chains (Area2D <-> body) rather than
## injecting damage directly: a fresh enemy is spawned straight onto the
## player, and both hitbox directions must fire and both damage flows apply.
## (Parked chasers from the live horde can't be used — the auto-attack
## legitimately kills them before the checks run.)
func _test_combat_contact() -> void:
	var spawner: EnemySpawner = _survival.get_node("%EnemySpawner")
	var player: Node2D = _survival.get_node("%player")
	await _ensure_unpaused()

	var definition: EnemyDefinition = spawner.definitions[0]
	var pool: ObjectPool = spawner._pools[definition.id]
	var enemy: Node2D = pool.acquire()
	_check(enemy != null, "combat: pool produced an enemy")
	if enemy == null:
		return
	enemy.setup(definition, player, pool, 1.0, 1.0, 1.0)
	player.enemy_attack_cooldown = true
	enemy.global_position = player.global_position + Vector2(10, 0)
	# The auto-attack kills the parked slime within a few frames, so poll
	# the contact flags for the brief window it is alive.
	var zone_ok := false
	var reach_ok := false
	var danger_ok := false
	for i in 8:
		await _wait_physics(1)
		if enemy._player_in_attack_zone:
			zone_ok = true
		if player.enemy_in_attack_range:
			reach_ok = true
		if player.enemy_in_danger_range:
			danger_ok = true
		if (zone_ok and reach_ok and danger_ok) or not enemy.visible or enemy._dying:
			break
	_check(zone_ok or not enemy.visible or enemy._dying, "combat: enemy hitbox detects player")
	_check(reach_ok or not enemy.visible or enemy._dying, "combat: player hitbox detects enemy")
	_check(danger_ok or not enemy.visible or enemy._dying, "combat: enemy enters the danger zone")

	# Contact tick: force the danger state the area signal sets and verify
	# the per-tick contact damage applies (with the auto-attack active the
	# horde rarely survives long enough to tick naturally).
	player.enemy_in_danger_range = true
	player.enemy_attack_cooldown = true
	var hp_before_tick: float = player.health
	await _wait_physics(2)
	_check(player.health < hp_before_tick, "combat: contact tick damages the player")
	player.enemy_in_danger_range = player._enemies_in_danger > 0

	# Manual attack through the real input action (mobile button does the same).
	var enemy_health_before: float = enemy.health
	Input.action_press("attack")
	await _wait_physics(2)
	Input.action_release("attack")
	await _ensure_unpaused()
	await _wait_physics(10)
	var manual_damaged: bool = not is_instance_valid(enemy) or enemy.health < enemy_health_before or enemy._dying
	_check(manual_damaged, "combat: manual attack damaged enemy")

	# Corpse must never linger: after the death animation (plus safety net
	# margin) the body is either released or legitimately reused. Level-up
	# pauses freeze animations, so keep the tree running while waiting.
	for i in 14:
		await _ensure_unpaused()
		if not enemy.visible or not enemy._dying:
			break
		await _wait_physics(30)
	_check(not enemy.visible or not enemy._dying, "combat: corpse does not linger")
	await _ensure_unpaused()


## A corpse frozen by a level-up pause (death animation halted mid-play)
## must be recycled by the pause-aware safety net after unpausing, without
## double-releasing it or corrupting its animation callback.
func _test_pause_frozen_corpse() -> void:
	var spawner: EnemySpawner = _survival.get_node("%EnemySpawner")
	var player: Node2D = _survival.get_node("%player")
	await _ensure_unpaused()

	var definition: EnemyDefinition = spawner.definitions[0]
	var pool: ObjectPool = spawner._pools[definition.id]
	var corpse: Node2D = pool.acquire()
	if corpse == null:
		_failures.append("pause-corpse: pool produced no enemy")
		return
	corpse.setup(definition, player, pool, 1.0, 1.0, 1.0)
	corpse.global_position = player.global_position + Vector2(14, 0)
	await _wait_physics(2)
	corpse.take_damage(999999.0)
	_check(corpse._dying, "pause-corpse: died")

	# Simulate the level-up overlay: freeze the tree past the 3s recycle
	# threshold while the death animation is stuck mid-play.
	get_tree().paused = true
	await get_tree().create_timer(3.5, true).timeout
	get_tree().paused = false
	await _ensure_unpaused()

	# After enough unpaused physics frames, the sweep must recycle it.
	await _wait_physics(240)
	_check(not corpse.visible or not corpse._dying, "pause-corpse: recycled after unpause")
	await _ensure_unpaused()


## Auto-attack kills feed EXP -> level-ups pause the tree; drain the queue
## through the UI so the game is running whenever a test needs it to be.
func _ensure_unpaused() -> void:
	var director := _director()
	var level_up_ui: CanvasLayer = _survival.get_node("%LevelUpUI")
	var guard := 0
	while get_tree().paused and guard < 50:
		if director.pending_level_ups > 0 and level_up_ui.is_open:
			level_up_ui._on_option_pressed(0)
		else:
			director.pending_level_ups = 0
			level_up_ui.close()
			get_tree().paused = false
		guard += 1
		await get_tree().process_frame
	get_tree().paused = false


## Skill window: the swing reach (24 px) extends beyond the danger zone
## (~15 px), so a well-timed swing damages the enemy without the player
## taking contact damage.
func _test_attack_outranges_contact() -> void:
	var spawner: EnemySpawner = _survival.get_node("%EnemySpawner")
	var player: Node2D = _survival.get_node("%player")
	await _ensure_unpaused()

	var definition: EnemyDefinition = spawner.definitions[0]
	var pool: ObjectPool = spawner._pools[definition.id]
	var enemy: Node2D = pool.acquire()
	if enemy == null:
		_failures.append("skill window: pool produced no enemy")
		return
	enemy.setup(definition, player, pool, 1.0, 1.0, 1.0)
	enemy.move_speed = 0.0  # frozen: the check is about reach vs danger geometry
	# 20 px: inside the swing reach, outside the danger zone.
	enemy.global_position = player.global_position + Vector2(20, 0)

	var enemy_health_before: float = enemy.health
	var player_health_before: float = player.health
	# One-shot the test enemy so it cannot crawl into the danger zone
	# before the swing resolves (in real play you would kite it).
	var original_damage: float = player.stats.get_stat(&"damage")
	player.stats._values[&"damage"] = 100.0
	Input.action_press("attack")
	await _wait_physics(2)
	Input.action_release("attack")
	var connected: bool = not is_instance_valid(enemy) or enemy.health < enemy_health_before or enemy._dying
	var swings := 0
	while not connected and swings < 6:
		await _ensure_unpaused()
		await _wait_physics(30)
		Input.action_press("attack")
		await _wait_physics(2)
		Input.action_release("attack")
		swings += 1
		connected = not is_instance_valid(enemy) or enemy.health < enemy_health_before or enemy._dying
	player.stats._values[&"damage"] = original_damage
	_check(connected, "skill window: swing connected from outside the danger zone")
	var reach_radius: float = player.get_node("player_hitbox/CollisionShape2D").shape.radius
	var danger_radius: float = player.get_node("danger_area/CollisionShape2D").shape.radius
	_check(reach_radius > danger_radius,
		"skill window: swing reach must outrange the danger zone")

	# Recycle the test enemy so it doesn't wander into later checks.
	for i in 12:
		await _ensure_unpaused()
		if not is_instance_valid(enemy) or not enemy.visible or not enemy._dying:
			break
		await _wait_physics(30)
	if is_instance_valid(enemy) and enemy.visible and not enemy._dying:
		pool.release(enemy)
	await _ensure_unpaused()


## Auto-attack: with no input at all, an enemy inside the reach gets hit.
func _test_auto_attack() -> void:
	var spawner: EnemySpawner = _survival.get_node("%EnemySpawner")
	var player: Node2D = _survival.get_node("%player")
	var enemy: Node2D = null
	for attempt in 6:
		enemy = _first_alive_enemy(spawner)
		if enemy != null:
			break
		await _wait_physics(30)
	if enemy == null:
		_failures.append("auto-attack: no live enemy found")
		return

	var health_before: float = enemy.health
	enemy.global_position = player.global_position + Vector2(12, 0)
	for i in 3:
		await _ensure_unpaused()
		await _wait_physics(15)
		if not is_instance_valid(enemy) or enemy.health < health_before or enemy._dying:
			break
	var damaged: bool = not is_instance_valid(enemy) or enemy.health < health_before or enemy._dying
	_check(damaged, "auto-attack damaged enemy without any input")


func _test_level_up_flow() -> void:
	var director := _director()
	var stats: PlayerStats = _survival.get_node("%player/PlayerStats")
	var level_up_ui: CanvasLayer = _survival.get_node("%LevelUpUI")

	_check(director.upgrades.size() >= 8, "upgrades discovered from data directory")

	# A large dump should queue several level-ups at once (edge case).
	director._on_exp_collected(500)
	_check(director.pending_level_ups >= 2, "multi-level burst queued (%d pending)" % director.pending_level_ups)
	_check(get_tree().paused, "tree paused during level-up")
	_check(level_up_ui.is_open, "level-up UI open")
	_check(level_up_ui._options.size() == 3, "exactly three options offered")

	# Pick through the whole queue; each pick must apply an upgrade.
	var applied := 0
	while director.pending_level_ups > 0 and level_up_ui.is_open:
		var stats_before := _stat_sum(stats)
		level_up_ui._on_option_pressed(0)
		applied += 1
		_check(_stat_sum(stats) != stats_before, "upgrade %d changed stats" % applied)
	_check(director.pending_level_ups == 0, "level-up queue drained")
	_check(not level_up_ui.is_open, "level-up UI closed after queue drained")
	_check(not get_tree().paused, "tree unpaused after level-ups")
	_check(applied >= 2, "applied every queued level-up (%d)" % applied)


## Sum of every stat, so any upgrade (radius, regen, exp...) registers.
func _stat_sum(stats: PlayerStats) -> float:
	var total := 0.0
	for stat in PlayerStats.BASE_STATS:
		total += stats.get_stat(stat)
	return total


func _test_death_flow() -> void:
	var director := _director()
	var player: Node2D = _survival.get_node("%player")
	var game_over_ui: CanvasLayer = _survival.get_node("%GameOverUI")

	player.die()
	_check(not player.player_alive, "player marked dead")
	_check(director.game_over, "director registered game over")
	_check(get_tree().paused, "tree paused on death")
	_check(game_over_ui.visible, "game over UI shown")
	get_tree().paused = false
