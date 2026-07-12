[x] ui de vida
[x] ui de colores
[~] poder hacer parry a los proyectiles y que te den colores
[ ] proyectiles viniendo por la derecha que le hacen daño al jugadore
[ ] poder disparar colores (gastas 1 de municion de cada color que uses)
[ ] little big endian mode te invierten las stats porque todo se interpreta al reves
[ ] intercambio de parrybox con la outerbox de la hitbox con tu outerbox en plan que te pegan mas facil o te hace mas facil el parry

refactor
[ ] rotation or any other kind of rendering changing values 
    should go inside the Entity struct

[ ] change the collision detection to be more automatic, like
    just having an array of entities in the game state, and each update check for all the kind of collisions, and if there are just update those states, like having detected if any of the player projectiles collide with the enemies ones or with the main enemy, that being done in just one loop makes the handling of the states way easier
    automatically remove entities from entities array (mark them as offs_screen or something)

[ ] make animation package be easier to use 
    like in the render just do something like
    switch (player.state) {
    case .DYING: 
        render_animation(g.player.animations, "dying")
    case .FLYING: 
        render_animation(g.player.animations, "flying")
    case .PARRYING: 
        render_animation(g.player.animations, "parrying")
    }
    the animations package just stores the animations in a hashmap with their name, which are registered when the game initalizes
