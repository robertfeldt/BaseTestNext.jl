if VERSION >= v"0.5-"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

# Let's create a (dummy) custom test set that times test execution and
# repeats the tests 30 times.
type FixedRepeatingTestSet <: BaseTestNext.AbstractTestSet
    description::AbstractString
    results::Vector
    anynonpass::Bool
    nextiter::Int64
    starttime::Float64
end
FixedRepeatingTestSet(desc) = FixedRepeatingTestSet(desc, [], false, -1, 0.0)

import BaseTestNext.record
# For a passing result, simply store the result
record(ts::FixedRepeatingTestSet, t::BaseTestNext.Pass) = (push!(ts.results, t); t)
# For the other result types, immediately print the error message
# but do not terminate. Print a backtrace.
function record(ts::FixedRepeatingTestSet, t::Union{BaseTestNext.Fail,BaseTestNext.Error})
    print_with_color(:white, ts.description, ": ")
    print(t)
    # don't print the backtrace for Errors because it gets printed in the show
    # method
    isa(t, BaseTestNext.Error) || Base.show_backtrace(STDOUT, backtrace())
    println()
    push!(ts.results, t)
    t
end

# When a DefaultTestSet finishes, it records itself to its parent
# testset, if there is one. This allows for recursive printing of
# the results at the end of the tests
record(ts::FixedRepeatingTestSet, t::BaseTestNext.AbstractTestSet) = push!(ts.results, t)

# Continue running tests 30 times. Save the start time if this is the first iteration.
import BaseTestNext.start
function start(ts::FixedRepeatingTestSet, nruns::Int)
    ts.nextiter = nruns+1
    if nruns < 1
      ts.starttime = time()
    end
    if nruns < 30
        println("Starting iteration $(ts.nextiter)!")
        return true  # Should still run since not reached 30 yet
    else
        return false
    end
end

# Called at the end of a @testset, behaviour depends on whether
# this is a child of another testset, or the "root" testset
import BaseTestNext.finish
function finish(ts::FixedRepeatingTestSet)
    elapsed = time() - ts.starttime
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if BaseTestNext.get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = BaseTestNext.get_testset()
        record(parent_ts, ts)
        return
    end

    numiters = ts.nextiter-1
    if numiters >= 30
      println("Executed the test block $(numiters) times in $(elapsed) seconds")
      println(@sprintf("  %.2f tests/sec", length(ts.results)/elapsed))
    end

    # return the testset so it is returned from the @testset macro
    ts
end

#@testset FixedRepeatingTestSet "Set 1" begin
@testset "Set 1" begin
  f(x) = x+1
  a = 1
  @test f(0) == a
  #@testset "Set 1.1 nested" begin
  #  @test (f(a)+1) == 1
  #end

  # A better example is to find some rare bug with random generation of test data.
  # Here we seed a bug to ensure there is one...
  myreverse(v) = length(v) > 1 ? reverse(v) : [1] # Bug happens only if length is 0
  len = rand(0:5) # This might not be found if only one repetition of test...
  v = randn(len)
  @test length(myreverse(v)) == length(v)
end