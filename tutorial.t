local utils = require("utils")
local lib = require("libtutorial")

local Stack = lib.DynamicStack(int)
local Vector = lib.DynamicVector(int)
local VectorPair = lib.DynamicVectorPair(int)

terra main()
    utils.printf("hello there\n")
    -- create a stack and push some data
    var s = Stack.new(3)
    utils.printf("Adding three elements to 's'.\n")
    s:push(1)
    s:push(2)
    s:push(3)
    utils.printf("Adding two more elements to 's'.\n")
    s:push(4) --reallocating here
    s:push(5)

    -- move contents of `s` into a Vector
    utils.printf("Move 's' -> 'v'\n")
    utils.assert(s:size() == 5)
    var v : Vector = s
    utils.assert(s:size() == 0)
    utils.assert(v:size() == 5)

    -- create another stack and push some data
    var t = Stack.new(5)
    t:push(1)
    t:push(2)
    t:push(3)
    t:push(2)
    t:push(1)

    -- move contents of `t` into a Vector
    utils.printf("Move 't' -> 'w'\n")
    utils.assert(t:size() == 5)
    var w : Vector = t
    utils.assert(t:size() == 0)
    utils.assert(w:size() == 5)

    -- move contents of vector v, w into the aggregate data-structure
    utils.printf("Move '(v, w)' -> 'dual'\n")
    var dual = VectorPair.new(v, w)
    utils.assert(dual:size() == 5)
    utils.assert(v:size() == 0 and w:size() == 0)

    -- print contents of aggregate data type
    utils.printf("Contents of 'dual':\n")
    for i=0,5 do
        var x, y = dual(i)
        utils.printf("  dual(%d) = (%d, %d)\n", i, x, y)
    end 

end

main()