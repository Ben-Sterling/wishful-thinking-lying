import csv
import itertools
import os
from concurrent.futures import ProcessPoolExecutor
from functools import partial
from grace_wishful_thinker_no_softmax import wishful_a, wishful_b, wishful_c, standard_a, standard_b, standard_c
import time
from itertools import product

# Function to compute differences
def write_csv(output_file_name, data, pref_range=None):
    output_dir = os.path.dirname(output_file_name)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    with open(output_file_name, mode="w", newline="") as file:
        writer = csv.writer(file)
        if pref_range is not None:
            writer.writerow(["Preference Range"] + pref_range)
        writer.writerow(["Difference", "Standard", "Wishful", "Preference_A", "Preference_B", "Preference_C", "Obs_A", "Obs_B", "Obs_C", "utterance", "n"])  # Write header
        for line in data:
            writer.writerow(line)

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
    return [i * z for i in range(-num_steps, num_steps + 1)]

def brute_outputs(n, pref_range):
    # Ranges for the parameters and indices
    pref_range = pref_range  # Range for pref_a, pref_b, pref_c
    
    index_range = range(0, n+1)  # Range for observed successes
    #index_range = [5]
    utterance_range = range(0, 3)
    
    # List to store differences and associated parameters/indices
    differences = []

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
            differences.append((difference, S[index], W[index], pref_a, pref_b, pref_c, i4, i5, i6, u, n))
    
    # Sort differences in descending order and keep the top N
    #differences.sort(reverse=True, key=lambda x: x[0])
    
    # Return the top differences with their parameters and indices
    return differences

def params():
    n = 5         # number of evidence trials
    z = 0.5       # step size between preference vals
    num_prefs = 5 # total # of possible pref scores
    return n, z, num_prefs

def main():
    n, z, num_prefs = params()
    pref_range = define_pref_range(z, num_prefs)
    t_start = time.time()
    diffs = brute_outputs(n, pref_range)
    
    t_finish = time.time()
    print(f"Elapsed time: {t_finish - t_start} seconds")
    write_csv("output.csv", diffs, pref_range)



if __name__ == "__main__":
    main()
