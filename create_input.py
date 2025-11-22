import struct

# special float values
pos_inf = float('inf')   # +Infinity
neg_inf = float('-inf')  # -Infinity
nan_val  = float('nan')  # NaN


float1 = -1.25e-30 
float2 = 2.3e27

# open binary file to write input
with open('FLOAT2.bin', 'wb') as f:
    f.write(struct.pack('<f', float1))
    f.write(struct.pack('<f', float2))


# Show correct sum result to check
print(f"First float: {float1}")
print(f"Sencond float: {float2}")
print(f"Sum: {float1 + float2}")
