// Write-side guards for values that go into half-float buffers
//
// A guard turns an already-wrong value into something plausible, so it hides the
// bug that produced it. That is why they are graded rather than always on: an
// overflow and a NaN are different failures. An overflow reaches the half-float
// ceiling and becomes inf, which then poisons every downstream blur and the
// exposure measure with no trace of where it came from -- so bounding it is
// cheap and it stays on by default. A NaN is the bug itself, and it should be
// visible, so at the default level it is left alone to propagate.
//
//   0  off       nothing is touched; use when bisecting a specific artifact
//   1  finite    clamp to the half-float range, NaN passes through   (default)
//   2  full      additionally replace NaN with black
//
// The clamp deliberately preserves NaN: min()/max() return the *other* operand
// when one side is NaN on some drivers, so a plain clamp() would quietly turn a
// NaN into HALF_MAX -- the same masking this file exists to avoid.

#ifndef UTILITY_GUARDS
#define UTILITY_GUARDS

#ifndef GUARD_LEVEL
#define GUARD_LEVEL 1
#endif

// Keep a margin below 65504 so a following arithmetic step cannot round up to
// inf, which is valid in half floats.
const float HALF_MAX = 65000.0;

float guardHalf(float x)
{
#if GUARD_LEVEL >= 2
    if (x != x)
    {
        x = 0.0;
    }
#elif GUARD_LEVEL >= 1
    if (x != x)
    {
        return x;
    }
#endif
#if GUARD_LEVEL >= 1
    x = clamp(x, 0.0, HALF_MAX);
#endif
    return x;
}

vec3 guardHalf(vec3 x)
{
#if GUARD_LEVEL >= 2
    if (any(notEqual(x, x)))
    {
        x = vec3(0.0);
    }
#elif GUARD_LEVEL >= 1
    if (any(notEqual(x, x)))
    {
        return x;
    }
#endif
#if GUARD_LEVEL >= 1
    x = clamp(x, 0.0, HALF_MAX);
#endif
    return x;
}

#endif
