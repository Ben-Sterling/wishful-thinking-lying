#This has has utterances based on expection (eliminating softmaxing step)

import jax.numpy as jnp
import jax
from memo import memo

X = jnp.array([0, 1])
P = jnp.arange(0, 1.001, 0.001)
U = jnp.array([0, 1, 2]) #Chemical B is 1

#X5 = domain(c1=len(X), c2=len(X), c3=len(X), c4=len(X), c5=len(X))
X5 = jnp.array([0, 1, 2, 3, 4, 5])

# Helper functions with JIT compilation
@jax.jit
def bernoulli(x, p):
    return jax.scipy.stats.bernoulli.pmf(x, p)

@jax.jit
def beta(p, alpha, beta):
    return jax.scipy.stats.beta.pdf(p, alpha, beta)

@jax.jit
def binomial(x5, p, n):
    return jax.scipy.stats.binom.pmf(x5, n, p)

@jax.jit
def categorical(u, pa, pb, pc):
    return jnp.array([pa, pb, pc])[u]
   
# 1 -> loves 2,1
# .5 -> likes 1.5, 1
#0 -> indifferent 1,1
#-0.5 -> dislikes 1, 1.5
#-1 -> hates 1, 2
# Z as the linear spacing between different prefs, here = 0.5

@jax.jit
def wishful_prior(p, pref):
    # Beta posterior for the prior, based on imagined evidence
    return jax.scipy.stats.beta.pdf(
        p,
        (1 + jnp.maximum(0, pref)),
        (1 + jnp.maximum(0, -pref))
    )


# Main functions with memoization
@memo
def wishful[p_a: P, p_b: P, p_c: P, a: X5, b: X5, c: X5, u: U](n, pref_a, pref_b, pref_c):
    cast: [listener, speaker, world]
    speaker: thinks[
        world: chooses(p_a in P, wpp=1),
        world: chooses(p_b in P, wpp=1),
        world: chooses(p_c in P, wpp=1),

        world: chooses(a in X5, wpp=binomial(a, p_a, n)),
        world: chooses(b in X5, wpp=binomial(b, p_b, n)),
        world: chooses(c in X5, wpp=binomial(c, p_c, n)),
    ]
    speaker: observes [world.a] is a
    speaker: observes [world.b] is b
    speaker: observes [world.c] is c

    speaker: thinks[
        listener: thinks[
            world: chooses(p_a in P, wpp=wishful_prior(p_a, pref_a)),
            world: chooses(p_b in P, wpp=wishful_prior(p_b, pref_b)),
            world: chooses(p_c in P, wpp=wishful_prior(p_c, pref_c)),

            world: chooses(a in X5, wpp=(binomial(a, p_a, n))),
            world: chooses(b in X5, wpp=(binomial(b, p_b, n))),
            world: chooses(c in X5, wpp=(binomial(c, p_c, n))),
        ],
        listener: observes [world.a] is world.a,
        listener: observes [world.b] is world.b,
        listener: observes [world.c] is world.c,
        listener: chooses(u in U, wpp=categorical(u, E[world.p_a], E[world.p_b], E[world.p_c]))

    ]

    speaker: chooses(u in U, wpp=Pr[listener.u == u])

    return Pr[u == speaker.u]

@memo
def standard_a[p_a: P, a: X5](n):
    speaker: thinks[
        world: chooses(p_a in P, wpp=1),
        world: chooses(a in X5, wpp=binomial(a, p_a, n)),
    ]
    speaker: observes [world.a] is a
    return speaker[E[world.p_a]]

@memo
def standard_b[p_b: P, b: X5](n):
    speaker: thinks[
        world: chooses(p_b in P, wpp=1),
        world: chooses(b in X5, wpp=binomial(b, p_b, n)),
    ]
    speaker: observes [world.b] is b
    return speaker[E[world.p_b]]

@memo
def standard_c[p_c: P, c: X5](n):
    speaker: thinks[
        world: chooses(p_c in P, wpp=1),
        world: chooses(c in X5, wpp=binomial(c, p_c, n)),
    ]
    speaker: observes [world.c] is c
    return speaker[E[world.p_c]]

@memo
def wishful_a[p_a: P, a: X5](n, pref_a):
    cast: [listener, speaker, world]
    speaker: thinks[
        world: chooses(p_a in P, wpp=1),
        world: chooses(a in X5, wpp=binomial(a, p_a, n)),
    ]
    speaker: observes [world.a] is a
    speaker: thinks[
        listener: thinks[
            world: chooses(p_a in P, wpp=wishful_prior(p_a, pref_a)),
            world: chooses(a in X5, wpp=(binomial(a, p_a, n))),
        ],
        listener: observes [world.a] is world.a,
        #listener[E[world.p_a]],
    ]
    return speaker[listener[E[world.p_a]]]

@memo
def wishful_b[p_b: P, b: X5](n, pref_b):
    cast: [listener, speaker, world]
    speaker: thinks[
        world: chooses(p_b in P, wpp=1),
        world: chooses(b in X5, wpp=binomial(b, p_b, n)),
    ]
    speaker: observes [world.b] is b
    speaker: thinks[
        listener: thinks[
            world: chooses(p_b in P, wpp=wishful_prior(p_b, pref_b)),
            world: chooses(b in X5, wpp=(binomial(b, p_b, n))),
        ],
        listener: observes [world.b] is world.b,
        #listener[E[world.p_b]],
    ]
    return speaker[listener[E[world.p_b]]]

@memo
def wishful_c[p_c: P, c: X5](n, pref_c):
    cast: [listener, speaker, world]
    speaker: thinks[
        world: chooses(p_c in P, wpp=1),
        world: chooses(c in X5, wpp=binomial(c, p_c, n)),
    ]
    speaker: observes [world.c] is c
    speaker: thinks[
        listener: thinks[
            world: chooses(p_c in P, wpp=wishful_prior(p_c, pref_c)),
            world: chooses(c in X5, wpp=(binomial(c, p_c, n))),
        ],
        listener: observes [world.c] is world.c,
        #listener[E[world.p_c]],
    ]
    return speaker[listener[E[world.p_c]]]

# Z = standard_b(5)
# print(Z.shape)
# print(Z[1, 0])