addon.name = 'chainbuilder';
addon.author = 'Laudout';
addon.version = '2.4.0';
addon.desc = 'ChainBuilder skillchain calculator.';
addon.link = '';

require 'common';

local imgui = require 'imgui';
local d3d = require 'd3d8';
local ffi = require 'ffi';

-- ChainBuilder banner - Ashita v4 / D3D8 texture loading.
local C = ffi.C;
local d3d8dev = d3d.get_device();
local banner = nil;
local banner_size = { 644, 177 };

local function load_banner()
    if banner ~= nil then return banner; end

    local path = addon.path .. '/images/header.png';
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');

    if C.D3DXCreateTextureFromFileA(d3d8dev, path, texture_ptr) ~= C.S_OK then
        return nil;
    end

    banner = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
    return banner;
end

local function to_texture_id(texture)
    if texture == nil then return 0; end

    local ok, id = pcall(function()
        return tonumber(ffi.cast('uint32_t', texture));
    end);
    if ok and type(id) == 'number' then return id; end

    ok, id = pcall(function()
        return tonumber(ffi.cast('uintptr_t', texture));
    end);
    if ok and type(id) == 'number' then return id; end

    return 0;
end



--[[
    Commands:
      /sc
      /sc show
      /sc hide
--]]

local state = {
    visible = { false },
    weapon = 'Great Katana',
    start_ws = 'Tachi: Kasha',
    target = 'Any',
    closer_weapon = 'Sword',
    depth = { 5 },
};

-- Skillchain result lookup.
-- Key format: opener_property .. '>' .. closer_property
local links = {
    -- Level 1
    ['Compression>Transfixion']='Transfixion',
    ['Transfixion>Compression']='Compression',
    ['Scission>Liquefaction']='Liquefaction',
    ['Liquefaction>Scission']='Scission',
    ['Transfixion>Reverberation']='Reverberation',
    ['Scission>Reverberation']='Reverberation',
    ['Reverberation>Induration']='Induration',
    ['Compression>Detonation']='Detonation',
    ['Scission>Detonation']='Detonation',
    ['Impaction>Detonation']='Detonation',
    ['Induration>Compression']='Compression',
    ['Reverberation>Impaction']='Impaction',
    ['Induration>Impaction']='Impaction',
    ['Liquefaction>Impaction']='Fusion',
    ['Detonation>Compression']='Gravitation',
    ['Transfixion>Scission']='Distortion',
    ['Induration>Reverberation']='Fragmentation',

    -- Level 2
    ['Gravitation>Fragmentation']='Fragmentation',
    ['Fragmentation>Distortion']='Distortion',
    ['Distortion>Fusion']='Fusion',
    ['Fusion>Gravitation']='Gravitation',
    ['Fusion>Fragmentation']='Light',
    ['Fragmentation>Fusion']='Light',
    ['Gravitation>Distortion']='Darkness',
    ['Distortion>Gravitation']='Darkness',

    -- Level 3 continuation
    ['Light>Light']='Light II',
    ['Darkness>Darkness']='Darkness II',
};

-- Core 75-era weapon skills.  The data table is deliberately easy to edit.
-- Properties are in game priority order.
local ws = {

    ['Summoner Pet'] = {
        {'Punch', {'Liquefaction'}},
        {'Rock Throw', {'Scission'}},
        {'Barracuda Dive', {'Reverberation'}},
        {'Claw', {'Detonation'}},
        {'Welt', {'Scission'}},
        {'Axe Kick', {'Induration'}},
        {'Shock Strike', {'Impaction'}},
        {'Camisado', {'Compression'}},
        {'Regal Scratch', {'Scission'}},
        {'Poison Nails', {'Transfixion'}},
        {'Moonlit Charge', {'Compression'}},
        {'Crescent Fang', {'Transfixion'}},
        {'Rock Buster', {'Reverberation'}},
        {'Burning Strike', {'Impaction'}},
        {'Roundhouse', {'Detonation'}},
        {'Tail Whip', {'Detonation'}},
        {'Double Punch', {'Compression'}},
        {'Megalith Throw', {'Induration'}},
        {'Double Slap', {'Scission'}},
        {'Eclipse Bite', {'Gravitation','Scission'}},
        {'Flaming Crush', {'Fusion','Reverberation'}},
        {'Mountain Buster', {'Gravitation','Induration'}},
        {'Spinning Dive', {'Distortion','Detonation'}},
        {'Predator Claws', {'Fragmentation','Scission'}},
        {'Rush', {'Distortion','Scission'}},
        {'Chaotic Strike', {'Fragmentation','Transfixion'}},
    },

    ['Scholar Magic'] = {
        {'Fire', {'Liquefaction'}},
        {'Earth', {'Scission'}},
        {'Water', {'Reverberation'}},
        {'Wind', {'Detonation'}},
        {'Ice', {'Induration'}},
        {'Thunder', {'Impaction'}},
        {'Light', {'Transfixion'}},
        {'Dark', {'Compression'}},
    },

    ['Blue Magic'] = {
        {'Final Sting', {'Fusion'}},
        -- Complete level 1-75 physical Blue Magic skillchain-property list.
        -- These are available as a closer-only Step 2 option when Step 1 is Sword or Club.
        -- Chain Affinity / Azure Lore is required in-game for the spell to participate in a skillchain.
        {'Foot Kick', {'Detonation'}},
        {'Power Attack', {'Reverberation'}},
        {'Sprout Smack', {'Reverberation'}},
        {'Wild Oats', {'Transfixion'}},
        {'Queasyshroom', {'Compression'}},
        {'Battle Dance', {'Impaction'}},
        {'Head Butt', {'Impaction'}},
        {'Feather Storm', {'Transfixion'}},
        {'Helldive', {'Transfixion'}},
        {'Bludgeon', {'Liquefaction'}},
        {'Claw Cyclone', {'Scission'}},
        {'Screwdriver', {'Transfixion','Scission'}},
        {'Grand Slam', {'Induration'}},
        {'Smite of Rage', {'Detonation'}},
        {'Pinecone Bomb', {'Liquefaction'}},
        {'Jet Stream', {'Impaction'}},
        {'Uppercut', {'Liquefaction','Impaction'}},
        {'Terror Touch', {'Compression','Reverberation'}},
        {'Mandibular Bite', {'Induration'}},
        {'Sickle Slash', {'Compression'}},
        {'Death Scissors', {'Compression','Reverberation'}},
        {'Dimensional Death', {'Transfixion','Impaction'}},
        {'Spiral Spin', {'Transfixion'}},
        {'Seedspray', {'Induration','Detonation'}},
        {'Body Slam', {'Impaction'}},
        {'Frenetic Rip', {'Induration'}},
        {'Frypan', {'Impaction'}},
        {'Hydro Shot', {'Reverberation'}},
        {'Spinal Cleave', {'Scission','Detonation'}},
        {'Hysteric Barrage', {'Detonation'}},
        {'Tail Slap', {'Reverberation'}},
        {'Asuran Claws', {'Liquefaction','Impaction'}},
        {'Cannonball', {'Fusion'}},
        {'Disseverment', {'Distortion'}},
        {'Sub-zero Smash', {'Fragmentation'}},
        {'Ram Charge', {'Fragmentation'}},
        {'Vertical Cleave', {'Gravitation'}},
        -- CatsEyeXI custom level-75 physical Blue Magic additions.
        {'Quadratic Continuum', {'Distortion'}},
        {'Empty Thrash', {'Compression','Scission'}},
        {'Heavy Strike', {'Fragmentation'}},
        {'Barbed Crescent', {'Distortion','Scission'}},
    },

    ['Automaton'] = {
        {'Slapstick', {'Reverberation','Impaction'}},
        {'Knockout', {'Scission','Detonation'}},
        {'Magic Mortar', {'Fusion'}},
        {'Chimera Ripper', {'Detonation','Induration'}},
        {'String Clipper', {'Scission'}},
        {'Cannibal Blade', {'Compression','Reverberation'}},
        {'Bone Crusher', {'Fragmentation'}},
        {'String Shredder', {'Distortion','Scission'}},
        {'Arcuballista', {'Liquefaction','Transfixion'}},
        {'Daze', {'Impaction','Transfixion'}},
        {'Armor Piercer', {'Gravitation'}},
        {'Armor Shatterer', {'Fusion','Impaction'}},
    },

    ['Hand-to-Hand'] = {
        {'Combo', {'Impaction'}},
        {'Shoulder Tackle', {'Reverberation','Impaction'}},
        {'One Inch Punch', {'Compression'}},
        {'Backhand Blow', {'Detonation'}},
        {'Raging Fists', {'Impaction'}},
        {'Spinning Attack', {'Liquefaction','Impaction'}},
        {'Howling Fist', {'Transfixion','Impaction'}},
        {'Dragon Kick', {'Fragmentation'}},
        {'Asuran Fists', {'Gravitation','Liquefaction'}},
        {'Final Heaven', {'Light','Fusion'}},
        {'Victory Smite', {'Light','Fragmentation'}},
        {'Ascetic\'s Fury', {'Fusion','Transfixion'}},
        {'Stringing Pummel', {'Gravitation','Liquefaction'}},
        {'Shijin Spiral', {'Fusion','Reverberation'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Dagger'] = {
        {'Wasp Sting', {'Scission'}},
        {'Viper Bite', {'Scission'}},
        {'Shadowstitch', {'Reverberation'}},
        {'Gust Slash', {'Detonation'}},
        {'Cyclone', {'Detonation','Scission'}},
        {'Energy Steal', {}},
        {'Energy Drain', {}},
        {'Dancing Edge', {'Scission','Detonation'}},
        {'Shark Bite', {'Fragmentation'}},
        {'Evisceration', {'Gravitation','Transfixion'}},
        {'Mercy Stroke', {'Darkness','Gravitation'}},
        {'Rudra\'s Storm', {'Darkness','Distortion'}},
        {'Exenterator', {'Fragmentation','Scission'}}, -- Aeonic L3 property intentionally omitted
        {'Mandalic Stab', {'Fusion','Compression'}},
        {'Mordant Rime', {'Fragmentation','Distortion'}},
        {'Pyrrhic Kleos', {'Distortion','Scission'}},
    },
    ['Sword'] = {
        {'Fast Blade', {'Scission'}},
        {'Burning Blade', {'Liquefaction'}},
        {'Red Lotus Blade', {'Liquefaction','Detonation'}},
        {'Flat Blade', {'Impaction'}},
        {'Shining Blade', {'Scission'}},
        {'Seraph Blade', {'Scission'}},
        {'Circle Blade', {'Reverberation','Impaction'}},
        {'Spirits Within', {}},
        {'Vorpal Blade', {'Scission','Impaction'}},
        {'Swift Blade', {'Gravitation'}},
        {'Savage Blade', {'Fragmentation','Scission'}},
        {'Knights of Round', {'Light','Fusion'}},
        {'Chant du Cygne', {'Light','Distortion'}},
        {'Death Blossom', {'Fragmentation','Distortion'}},
        {'Atonement', {'Fusion','Reverberation'}},
        {'Expiacion', {'Distortion','Scission'}},
        {'Requiescat', {'Gravitation','Scission'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Great Sword'] = {
        {'Hard Slash', {'Scission'}},
        {'Power Slash', {'Transfixion'}},
        {'Frostbite', {'Induration'}},
        {'Freezebite', {'Induration','Detonation'}},
        {'Shockwave', {'Reverberation'}},
        {'Crescent Moon', {'Scission'}},
        {'Sickle Moon', {'Scission','Impaction'}},
        {'Spinning Slash', {'Fragmentation'}},
        {'Ground Strike', {'Fragmentation','Distortion'}},
        {'Scourge', {'Light','Fusion'}},
        {'Torcleaver', {'Light','Distortion'}},
        {'Resolution', {'Fragmentation','Scission'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Axe'] = {
        {'Raging Axe', {'Detonation','Impaction'}},
        {'Smash Axe', {'Induration','Reverberation'}},
        {'Gale Axe', {'Detonation'}},
        {'Avalanche Axe', {'Scission','Impaction'}},
        {'Spinning Axe', {'Liquefaction','Scission','Impaction'}},
        {'Rampage', {'Scission'}},
        {'Calamity', {'Scission','Impaction'}},
        {'Mistral Axe', {'Fusion'}},
        {'Decimation', {'Fusion','Reverberation'}},
        {'Onslaught', {'Darkness','Gravitation'}},
        {'Cloudsplitter', {'Darkness','Fragmentation'}},
        {'Primal Rend', {'Gravitation','Reverberation'}},
        {'Ruinator', {'Distortion','Detonation'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Great Axe'] = {
        {'Shield Break', {'Impaction'}},
        {'Iron Tempest', {'Scission'}},
        {'Sturmwind', {'Reverberation','Scission'}},
        {'Armor Break', {'Impaction'}},
        {'Keen Edge', {'Compression'}},
        {'Weapon Break', {'Impaction'}},
        {'Raging Rush', {'Reverberation','Induration'}},
        {'Full Break', {'Distortion'}},
        {'Steel Cyclone', {'Distortion','Detonation'}},
        {'Metatron Torment', {'Light','Fusion'}},
        {'Ukko\'s Fury', {'Light','Fragmentation'}},
        {'King\'s Justice', {'Fragmentation','Scission'}},
        {'Upheaval', {'Compression','Scission'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Scythe'] = {
        {'Slice', {'Scission'}},
        {'Dark Harvest', {'Reverberation'}},
        {'Shadow of Death', {'Induration','Reverberation'}},
        {'Nightmare Scythe', {'Compression','Scission'}},
        {'Spinning Scythe', {'Reverberation','Scission'}},
        {'Vorpal Scythe', {'Scission','Impaction'}},
        {'Guillotine', {'Induration'}},
        {'Cross Reaper', {'Distortion'}},
        {'Spiral Hell', {'Distortion','Scission'}},
        {'Catastrophe', {'Darkness','Gravitation'}},
        {'Quietus', {'Darkness','Distortion'}},
        {'Insurgency', {'Fusion','Compression'}},
        {'Entropy', {'Gravitation','Reverberation'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Polearm'] = {
        {'Double Thrust', {'Transfixion'}},
        {'Thunder Thrust', {'Transfixion','Impaction'}},
        {'Raiden Thrust', {'Transfixion','Impaction'}},
        {'Leg Sweep', {'Impaction'}},
        {'Penta Thrust', {'Compression'}},
        {'Vorpal Thrust', {'Reverberation','Transfixion'}},
        {'Skewer', {'Transfixion','Impaction'}},
        {'Wheeling Thrust', {'Fusion'}},
        {'Impulse Drive', {'Gravitation','Induration'}},
        {'Geirskogul', {'Light','Distortion'}},
        {'Camlann\'s Torment', {'Light','Fragmentation'}},
        {'Drakesbane', {'Fusion','Transfixion'}},
        {'Stardiver', {'Gravitation','Transfixion'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Katana'] = {
        {'Blade: Rin', {'Transfixion'}},
        {'Blade: Retsu', {'Scission'}},
        {'Blade: Teki', {'Reverberation'}},
        {'Blade: To', {'Induration','Detonation'}},
        {'Blade: Chi', {'Impaction','Transfixion'}},
        {'Blade: Ei', {'Compression'}},
        {'Blade: Jin', {'Detonation','Impaction'}},
        {'Blade: Ten', {'Gravitation'}},
        {'Blade: Ku', {'Gravitation','Transfixion'}},
        {'Blade: Metsu', {'Darkness','Fragmentation'}},
        {'Blade: Hi', {'Darkness','Gravitation'}},
        {'Blade: Kamu', {'Fragmentation','Compression'}},
        {'Blade: Shun', {'Fusion','Impaction'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Great Katana'] = {
        {'Tachi: Enpi', {'Transfixion','Scission'}},
        {'Tachi: Hobaku', {'Induration'}},
        {'Tachi: Goten', {'Transfixion','Impaction'}},
        {'Tachi: Kagero', {'Liquefaction'}},
        {'Tachi: Jinpu', {'Scission','Detonation'}},
        {'Tachi: Koki', {'Reverberation','Impaction'}},
        {'Tachi: Yukikaze', {'Induration','Detonation'}},
        {'Tachi: Gekko', {'Distortion','Reverberation'}},
        {'Tachi: Kasha', {'Fusion','Compression'}},
        {'Tachi: Kaiten', {'Light','Fragmentation'}},
        {'Tachi: Fudo', {'Light','Distortion'}},
        {'Tachi: Rana', {'Gravitation','Induration'}},
        {'Tachi: Shoha', {'Fragmentation','Compression'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Club'] = {
        {'Shining Strike', {'Impaction'}},
        {'Seraph Strike', {'Impaction'}},
        {'Brainshaker', {'Reverberation'}},
        {'Starlight', {}},
        {'Moonlight', {}},
        {'Skullbreaker', {'Induration','Reverberation'}},
        {'True Strike', {'Detonation','Impaction'}},
        {'Judgment', {'Impaction'}},
        {'Hexa Strike', {'Fusion'}},
        {'Black Halo', {'Fragmentation','Compression'}},
        {'Realmrazer', {'Fusion','Impaction'}}, -- Aeonic L3 property intentionally omitted
        {'Randgrith', {'Light','Fragmentation'}},
        {'Mystic Boon', {}},
        {'Dagan', {}},
        {'Exudation', {'Darkness','Fragmentation'}},
    },
    ['Staff'] = {
        {'Heavy Swing', {'Impaction'}},
        {'Rock Crusher', {'Impaction'}},
        {'Earth Crusher', {'Detonation','Impaction'}},
        {'Starburst', {'Compression','Reverberation'}},
        {'Sunburst', {'Compression','Reverberation'}},
        {'Shell Crusher', {'Detonation'}},
        {'Full Swing', {'Liquefaction','Impaction'}},
        {'Spirit Taker', {}},
        {'Retribution', {'Gravitation','Reverberation'}},
        {'Gate of Tartarus', {'Darkness','Distortion'}},
        {'Shattersoul', {'Gravitation','Induration'}}, -- Aeonic L3 property intentionally omitted
        {'Vidohunir', {'Fragmentation','Distortion'}},
        {'Garland of Bliss', {'Fusion','Reverberation'}},
        {'Omniscience', {'Gravitation','Transfixion'}},
        {'Myrkr', {}},
    },
    ['Archery'] = {
        {'Flaming Arrow', {'Liquefaction','Transfixion'}},
        {'Piercing Arrow', {'Reverberation','Transfixion'}},
        {'Dulling Arrow', {'Liquefaction','Transfixion'}},
        {'Sidewinder', {'Reverberation','Transfixion','Detonation'}},
        {'Blast Arrow', {'Induration','Transfixion'}},
        {'Arching Arrow', {'Fusion'}},
        {'Empyreal Arrow', {'Fusion','Transfixion'}},
        {'Namas Arrow', {'Light','Distortion'}},
        {'Jishnu\'s Radiance', {'Light','Fusion'}},
        {'Apex Arrow', {'Fragmentation','Transfixion'}}, -- Aeonic L3 property intentionally omitted
    },
    ['Marksmanship'] = {
        {'Hot Shot', {'Liquefaction','Transfixion'}},
        {'Split Shot', {'Reverberation','Transfixion'}},
        {'Sniper Shot', {'Liquefaction','Transfixion'}},
        {'Slug Shot', {'Reverberation','Transfixion','Detonation'}},
        {'Blast Shot', {'Induration','Transfixion'}},
        {'Heavy Shot', {'Fusion'}},
        {'Detonator', {'Fusion','Transfixion'}},
        {'Coronach', {'Darkness','Fragmentation'}},
        {'Wildfire', {'Darkness','Gravitation'}},
        {'Trueflight', {'Fragmentation','Scission'}},
        {'Leaden Salute', {'Gravitation','Transfixion'}},
        {'Last Stand', {'Fusion','Reverberation'}}, -- Aeonic L3 property intentionally omitted
    },
};

local weapon_names = {};
for k,_ in pairs(ws) do if k ~= 'Blue Magic' and k ~= 'Automaton' then weapon_names[#weapon_names+1] = k; end end
table.sort(weapon_names);

local function ws_by_name(name)
    for _, list in pairs(ws) do
        for _, entry in ipairs(list) do
            if entry[1]:lower() == name:lower() then return entry; end
        end
    end
    return nil;
end


local function close_with(active, entry)
    
    local active_props = {};
    if type(active) == 'table' then
        active_props = active;
    elseif active then
        active_props = { active };
    end

    for _, closer_prop in ipairs(entry[2] or {}) do
        for _, opener_prop in ipairs(active_props) do
            local result = links[opener_prop .. '>' .. closer_prop];
            if result then return result, closer_prop, opener_prop; end
        end
    end
    return nil, nil, nil;
end

local function initial_property(entry)
    -- Keep every opener property, in priority order.  Once a skillchain is
    -- created, close_with receives the single resulting skillchain property.
    return entry and entry[2] or nil;
end

local function route_hits_target(result)
    if state.target == 'Any' then return true; end
    if state.target == 'Light' then return result == 'Light' or result == 'Light II'; end
    if state.target == 'Darkness' then return result == 'Darkness' or result == 'Darkness II'; end
    return result == state.target;
end

-- Lightweight two-weapon multi-step engine.
-- Only the selected two weapon families are ever considered.
-- Results are calculated once when the pair changes and then cached.
local multi_cache = { key = '', groups = {} };
local MAX_STEPS = 5;
local MAX_PER_GROUP = 800;

local function pair_key()
    return tostring(state.weapon) .. '|' .. tostring(state.closer_weapon);
end

local function candidates_for_step(step)
    -- Alternate the selected weapons. Step 1 is Weapon 1 opener.
    local weapon = ((step % 2) == 1) and state.weapon or state.closer_weapon;
    local out = {};
    for _, entry in ipairs(ws[weapon] or {}) do
        out[#out+1] = { weapon = weapon, entry = entry };
    end
    return out;
end

local function add_multi(groups, step, path, result)
    local g = groups[step];
    if not g or #g >= MAX_PER_GROUP then return; end
    g[#g+1] = {
        text = table.concat(path, '  ->  ') .. '  =>  ' .. result,
        result = result,
    };
end

local function walk_pair(groups, active, step, path)
    if step > MAX_STEPS then return; end

    for _, candidate in ipairs(candidates_for_step(step)) do
        local result = close_with(active, candidate.entry);
        if result then
            local np = {};
            for i,v in ipairs(path) do np[i] = v; end
            np[#np+1] = candidate.entry[1];
            add_multi(groups, step, np, result);

            if step < MAX_STEPS and result ~= 'Light II' and result ~= 'Darkness II' then
                walk_pair(groups, result, step + 1, np);
            end
        end
    end
end

local function rebuild_multi_cache()
    local groups = {};
    for i=2,MAX_STEPS do groups[i] = {}; end

    -- Weapon 1 -> Weapon 2 -> Weapon 1 -> Weapon 2 ...
    for _, opener in ipairs(ws[state.weapon] or {}) do
        local active = initial_property(opener);
        if active then
            local path = { opener[1] };
            walk_pair(groups, active, 2, path);
        end
    end

    for step=2,MAX_STEPS do
        table.sort(groups[step], function(x,y)
            if x.result ~= y.result then return x.result < y.result; end
            return x.text < y.text;
        end);
    end

    multi_cache.key = pair_key();
    multi_cache.groups = groups;
end

local function get_multi_groups()
    local key = pair_key();
    if multi_cache.key ~= key then rebuild_multi_cache(); end
    return multi_cache.groups;
end

local function set_weapon(name)
    for _, w in ipairs(weapon_names) do
        if w:lower() == name:lower() then
            state.weapon = w;
            local list = ws[w];
            if list and list[1] then state.start_ws = list[1][1]; end
            return true;
        end
    end
    return false;
end

ashita.events.register('command', 'skillchains_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 or not args[1]:any('/sc', '/chainbuilder') then return; end
    e.blocked = true;

    -- /sc or /chainbuilder toggles the window.
    if #args == 1 then
        state.visible[1] = not state.visible[1];
        return;
    end

    -- Keep only the simple show / hide commands.
    local sub = args[2]:lower();
    if sub == 'show' then
        state.visible[1] = true;
        return;
    end
    if sub == 'hide' then
        state.visible[1] = false;
        return;
    end
end);



local COLORS = {
    window={0.004,0.010,0.022,0.985}, panel={0.008,0.024,0.045,0.985},
    panel2={0.012,0.042,0.075,0.985}, border={0.055,0.50,0.94,0.95},
    border_soft={0.055,0.22,0.40,0.90}, gold={0.96,0.72,0.25,1},
    button={0.015,0.085,0.155,1}, button_hov={0.025,0.19,0.34,1},
    button_act={0.03,0.31,0.54,1}, cyan={0.20,0.82,1,1},
    cyan_soft={0.45,0.76,0.96,1}, white={0.94,0.97,1,1},
    muted={0.48,0.60,0.72,1}, red={1,.30,.30,1},
};
local PROPERTY_COLORS = {
    Light={1,.93,.18,1}, ['Light II']={1,.93,.18,1}, Darkness={.82,.35,1,1}, ['Darkness II']={.82,.35,1,1},
    Fragmentation={.25,.72,1,1}, Distortion={.20,.90,1,1}, Fusion={1,.40,.10,1}, Gravitation={.86,.64,.26,1},
    Liquefaction={1,.30,.18,1}, Induration={.30,.70,1,1}, Detonation={.20,1,.72,1}, Scission={1,.68,.20,1},
    Reverberation={.55,.30,1,1}, Transfixion={1,.90,.42,1}, Compression={.25,1,.72,1}, Impaction={.72,.84,1,1},
};
local function tc(c,t) imgui.TextColored(c,tostring(t or '')); end
local function prop_color(n) return PROPERTY_COLORS[n] or COLORS.white; end

local function push_style()
    imgui.PushStyleColor(ImGuiCol_WindowBg,COLORS.window); imgui.PushStyleColor(ImGuiCol_ChildBg,COLORS.panel);
    imgui.PushStyleColor(ImGuiCol_Border,COLORS.border); imgui.PushStyleColor(ImGuiCol_Separator,COLORS.border_soft);
    imgui.PushStyleColor(ImGuiCol_Button,COLORS.button); imgui.PushStyleColor(ImGuiCol_ButtonHovered,COLORS.button_hov);
    imgui.PushStyleColor(ImGuiCol_ButtonActive,COLORS.button_act); imgui.PushStyleColor(ImGuiCol_Header,COLORS.button);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered,COLORS.button_hov); imgui.PushStyleColor(ImGuiCol_HeaderActive,COLORS.button_act);
    imgui.PushStyleColor(ImGuiCol_Text,COLORS.white);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding,7); imgui.PushStyleVar(ImGuiStyleVar_ChildRounding,5);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding,4); imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize,1);
    imgui.PushStyleVar(ImGuiStyleVar_ChildBorderSize,1); imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize,1);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding,{6,5}); imgui.PushStyleVar(ImGuiStyleVar_FramePadding,{8,4});
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing,{5,2});
end
local function pop_style() imgui.PopStyleVar(9); imgui.PopStyleColor(11); end
local function button(label,size) return imgui.Button(label,size); end
local function header(n,title)
    tc(COLORS.gold,n..'.'); imgui.SameLine(); tc(COLORS.cyan,title); imgui.Separator();
end

-- Ordered calculator UI. Kept separate from the skillchain data above.
local slot_count={2};
local slot_weapons={state.weapon,state.closer_weapon,'Club','Dagger'};
local slot_ws={'','','',''};

local function find_ws_entry(weapon,name)
    for _,e in ipairs(ws[weapon] or {}) do if e[1]==name then return e end end
    return nil
end
local function ensure_slot_ws(slot)
    local list=ws[slot_weapons[slot]] or {};
    if #list==0 then slot_ws[slot]=''; return end
    if not find_ws_entry(slot_weapons[slot],slot_ws[slot]) then slot_ws[slot]=list[1][1] end
end
local function weapon_combo(id,slot)
    local current=slot_weapons[slot];

    -- Blue Magic and Automaton are closer/follow-up choices only.
    -- They are available in Steps 2, 3 and 4, but never as Step 1.
    -- All normal weapon choices remain available at every step.
    local choices = {};
    for _, w in ipairs(weapon_names) do choices[#choices+1] = w; end

    if slot >= 2 then
        choices[#choices+1] = 'Blue Magic';
        choices[#choices+1] = 'Automaton';
    end

    if imgui.BeginCombo(id,current) then
        for _,w in ipairs(choices) do
            if imgui.Selectable(w,current==w) then
                slot_weapons[slot]=w;
                slot_ws[slot]='';
                ensure_slot_ws(slot);

                if slot==1 then state.weapon=w; end
                if slot==2 then state.closer_weapon=w; end
            end
        end
        imgui.EndCombo();
    end
end

local function ws_combo(id,slot)
    ensure_slot_ws(slot);
    local current=slot_ws[slot]~='' and slot_ws[slot] or 'None';
    if imgui.BeginCombo(id,current) then
        for _,e in ipairs(ws[slot_weapons[slot]] or {}) do
            if imgui.Selectable(e[1],slot_ws[slot]==e[1]) then slot_ws[slot]=e[1] end
        end
        imgui.EndCombo();
    end
end
local function calculate_selected_chain()
    for i=1,slot_count[1] do ensure_slot_ws(i) end
    local opener=find_ws_entry(slot_weapons[1],slot_ws[1]);
    if not opener then return {},nil,1 end
    local path={slot_ws[1]}; local active=initial_property(opener);
    if not active then return path,nil,1 end
    local results={};
    for step=2,slot_count[1] do
        local e=find_ws_entry(slot_weapons[step],slot_ws[step]);
        if not e then return path,results,step end
        path[#path+1]=slot_ws[step];
        local result=close_with(active,e); results[step]=result;
        if not result then return path,results,step end
        active=result;
    end
    return path,results,nil
end
local function opener_prop(i)
    local e=find_ws_entry(slot_weapons[i],slot_ws[i]);
    return e and e[2] and e[2][1] or nil
end

ashita.events.register('d3d_present','skillchains_present_cb',function()
    if not state.visible[1] then return end
    for i=1,slot_count[1] do ensure_slot_ws(i) end
    local path,results,failed=calculate_selected_chain();

    push_style();
    imgui.SetNextWindowSize({674,473},ImGuiCond_Always);
    imgui.SetNextWindowBgAlpha(.99);
    local flags=bit.bor(ImGuiWindowFlags_NoTitleBar,ImGuiWindowFlags_NoCollapse,ImGuiWindowFlags_NoResize,ImGuiWindowFlags_NoScrollbar,ImGuiWindowFlags_NoScrollWithMouse);

    if imgui.Begin('CHAINBUILDER##Fantasy21',state.visible,flags) then
        -- Header panel. Remove child padding so the artwork fills the
        -- bordered header instead of sitting inside a second large inset.
        imgui.PushStyleVar(ImGuiStyleVar_WindowPadding,{1,1});
        if imgui.BeginChild('##header',{0,174},true,ImGuiWindowFlags_NoScrollbar) then
            local banner_tex = load_banner();
            if banner_tex ~= nil then
                imgui.SetCursorPos({1,1});
                imgui.Image(to_texture_id(banner_tex), {658,170});
            else
                -- Safe fallback if the PNG is missing or fails to load.
                tc(COLORS.gold,'CHAINBUILDER');
                imgui.SameLine();
                tc(COLORS.cyan,' SKILLCHAIN CALCULATOR');
            end
            imgui.EndChild();
        end
        imgui.PopStyleVar();
        imgui.Dummy({0,2});



        if imgui.BeginChild('##setup',{0,136},true) then
            header('1','CHAIN SETUP');
            -- Compact fixed columns matching the approved layout:
            -- number | weapon | weapon skill | result
            tc(COLORS.muted,'#');
            imgui.SameLine(32);  tc(COLORS.muted,'WEAPON');
            imgui.SameLine(198); tc(COLORS.muted,'WEAPON SKILL');
            imgui.SameLine(486); tc(COLORS.muted,'RESULT');

            for i=1,slot_count[1] do
                -- Same baseline: 01/02 now line up with the dropdown itself.
                tc(COLORS.gold,string.format('%02d',i));
                imgui.SameLine(32);
                imgui.PushItemWidth(146);
                weapon_combo('##weapon'..i,i);
                imgui.PopItemWidth();

                imgui.SameLine(198);
                imgui.PushItemWidth(268);
                ws_combo('##ws'..i,i);
                imgui.PopItemWidth();

                imgui.SameLine(486);
                local p=(i==1) and nil or (results and results[i]);
                if p then tc(prop_color(p),p) else tc(COLORS.muted,'--') end
            end

            imgui.Spacing();
            if slot_count[1]<4 and button('+ ADD STEP',{112,25}) then slot_count[1]=slot_count[1]+1; ensure_slot_ws(slot_count[1]) end
            if slot_count[1]>2 then
                imgui.SameLine();
                if button('- REMOVE',{105,25}) then slot_count[1]=slot_count[1]-1 end
            end
            imgui.SameLine();
            if button('CLEAR',{82,25}) then
                slot_count[1]=2; slot_weapons={state.weapon,state.closer_weapon,'Club','Dagger'}; slot_ws={'','','',''};
                for i=1,2 do ensure_slot_ws(i) end
            end
            imgui.EndChild();
        end

        imgui.Dummy({0,2});
        if imgui.BeginChild('##preview',{0,142},true) then
            header('2','CHAIN PREVIEW');

            -- Simple two-row preview.  Keep normal ImGui flow so Ashita does not
            -- get confused by absolute cursor positioning.
            tc(COLORS.muted,'STEP');
            imgui.SameLine(54);  tc(COLORS.muted,'WEAPON');
            imgui.SameLine(205); tc(COLORS.muted,'WEAPON SKILL');
            imgui.SameLine(485); tc(COLORS.muted,'CREATES');

            for i=1,#path do
                tc(COLORS.gold,string.format('%02d',i));

                imgui.SameLine(54);
                tc(COLORS.cyan_soft,slot_weapons[i]);

                imgui.SameLine(205);
                tc(COLORS.white,path[i]);

                -- The opener does not need an element/result displayed in preview.
                -- Only Step 2 onward shows the skillchain created.
                if i > 1 then
                    imgui.SameLine(485);
                    local p=results and results[i] or nil;
                    if p then
                        tc(prop_color(p),string.upper(p));
                    else
                        tc(COLORS.muted,'--');
                    end
                end
            end

            imgui.Spacing();
            imgui.Separator();

            local final=(results and results[#path]) or nil;
            if failed then
                tc(COLORS.red,'NO SKILLCHAIN');
                imgui.SameLine(205);
                tc(COLORS.muted,'BREAKS AT STEP '..tostring(failed));
            elseif final then
                tc(COLORS.gold,'FINAL SKILLCHAIN');
                imgui.SameLine(205);
                tc(prop_color(final),string.upper(final));
            else
                tc(COLORS.muted,'Select weapon skills above to build a chain.');
            end
            imgui.EndChild();
        end

    end
    imgui.End();
    pop_style();
end);
