--[[
    Copyright (C) 2023  1F616EMO

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
    USA

    The full license text can be found at lgpl-2.1.txt.
]]

-- Allow uses outside of Minetest
local sort, in_area, table_copy, debug
if rawget(_G, "vector") then
    sort = vector.sort
    in_area = vector.in_area
else
    sort = function(a,b)
        return {x=math.min(a.x, b.x), y=math.min(a.y, b.y), z=math.min(a.z, b.z)},
            {x=math.max(a.x, b.x), y=math.max(a.y, b.y), z=math.max(a.z, b.z)}
    end
    in_area = function(pos, min, max)
        return (pos.x >= min.x) and (pos.x <= max.x) and
            (pos.y >= min.y) and (pos.y <= max.y) and
            (pos.z >= min.z) and (pos.z <= max.z)
    end
end
---@diagnostic disable-next-line: undefined-field
if table.copy then
    ---@diagnostic disable-next-line: undefined-field
    table_copy = table.copy
else
    table_copy = function(t, seen)
        local n = {}
        seen = seen or {}
        seen[t] = n
        for k, v in pairs(t) do
            n[(type(k) == "table" and (seen[k] or table_copy(k, seen))) or k] =
                (type(v) == "table" and (seen[v] or table_copy(v, seen))) or v
        end
        return n
    end
end
if rawget(_G,"dump") then
    debug = dump
else
    local ok, mod = require('inspect')
    if not ok then
        debug = print -- We have no access to fancy debugging functions
    else
        debug = mod
    end
end
local function is_vector(v)
    return type(v) == "table" and v.x and v.y and v.z
end

local p = {}

p.registered_areas = {}
p.registered_areas_by_groups = {}

function p.register_area(name,area)
    assert(name and name ~= "","[within] Invalid area name!")
    assert(area,"[within] Invalid area!")

    if type(area) == "table" and area.groups then
        for _,y in ipairs(area.groups) do
            assert(y ~= "any","[within] Attempt to override built-in group \"any\"")
            if not p.registered_areas_by_groups[y] then
                p.registered_areas_by_groups[y] = {}
            end
            table.insert(p.registered_areas_by_groups[y],name)
        end
    end

    local after_compress = p.compile(area,true,true)
    p.registered_areas[name] = after_compress
end

local function compile_lookup(area)
    if string.sub(area,1,6) == "group:" then -- Group
        local group_name = string.sub(area,7)
        if group_name == "any" then -- Special group handle
            return table_copy(p.registered_areas)
        end
        
        if p.registered_areas_by_groups[group_name] then
            local returns = {}
            for _,name in ipairs(p.registered_areas_by_groups[group_name]) do
                table.insert(returns,p.registered_areas[name])
            end
            return returns
        end

        return {}
    else -- Area name
        if p.registered_areas[area] then
            return table_copy(p.registered_areas[area])
        end
        -- If not present
        error("[within] Attempt to refer to unregistered area \"" .. area .. "\"")
    end
end

local function do_sort(simp_area)
    
    local mint,maxt = sort(simp_area[1],simp_area[2])
    local return_t = {mint,maxt}
    return_t.name = simp_area.name
    return_t.exclude = simp_area.exclude
    return return_t
end

function p.compile(area,optimize,compress)
    if type(area) == "string" then
        area = compile_lookup(area)
    end

    if type(area) == "table" then
        if is_vector(area) then -- Just a vector. We've somehow reached here, but anyway
            return area
        elseif is_vector(area[1]) and is_vector(area[2]) then -- simple definitions
            return do_sort(area)
        end
        -- Nested area
        local compiled_area = {}
        compiled_area.name = area.name
        compiled_area.exclude = area.exclude
        for i,v in ipairs(area) do
            if is_vector(v[1]) and is_vector(v[2]) then
                compiled_area[i] = do_sort(v)
            else
                compiled_area[i] = p.compile(v,optimize,false)
            end
        end
        -- Optmize functions
        -- # Do the check reversely to ensure newly added entries are not checked
        if optimize then
            do
                local i = #compiled_area
                while i > 0 do
                    local v = compiled_area[i]
                    if not(is_vector(v[1]) and is_vector(v[2])) then -- nothing to do with simple definitions
                        if not v.name then -- Do not affect named area detection

                            -- Not working on nests with exclude and non-exclude mixed
                            local mixed = false
                            do
                                local old_val = nil
                                for _,v_v in ipairs(v) do
                                    local new_val = false
                                    if v_v.exclude then
                                        new_val = true
                                    end
                                    if old_val ~= nil and old_val ~= new_val then
                                        mixed = true
                                        break
                                    end
                                    old_val = new_val
                                end
                            end
                            if not mixed then
                                -- Optimize start
                                table.remove(compiled_area,i)

                                -- Insert back to the main table reversely
                                local v_i = #v
                                while v_i > 0 do
                                    local v_v = v[v_i]
                                    if v.exclude then
                                        if v_v.exclude then
                                            v_v.exclude = nil
                                        else
                                            v_v.exclude = true
                                        end
                                    end

                                    table.insert(compiled_area,i,v_v)
                                    v_i = v_i - 1
                                end
                            end
                        end
                    end
                    
                    i = i - 1
                end
            end

            if compress then
                -- TODO: Add compress algorithms
            end
        end

        area = compiled_area
    end

    return area
end

local function get_pos_within_int(pos,compiled_area)
    if is_vector(compiled_area[1]) and is_vector(compiled_area[2]) then -- Simple area
        local is_within = in_area(pos,compiled_area[1],compiled_area[2])
        local names = {}
        if compiled_area.name then
            table.insert(names,compiled_area.name)
        end
        if is_within then
            return true, names
        end
    end

    local matched = false
    local names_rtn = {}
    for i,v in ipairs(compiled_area) do
        local status, names = get_pos_within_int(pos,v)
        if status == true then
            matched = not v.exclude
            if not v.exclude and v.name then
                table.insert(names_rtn,v.name)
            end
            for _,v in ipairs(names) do
                table.insert(names_rtn,v)
            end
        end
    end
    return matched, names_rtn
end

function p.get_pos_within(pos,area)
    local compiled_area = p.compile(area,false,false)

    local status, names = get_pos_within_int(pos,compiled_area)
    return status, names
end



return p -- within