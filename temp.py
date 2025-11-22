import struct

x = 2.161593

# pack thành 4 byte dạng float32 rồi chuyển sang hex
bytes_val = struct.pack('>f', x)

hex_val = bytes_val.hex()

bin_val = ''.join(f'{byte:08b}' for byte in bytes_val)

print(f"Hex: {hex_val}")
print(f"Bin: {bin_val}")
