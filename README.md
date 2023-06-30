# within

Check whether a position is within an given area or [subareas](#named-definitions).

## Area Definitions

### Spatial vector

A [spatial vector](https://github.com/minetest/minetest/blob/master/doc/lua_api.md#spatial-vectors) (often referred to as positions or points) consists of three axes, x, y and z. They can be constructed by either the following methods:

```lua
-- Table form
{x = 0, y = 0, z = 0}

-- Vector objects
vector.new(0,0,0)
```

In this documentation, `vector.new` will always be used.

### Simple Area Definition

A simple area definition is an array of two points, e.g.

```lua
{vector.new(1,1,1),vector.new(-1,-1,-1)}
```

The above area definition will match all points within the range of (1,1,1) and (-1,-1,-1). Strictly speaking, the first vector must be smaller than the later one, but [`within.compile`](#withincompileareaoptimizecompress) will always handle the sorting.

### Combining multiple area definitions

More complex area definitions can be constructed by putting multiple simple area definitions into an array.

```lua
{
    {vector.new(1,1,1),vector.new(-1,-1,-1)},
    {vector.new(10,10,10),vector.new(7,7,7)}
}
```

The above area definition will match all points within either the range of (1,1,1) and (-1,-1,-1), or the range of (10,10,10) and (7,7,7).

### Excluding areas

In a complex area definition, an `exclude` field can be set to exclude areas from being matched:

```lua
{
    {vector.new(10,10,10),vector.new(-10,-10,-10)},
    {exclude=true,vector.new(2,2,2),vector.new(-2,-2,-2)}
}
```

The above example will match all points within the range of (10,10,10) and (-10,-10,-10) if they are not within the range of (2,2,2) and (-2,-2,-2).

If [nested](#nesting-definitions), exclusion rules take effect to its parent nest only.

As the later definitions take priority over the previous ones, additional definitions can be used to include areas that are excluded by another one:

```lua
{
    {vector.new(10,10,10),vector.new(-10,-10,-10)},
    {exclude=true,vector.new(2,2,2),vector.new(-2,-2,-2)},
    {vector.new(1,1,1),vector.new(-1,-1,-1)}
}
```

The above example will additionally match all points within the range of (1,1,1) and (-1,-1,-1).

### Nesting definitions

To organize things in a better way, definitions can be nested. In a nested definition, the `exclude` field can also be set, indicating all the areas defined inside are excluded. For example:

```lua
{
    {vector.new(10,10,10),vector.new(-10,-10,-10)},
    {
        exclude = true,
        {vector.new(1,1,1),vector.new(0,0,0)},
        {vector.new(0,0,0),vector.new(-1,-1,-1)}
    }
}
```

The above example matches all points within the range of (10,10,10) and (-10,-10,-10) if they are not within either the range of (1,1,1) and (0,0,0) or the range of (0,0,0) and (-1,-1,-1).

If a definition with `exclude = true` is present within a nest also with that value set, the area defined in the earlier definition will be excluded from the exclusion:

```lua
{
    {vector.new(10,10,10),vector.new(-10,-10,-10)},
    {
        exclude = true,
        {vector.new(7,7,7),vector.new(-7,-7,-7)},
        {exclude=true,vector.new(1,1,1),vector.new(-1,-1,-1)}
    }
}
```

The range of exclusion in the above examples covers the range of (7,7,7) and (-7,-7,-7), but not including the range of (1,1,1) and (-1,-1,-1). The above example matches all points within the range of (10,10,10) and (-10,-10,-10) if they are not within the range of exclusion.

### Named definitions

An area definition, or a nest of them, can be named using the `name` field:

```lua
{
    {name="universe",vector.new(10,10,10),vector.new(-10,-10,-10)},
    {
        name = "earth",
        {vector.new(7,7,7),vector.new(-7,-7,-7)},
        {exclude=true,vector.new(1,1,1),vector.new(-1,-1,-1)}
    }
}
```

When querying for the area name, the point (9,9,9) will return `{"universe"}`. The point (6,6,6) will return `{"universe","earth"}`. However, as (1,1,1) to (-1,-1,-1) are excluded from the nest defining `"earth"`, the point (0,0,0) will only return `{"universe"}`. See [`within.get_pos_within`](#withinget_pos_withinposarea) for more information.

## API

### `within.register_area(name,area)`

Register an area that can be re-used using the string `name`. `area` is a definition of an area.

Once registered, the string `name` can be used in place of the original definition, hence the tidiness of the code is maintained.

An additional `groups` field can be defined in the area definition:

```lua
within.register_area("test1",{
    groups = {"test_group"},
    vector.new(10,10,10), vector.new(-10,-10,-10)
})
within.register_area("test2",{
    groups = {"test_group"},
    vector.new(20,20,20), vector.new(11,11,11)
})
```

If set to one or more registered area definitions, the string `"group:" .. group` can be used to refer to all the registered areas of the same group in the order of registration. As a result, if the above two areas are registered that way, the following area definitions are identical:

```lua
-- By giving the definitions directly
{
    {vector.new(10,10,10), vector.new(-10,-10,-10)},
    {vector.new(20,20,20), vector.new(11,11,11)}
}

-- By referring to their registered names
{"test1","test2"}

-- By their group names
{"group:test_group"}
```

A special group, `group:any`, can be used to match all registered areas. However, the use of it is discouraged, and you are recommended to register your own group.

### `within.get_pos_within(pos,area)`

Check if a point lies within the area. If yes, also return a list of matched named areas.

For example:

```lua
within.register_area("test",{
    {name="universe",vector.new(10,10,10),vector.new(-10,-10,-10)},
    {
        name = "earth",
        {vector.new(7,7,7),vector.new(-7,-7,-7)},
        {exclude=true,vector.new(1,1,1),vector.new(-1,-1,-1)}
    }
})

do
    local POS = vector.new(6,6,6)
    local is_within, named_areas = within.get_pos_within(POS,"test")
    print(is_within) -- true
    print(dump(named_areas)) -- {"universe","earth"}
end

do
    local POS = vector.new(11,11,11) -- Not within the area
    local is_within, named_areas = within.get_pos_within(POS,"test")
    print(is_within) -- false
    print(dump(named_areas)) -- {}
end
```

### `within.compile(area[,optimize[,compress]])`

Expand the area to its table form (i.e. no name or group alias). If `optimize` is `true`, return the area in its simplest form.

When compiling the area into its simplest form, nested areas, except those with a `name` set, are simplified so that the children areas are placed in the root table. For example:

```lua
-- Before optimization
{
    {
        name = "test1"
        {vector.new(7,7,7),vector.new(-7,-7,-7)}
    },
    {
        exclude = true,
        {vector.new(5,5,5),vector.new(3,3,3)},
        {vector.new(1,1,1),vector.new(-1,-1,-1)}
    }
}

-- After optimization
{
    {
        name = "test1"
        {vector.new(7,7,7),vector.new(-7,-7,-7)}
    },
    {exclude = true,vector.new(5,5,5),vector.new(3,3,3)},
    {exclude = true,vector.new(1,1,1),vector.new(-1,-1,-1)}
}
```

If `compress` field is set to `true`, algorithms will be used to reduce the number of area definitions while not affecting the order and accuracy of matching. This only works if `optimize` is also `true`. However, no algorithms are present now, and you are welcome to contribute on this field.

Note that the optimization only works on nested areas without mixing `exclude = false` and `exclude = true`.

The optimizing and compressing functions are considered slow, so it is recommended not to use them in any runtime components, like callbacks, ABMs and globalsteps.

This function is mostly for internal purpose:

- [`within.register_area`](#withinregister_areanamearea) uses it with `optimize` and `compress` set to `true`.
- [`within.get_pos_within`](#withinget_pos_withinposarea) uses it with `optimize` and `compress` set to `false`.

### `within.registered_areas` and `within.registered_areas_by_groups`

These are the two internal tables storing a list of, or the relevant data of, registered area definitions.

- `within.registered_areas`: Dictionary of all [registered](#withinregister_areanamearea) area definitions, with their registration names as the key.
- `within.registered_areas_by_groups`: Dictionary storing the group-area mapping. The key is the name of the group, while the value is a list of area registration names.

Their values are read-only. Modifying them will break the functionality of the library.
