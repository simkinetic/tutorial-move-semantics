require "terralibext"
local C = terralib.includec("stdlib.h")
local utils = require("utils")


local DynamicStack = terralib.memoize(function(T)
    local struct Stack {
        data : &T       -- Pointer to heap-allocated elements
        size : int      -- Current number of elements
        capacity : int  -- Maximum capacity before reallocation
    }

    -- This table stores all the static methods
    Stack.staticmethods = {}

    -- Enable static method dispatch (e.g., Stack.new)
    Stack.metamethods.__getmethod = function(self, methodname)
        return self.methods[methodname] or Stack.staticmethods[methodname]
    end

    terra Stack:size() return self.size end
    terra Stack:capacity() return self.capacity end

    -- Macro for get/set access: stack(i)
    Stack.metamethods.__apply = macro(function(self, i)
        return `self.data[i]
    end)

    -- Initialize with null pointer and zero size/capacity
    terra Stack:__init()
        self.data = nil
        self.size = 0
        self.capacity = 0
    end

    -- Free heap memory and reset state
    terra Stack:__dtor()
        if self.data~=nil then
            utils.printf("Deleting stack.\n")
            C.free(self.data)
            self.data = nil
        end
    end

    -- Create a new stack with initial capacity
    Stack.staticmethods.new = terra(capacity : int)
        return Stack{data=[&T](C.malloc(capacity * sizeof(T))), capacity=capacity}
    end

    -- Reallocate when capacity is exceeded
    terra Stack:realloc(capacity : int)
        utils.printf("Reallocating stack memory.\n")
        self.data = [&T](C.realloc(self.data, capacity * sizeof(T)))
        self.capacity = capacity
    end

    -- Push an element, moving it into the stack
    terra Stack:push(v : T)
        if self.size == self.capacity then
            self:realloc(1 + 2 * self.capacity) -- Double capacity plus one
        end
        self.size = self.size + 1
        self.data[self.size - 1] = __move__(v) -- Explicit move, avoiding copy when `v` is managed and copyable
    end

    -- Pop an element, moving it out
    terra Stack:pop()
        if self.size > 0 then
            var tmp = __move__(self.data[self.size - 1]) -- Explicit move, cleaning resources of Stack element in case `T` is managed
            self.size = self.size - 1
            return tmp
        end
    end

    return Stack
end)


local DynamicVector = terralib.memoize(function(T)

    local struct Vector {
        data : &T   -- Pointer to fixed heap memory
        size : int  -- Number of elements
    }

    -- This table stores all the static methods
    Vector.staticmethods = {}

    -- Enable static method dispatch (e.g., Vector.new)
    Vector.metamethods.__getmethod = function(self, methodname)
        return self.methods[methodname] or Vector.staticmethods[methodname]
    end

    -- Initialize with null pointer and zero size
    terra Vector:__init()
        self.data = nil
        self.size = 0
    end

    -- Free heap memory and reset
    terra Vector:__dtor()
        if self.data~=nil then
            utils.printf("Deleting vector.\n")
            C.free(self.data)
            self.data = nil
            self.size = 0
        end
    end

    terra Vector:size() return self.size end

    -- Macro for get/set access: vector(i)
    Vector.metamethods.__apply = macro(function(self, i)
        return `self.data[i]
    end)

    -- Allocate a dynamic vector of `size`
    Vector.staticmethods.new = terra(size : int)
        return Vector{data=[&T](C.malloc(size * sizeof(T))), size=size}
    end

    -- Import DynamicStack for casting
    local Stack = DynamicStack(T)

    -- Reinterprete a reference to a stack to a reference of a vector. This is for example used in `__move :: {&Vector, &Vector}` when one of the arguments is a pointer to a stack
    Vector.metamethods.__cast = function(from, to, exp)
        if from:ispointer() and from.type == Stack and to:ispointer() and to.type == Vector then
            return quote
                exp.capacity = 0 -- Invalidate Stack’s ownership
            in
                [&Vector](exp) -- Transfer to &Vector, preps for `__move :: {&Vector, &Vector} -> {}`
            end
        else
            error("ArgumentError: not able to cast " .. tostring(from) .. " to " .. tostring(to) .. ".")
        end
    end

    return Vector
end)

local DynamicVectorPair = terralib.memoize(function(T)

    local Vector = DynamicVector(T)

    local struct Pair {
        first : Vector
        second : Vector
    }

    -- This table stores all the static methods
    Pair.staticmethods = {}

    -- Enable static method dispatch (e.g., Pair.new)
    Pair.metamethods.__getmethod = function(self, methodname)
        return self.methods[methodname] or Pair.staticmethods[methodname]
    end

    -- Create a new `DynamicVectorPair`. Note that the function arguments are passed by value. Since `Vector` does not implement `__copy`, the function argumens will be moved from by default. 
    Pair.staticmethods.new = terra(first : Vector, second : Vector)
        utils.assert(first:size() == second:size(), "Error: sizes are not compatible.")
        return Pair{first=first, second=second}
    end

    -- Macro for get/set access: dualvector(i)
    Pair.metamethods.__apply = macro(function(self, i)
        return quote
        in
            self.first(i), self.second(i)
        end
    end)

    terra Pair:size() return self.first:size() end

    return Pair
end)

return {
    DynamicStack = DynamicStack,
    DynamicVector = DynamicVector,
    DynamicVectorPair = DynamicVectorPair
}