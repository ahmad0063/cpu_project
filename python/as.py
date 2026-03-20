#!/usr/bin/env python3
"""Assembler for the custom 8-bit CPU instruction set."""

from __future__ import annotations

import argparse
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


NO_OPERAND_FILLER = 0x40
BINARY_HEADER = [0x00, 0x00]


@dataclass(frozen=True)
class Instruction:
    pattern: re.Pattern[str]
    opcode: int
    operand_kind: str | None = None


INSTRUCTIONS: tuple[Instruction, ...] = (
    Instruction(re.compile(r"^CLR AC$", re.IGNORECASE), 0b00000000),
    Instruction(re.compile(r"^STA AC$", re.IGNORECASE), 0b00000010),
    Instruction(re.compile(r"^INV AC$", re.IGNORECASE), 0b00000011),
    Instruction(re.compile(r"^PRNT AC$", re.IGNORECASE), 0b00000100),
    Instruction(re.compile(r"^PRNTF AC$", re.IGNORECASE), 0b00011011),
    Instruction(re.compile(r"^SHR AC$", re.IGNORECASE), 0b00010011),
    Instruction(re.compile(r"^SHL AC$", re.IGNORECASE), 0b00010100),
    Instruction(re.compile(r"^ROR AC$", re.IGNORECASE), 0b00010101),
    Instruction(re.compile(r"^ROL AC$", re.IGNORECASE), 0b00010110),
    Instruction(re.compile(r"^HLT$", re.IGNORECASE), 0b00000111),
    Instruction(re.compile(r"^LCD$", re.IGNORECASE), 0b00011110),
    Instruction(re.compile(r"^I2C_START$", re.IGNORECASE), 0b00011111),
    Instruction(re.compile(r"^I2C_STOP$", re.IGNORECASE), 0b00100000),
    Instruction(re.compile(r"^I2C_READ$", re.IGNORECASE), 0b00100001),
    Instruction(re.compile(r"^CLR R\((\d+)\)$", re.IGNORECASE), 0b11000000, "register"),
    Instruction(re.compile(r"^ADD R\((\d+)\)$", re.IGNORECASE), 0b11000000, "register"),
    Instruction(re.compile(r"^STA R\((\d+)\)$", re.IGNORECASE), 0b11000010, "register"),
    Instruction(re.compile(r"^INV R\((\d+)\)$", re.IGNORECASE), 0b11000011, "register"),
    Instruction(re.compile(r"^PRNT R\((\d+)\)$", re.IGNORECASE), 0b11000100, "register"),
    Instruction(re.compile(r"^WAIT R\((\d+)\)$", re.IGNORECASE), 0b11000110, "register"),
    Instruction(re.compile(r"^OR R\((\d+)\)$", re.IGNORECASE), 0b11001000, "register"),
    Instruction(re.compile(r"^AND R\((\d+)\)$", re.IGNORECASE), 0b11001001, "register"),
    Instruction(re.compile(r"^SUB R\((\d+)\)$", re.IGNORECASE), 0b11001010, "register"),
    Instruction(re.compile(r"^MUL R\((\d+)\)$", re.IGNORECASE), 0b11011001, "register"),
    Instruction(re.compile(r"^DIV R\((\d+)\)$", re.IGNORECASE), 0b11011010, "register"),
    Instruction(re.compile(r"^PRNTF R\((\d+)\)$", re.IGNORECASE), 0b11011011, "register"),
    Instruction(re.compile(r"^INPUT R\((\d+)\)$", re.IGNORECASE), 0b11011100, "register"),
    Instruction(re.compile(r"^INPUTI R\((\d+)\)$", re.IGNORECASE), 0b11011101, "register"),
    Instruction(re.compile(r"^ADD ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10000001, "constant"),
    Instruction(re.compile(r"^STA ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10000010, "constant"),
    Instruction(re.compile(r"^INV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10000011, "constant"),
    Instruction(re.compile(r"^PRNT ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10000100, "constant"),
    Instruction(re.compile(r"^JMP ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10000101, "constant"),
    Instruction(re.compile(r"^JN ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10001011, "constant"),
    Instruction(re.compile(r"^JP ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10001100, "constant"),
    Instruction(re.compile(r"^JZ ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10001101, "constant"),
    Instruction(re.compile(r"^JNZ ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10001110, "constant"),
    Instruction(re.compile(r"^JC ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10001111, "constant"),
    Instruction(re.compile(r"^JNC ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10010000, "constant"),
    Instruction(re.compile(r"^JB ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10010001, "constant"),
    Instruction(re.compile(r"^JNB ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10010010, "constant"),
    Instruction(re.compile(r"^JV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10010111, "constant"),
    Instruction(re.compile(r"^JNV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10011000, "constant"),
    Instruction(re.compile(r"^WAIT ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10000110, "constant"),
    Instruction(re.compile(r"^MUL ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10011001, "constant"),
    Instruction(re.compile(r"^DIV ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10011010, "constant"),
    Instruction(re.compile(r"^PRNTF ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10011011, "constant"),
    Instruction(re.compile(r"^I2C_WRITE ([0-9A-F]+?)([HBD]?)$", re.IGNORECASE), 0b10100010, "constant"),
)


def parse_constant(value: str, base_hint: str) -> int:
    base_code = base_hint.upper() if base_hint else "H"
    bases = {"H": 16, "B": 2, "D": 10}

    if base_code not in bases:
        raise ValueError(f"Unknown constant base: {base_code}")

    parsed = int(value, bases[base_code])
    if not 0 <= parsed <= 0xFF:
        raise ValueError(f"Constant out of range for one byte: {value}{base_code}")
    return parsed


def encode_line(line: str) -> list[int]:
    if line.startswith('PRNT "') and line.endswith('"'):
        return [byte for char in line[6:-1] for byte in (0b10000100, ord(char))]

    for instruction in INSTRUCTIONS:
        match = instruction.pattern.match(line)
        if not match:
            continue

        encoded = [instruction.opcode]

        if instruction.operand_kind == "constant":
            encoded.append(parse_constant(match.group(1), match.group(2)))
        elif instruction.operand_kind == "register":
            register_number = int(match.group(1))
            if not 0 <= register_number <= 0xFF:
                raise ValueError(f"Register number out of range: {register_number}")
            encoded.append(register_number)
        else:
            encoded.append(NO_OPERAND_FILLER)

        return encoded

    raise ValueError(f"Unrecognized command: {line}")


def assemble_lines(lines: Iterable[str]) -> list[int]:
    binary_output = list(BINARY_HEADER)

    for line_number, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue

        try:
            binary_output.extend(encode_line(line))
        except ValueError as exc:
            raise ValueError(f"Line {line_number}: {exc}") from exc

    return binary_output


def assemble_file(input_path: Path) -> list[int]:
    return assemble_lines(input_path.read_text(encoding="utf-8").splitlines())


def write_binary(output_path: Path, binary_code: list[int]) -> None:
    output_path.write_bytes(bytes(binary_code))


def flash_binary(loader: str, board: str, binary_path: Path, sudo: bool) -> None:
    command = [loader, "-b", board, "--external-flash", str(binary_path)]
    if sudo:
        command.insert(0, "sudo")
    subprocess.run(command, check=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Assemble source code for the custom 8-bit CPU.")
    parser.add_argument("input", type=Path, help="Assembly source file")
    parser.add_argument("-o", "--output", type=Path, default=Path("compile.bin"), help="Output binary path")
    parser.add_argument("--flash", action="store_true", help="Flash the generated binary after assembly")
    parser.add_argument("--loader", default="./openFPGALoader", help="Path to the flash utility")
    parser.add_argument("--board", default="tangnano9k", help="Board name passed to the flash utility")
    parser.add_argument("--sudo", action="store_true", help="Run the flash utility via sudo")
    parser.add_argument("--print-binary", action="store_true", help="Print the generated bytes as 8-bit binary strings")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        binary_code = assemble_file(args.input)
        write_binary(args.output, binary_code)

        if args.print_binary:
            print("\n".join(f"{byte:08b}" for byte in binary_code))

        if args.flash:
            flash_binary(args.loader, args.board, args.output, args.sudo)
    except FileNotFoundError as exc:
        parser.error(str(exc))
    except ValueError as exc:
        parser.error(str(exc))
    except subprocess.CalledProcessError as exc:
        parser.error(f"Flash command failed: {exc}")

    print(f"Wrote {len(binary_code)} bytes to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
