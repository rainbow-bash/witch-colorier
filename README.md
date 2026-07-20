
## parry detector
```odin
	g.player.rects.parry.is_colliding = false
	g.player.rects.parry.last_collision = time.Time{}

	g.player.collided_with = nil
	{
		// colliding_entity: ^Entity
		last_collision: time.Time
		is_colliding := false
		collided_with: [dynamic]^Projectile

		for &p in g.projectiles {
			is, lc := entity_check_collision(
				&g.player.entity, //
				&g.player.rects.parry,
				&p,
				&p.rects.core,
			)
			if is {
				last_collision = lc
				is_colliding = is
				append(&collided_with, &p)
			}
		}
		g.player.rects.parry.is_colliding = is_colliding
		g.player.rects.parry.last_collision = last_collision
		for ent in collided_with {
			append(&g.player.collided_with, ent)
		}
	}
	{
		last_collision: time.Time
		is_colliding := false
		rect := &g.player.rects.outermost
		collided_with: [dynamic]^Projectile
		for &p in g.projectiles {
			is, lc := entity_check_collision(
				&g.player.entity, //
				rect,
				&p,
				&p.rects.core,
			)
			if is {
				is_colliding = is
				last_collision = lc
				append(&collided_with, &p)
			}
		}
		rect.is_colliding = is_colliding
		rect.last_collision = last_collision
		for ent in collided_with {
			append(&g.player.collided_with, ent)
		}
	}

	parry_dt := time.since(g.player.rects.parry.last_collision)
	core_parry_dt := time.since(g.player.rects.core.last_collision)

	can_parry :=
		(parry_dt < 300 * time.Millisecond && g.player.rects.parry.is_colliding) ||
		(core_parry_dt < 100 * time.Millisecond && g.player.rects.core.is_colliding)

	g.player.flags.can_parry = can_parry
```


## movement for other entities
```odin
	for &p in g.projectiles {
		entity_update_position(&p.entity, {-p.auto_speed.x, 0})
	}

	for &a in g.player.attacks {
		entity_update_position(&a.entity, {a.auto_speed.x, 0})
		a.rotation = f32((int(a.rotation + 1)) % 360)
	}
```
