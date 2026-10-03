addon.name = 'chainbuilder';
addon.author = 'Laudout';
addon.version = '2.6.0';
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
    ['Detonation>Scission']='Scission',

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
    local active_props = type(active) == 'table' and active or { active };
    local results, seen = {}, {};

    for _, opener_prop in ipairs(active_props) do
        for _, closer_prop in ipairs(entry[2] or {}) do
            local result = links[opener_prop .. '>' .. closer_prop];
            if result and not seen[result] then
                seen[result] = true;
                results[#results + 1] = result;
            end
        end
    end

    if #results == 0 then return nil, nil, nil; end
    if #results == 1 then return results[1], nil, nil; end
    return results, nil, nil;
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



-- Ordered calculator UI. Kept separate from the skillchain data above.
local slot_count={2};
local slot_weapons={state.weapon,state.closer_weapon};
local slot_ws={'',''};

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

    local path={slot_ws[1]};
    local active=initial_property(opener);
    if not active then return path,nil,1 end

    local results={};
    for step=2,slot_count[1] do
        local e=find_ws_entry(slot_weapons[step],slot_ws[step]);
        if not e then return path,results,step end
        path[#path+1]=slot_ws[step];

        local result=close_with(active,e);
        if not result then return path,results,step end

        active=result;
        results[step]=(type(result)=='table') and result[1] or result;
    end
    return path,results,nil
end

local function opener_prop(i)
    local e=find_ws_entry(slot_weapons[i],slot_ws[i]);
    return e and e[2] and e[2][1] or nil
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local COLORS = {
    window      = { 0.012, 0.020, 0.040, 0.97 },
    card        = { 0.030, 0.050, 0.090, 0.96 },
    card_line   = { 0.35, 0.60, 1.00, 0.14 },
    frame       = { 0.020, 0.075, 0.140, 1.00 },
    frame_hov   = { 0.035, 0.130, 0.240, 1.00 },
    frame_act   = { 0.045, 0.190, 0.340, 1.00 },
    border      = { 0.25, 0.62, 1.00, 0.35 },
    gold        = { 0.98, 0.76, 0.32, 1.00 },
    cyan        = { 0.32, 0.82, 1.00, 1.00 },
    white       = { 0.94, 0.97, 1.00, 1.00 },
    subtext     = { 0.70, 0.78, 0.88, 1.00 },
    muted       = { 0.48, 0.58, 0.70, 1.00 },
    faint       = { 0.30, 0.38, 0.50, 1.00 },
    red         = { 1.00, 0.36, 0.36, 1.00 },
    track       = { 1.00, 1.00, 1.00, 0.07 },
};

-- Elemental colours: each property takes the colour of its element(s).
local PROPERTY_COLORS = {
    Transfixion   = { 0.96, 0.95, 0.86, 1 }, -- light
    Compression   = { 0.62, 0.55, 0.80, 1 }, -- dark
    Liquefaction  = { 1.00, 0.40, 0.30, 1 }, -- fire
    Scission      = { 0.92, 0.78, 0.44, 1 }, -- earth
    Reverberation = { 0.36, 0.56, 1.00, 1 }, -- water
    Detonation    = { 0.42, 0.92, 0.50, 1 }, -- wind
    Induration    = { 0.62, 0.93, 1.00, 1 }, -- ice
    Impaction     = { 0.90, 0.50, 0.98, 1 }, -- thunder
    Fusion        = { 1.00, 0.62, 0.26, 1 }, -- fire / light
    Fragmentation = { 0.70, 0.58, 1.00, 1 }, -- wind / thunder
    Gravitation   = { 0.80, 0.52, 0.42, 1 }, -- earth / dark
    Distortion    = { 0.28, 0.82, 0.86, 1 }, -- water / ice
    Light         = { 1.00, 0.94, 0.55, 1 },
    ['Light II']  = { 1.00, 0.94, 0.55, 1 },
    Darkness      = { 0.66, 0.40, 1.00, 1 },
    ['Darkness II'] = { 0.66, 0.40, 1.00, 1 },
};

local PROPERTY_LEVEL = {
    Fusion = 2, Fragmentation = 2, Gravitation = 2, Distortion = 2,
    Light = 3, Darkness = 3, ['Light II'] = 4, ['Darkness II'] = 4,
};

local CORNERS_ALL = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;

local function prop_color(n) return PROPERTY_COLORS[n] or COLORS.white; end
local function prop_level(n) return PROPERTY_LEVEL[n] or 1; end

local function rgba(c, a) return { c[1], c[2], c[3], a or c[4] }; end
local function col(c, a) return imgui.GetColorU32(rgba(c, a)); end
local function pulse(speed) return (math.sin(os.clock() * (speed or 3.0)) + 1.0) * 0.5; end
local function line_h() return tonumber(imgui.GetTextLineHeight()) or 13; end
local function text_w(s) return tonumber((imgui.CalcTextSize(s))) or 0; end

local function draw_text(x, y, color, text, scale)
    local dl = imgui.GetWindowDrawList();
    if scale ~= nil and scale ~= 1 and type(imgui.GetFont) == 'function' and type(imgui.GetFontSize) == 'function' then
        local ok = pcall(function()
            dl:AddText(imgui.GetFont(), imgui.GetFontSize() * scale, { x, y }, col(color), text);
        end);
        if ok then return; end
    end
    dl:AddText({ x, y }, col(color), text);
end

local function draw_glow_text(x, y, color, text, scale, strength)
    local a = 0.22 * (strength or 1);
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        draw_text(x + o[1], y + o[2], rgba(color, a), text, scale);
    end
    draw_text(x, y, color, text, scale);
end

local function draw_dot(cx, cy, r, color, glow)
    local dl = imgui.GetWindowDrawList();
    if glow ~= nil and glow > 0 then
        dl:AddCircleFilled({ cx, cy }, r * 2.4, col(color, 0.10 * glow), 20);
        dl:AddCircleFilled({ cx, cy }, r * 1.6, col(color, 0.22 * glow), 20);
    end
    dl:AddCircleFilled({ cx, cy }, r, col(color), 16);
end

local function pill_w(text) return text_w(text) + 16; end

local function draw_pill(x, y, text, color, fill_alpha)
    local dl = imgui.GetWindowDrawList();
    local w, h = pill_w(text), line_h() + 5;
    dl:AddRectFilled({ x, y }, { x + w, y + h }, col(color, fill_alpha or 0.15), h * 0.5);
    dl:AddRect({ x, y }, { x + w, y + h }, col(color, 0.55), h * 0.5, CORNERS_ALL, 1.0);
    dl:AddText({ x + 8, y + 2.5 }, col(color), text);
    return w, h;
end

-- Custom pill button. Returns true when clicked.
local function fancy_button(id, label, w, color)
    local x, y = imgui.GetCursorScreenPos();
    local h = line_h() + 12;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local act = type(imgui.IsItemActive) == 'function' and imgui.IsItemActive() or false;
    local dl = imgui.GetWindowDrawList();
    local fill = act and 0.32 or (hov and 0.22 or 0.12);
    dl:AddRectFilled({ x, y }, { x + w, y + h }, col(color, fill), 6);
    dl:AddRect({ x, y }, { x + w, y + h }, col(color, hov and 0.85 or 0.45), 6, CORNERS_ALL, 1.0);
    dl:AddText({ x + (w - text_w(label)) * 0.5, y + 6 }, col(hov and COLORS.white or color), label);
    if hov then imgui.SetMouseCursor(ImGuiMouseCursor_Hand); end
    return clicked;
end

local function section_title(title, color)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local w = imgui.GetContentRegionAvail();
    local lh = line_h();
    dl:AddRectFilled({ x, y + 2 }, { x + 3, y + lh - 2 }, col(color), 1.5);
    dl:AddText({ x + 10, y }, col(color), title);
    local after = x + 10 + text_w(title) + 10;
    if x + w > after then
        dl:AddRectFilledMultiColor({ after, y + lh * 0.5 }, { x + w, y + lh * 0.5 + 1 },
            col(color, 0.45), col(color, 0.0), col(color, 0.0), col(color, 0.45));
    end
    imgui.Dummy({ w, lh });
    imgui.Dummy({ 0, 2 });
end

--------------------------------------------------------------------------------
-- Banner
--------------------------------------------------------------------------------

local function render_banner()
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local w = imgui.GetContentRegionAvail();
    local h;

    local tex = load_banner();
    if tex ~= nil then
        h = math.floor(w * banner_size[2] / banner_size[1]);
        imgui.Image(to_texture_id(tex), { w, h });
        -- Soft fade into the window and a thin frame.
        dl:AddRectFilledMultiColor({ x, y + h - 26 }, { x + w, y + h },
            col(COLORS.window, 0.0), col(COLORS.window, 0.0), col(COLORS.window, 0.85), col(COLORS.window, 0.85));
        dl:AddRect({ x, y }, { x + w, y + h }, col(COLORS.border, 0.5), 6, CORNERS_ALL, 1.0);
    else
        h = 64;
        dl:AddRectFilled({ x, y }, { x + w, y + h }, col(COLORS.card), 8);
        dl:AddRectFilledMultiColor({ x, y }, { x + w, y + h },
            col(COLORS.cyan, 0.16), col(COLORS.cyan, 0.0), col(COLORS.cyan, 0.0), col(COLORS.cyan, 0.05));
        dl:AddRect({ x, y }, { x + w, y + h }, col(COLORS.border, 0.6), 8, CORNERS_ALL, 1.0);
        draw_glow_text(x + 16, y + 12, COLORS.gold, 'CHAINBUILDER', 1.6, 1.0);
        dl:AddText({ x + 18, y + 14 + line_h() * 1.6 }, col(COLORS.cyan), 'SKILLCHAIN CALCULATOR');
        imgui.Dummy({ w, h });
    end

    -- Close button floating on the banner's top-right corner.
    local s = line_h() + 6;
    local bx, by = x + w - s - 8, y + 8;
    local after_x, after_y = imgui.GetCursorScreenPos();
    imgui.SetCursorScreenPos({ bx, by });
    if imgui.InvisibleButton('##cb_close', { s, s }) then
        state.visible[1] = false;
    end
    local hov = imgui.IsItemHovered();
    dl:AddCircleFilled({ bx + s * 0.5, by + s * 0.5 }, s * 0.5, col({ 0, 0, 0, 1 }, hov and 0.75 or 0.45), 20);
    local m, c = s * 0.32, hov and COLORS.white or COLORS.subtext;
    dl:AddLine({ bx + m, by + m }, { bx + s - m, by + s - m }, col(c), 1.6);
    dl:AddLine({ bx + s - m, by + m }, { bx + m, by + s - m }, col(c), 1.6);
    if hov then imgui.SetMouseCursor(ImGuiMouseCursor_Hand); end
    imgui.SetCursorScreenPos({ after_x, after_y });
    imgui.Dummy({ 0, 4 });
end

--------------------------------------------------------------------------------
-- Chain steps
--------------------------------------------------------------------------------

local COL_WEAPON_X, COL_WEAPON_W = 44, 150;
local COL_WS_X, COL_WS_W = 202, 216;

local function step_status(i, results, failed)
    if i == 1 then
        if failed == 1 then return 'NO PROPERTIES', COLORS.red, nil; end
        return 'OPENER', COLORS.muted, nil;
    end
    local r = results and results[i];
    if r then return r:upper(), prop_color(r), r; end
    if failed and i == failed then return 'NO CHAIN', COLORS.red, nil; end
    return '--', COLORS.faint, nil;
end

local function render_step(i, results, failed, prev_node)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local w = imgui.GetContentRegionAvail();
    local lh = line_h();
    local fh = lh + 8;
    local h = 10 + fh + 6 + lh + 10;

    local label, tone, result = step_status(i, results, failed);
    local broken = failed ~= nil and i == failed;
    local dimmed = failed ~= nil and i > failed;

    -- Card
    dl:AddRectFilled({ x, y }, { x + w, y + h }, col(COLORS.card, dimmed and 0.55 or nil), 8);
    if broken then
        dl:AddRect({ x, y }, { x + w, y + h }, col(COLORS.red, 0.55), 8, CORNERS_ALL, 1.0);
    elseif result ~= nil then
        dl:AddRect({ x, y }, { x + w, y + h }, col(tone, 0.35), 8, CORNERS_ALL, 1.0);
        dl:AddRectFilledMultiColor({ x + w * 0.55, y + 1 }, { x + w - 1, y + h - 1 },
            col(tone, 0.0), col(tone, 0.10), col(tone, 0.10), col(tone, 0.0));
    else
        dl:AddRect({ x, y }, { x + w, y + h }, col(COLORS.card_line), 8, CORNERS_ALL, 1.0);
    end

    -- Timeline node + connector from the previous step
    local nx, ny, nr = x + 22, y + 10 + fh * 0.5, 12;
    if prev_node ~= nil then
        local link = result ~= nil and tone or (broken and COLORS.red or COLORS.faint);
        dl:AddRectFilled({ nx - 1.5, prev_node + nr }, { nx + 1.5, ny - nr }, col(link, result and 0.9 or 0.5));
    end
    local node_col = result ~= nil and tone or (broken and COLORS.red or (i == 1 and COLORS.gold or COLORS.muted));
    if result ~= nil then dl:AddCircleFilled({ nx, ny }, nr + 5, col(node_col, 0.16 * (0.6 + pulse(2.5) * 0.4)), 24); end
    dl:AddCircleFilled({ nx, ny }, nr, col(COLORS.window), 24);
    dl:AddCircle({ nx, ny }, nr, col(node_col, dimmed and 0.4 or 0.9), 24, 1.5);
    local num = ('%d'):format(i);
    dl:AddText({ nx - text_w(num) * 0.5, ny - lh * 0.5 }, col(dimmed and COLORS.faint or node_col), num);

    -- Combos
    imgui.SetCursorScreenPos({ x + COL_WEAPON_X, y + 10 });
    imgui.PushItemWidth(COL_WEAPON_W); weapon_combo('##weapon' .. i, i); imgui.PopItemWidth();
    imgui.SetCursorScreenPos({ x + COL_WS_X, y + 10 });
    imgui.PushItemWidth(COL_WS_W); ws_combo('##ws' .. i, i); imgui.PopItemWidth();

    -- Status / result pill
    local px = x + w - pill_w(label) - 12;
    local py = y + 10 + (fh - (lh + 5)) * 0.5;
    if result ~= nil then
        local lv = ('LV%d'):format(prop_level(result));
        draw_pill(px, py, label, tone, 0.18 + pulse(2.5) * 0.08);
        dl:AddText({ px - text_w(lv) - 8, py + 2.5 }, col(tone, 0.75), lv);
    else
        draw_pill(px, py, label, tone, 0.08);
    end

    -- Property chips for the selected weapon skill
    local cx, cy = x + COL_WEAPON_X + 2, y + 10 + fh + 6;
    local entry = find_ws_entry(slot_weapons[i], slot_ws[i]);
    local props = entry and entry[2] or {};
    if #props == 0 then
        dl:AddText({ cx, cy }, col(COLORS.faint), 'No skillchain properties');
    else
        for _, p in ipairs(props) do
            local pc = prop_color(p);
            draw_dot(cx + 3.5, cy + lh * 0.5, 3.5, rgba(pc, dimmed and 0.4 or 1));
            dl:AddText({ cx + 12, cy }, col(pc, dimmed and 0.45 or 0.95), p);
            cx = cx + 12 + text_w(p) + 16;
        end
    end

    imgui.SetCursorScreenPos({ x, y + h });
    imgui.Dummy({ w, 6 });
    return ny;
end

--------------------------------------------------------------------------------
-- Result card
--------------------------------------------------------------------------------

local result_card_h = nil;

local function render_result(path, results, failed)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local w = imgui.GetContentRegionAvail();
    local lh = line_h();

    local final = (not failed) and results and results[slot_count[1]] or nil;
    local tone = final and prop_color(final) or (failed and COLORS.red or COLORS.muted);
    local h = result_card_h or (lh * 4 + 30);

    dl:AddRectFilled({ x, y }, { x + w, y + h }, col(COLORS.card), 10);
    dl:AddRectFilledMultiColor({ x + 1, y + 1 }, { x + w - 1, y + h - 1 },
        col(tone, 0.16), col(tone, 0.02), col(tone, 0.02), col(tone, 0.08));
    local glow = final and (0.55 + pulse(2.0) * 0.45) or 1.0;
    dl:AddRect({ x, y }, { x + w, y + h }, col(tone, 0.55 * glow), 10, CORNERS_ALL, 1.2);

    local ix, iy = x + 16, y + 12;
    if final then
        dl:AddText({ ix, iy }, col(COLORS.muted), 'SKILLCHAIN');
        local steps = ('%d STEPS  -  LEVEL %d'):format(slot_count[1], prop_level(final));
        dl:AddText({ x + w - 16 - text_w(steps), iy }, col(tone, 0.85), steps);
        draw_glow_text(ix, iy + lh + 4, tone, final:upper(), 1.8, glow);
        iy = iy + lh + 4 + lh * 1.8 + 8;
    elseif failed then
        dl:AddText({ ix, iy }, col(COLORS.muted), 'SKILLCHAIN');
        draw_glow_text(ix, iy + lh + 4, COLORS.red, 'NO SKILLCHAIN', 1.8, 0.6);
        iy = iy + lh + 4 + lh * 1.8 + 8;
        local why;
        if failed == 1 then
            why = ('%s has no skillchain properties to open with.'):format(path[1] or 'The opener');
        else
            local active = failed == 2 and (find_ws_entry(slot_weapons[1], slot_ws[1]) or { nil, {} })[2] or { results[failed - 1] };
            why = ('Breaks at step %d: %s does not chain off %s.'):format(
                failed, slot_ws[failed] or '?', table.concat(active or {}, ' / '));
        end
        dl:AddText({ ix, iy }, col(COLORS.subtext), why);
        iy = iy + lh + 6;
    end

    -- Path, coloured by the chain each step creates (wraps across lines).
    local px, py = ix, iy;
    local right = x + w - 16;
    for i, name in ipairs(path or {}) do
        local c = (i == 1) and COLORS.white or ((results and results[i]) and prop_color(results[i]) or COLORS.faint);
        local seg = name;
        local sw = text_w(seg);
        if px + sw > right and px > ix then px, py = ix, py + lh + 4; end
        dl:AddText({ px, py }, col(c), seg);
        px = px + sw;
        if i < #path then
            local arrow = '  >  ';
            if px + text_w(arrow) > right then px, py = ix, py + lh + 4; end
            dl:AddText({ px, py }, col(COLORS.faint), arrow);
            px = px + text_w(arrow);
        end
    end
    py = py + lh;

    result_card_h = (py - y) + 14;
    imgui.Dummy({ w, result_card_h });
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local function push_style()
    imgui.PushStyleColor(ImGuiCol_WindowBg, COLORS.window);
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_Border, COLORS.border);
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.020, 0.040, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_FrameBg, COLORS.frame);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, COLORS.frame_hov);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, COLORS.frame_act);
    imgui.PushStyleColor(ImGuiCol_Button, COLORS.frame);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, COLORS.frame_hov);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, COLORS.frame_act);
    imgui.PushStyleColor(ImGuiCol_Header, { 0.10, 0.36, 0.62, 0.55 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.14, 0.46, 0.78, 0.60 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.18, 0.54, 0.90, 0.70 });
    imgui.PushStyleColor(ImGuiCol_Text, COLORS.white);
    imgui.PushStyleColor(ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrab, { 0.32, 0.82, 1.00, 0.25 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabHovered, { 0.32, 0.82, 1.00, 0.45 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabActive, { 0.32, 0.82, 1.00, 0.65 });
    imgui.PushStyleColor(ImGuiCol_ResizeGrip, { 0.32, 0.82, 1.00, 0.10 });
    imgui.PushStyleColor(ImGuiCol_ResizeGripHovered, { 0.32, 0.82, 1.00, 0.35 });
    imgui.PushStyleColor(ImGuiCol_ResizeGripActive, { 0.32, 0.82, 1.00, 0.60 });

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 10);
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 5);
    imgui.PushStyleVar(ImGuiStyleVar_PopupRounding, 6);
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1);
    imgui.PushStyleVar(ImGuiStyleVar_ChildBorderSize, 0);
    imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 8 });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 8, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 6, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, 8);
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarRounding, 6);
end

local function pop_style()
    imgui.PopStyleVar(12);
    imgui.PopStyleColor(21);
end

ashita.events.register('d3d_present', 'skillchains_present_cb', function()
    if not state.visible[1] then return end
    for i = 1, slot_count[1] do ensure_slot_ws(i) end
    local path, results, failed = calculate_selected_chain();

    push_style();
    imgui.SetNextWindowSize({ 690, 640 }, ImGuiCond_FirstUseEver);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse);

    if imgui.Begin('CHAINBUILDER##Fantasy21', state.visible, flags) then
        render_banner();

        -- The setup area scrolls, so any number of steps fits.
        imgui.BeginChild('##setup', { 0, 0 }, true);

        section_title('CHAIN SETUP', COLORS.cyan);

        -- Column labels
        local lx, ly = imgui.GetCursorScreenPos();
        local lw = imgui.GetContentRegionAvail();
        local dl = imgui.GetWindowDrawList();
        dl:AddText({ lx + COL_WEAPON_X, ly }, col(COLORS.faint), 'WEAPON');
        dl:AddText({ lx + COL_WS_X, ly }, col(COLORS.faint), 'WEAPON SKILL');
        dl:AddText({ lx + lw - 12 - text_w('RESULT'), ly }, col(COLORS.faint), 'RESULT');
        imgui.Dummy({ lw, line_h() });

        local prev_node = nil;
        for i = 1, slot_count[1] do
            prev_node = render_step(i, results, failed, prev_node);
        end

        -- Controls
        imgui.Dummy({ 0, 2 });
        if fancy_button('##cb_add', '+  ADD STEP', 120, COLORS.cyan) then
            local n = slot_count[1] + 1;
            slot_count[1] = n;
            slot_weapons[n] = slot_weapons[n - 1] or 'Sword';
            slot_ws[n] = '';
            ensure_slot_ws(n);
        end
        if slot_count[1] > 2 then
            imgui.SameLine();
            if fancy_button('##cb_remove', '-  REMOVE', 110, COLORS.gold) then
                slot_weapons[slot_count[1]] = nil;
                slot_ws[slot_count[1]] = nil;
                slot_count[1] = slot_count[1] - 1;
            end
        end
        imgui.SameLine();
        if fancy_button('##cb_clear', 'CLEAR', 86, COLORS.red) then
            slot_count[1] = 2;
            slot_weapons = { state.weapon, state.closer_weapon };
            slot_ws = { '', '' };
            for i = 1, 2 do ensure_slot_ws(i) end
        end

        imgui.Dummy({ 0, 6 });
        section_title('RESULT', COLORS.gold);
        path, results, failed = calculate_selected_chain();
        render_result(path, results, failed);

        imgui.EndChild();
    end
    imgui.End();
    pop_style();
end);
