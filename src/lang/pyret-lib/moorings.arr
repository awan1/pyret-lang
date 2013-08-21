#lang pyret/library

provide {
  list: list,
  builtins: builtins,
  error: error,
  checkers: checkers,
  option: option
}
end

# BUILTINS

fun mklist(obj):
  doc: "creates a List from something with `first` and `rest` fields, recursively"
  if obj.is-empty: empty
  else:            link(obj.first, mklist(obj.rest))
  end
end

fun keys(obj):
  doc: "returns a List of the keys of an object, as strings"
  mklist(prim-keys(obj))
end

fun has-field(obj, name):
  doc: "returns true if the object has a field with the name specified"
  prim-has-field(obj, name)
end

fun num-keys(obj):
  doc: "returns the Number of fields in an object"
  prim-num-keys(obj)
end

fun equiv(obj1, obj2):
  doc: "Check if two objects are equal via an _equals method, or
        have all the same keys with equiv fields"
  fun all_same(obj1, obj2):
    if Method(obj1) or Function(obj1):
      false
    else if has-field(obj1, "_equals"):
      obj1._equals(obj2)
    else:
      left_keys = keys(obj1)
      for fold(same from true, key from left_keys):
        if not (has-field(obj2, key)): false
        else:
          left_val = obj1.[key]
          right_val = obj2.[key]
          same and equiv(left_val, right_val)
        end
      end
    end
  end
  if has-field(obj1, "_equals"):
    obj1._equals(obj2)
  else if num-keys(obj1)._equals(num-keys(obj2)):
    all_same(obj1, obj2)
  else:
    false
  end
check:
  eq = checkers.check-equals
  eq("empty objects", equiv({}, {}), true)
  eq("",equiv({x : 5}, {y : 6}), false)
  eq("",equiv({x : 5}, {x : 6}), false)
  eq("",equiv({x : 5}, {x : 5}), true)
  eq("",equiv({x : 5, y : 6}, {y : 6, x : 5}), true)
  eq("",equiv({x : {z: "foo"}, y : 6}, {y : 6, x : {z: "foo"}}), true)
  eq("",equiv({x : {z: "foo"}, y : [true, 6]}, {y : [true, 6], x : {z: "foo"}}), true)
  eq("",equiv(fun: end, fun: end), false)
  
  f = fun: end
  eq("functions in objects aren't ever equal", equiv({my_fun:f}, {my_fun:f}), false)
  m = method(self): end
  eq("methods in objects aren't ever equal", equiv({my_meth:m}, {my_meth:m}), false)
  
  eq("lists of objects", equiv([{}], [{}]), true)
  eq("lists of prims", equiv([5], [5]), true)
end

builtins = {
  keys: keys,
  has-field: has-field,
  mklist: mklist,
  equiv: equiv
}

# LISTS

fun get-help(lst, n :: Number):
  fun help(lst, cur):
    if is-empty(lst): raise("get: n too large " + tostring(n))
    else if cur == 0: lst.first
    else: help(lst.rest, cur - 1)
    end
  end
  if n < 0: raise("get: invalid argument: " + tostring(n))
  else: help(lst, n)
  end
end
fun set-help(lst, n :: Number, v):
  fun help(lst, cur):
    if is-empty(lst): raise("set: n too large " + tostring(n))
    else if cur == 0: v ^ link(lst.rest)
    else: lst.first ^ link(help(lst.rest, cur - 1))
    end
  end
  if n < 0: raise("set: invalid argument: " + tostring(n))
  else: help(lst, n)
  end
end

data List:
  | empty with:

    length(self): 0 end,

    each(self, f): nothing end,

    map(self, f): empty end,

    filter(self, f): empty end,

    foldr(self, f, base): base end,

    foldl(self, f, base): base end,

    member(self, elt): false end,

    append(self, other): other end,

    last(self): raise('last: took last of empty list') end,

    take(self, n):
      if n == 0:     empty
      else if n > 0: raise('take: took too many')
      else:          raise('take: invalid argument on empty list: ' + n.tostring())
      end
    end,

    drop(self, n):
      if n == 0:     empty
      else if n > 0: raise('drop: dropped too many')
      else:          raise('drop: invalid argument')
      end
    end,

    reverse(self): self end,

    get(self, n): get-help(self, n) end,

    set(self, n, e): set-help(self, n, e) end,
    
    _equals(self, other): is-empty(other) end,

    tostring(self): "[]" end,

    sort-by(self, cmp, eq): self end,

    sort(self): self end,

    join-str(self, str): "" end

  | link(first, rest :: List) with:

    length(self): 1 + self.rest.length() end,

    each(self, f): f(self.first) self.rest.each(f) end,

    map(self, f): f(self.first)^link(self.rest.map(f)) end,

    filter(self, f):
      if f(self.first): self.first^link(self.rest.filter(f))
      else:             self.rest.filter(f)
      end
    end,

    member(self, elt): (elt == self.first) or self.rest.member(elt) end,

    foldr(self, f, base): f(self.first, self.rest.foldr(f, base)) end,

    foldl(self, f, base): self.rest.foldl(f, f(self.first, base)) end,

    append(self, other): self.first^link(self.rest.append(other)) end,

    last(self):
      if is-empty(self.rest): self.first
      else: self.rest.last()
      end
    end,

    reverse(self):
       self.rest.reverse().append(self.first^link(empty))
    end,

    take(self, n):
      if n == 0:      empty
      else if n >= 0: self.first^link(self.rest.take(n - 1))
      else:           raise('take: invalid argument on non-empty list: ' + n.tostring())
      end
    end,

    drop(self, n):
      if n == 0:     self
      else if n > 0: self.rest.drop(n - 1)
      else: raise('drop: invalid argument')
      end
    end,

    get(self, n): get-help(self, n) end,

    set(self, n, e): set-help(self, n, e) end,
        
    _equals(self, other):
      if is-link(other):
        others-equal = (self.first == other.first)
        others-equal and (self.rest == other.rest)
      else:
        false
      end
    end,

    tostring(self):
      "[" +
        for fold(combined from tostring(self.first), elt from self.rest):
          combined + ", " + tostring(elt)
        end
      + "]"
    end,

    sort-by(self, cmp, eq):
      pivot = self.first
      less = self.filter(fun(e): cmp(e,pivot) end).sort-by(cmp, eq)
      equal = self.filter(fun(e): eq(e,pivot) end)
      greater = self.filter(fun(e): cmp(pivot,e) end).sort-by(cmp, eq)
      less.append(equal).append(greater)
    end,

    sort(self):
      self.sort-by(fun(e1,e2): e1 < e2 end, fun(e1,e2): e1 == e2 end)
    end,

    join-str(self, str):
      if is-link(self.rest):
         tostring(self.first) + str + self.rest.join-str(str)
      else:
         tostring(self.first)
      end
    end

sharing:
  push(self, elt):
    doc: "adds an element to the front of the list, returning a new list"
    link(elt, self)
  end,
  _plus(self, other): self.append(other) end

check:
  eq = checkers.check-equals
  
  eq("list set", [1,2,3].set(1, 5), [1,5,3])

  o1 = {
    _lessthan(self, other): self.x < other.x end,
    _equals(self, other): self.x == other.x end,
    x: 5
  }
  o2 = o1.{
    _lessthan(self, other): self.x < other.x end,
    _equals(self, other): self.x == other.x end,
    x: 10
  }
  [o2, o1].sort() is [o1, o2]
end

fun range(start, stop):
  doc: "creates a list of numbers, starting with start, ending with stop-1"
  if start < stop:       link(start, range(start + 1, stop))
  else if start == stop: empty
  else if start > stop:  raise("range: start greater than stop: ("
                                 + start.tostring()
                                 + ", "
                                 + stop.tostring()
                                 + ")")
  end
end

fun repeat(n :: Number, e :: Any):
  doc: "creates a list with n copies of e"
  if n > 0:       link(e, repeat(n - 1, e))
  else if n == 0: empty
  else:           raise("repeat: can't have a negative argument'")
  end
check:
  eq = checkers.check-equals

  eq("repeat 0", repeat(0, 10), [])
  eq("repeat 3", repeat(3, -1), [-1, -1, -1])
  eq("repeat 1", repeat(1, "foo"), ["foo"])
end

fun filter(f, lst :: List):
  doc: "returns the subset of lst for which f(elem) is true"
  if is-empty(lst):
    empty
  else:
    if f(lst.first):
      lst.first^link(filter(f, lst.rest))
    else:
      filter(f, lst.rest)
    end
  end
end

fun find(f, lst :: List):
  doc: "returns Some<elem> where eleme is the first elem in lst for which
        f(elem) returns true, or none otherwise"
  if is-empty(lst):
    none
  else:
    if f(lst.first):
      some(lst.first)
    else:
      find(f, lst.rest)
    end
  end
end
  
fun map(f, lst :: List):
  doc: "returns a list made up of f(elem) for each elem in lst"
  if is-empty(lst):
    empty
  else:
    f(lst.first)^link(map(f, lst.rest))
  end
end

fun map2(f, l1 :: List, l2 :: List):
  doc: "returns a list made up of f(elem1, elem2) for each elem1 in l1, elem2 in l2"
  if is-empty(l1) or is-empty(l2):
    empty
  else:
    f(l1.first, l2.first)^link(map2(f, l1.rest, l2.rest))
  end
end

fun map3(f, l1 :: List, l2 :: List, l3 :: List):
  doc: "returns a list made up of f(e1, e2, e3) for each e1 in l1, e2 in l2, e3 in l3"
  if is-empty(l1) or is-empty(l2) or is-empty(l3):
    empty
  else:
    f(l1.first, l2.first, l3.first)^link(map3(f, l1.rest, l2.rest, l3.rest))
  end
end

fun map4(f, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  doc: "returns a list made up of f(e1, e2, e3, e4) for each e1 in l1, e2 in l2, e3 in l3, e4 in l4"
  if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
    empty
  else:
    f(l1.first, l2.first, l3.first, l4.first)^link(map4(f, l1.rest, l2.rest, l3.rest, l4.rest))
  end
end

fun map_n(f, n :: Number, lst :: List):
  doc: "returns a list made up of f(n, e1), f(n+1, e2) .. for e1, e2 ... in lst"
  if is-empty(lst):
    empty
  else:
    f(n, lst.first)^link(map_n(f, n + 1, lst.rest))
  end
end

fun map2_n(f, n :: Number, l1 :: List, l2 :: List):
  if is-empty(l1) or is-empty(l2):
    empty
  else:
    f(n, l1.first, l2.first)^link(map2_n(f, n + 1, l1.rest, l2.rest))
  end
end

fun map3_n(f, n :: Number, l1 :: List, l2 :: List, l3 :: List):
  if is-empty(l1) or is-empty(l2) or is-empty(l3):
    empty
  else:
    f(n, l1.first, l2.first, l3.first)^link(map3_n(f, n + 1, l1.rest, l2.rest, l3.rest))
  end
end

fun map4_n(f, n :: Number, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
    empty
  else:
    f(n, l1.first, l2.first, l3.first, l4.first)^link(map4(f, n + 1, l1.rest, l2.rest, l3.rest, l4.rest))
  end
end

fun each(f, lst :: List):
  doc: "Calls f for each elem in lst, and returns nothing"
  fun help(lst):
    if is-empty(lst):
      nothing
    else:
      f(lst.first)
      help(lst.rest)
    end
  end
  help(lst)
end

fun each2(f, l1 :: List, l2 :: List):
  doc: "Calls f on each pair of corresponding elements in l1 and l2, and returns nothing.  Stops after the shortest list"
  fun help(l1, l2):
    if is-empty(l1) or is-empty(l2):
      nothing
    else:
      f(l1.first, l2.first)
      help(l1.rest, l2.rest)
    end
  end
  help(l1, l2)
end

fun each3(f, l1 :: List, l2 :: List, l3 :: List):
  doc: "Calls f on each triple of corresponding elements in l1, l2 and l3, and returns nothing.  Stops after the shortest list"
  fun help(l1, l2, l3):
    if is-empty(l1) or is-empty(l2) or is-empty(l3):
      nothing
    else:
      f(l1.first, l2.first, l3.first)
      help(l1.rest, l2.rest, l3.rest)
    end
  end
  help(l1, l2, l3)
end

fun each4(f, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  doc: "Calls f on each tuple of corresponding elements in l1, l2, l3 and l4, and returns nothing.  Stops after the shortest list"
  fun help(l1, l2, l3, l4):
    if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
      nothing
    else:
      f(l1.first, l2.first, l3.first, l4.first)
      help(l1.rest, l2.rest, l3.rest, l4.rest)
    end
  end
  help(l1, l2, l3, l4)
end

fun each_n(f, n :: Number, lst:: List):
  fun help(n, lst):
    if is-empty(lst):
      nothing
    else:
      f(n, lst.first)
      help(n + 1, lst.rest)
    end
  end
  help(n, lst)
end

fun each2_n(f, n :: Number, l1 :: List, l2 :: List):
  fun help(n, l1, l2):
    if is-empty(l1) or is-empty(l2):
      nothing
    else:
      f(n, l1.first, l2.first)
      help(n + 1, l1.rest, l2.rest)
    end
  end
  help(n, l1, l2)
end

fun each3_n(f, n :: Number, l1 :: List, l2 :: List, l3 :: List):
  fun help(n, l1, l2, l3):
    if is-empty(l1) or is-empty(l2) or is-empty(l3):
      nothing
    else:
      f(n, l1.first, l2.first, l3.first)
      help(n + 1, l1.rest, l2.rest, l3.rest)
    end
  end
  help(n, l1, l2, l3)
end

fun each4_n(f, n :: Number, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  fun help(n, l1, l2, l3, l4):
    if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
      nothing
    else:
      f(n, l1.first, l2.first, l3.first, l4.first)
      help(n + 1, l1.rest, l2.rest, l3.rest, l4.rest)
    end
  end
  help(n, l1, l2, l3, l4)
end

fun fold(f, base, lst :: List):
  if is-empty(lst):
    base
  else:
    fold(f, f(base, lst.first), lst.rest)
  end
end

fun fold2(f, base, l1 :: List, l2 :: List):
  if is-empty(l1) or is-empty(l2):
    base
  else:
    fold2(f, f(base, l1.first, l2.first), l1.rest, l2.rest)
  end
end

fun fold3(f, base, l1 :: List, l2 :: List, l3 :: List):
  if is-empty(l1) or is-empty(l2) or is-empty(l3):  
    base
  else:
    fold3(f, f(base, l1.first, l2.first, l3.first), l1.rest, l2.rest, l3.rest)
  end
end

fun fold4(f, base, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
    base
  else:
    fold4(f, f(base, l1.first, l2.first, l3.first, l4.first), l1.rest, l2.rest, l3.rest, l4.rest)
  end
end

list = {
    List: List,
    is-empty: is-empty,
    is-link: is-link,
    empty: empty,
    link: link,

    range: range,
    repeat: repeat,
    filter: filter,
    find: find,
    map: map,
    map2: map2,
    map3: map3,
    map4: map4,
    map_n: map_n,
    map2_n: map2_n,
    map3_n: map3_n,
    map4_n: map4_n,
    each: each,
    each2: each2,
    each3: each3,
    each4: each4,
    each_n: each_n,
    each2_n: each2_n,
    each3_n: each3_n,
    each4_n: each4_n,
    fold: fold,
    fold2: fold2,
    fold3: fold3,
    fold4: fold4
  }

data Location:
  | location(file :: String, line, column) with:
    _equals(self, other):
      is-location(other) and
      (self.file == other.file) and
      (self.line == other.line) and
      (self.column == other.column)
    end,
    format(self):
      self.file +
      ": line " +
      self.line.tostring() +
      ", column " +
      self.column.tostring()
    end,
    tostring(self): self.format() end
end

data Error:
  | opaque-error(message :: String, location :: Location, trace :: List<Location>) with:
    name(self): "Error using opaque internal value" end
  | field-not-found(message :: String, location :: Location, trace :: List<Location>) with:
    name(self): "Field not found" end
  | field-non-string(message :: String, location :: Location, trace :: List<Location>) with:
    name(self): "Non-string in field name" end
  | cases-miss(message :: String, location :: Location, trace :: List<Location>) with:
    name(self): "No cases matched" end
  | invalid-case(message :: String, location :: Location, trace :: List<Location>) with:
    name(self): "Invalid case" end
  | lazy-error(message :: String, location :: Location, trace :: List<Location>) with:
    name(self): "Email joe@cs.brown.edu or dbpatter@cs.brown.edu and complain that they were lazy" end
sharing:
  tostring(self): self.format() end,
  format(self):
    self.location.format().append(":\n").append(self.name()).append(": ").append(self.message) end
end


fun make-error(obj):
  trace = for map(loc from mklist(obj.trace)):
    location(loc.path, loc.line, loc.column)
  end
  loc = location(obj.path, obj.line, obj.column)
  if obj.system:
    type = obj.value.type
    msg = obj.value.message
    if (type == "opaque"): opaque-error(msg, loc, trace)
    else if (type == "field-not-found"): field-not-found(msg, loc, trace)
    else if (type == "field-non-string"): field-non-string(msg, loc, trace)
    else: lazy-error(msg, loc, trace)
    end
  else: obj.value
  end
end

error = {
  opaque-error: opaque-error,
  is-opaque-error : is-opaque-error,
  field-not-found: field-not-found,
  is-field-not-found: is-field-not-found,
  cases-miss: cases-miss,
  is-cases-miss: is-cases-miss,
  invalid-case: invalid-case,
  is-invalid-case: is-invalid-case,
  make-error: make-error,
  Error: Error,
  Location: Location,
  location: location,
  is-location: is-location
}



data Option:
  | none with:
      orelse(self, v): v end,
      andthen(self, f): self end,
      tostring(self): "None" end
  | some(value) with:
      orelse(self, v): self.value end,
      andthen(self, f): f(self.value) end,
      tostring(self): "Some(" + tostring(self.value) + ")" end
end

option = {
  Option: Option,
  is-none: is-none,
  is-some: is-some,
  none: none,
  some: some,
}


data Result:
  | success(name :: String)
  | failure(name :: String, reason :: String)
  | err(name :: String, exception :: Any)
end

var current-results = empty 

fun check-true(name, val): check-equals(name, val, true) end
fun check-false(name, val): check-equals(name, val, false) end
fun check-equals(name, val1, val2):
  try:
    values_equal = val1 == val2
    if values_equal:
      current-results := current-results.push(success(name))
    else:
      current-results :=
        current-results.push(failure(name, "Values not equal: \n" +
                                     tostring(val1) +
                                     "\n\n" +
                                     tostring(val2)))
    end
    values_equal
  except(e):
    current-results := current-results.push(err(name, e))
  end
end

fun check-pred(name, val1, pred):
  try:
    if pred(val1):
      current-results := current-results.push(success(name))
    else:
      current-results :=
        current-results.push(failure(name, "Value didn't satisfy predicate: " +
                                     tostring(val1) +
                                     ", " +
                                     pred._doc))
    end
  except(e):
    current-results := current-results.push(err(name, e))
  end
end

data CheckResult:
  | normal-result(name :: String, location :: Location, results :: List)
  | error-result(name :: String, location :: Location, results :: List, err :: Any)
end

var all-results :: List = empty

fun run-checks(checks):
  when checks.length() <> 0:
    fun lst-to-structural(lst):
      if has-field(lst, 'first'):
        { first: lst.first, rest: lst-to-structural(lst.rest), is-empty: false}
      else:
        { is-empty: true }
      end
    end
    these-checks = mklist(lst-to-structural(checks))
    old-results = current-results
    these-check-results = 
      for map(chk from these-checks):
        l = chk.location
        loc = error.location(l.file, l.line, l.column)
        current-results := empty
        result = try:
          chk.run()
          normal-result(chk.name, loc, current-results)
        except(e):
          error-result(chk.name, loc, current-results, e)
        end
        result
      end

    relevant-results = these-check-results.filter(fun(elt):
      is-error-result(elt) or (elt.results.length() > 0)
    end)

    current-results := old-results
    when relevant-results.length() > 0:
      all-results := all-results.push(relevant-results)
    end
  end
  nothing
end

fun clear-results(): all-results := empty nothing end
fun get-results(): {
  results: all-results,
  format(self): format-check-results(self.results) end
} end

fun format-check-results(results):
  init = { passed: 0, failed : 0, test-errors: 0, other-errors: 0, total: 0}
  counts = for fold(acc from init, results from results):
    for fold(inner-acc from acc, check-result from results):
      inner-results = check-result.results
      other-errors = link(check-result,empty).filter(is-error-result).length()
      for each(failure from inner-results.filter(is-failure)):
        print("In check block at " + check-result.location.format())
        print("Test " + failure.name + " failed:")
        print(failure.reason)
        print("")
      end
      for each(failure from inner-results.filter(is-err)):
        print("In check block at " + check-result.location.format())
        print("Test " + failure.name + " raised an error:")
        print(failure.exception)
        print("")
        when has-field(failure.exception, "trace"):
          print("Trace:")
          for each(loc from failure.trace):
            print(loc)
          end
        end
      end
      when is-error-result(check-result):
        print("Check block " + check-result.name + " " + check-result.location.format() + " ended in an error: ")
        print(check-result.err)
        print("")
        when has-field(check-result.err, "trace"):
          print("Trace:")
          for each(loc from check-result.err.trace):
            print("  " + loc.format())
          end
        end
      end
      inner-acc.{
        passed: inner-acc.passed + inner-results.filter(is-success).length(),
        failed: inner-acc.failed + inner-results.filter(is-failure).length(),
        test-errors: inner-acc.test-errors + inner-results.filter(is-err).length(),
        other-errors: inner-acc.other-errors + other-errors,
        total: inner-acc.total + inner-results.length() 
      }
    end
  end
  print("Total: " + counts.total.tostring() +
        ", Passed: " + counts.passed.tostring() +
        ", Failed: " + counts.failed.tostring() +
        ", Errors in tests: " + counts.test-errors.tostring() +
        ", Errors in between tests: " + counts.other-errors.tostring())
  nothing
end

checkers = {
  check-true: check-true,
  check-false: check-false,
  check-equals: check-equals,
  check-pred: check-pred,
  run-checks: run-checks,
  format-check-results: format-check-results,
  clear-results: clear-results,
  get-results: get-results
}

