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


within = dofile("within.lua")
local function vnew(x,y,z) return {x=x,y=y,z=z} end
dump = require 'inspect'

do
    print("-- within.get_pos_within")
    within.register_area("test",{
        {name="universe",vnew(10,10,10),vnew(-10,-10,-10)},
        {
            name = "earth",
            {vnew(7,7,7),vnew(-7,-7,-7)},
            {exclude=true,vnew(1,1,1),vnew(-1,-1,-1)}
        }
    })

    do
        local POS = vnew(6,6,6)
        local is_within, named_areas = within.get_pos_within(POS,"test")
        print(is_within) -- true
        print(dump(named_areas)) -- {"universe","earth"}
    end

    do
        local POS = vnew(11,11,11) -- Not within the area
        local is_within, named_areas = within.get_pos_within(POS,"test")
        print(is_within) -- false
        print(dump(named_areas)) -- {}
    end
end