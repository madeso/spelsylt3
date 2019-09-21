local sti = require "sti"
local bump = require "bump"
local bump_debug = require "bump_debug"
local lume = require "lume"
require "perlin"
perlin:load()

math.randomseed(os.time())
math.random(); math.random(); math.random()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  _   _ _   _ _    __                  _   _
-- | | | | |_(_) |  / _|_   _ _ __   ___| |_(_) ___  _ __  ___
-- | | | | __| | | | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __|
-- | |_| | |_| | | |  _| |_| | | | | (__| |_| | (_) | | | \__ \
--  \___/ \__|_|_| |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
--
-- Util functions

local str = tostring

local xor = function(a,b)
    return not( not( a and not( a and b ) ) and not( b and not( a and b ) ) )
end

local niceval = function(x, max)
  if not x then return "" end
  max = max or 4
  local val = string.format("%.2f", x)
  local c = string.len(val)
  local space = ""
  if c < max then
    space = string.rep(" ", max-c)
  end
  return space .. val
end


local plusminus = function(plus, minus)
  if plus then
    if minus then
      return 0, false
    else
      return 1, true
    end
  end
  if minus then
    return -1, true
  end
  return 0, false
end

local set_color = function(c)
  local m = 255
  local a = 1
  if c.a then
    a = c.a / m
  end
  love.graphics.setColor(c.r/m, c.g/m, c.b/m, a)
end

local draw_centered_text = function(t)
  local font = love.graphics.getFont()
  local tw = font:getWidth(t)
  local th = font:getHeight()
  local ww = love.graphics.getWidth()
  local wh = love.graphics.getHeight()
  local x = (ww-tw)/2
  local y = (wh-th)/2
  love.graphics.print(t, x, y)
end

local from01 = function(min, val, max)
  return val * (max - min) + min
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  ____       _
-- / ___|  ___| |_ _   _ _ __
-- \___ \ / _ \ __| | | | '_ \
--  ___) |  __/ |_| |_| | |_) |
-- |____/ \___|\__|\__,_| .__/
--                      |_|
--
-- Setup

love.graphics.setDefaultFilter("nearest", "nearest")
local sprites = love.graphics.newImage("sprites.png")
local debug_font = love.graphics.newFont("SourceCodePro-Regular.ttf", 14)
local pause_font = love.graphics.newFont("Boxy-Bold.ttf", 100)

if not world then world = {} end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--     _             _ _
--    / \  _   _  __| (_) ___
--   / _ \| | | |/ _` | |/ _ \
--  / ___ \ |_| | (_| | | (_) |
-- /_/   \_\__,_|\__,_|_|\___/
--
-- Audio

local load_sfx = function()
  local sfx = function(p, ext)
    ext = ext or "wav"
    return love.audio.newSource(p .. "." .. ext, "static")
  end

  local sounds = {}
  -- todo: load sounds
  sounds.fallout = sfx("fallout", "ogg")
  sounds.win = sfx("win", "ogg")
  sounds.walk = sfx("step")
  sounds.land = sfx("land")
  sounds.change_dir = sfx("changedir")
  sounds.jump = sfx("jump")
  sounds.land = sfx("land")
  sounds.octdie = sfx("crash")
  sounds.octhurt = sfx("hurt")
  sounds.slash = sfx("jump")
  sounds.semihurt = sfx("semihurt")
  sounds.walljump = sfx("walljump")

  return sounds
end

local sfx = load_sfx()

local playsfx = function(s)
  s:play()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--   ____ _                     _       __ _       _ _   _
--  / ___| | __ _ ___ ___    __| | ___ / _(_)_ __ (_) |_(_) ___  _ __  ___
-- | |   | |/ _` / __/ __|  / _` |/ _ \ |_| | '_ \| | __| |/ _ \| '_ \/ __|
-- | |___| | (_| \__ \__ \ | (_| |  __/  _| | | | | | |_| | (_) | | | \__ \
--  \____|_|\__,_|___/___/  \__,_|\___|_| |_|_| |_|_|\__|_|\___/|_| |_|___/
--
-- Class definitions

local class = {}
class.PLAYER = 1

local player_filter = function(_, other)
  -- false or "cross"
  return "slide"
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  _____                    _
-- |_   _|_      _____  __ _| | _____
--   | | \ \ /\ / / _ \/ _` | |/ / __|
--   | |  \ V  V /  __/ (_| |   <\__ \
--   |_|   \_/\_/ \___|\__,_|_|\_\___/
--
-- Tweaks

local FIXED_STEP = 1/60

local OCT_DAMAGE_MOVE = 80
local OCT_DETECT_X = 250
local OCT_DETECT_Y = 250
local OCT_SPEED = 60
local OCT_ANGRY = 20
local WALLSLIDE_DUST_INTERVAL = 0.15
local BUBBLES_INTERVAL = 2.50
local FALLOUT_TIME = 2
local WIN_TIME = 1.5
local PLAYER_SPEED = 130
local SLASH_TIME = 0.2
local SLASH_VEL = 0.5
local GRAVITY = 350
local JUMP_SPEED = 90
local JUMP_TIME = 0.4
local ON_GROUND_REACTION = 0.1
local GROUND_FRICTION = 2
local AIR_CONTROL = 0.9
local ACCELERATION = 2
local WALLSLIDE = 20
local WALLSLIDE_SPEED = GRAVITY + 10
local WALLJUMP = 80
local WALLJUMP_ACCELERATION = 0.3
local WALK_STEP_TIME = 0.13

local DASH_TIMEOUT = 1
local DASH_JUMP_POWER = -300
local DASH_DY = 800
local DASH_DX = 800
local DASH_MIN_VELY = 240

local CAMERA_FOLLOW_X = 8
local CAMERA_FOLLOW_Y = 8
local CAMERA_MAX_DISTANCE_Y = 80
local CAMERA_PLAYER_MAX_VELY = 750
local CAMERA_MAX_TRANSLATION_SHAKE = 120
local CAMERA_SEED_0 = 100
local CAMERA_SEED_1 = 120
local CAMERA_SEED_2 = 220
local CAMERA_SHAKE_FREQUENCY = 5
local CAMERA_TRAUMA_DECREASE = 0.7


local gids = {}
gids.PLAYER_SPAWN = 4
gids.NEXT_LEVEL = 10
gids.OCT = 16


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--   ____      _
--  / ___|___ | | ___  _ __ ___
-- | |   / _ \| |/ _ \| '__/ __|
-- | |__| (_) | | (_) | |  \__ \
--  \____\___/|_|\___/|_|  |___/
--
-- Colors

local BLACK      = {r=0,   g=0,   b=0  }
local WHITE      = {r=255, g=255, b=255}
local DEFAULT_BG = {r=255, g=255, b=181}
local LIGHT_BG   = WHITE



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  ___                   _
-- |_ _|_ __  _ __  _   _| |_
--  | || '_ \| '_ \| | | | __|
--  | || | | | |_) | |_| | |_
-- |___|_| |_| .__/ \__,_|\__|
--           |_|
--
-- Input

local input = {}
input.debug_draw = false
input.debug_print = false
input.input_left = false
input.input_right = false
input.input_jump = false
input.old_input_jump = false
input.game_is_paused = false
input.game_has_focus = false
input.attack = false


local is_paused = function()
  return not input.game_has_focus or input.game_is_paused
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--   ____                            _
--  / ___| __ _ _ __ ___   ___ _ __ | | __ _ _   _
-- | |  _ / _` | '_ ` _ \ / _ \ '_ \| |/ _` | | | |
-- | |_| | (_| | | | | | |  __/ |_) | | (_| | |_| |
--  \____|\__,_|_| |_| |_|\___| .__/|_|\__,_|\__, |
--                            |_|            |___/
--
-- Gameplay

local current_level = "level1.lua"
local dust_wallslide_timer = 0
local bubbles_timer = 0
local fps = 0
local jump_timer = 0
local slash_timer = -2
local hit_slash = false
local on_ground_timer = 0
local is_walljumping = false
local camera = {x=0, y=0, trauma=0, time=0}
local walk_timer = 0

local perlin_noise = function(x, y)
  if not x then
    print("x is null")
  end
  if not y then
    print("y is null")
  end
  return perlin:noise(x, y, x)
end

local add_trauma = function(val)
  camera.trauma = lume.clamp(camera.trauma + val, 0, 1)
end

local make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

local draw_sprite = function(q, x, y, facing_right)
  local scale_x = 1
  local offset_x = 0
  if not facing_right then
    scale_x = -1
    offset_x = 32
  end
  love.graphics.draw(sprites, q, x + offset_x, y, 0, scale_x, 1)
end

local animation_index = 0

local make_animation = function(frames, speed)
  local anim = {}
  anim.id = animation_index
  animation_index = animation_index + 1
  anim.sprites = {}
  for i, f in ipairs(frames) do
    anim.sprites[i] = make_sprite(f - 1)
  end
  anim.time = 0
  anim.speed = speed
  anim.current_frame = 1
  return anim
end


local step_animation = function(anim, dt)
  anim.time = anim.time + dt
  while anim.time > anim.speed do
    anim.time = anim.time - anim.speed
    anim.current_frame = anim.current_frame + 1
    if anim.current_frame > #anim.sprites then
      anim.current_frame = 1
    end
  end
end

local reset_animation = function(anim, t)
  anim.current_frame = 1
  if t == nil then
    anim.time = 0
  else
    anim.time = t
  end
end

local draw_animation = function(anim, x, y, facing_right)
  if not anim then return end
  local sprite = anim.sprites[anim.current_frame]
  draw_sprite(sprite, x, y, facing_right)
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--     _          _                 _   _
--    / \   _ __ (_)_ __ ___   __ _| |_(_) ___  _ __  ___
--   / _ \ | '_ \| | '_ ` _ \ / _` | __| |/ _ \| '_ \/ __|
--  / ___ \| | | | | | | | | | (_| | |_| | (_) | | | \__ \
-- /_/   \_\_| |_|_|_| |_| |_|\__,_|\__|_|\___/|_| |_|___/
--
-- Animations
local anim = {}
-- animations are based on 1, sprites are based on 0
anim.idle = make_animation({1, 2, 3, 2}, 0.45)
anim.run = make_animation({4, 1, 5, 1}, 0.10)
anim.jump = make_animation({4}, 0.45)
anim.fall = make_animation({4}, 0.45)
anim.halt = make_animation({5}, 0.45)
anim.wall = make_animation({6}, 0.45)
anim.slash = make_animation({17, 18}, 0.1)

local dust = love.graphics.newParticleSystem(sprites)
dust:setParticleLifetime(0.5, 1)
dust:setQuads(make_sprite(6), make_sprite(7), make_sprite(8), make_sprite(9))
dust:setOffset(0, 0)

local bubbles = love.graphics.newParticleSystem(sprites)
bubbles:setParticleLifetime(4, 9)
bubbles:setQuads(make_sprite(12), make_sprite(11), make_sprite(10))
bubbles:setOffset(0, 0)
bubbles:setSpeed(3,13)
bubbles:setDirection(-math.pi/2)
bubbles:setAreaSpread('normal', 4, 4)
bubbles:setColors(1,1,1,1,  1,1,1,1,  1,1,1,1,    1,1,1,0)

local dashes = love.graphics.newParticleSystem(sprites)
dashes:setParticleLifetime(2.5, 3)
dashes:setQuads(make_sprite(25))
dashes:setOffset(16,16)
dashes:setLinearDamping(0.01)
dashes:setSpeed(3, 13)
dashes:setRotation(0, math.pi / 4)
dashes:setSpin(0, math.pi / 4)
dashes:setSpinVariation(1)
dashes:setSizes(0.5, 2.0)
dashes:setSpread(math.pi * 2)
dashes:setEmissionArea("normal", 5, 5)
local pwhite = {1, 1, 1, 1}
local ptrans = {1, 1, 1, 0}
dashes:setColors(pwhite, pwhite, pwhite, ptrans)

local spawn_dust_at_feet = function()
  local dx
  local step = 15
  if player.facing_right then
    dx = step
  else
    dx = -step
  end
  dust:setPosition(player.x + dx, player.y)
  dust:emit(1)
end

local spawn_some_bubbles = function()
  bubbles:setPosition(player.x - 6, player.y - 13)
  bubbles:emit(3)
end

local dustwave = function(a, b)
  dust:setSpeed(300, 490)
  dust:setLinearDamping(10)
  dust:setDirection(a)
  dust:emit(2)
  dust:setDirection(b)
  dust:emit(2)
  dust:setSpeed(0,0)
end

local add_dust_floor = function()
  dust:setPosition(player.x, player.y+10)
  dustwave(0, math.pi)
end

local add_dust_wall = function()
  local dx
  local step = 9
  if not player.facing_right then
    dx = -step
  else
    dx = step
  end
  dust:setPosition(player.x + dx, player.y)
  dustwave(-math.pi/2, math.pi/2)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--   ____                                      _
--  / ___| __ _ _ __ ___   ___    ___ ___   __| | ___
-- | |  _ / _` | '_ ` _ \ / _ \  / __/ _ \ / _` |/ _ \
-- | |_| | (_| | | | | | |  __/ | (_| (_) | (_| |  __/
--  \____|\__,_|_| |_| |_|\___|  \___\___/ \__,_|\___|
--
-- Game code

local maxy = 0
local capture_y = true

local draw_debug_text = function()
  local y = 10
  local text = function(t)
    local x = 10
    local f = love.graphics.getFont()
    local h = f:getHeight()
    local w = f:getWidth(t)
    local padding = 3
    set_color(LIGHT_BG)
    love.graphics.rectangle("fill", x-padding, y-padding, w+padding*2, h+padding*2)
    set_color(BLACK)
    love.graphics.print(t, x, y)
    y = y + h + padding*3
  end
  love.graphics.setFont(debug_font)
  text("FPS: " .. str(math.ceil(fps)))
  text("Y: " .. niceval(maxy, 6) .. " / " .. niceval(player.vely, 7))
  text("Jump timer: " .. niceval(jump_timer))
  text("On ground: " .. niceval(on_ground_timer))
  text("Hor move: " .. niceval(player.velx, 5))
  text("Trauma: " .. niceval(camera.trauma))
  text("Right: " .. str(player.facing_right))
  text("Reset timer: " .. niceval(player.reset_timer))
  text("Y: " .. niceval(player.y) .. " / " .. niceval(camera.y))
end

local octdefs = {}

local load_spawn_positions = function()
  if not world.level_gfx then return end

  if not start_position then start_position = {x=0, y=0} end

  octdefs = {}

  local spawn = world.level_gfx.layers["spawn"]
  if spawn then
    for _,o in ipairs(spawn.objects) do
      if o.gid == gids.PLAYER_SPAWN then
        start_position.x = o.x
        start_position.y = o.y - 32
      elseif o.gid == gids.NEXT_LEVEL then
        print("got next level")
      elseif o.gid == gids.OCT then
        local oct = {}
        oct.x = o.x
        oct.y = o.y
        table.insert(octdefs, oct)
      else
        print("Invalid gid: ", o.gid)
      end
    end
  end
end

load_spawn_positions()


local load_level = function()
  print("loading level " .. current_level)
  if not player then player = {} end
  octs = {}
  world.level_gfx = sti(current_level, {"bump"})
  world.level_collision = bump.newWorld(32 * 2)
  world.col = world.level_gfx.layers["col"]
  camera.time = 0
  load_spawn_positions()
  player.x, player.y = start_position.x, start_position.y
  camera.x, camera.y = start_position.x, start_position.y
  player.is_alive = true
  player.reset_timer = 0
  player.next_level = false
  player.vely = 0
  player.facing_right = true
  -- todo: setup player collision box
  world.level_collision:add(player, player.x, player.y, 16, 30)
  world.level_gfx:bump_init(world.level_collision)
  for _, d in ipairs(octdefs) do
    local o = {}
    o.x = d.x
    o.y = d.y
    o.anim = make_animation({16, 14, 16, 15}, 0.3)
    o.right = false
    reset_animation(o.anim, math.random())
    table.insert(octs, o)
    o.timer = -1
    o.active = false
    o.angry = false
    o.atimer = math.random() * OCT_ANGRY
    o.px = 0
    o.py = 0
    o.hurt = -1
    o.rightkick = true
    o.health = 3
    o.alive = true
  end

  -- reset data
  camera.time = 0
  player.x = start_position.x
  player.y = start_position.y
  world.level_collision:update(player, player.x, player.y)
  camera.target_x = player.x
  camera.target_y = player.y
  camera.x = player.x
  camera.y = player.y
  player.velx = 0
  player.vely = 0
  player.facing_right = true
  jump_timer = JUMP_TIME + 1
  player.reset_timer = 0
  player.is_alive = true
  player.next_level = false
end


local onkey = function(key, down)
  if key == "left" then
    input.input_left = down
  end
  if key == "right" then
    input.input_right = down
  end
  if key == "up" then
    input.input_jump = down
  end
  if key == "p" and down then
    input.game_is_paused = not input.game_is_paused
  end
  if key == "1" and down then
    input.debug_draw = not input.debug_draw
  end
  if key == "2" and down then
    input.debug_print = not input.debug_print
  end
  if key == "3" and down then
    load_level()
  end
  if key == "x" and down then
    add_trauma(0.3)
  end
  if key == "c" and down then
    input.attack = true
    playsfx(sfx.slash)
  end
end

local kill_player = function()
  player.is_alive = false
  player.reset_timer = FALLOUT_TIME
  playsfx(sfx.fallout)
end

local within_range = function(x, y, ox, oy, rx, ry)
  local within_x = x > ox - rx/2 and x < ox + rx/2
  local within_y = y > oy - ry/2 and y < oy + ry/2
  return within_x and within_y
end

local player_update = function(dt)
  local handle_player_collision = function(objects)
    local r = false
    for _, c in ipairs(objects) do
      if c.other.class then
        print("player collided with " .. str(c.other))
      elseif not c.other.class then
        r = true
      end
    end
    return r
  end

  if not player.is_alive then
    return
  end

  if player.next_level then
    return
  end

  -- make sure velocity is not nil
  if not player.vely then player.vely = 0 end
  if not player.velx then player.velx = 0 end
  if not player.animation then player.animation = anim.idle end

  step_animation(player.animation, dt)
  for _, o in ipairs(octs) do
    if o.anim then
      step_animation(o.anim, dt)
    end
    if not o.active then
      if within_range(player.x, player.y, o.x, o.y, OCT_DETECT_X, OCT_DETECT_Y) then
        o.active = true
      end
    end
    if o.active and o.health > 0 then
      if slash_timer > 0 then
        local dx = 0
        if player.facing_right then
          dx = 8
          dy = 0
        else
          dx = -25
        end
        if within_range(player.x + dx, player.y, o.x, o.y, 16,16) then
          hit_slash = true
          player.vely = 0
          if o.hurt < 0 then
            o.hurt = 0.4
            o.health = o.health - 1
            o.rightkick = player.facing_right
            if o.health <= 0 then
              playsfx(sfx.octdie)
            else
              playsfx(sfx.octhurt)
            end
          end
        end
      end
      if o.hurt > 0 then
        o.hurt = o.hurt - dt
        local dx = -OCT_DAMAGE_MOVE
        if o.rightkick then
          dx = -dx
        end
        o.x = o.x + dx * dt
      else
        o.timer = o.timer - dt
        o.atimer = o.atimer - dt
        if o.atimer < 0 then
          o.angry = not o.angry
          if o.angry then
            o.atimer = math.random()*10
          else
            o.atimer = math.random()*OCT_ANGRY
          end
        end
        if o.timer < 0 then
          o.timer = o.timer + 0.5 + math.random()*4
          o.px = player.x
          o.py = player.y
        end
        local tx = o.px - o.x
        local ty = o.py - o.y
        local l = math.sqrt(tx*tx + ty*ty)
        if l > 8 then
          local os = 1
          if o.angry then
            os = 3
          end
          o.x = o.x + (tx/l)*OCT_SPEED*dt*os
          o.y = o.y + (ty/l)*OCT_SPEED*dt*os
          o.right = tx > 0
        end
      end
    end
  end

  if slash_timer >= 0 then
    slash_timer = slash_timer - dt
  end

  if input.attack then
    slash_timer = SLASH_TIME
  end
  input.attack = false

  if slash_timer > 0 then
    step_animation(anim.slash, dt)
    if player.facing_right then
      player.velx = SLASH_VEL
    else
      player.velx = -SLASH_VEL
    end
  else
    hit_slash = false
  end

  if input.input_dash and not input.old_input_dash and on_ground_timer > 0.1 and not player.is_wallsliding then
    if player.vely < DASH_MIN_VELY then
      player.dash_state = DASH_HOLD
      player.dash_timer = 0
      player.vely = 0
      player.velx = 0
      input.input_dash = false
      input.input_jump = false
      capture_y = true
      maxy = 0
      jump_timer = JUMP_TIME + 1
      playsfx(sfx.dash_ready)
    else
      print("Too high vely: " .. str(player.vely))
      playsfx(sfx.dash_timeout)
    end
  end

  if player.dash_state == DASH_NONE then
    if slash_timer > 0 and hit_slash then
      -- nop
    else
      player.vely = player.vely + GRAVITY * dt
    end

    if input.input_jump and jump_timer < JUMP_TIME then
      if not is_walljumping then
        player.vely = -JUMP_SPEED
        if not input.old_input_jump then
          playsfx(sfx.jump)
        end
      else
        player.vely = -WALLJUMP
      end
    end
    -- increase jump timer or set it beyond the max when released, so release+hold wont rejump
    if input.input_jump then
      jump_timer = jump_timer + dt
      capture_y = true
      maxy = 0
    else
      jump_timer = JUMP_TIME + 1
    end
  elseif player.dash_state == DASH_HOLD then
    player.dash_timer = player.dash_timer + dt
    if player.dash_timer > DASH_TIMEOUT then
      print("dash timeout")
      player.dash_state = DASH_NONE
      playsfx(sfx.dash_timeout)
    end
  elseif player.dash_state == DASH_DASH then
    dashes:moveTo(player.x, player.y)
    dashes:emit(2)
  else
    print("Unknown dash state: " .. str(player.dash_state))
    player.dash_state = DASH_NONE
  end




  ----------- vertical movment:
  local ground_collision_objects
  local the_ground_collision_count
  player.x, player.y, ground_collision_objects, the_ground_collision_count = world.level_collision:move(player, player.x, player.y + player.vely*dt, player_filter)
  local collided_with_y = handle_player_collision(ground_collision_objects, the_ground_collision_count)
  local is_on_ground = collided_with_y and player.vely >= 0
  player.is_on_ground = is_on_ground
  if is_on_ground then
    if player.vely > 100 then
      print("landed: " .. str(player.vely))
      add_dust_floor()
      playsfx(sfx.land)
    end
    on_ground_timer = 0
    is_walljumping = false
  else
    on_ground_timer = on_ground_timer + dt
  end
  if capture_y then
    maxy = math.max(maxy, player.vely)
  end
  if is_on_ground then
    capture_y = false
  end
  if collided_with_y then
    player.vely = 0
    jump_timer = JUMP_TIME + 1
  end
  -- if we was on the ground recently and we are not pressing the jump button
  if on_ground_timer < ON_GROUND_REACTION and not input.input_jump then
    jump_timer = 0
  end

  -------------- horizontal movment:
  local input_movement, has_moved_hor = plusminus(input.input_right, input.input_left)
  if player.dash_state == DASH_NONE then
    local control = 1
    if has_moved_hor then
      if input_movement > 0 then
        player.facing_right = true
      else
        player.facing_right = false
      end
    end
    if not is_on_ground then
      control = AIR_CONTROL
    end
    if has_moved_hor then
      player.velx = lume.clamp(player.velx + control * ACCELERATION * input_movement * dt, -1, 1)
    else
      -- decrease horizontal movment if no input is hold
      if math.abs(player.velx) > 0 and is_on_ground then
        local change = GROUND_FRICTION * dt
        if math.abs(player.velx) < change then
          player.velx = 0
        else
          if player.velx > 0 then
            player.velx = player.velx - change
          else
            player.velx = player.velx + change
          end
        end
      end
    end

    local the_hor_collision_count
    local hor_collision_objects
    player.x, player.y, hor_collision_objects, the_hor_collision_count = world.level_collision:move(player, player.x + player.velx * PLAYER_SPEED * dt, player.y, player_filter)
    local touches_wall = handle_player_collision(hor_collision_objects, the_hor_collision_count)

    if touches_wall then
      player.velx = 0
    end

    local sliding = false
    if has_moved_hor and touches_wall and player.vely > WALLSLIDE then
      player.vely = player.vely - WALLSLIDE_SPEED * dt
      sliding = true
      if player.vely <= WALLSLIDE then
        player.vely = WALLSLIDE
      end
    end

    player.is_wallsliding = sliding
    player.is_walljumping = false

    if sliding then
      dust_wallslide_timer = dust_wallslide_timer + dt
      while dust_wallslide_timer > WALLSLIDE_DUST_INTERVAL do
        spawn_dust_at_feet()
        dust_wallslide_timer = dust_wallslide_timer - WALLSLIDE_DUST_INTERVAL
      end
    end

    if player.is_wallsliding and input.input_jump then
      player.is_wallsliding = false
      player.is_walljumping = true
      playsfx(sfx.walljump)
      add_dust_wall()
      jump_timer = 0
      is_on_ground = false
      player.vely = WALLJUMP
      is_walljumping = true
      if input_movement > 0 then
        player.velx = -WALLJUMP_ACCELERATION
      else
        player.velx = WALLJUMP_ACCELERATION
      end
    end

    -- this if stops the infinite-jump when holding down the jump button
    if input.input_jump and jump_timer > JUMP_TIME then
      input.input_jump = false
    end
  elseif player.dash_state == DASH_HOLD then
    if has_moved_hor and not input.last_moved_hor then
      playsfx(sfx.dash)
      if input_movement > 0 then
        player.facing_right = true
      else
        player.facing_right = false
      end
      player.dash_state = DASH_DASH
    end
  elseif player.dash_state == DASH_DASH then
    local dash_dx = DASH_DX
    if not player.facing_right then
      dash_dx = -dash_dx
    end
    local collision_data
    local the_dash_collision_count
    player.x, player.y, collision_data, the_dash_collision_count = world.level_collision:move(player, player.x + dash_dx * dt, player.y + DASH_DY * dt, player_filter)
    local collided_with_dash = handle_player_collision(collision_data, the_dash_collision_count)

    if collided_with_dash then
      add_trauma(0.7)
      playsfx(sfx.crash)
      camera.target_x = player.x
      camera.target_y = player.y
      player.dash_state = DASH_NONE
      player.vely = DASH_JUMP_POWER
      local was_wall = math.abs(collision_data[1].normal.x) > 0.5
      if xor(player.facing_right, was_wall) then
        player.velx = 1
      else
        player.velx = -1
      end
      if was_wall then
        add_dust_wall()
      else
        add_dust_floor()
      end
    end
  else
    print("invalid dash state " .. str(player.dash_state))
  end

  --------- spawn some bubbles
  bubbles_timer = bubbles_timer + dt
  if has_moved_hor then
    bubbles_timer = bubbles_timer + 6*dt
  end
  if bubbles_timer > BUBBLES_INTERVAL then
    bubbles_timer = bubbles_timer - BUBBLES_INTERVAL
    spawn_some_bubbles()
  end

  local halt = (input_movement > 0 and player.velx < 0) or (input_movement < 0 and player.velx > 0)
  local last_halt = player.halt
  player.halt = halt

  dust:setPosition(player.x, player.y+10)
  if not halt and not player.is_wallsliding and has_moved_hor and is_on_ground then
    walk_timer = walk_timer + dt
    if walk_timer > WALK_STEP_TIME then
      walk_timer = walk_timer - WALK_STEP_TIME
      playsfx(sfx.walk)
      dust:emit(1)
    end
  end

  if is_on_ground and halt and not last_halt then
    playsfx(sfx.change_dir)
    if not player.facing_right then
      dust:setDirection(0)
    else
      dust:setDirection(math.pi)
    end
    dust:setSpeed(490)
    dust:setLinearDamping(10)
    dust:emit(1)
    dust:setSpeed(0,0)
  end

  if player.y > world.col.height * 32 then
    kill_player()
  end

  if player.x > world.col.width * 32 then

    player.next_level = true
    player.reset_timer = WIN_TIME
    playsfx(sfx.win)
  end

  -- determine player animation
  local set_animation = function(o, an)
    if o.anim_state ~= an.id then
      o.animation = an
      o.anim_state = an.id
      reset_animation(o.animation)
    end
  end

  -- set player animation
  if player.dash_state == DASH_NONE then
    if is_on_ground then
      if has_moved_hor then
        if halt then
          set_animation(player, anim.halt)
        else
          set_animation(player, anim.run)
        end
      else
        set_animation(player, anim.idle)
      end
    else
      if player.is_wallsliding then
        set_animation(player, anim.wall)
      else
        if player.vely < 0 then
          set_animation(player, anim.jump)
        else
          set_animation(player, anim.fall)
        end
      end
    end
  elseif player.dash_state == DASH_HOLD then
    set_animation(player, anim.dash_hold)
  else
    set_animation(player, anim.dash)
  end
end


local camera_update = function(dt)
  if not camera.target_x then camera.target_x = camera.x end
  if not camera.target_y then camera.target_y = camera.x end

  local camera_follow_y = CAMERA_FOLLOW_Y

  camera.time = camera.time + dt
  camera.trauma = lume.clamp(camera.trauma - dt * CAMERA_TRAUMA_DECREASE, 0, 1)

  if player.is_on_ground then
    camera.target_y = player.y
  end

  if math.abs(player.vely) > CAMERA_PLAYER_MAX_VELY then
    camera.target_y = player.y
    camera_follow_y = 30
  end

  if player.is_wallsliding and math.abs(camera.target_y - player.y) > CAMERA_MAX_DISTANCE_Y and player.y > camera.target_y then
    print("target: " .. str(camera.target_y))
    print("player: " .. str(player.y))
    camera.target_y = player.y
  end

  if player.is_walljumping then
    camera.target_y = player.y
  end

  camera.target_x = player.x

  camera.x = camera.x + (camera.target_x - camera.x) * lume.clamp(CAMERA_FOLLOW_X * dt, 0, 1)
  camera.y = camera.y + (camera.target_y - camera.y) * lume.clamp(camera_follow_y * dt, 0, 1)


  local ww = love.graphics.getWidth()
  local wh = love.graphics.getHeight()
  camera.x = lume.clamp(camera.x, ww/4, world.col.width * 32 - ww/4)
  camera.y = lume.clamp(camera.y, wh/4, world.col.height * 32 - wh/4)
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  _                               _ _ _                _
-- | |    _____   _____    ___ __ _| | | |__   __ _  ___| | _____
-- | |   / _ \ \ / / _ \  / __/ _` | | | '_ \ / _` |/ __| |/ / __|
-- | |__| (_) \ V /  __/ | (_| (_| | | | |_) | (_| | (__|   <\__ \
-- |_____\___/ \_/ \___|  \___\__,_|_|_|_.__/ \__,_|\___|_|\_\___/
--
-- Love callbacks

love.draw = function()
  local set_background = function(c)
    local max = 255
    love.graphics.setBackgroundColor(c.r/max, c.g/max, c.b/max)
  end
  set_background(DEFAULT_BG)
  set_color(WHITE)
  local zoom = 2
  local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
  local camera_shake = camera.trauma * camera.trauma
  local offset_x = camera_shake * CAMERA_MAX_TRANSLATION_SHAKE * perlin_noise(camera.time * CAMERA_SHAKE_FREQUENCY, CAMERA_SEED_0)
  local offset_y = camera_shake * CAMERA_MAX_TRANSLATION_SHAKE * perlin_noise(camera.time * CAMERA_SHAKE_FREQUENCY, CAMERA_SEED_1)
  local camera_x, camera_y = (offset_x + camera.x) * zoom - window_width / 2, (offset_y + camera.y) * zoom - window_height/2
  local angle = 0.5 * math.pi/2 * camera_shake * perlin_noise(camera.time * CAMERA_SHAKE_FREQUENCY, CAMERA_SEED_2)

  love.graphics.push()
  love.graphics.translate(window_width/2, window_height/2)
  love.graphics.rotate(angle)
  love.graphics.translate(-window_width/2, -window_height/2)
  love.graphics.translate(math.floor(-camera_x), math.floor(-camera_y))
  love.graphics.scale(zoom, zoom)
  if input.debug_draw then
    bump_debug.draw(world.level_collision)
  end
  local para = world.level_gfx.layers["parallax"]
  if para then
    love.graphics.push()
    local px = camera.x / (world.col.width * 32)
    local py = camera.y / (world.col.height * 32)
    local extent = 640
    love.graphics.translate(math.floor(px * extent), math.floor(py * extent / 2))
    world.level_gfx:drawLayer(para)
    love.graphics.pop()
  end
  world.level_gfx:drawLayer(world.level_gfx.layers["col"])
  local detail_layer = world.level_gfx.layers["detail"]
  if detail_layer then
    world.level_gfx:drawLayer(detail_layer)
  end
  love.graphics.draw(dashes, 0,0)
  for _, o in ipairs(octs) do
    if o.health > 0 then
      draw_animation(o.anim, o.x, o.y, o.right)
    end
  end
  draw_animation(player.animation, player.x-8, player.y, player.facing_right)
  love.graphics.draw(dust, 0, 0)
  love.graphics.draw(bubbles, 0, 0)
  if slash_timer > 0 then
    local dx = 0
    local dy = 0
    if player.facing_right then
      dx = 8
      dy = 0
    else
      dx = -25
    end
    draw_animation(anim.slash, player.x + dx, player.y + dy, player.facing_right)
  end
  love.graphics.pop()
  if is_paused() then
    love.graphics.setFont(pause_font)
    set_color(WHITE)
    -- love.graphics.print("PAUSED", 100, 100)
    draw_centered_text("PAUSED")
  end
  if not player.is_alive then
    love.graphics.setFont(pause_font)
    draw_centered_text("game over")
  end
  if player.next_level then
    love.graphics.setFont(pause_font)
    draw_centered_text("good job")
  end
  if input.debug_print then
    draw_debug_text()
  end
end

local dtsum = 0
love.update = function(dt)
  if dt > 0 then
    fps = 1/dt
  end
  dtsum = dtsum + dt
  while dtsum > FIXED_STEP do
    dtsum = dtsum - FIXED_STEP
    dust:update(FIXED_STEP)
    bubbles:update(FIXED_STEP)
    dashes:update(FIXED_STEP)
    if not is_paused() then
      if not player.is_alive or player.next_level then
        player.reset_timer = player.reset_timer - FIXED_STEP
        if player.reset_timer < 0 then
          load_level()
        end
      end
      player_update(FIXED_STEP)
      camera_update(FIXED_STEP)
      input.old_input_jump = input.input_jump
      input.old_input_dash = input.input_dash
      _, input.last_moved_hor = plusminus(input.input_left, input.input_right)
    end
  end
  require("lurker").update()
end

love.keypressed = function(key)
  onkey(key, true)
end

love.keyreleased = function(key)
  onkey(key, false)
end

love.focus = function(f)
  print("Focus " .. str(f))
  input.game_has_focus = f
end


if not player then
  player = {x=0, y=0, vely=0, facing_right=true, animation=nil, reset_timer=0, is_alive=true, next_level=false}
  player.__tostring = function() return "struct Player" end
end

if not world.level_gfx then
  load_level()
end

camera.x = player.x
camera.y = player.y
camera.target_x = player.x
camera.target_y = player.y

player.class = class.PLAYER
