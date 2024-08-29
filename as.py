import re
import subprocess

# Define the commands with their regex patterns and corresponding binary byte values
commands =[
    # Commands without constants or registers
    { "regex": re.compile(r"^CLR AC$", re.IGNORECASE), "byte": 0b00000000 },
    { "regex": re.compile(r"^STA AC$", re.IGNORECASE), "byte": 0b00000010 },
    { "regex": re.compile(r"^INV AC$", re.IGNORECASE), "byte": 0b00000011 },
    { "regex": re.compile(r"^PRNT AC$", re.IGNORECASE), "byte": 0b00000100 },
    { "regex": re.compile(r"^PRNTF AC$", re.IGNORECASE), "byte": 0b00011011 },
    { "regex": re.compile(r"^SHR AC$", re.IGNORECASE), "byte": 0b00010011 },
    { "regex": re.compile(r"^SHL AC$", re.IGNORECASE), "byte": 0b00010100 },
    { "regex": re.compile(r"^ROR AC$", re.IGNORECASE), "byte": 0b00010101 },
    { "regex": re.compile(r"^ROL AC$", re.IGNORECASE), "byte": 0b00010110 },
    { "regex": re.compile(r"^HLT$", re.IGNORECASE), "byte": 0b00000111 },
    { "regex": re.compile(r"^LCD$", re.IGNORECASE), "byte": 0b00011110 },
    { "regex": re.compile(r"^I2C_START$", re.IGNORECASE), "byte": 0b00011111},
    { "regex": re.compile(r"^I2C_STOP$", re.IGNORECASE), "byte": 0b00100000},
    { "regex": re.compile(r"^I2C_READ$", re.IGNORECASE), "byte": 0b00100001 },

    # Commands with registers
    { "regex": re.compile(r"^CLR R\((\d+)\)$", re.IGNORECASE), "byte": 0b11000000, "isRegister": True },
    { "regex": re.compile(r"^ADD R\((\d+)\)$", re.IGNORECASE), "byte": 0b11000000, "isRegister": True },
    { "regex": re.compile(r"^STA R\((\d+)\)$", re.IGNORECASE), "byte": 0b11000010, "isRegister": True },
    { "regex": re.compile(r"^INV R\((\d+)\)$", re.IGNORECASE), "byte": 0b11000011, "isRegister": True },
    { "regex": re.compile(r"^PRNT R\((\d+)\)$", re.IGNORECASE), "byte": 0b11000100, "isRegister": True },
    { "regex": re.compile(r"^WAIT R\((\d+)\)$", re.IGNORECASE), "byte": 0b11000110, "isRegister": True },
    { "regex": re.compile(r"^OR R\((\d+)\)$", re.IGNORECASE), "byte": 0b11001000, "isRegister": True },
    { "regex": re.compile(r"^AND R\((\d+)\)$", re.IGNORECASE), "byte": 0b11001001, "isRegister": True },
    { "regex": re.compile(r"^SUB R\((\d+)\)$", re.IGNORECASE), "byte": 0b11001010, "isRegister": True },
    { "regex": re.compile(r"^SUB R\((\d+)\)$", re.IGNORECASE), "byte": 0b11001010, "isRegister": True },
    { "regex": re.compile(r"^MUL R\((\d+)\)$", re.IGNORECASE), "byte": 0b11011001, "isRegister": True },
    { "regex": re.compile(r"^DIV R\((\d+)\)$", re.IGNORECASE), "byte": 0b11011010, "isRegister": True },
    { "regex": re.compile(r"^PRNTF R\((\d+)\)$", re.IGNORECASE), "byte": 0b11011011, "isRegister": True },
    { "regex": re.compile(r"^INPUT R\((\d+)\)$", re.IGNORECASE), "byte": 0b11011100, "isRegister": True },
    { "regex": re.compile(r"^INPUTI R\((\d+)\)$", re.IGNORECASE), "byte": 0b11011101, "isRegister": True },
    # Commands with constants
    { "regex": re.compile(r"^ADD ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10000001, "hasConstant": True },
    { "regex": re.compile(r"^STA ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10000010, "hasConstant": True },
    { "regex": re.compile(r"^INV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10000011, "hasConstant": True },
    { "regex": re.compile(r"^PRNT ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10000100, "hasConstant": True },
    { "regex": re.compile(r"^JMP ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10000101, "hasConstant": True },
    { "regex": re.compile(r"^JN ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10001011, "hasConstant": True },
    { "regex": re.compile(r"^JP ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10001100, "hasConstant": True },
    { "regex": re.compile(r"^JZ ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10001101, "hasConstant": True },
    { "regex": re.compile(r"^JNZ ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10001110, "hasConstant": True },
    { "regex": re.compile(r"^JC ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10001111, "hasConstant": True },
    { "regex": re.compile(r"^JNC ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10010000, "hasConstant": True },
    { "regex": re.compile(r"^JB ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10010001, "hasConstant": True },
    { "regex": re.compile(r"^JNB ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10010010, "hasConstant": True },
    { "regex": re.compile(r"^JV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10010111, "hasConstant": True },
    { "regex": re.compile(r"^JNV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10011000, "hasConstant": True },
    { "regex": re.compile(r"^WAIT ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10000110, "hasConstant": True },
    { "regex": re.compile(r"^MUL ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10011001, "hasConstant": True },
    { "regex": re.compile(r"^DIV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10011010, "hasConstant": True },
    { "regex": re.compile(r"^PRNTF ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10011011, "hasConstant": True },
    { "regex": re.compile(r"^I2C_WRITE ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), "byte": 0b10100010, "hasConstant": True },
]

def convert_assembly_to_binary(assembly_code):
    binary_output = [0x00, 0x00]  # Add a leading byte of 0x00
    
    for line in assembly_code.splitlines():
        line = line.strip()
        if not line:
            continue  # Skip empty lines

        # Handle PRNT with a string
        if line.startswith('PRNT "'):
            end_index = line.find('"', 6)
            if end_index != -1:
                string_to_print = line[6:end_index]
                for char in string_to_print:
                    ascii_value = ord(char)
                    binary_output.append(0b10000100)  # PRNT command
                    binary_output.append(ascii_value)
                continue
        
        matched = False

        for command in commands:
            match = command["regex"].match(line)
            if match:
                binary_output.append(command["byte"])
                if "hasConstant" in command and command["hasConstant"]:
                    constant = match.group(1)
                    base = match.group(2).upper() if match.group(2) else 'H'  # Default to hexadecimal if no base is specified
                    
                    if base == 'H':
                        constant_value = int(constant, 16)
                    elif base == 'B':
                        constant_value = int(constant, 2)
                    elif base == 'D':
                        constant_value = int(constant, 10)
                    else:
                        raise ValueError(f"Unknown constant base: {base}")
                    
                    binary_output.append(constant_value)
                elif "isRegister" in command and command["isRegister"]:
                    register_number = int(match.group(1))
                    if 0 <= register_number <= 255:
                        binary_output.append(register_number)
                    else:
                        raise ValueError(f"Register number out of range: {register_number}")
                else:
                    # Add an extra byte (0x00) if the command does not have a constant or register
                    binary_output.append(0x40)
                    
                matched = True
                break
        
        if not matched:
            print(f"Debug: Unrecognized command line: '{line}'")
            raise ValueError(f"Unrecognized command: {line}")
    
    return binary_output

# Example usage
# Read the assembly code from a file
with open('assembly.txt', 'r') as file:
    assembly_code = file.read()

try:
    binary_code = convert_assembly_to_binary(assembly_code)

    # Write binary code to compile.bin
    with open('compile.bin', 'wb') as f:
        for byte in binary_code:
            f.write(byte.to_bytes(1, byteorder='big'))

    # Execute the command
    binary_code = [f'{byte:08b}' for byte in binary_code]

    print("Binary Code:")
    print("\n".join(binary_code))
    subprocess.run(['sudo', './openFPGALoader', '-b', 'tangnano9k', '--external-flash', 'compile.bin'], check=True)
    #sudo ./openFPGALoader -v -b tangnano9k -f ../../IDE/bin/fpga_project/spi_lcd/impl/pnr/spi_lcd.fs
    print("Binary file 'compile.bin' created and command executed successfully.")
except ValueError as e:
    print(e)
except subprocess.CalledProcessError as e:
    print(f"Error executing command: {e}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")


