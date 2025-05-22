from brute_force import brute_outputs
import jax.numpy as np
import time
import csv
import jax

#Make sure to delete an old data_all_zs.csv file before running this script

# Parameters:
n = 5         # number of evidence trials
num_prefs = 5 # total # of possible pref scores
# z = 0.5       # step size between preference vals. Original value was 0.5

#z_range = np.arange(-2, 2, 0.1) #also worked previously
#z_range = np.arange(-1, 1, 0.1) #works for sure. for sure for sure 1/20.
#z_range = np.arange(0, 4, 0.5) #did not work with our merge in R with selected trials. Ended up with a bunch of loves / Trial 4.
#z_range = np.arange(-4, 4, 0.1) #worked! Need to have symmetric range around 0 for the merge in R to work. Don't know why. 1/20.
z_range = np.arange(4, 4.1, 0.1)

# Initialize a list to accumulate all data
all_data = []

for z in z_range:
    t_start = time.time()
    new_data = brute_outputs(n, num_prefs, z)
    t_finish = time.time()
    print(f"Finished z = {z}")
    print(f"Elapsed time: {t_finish - t_start} seconds")
     
    # Convert jax.numpy arrays to native Python types
    new_data_converted = [
        [float(item) if isinstance(item, (np.ndarray, jax.Array)) else item for item in row]
        for row in new_data
    ]
    
    # Accumulate data
    all_data.extend(new_data_converted)

# Write the data to a CSV file using the csv module
print("Writing data to CSV file...")
total_rows = len(all_data)
print(f"Total rows to write: {total_rows}")

with open('data_all_zs.csv', mode='w', newline='') as file:
    writer = csv.writer(file)
    # Write the header
    writer.writerow(["Difference", "Standard", "Wishful", "Preference_A", "Preference_B", "Preference_C", "Obs_A", "Obs_B", "Obs_C", "utterance", "n", "z"])
    # Write the data row by row
    for i, row in enumerate(all_data, start=1):
        writer.writerow(row)
        if i % 100000 == 0:  # Print progress every 100 rows
            print(f"Written {i} of {total_rows} rows")

print("CSV file has been written successfully.")