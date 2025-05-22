import csv
import itertools
import os
from concurrent.futures import ProcessPoolExecutor
from functools import partial
from grace_wishful_thinker_no_softmax import wishful_a, wishful_b, wishful_c, standard_a, standard_b, standard_c
import time
from itertools import product

##################################################
#Original parameters:
#n = 5         # number of evidence trials
#z = 0.5       # step size between preference vals
#num_prefs = 5 # total # of possible pref scores
##################################################

def define_pref_range(z, num_prefs):
    """
    Defines a symmetric preference range based on step size (z) and total number of elements
    Args: 
        z: the step size between pref vals
        num_prefs: the total # of prefs in pref range (must be odd)
    Returns:
        A list representing the pref range
    """
    if num_prefs % 2 == 0:
        raise ValueError("num_elems must be an odd number.")
    num_steps = (num_prefs - 1) // 2
    return [float(i * z) for i in range(-num_steps, num_steps + 1)]


# Function to compute differences
def brute_outputs(n, num_prefs, z):
    # Ranges for the parameters and indices
    pref_range = define_pref_range(z, num_prefs)
    # Mapping preference scores to verbs
    labels = ["hates", "dislikes", "is indifferent to", "likes", "loves"]
    # Create the preference map
    preference_map = dict(zip(pref_range, labels))

    
    index_range = range(0, n+1)  # Range for observed successes
    #index_range = [5]
    utterance_range = range(0, 3)
    
    # List to store differences and associated parameters/indices
    data = []

    S_a, S_b, S_c = standard_a(n), standard_b(n), standard_c(n)
    # Iterate over all combinations of pref parameters
    for pref_a, pref_b, pref_c in product(pref_range, repeat=3):
        W_a, W_b, W_c = wishful_a(n, pref_a), wishful_b(n, pref_b), wishful_c(n, pref_c)
        for i4, i5, i6, u in product(index_range, index_range, index_range, utterance_range):
            if u == 0:
                S = S_a
                W = W_a
                index = (0, i4)
            elif u == 1:
                S = S_b
                W = W_b
                index = (0, i5)
            elif u == 2:
                S = S_c
                W = W_c
                index = (0, i6)
                
            difference = abs(S[index] - W[index])
            
            # Store the difference and associated parameters/indices
            data.append((difference, S[index], W[index], preference_map[pref_a], preference_map[pref_b], preference_map[pref_c], i4, i5, i6, u, n, z))
    
    # Sort differences in descending order and keep the top N
    #differences.sort(reverse=True, key=lambda x: x[0])
    
    # Return the top differences with their parameters and indices
    return data

