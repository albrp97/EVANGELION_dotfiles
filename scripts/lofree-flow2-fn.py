#!/usr/bin/env python3
"""Read or apply the Flow 2 Fn-layer F-key mapping over USB HID."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import json
import os
import sys
import time
from pathlib import Path


VENDOR_ID = 0x388D
PRODUCT_ID = 0x0001
RAW_INTERFACE = 2
RAW_REPORT_SIZE = 32
MATRIX_ROWS = 5
MATRIX_COLS = 15
FN_LAYERS = (1, 3)
TOP_ROW = 0
NUMBER_COLUMNS = tuple(range(1, 13))
F_KEYCODES = tuple(range(0x3A, 0x46))


class HidDeviceInfo(ctypes.Structure):
    pass


HidDeviceInfo._fields_ = [
    ("path", ctypes.c_char_p),
    ("vendor_id", ctypes.c_ushort),
    ("product_id", ctypes.c_ushort),
    ("serial_number", ctypes.c_wchar_p),
    ("release_number", ctypes.c_ushort),
    ("manufacturer_string", ctypes.c_wchar_p),
    ("product_string", ctypes.c_wchar_p),
    ("usage_page", ctypes.c_ushort),
    ("usage", ctypes.c_ushort),
    ("interface_number", ctypes.c_int),
    ("next", ctypes.POINTER(HidDeviceInfo)),
]


def load_hid_library() -> ctypes.CDLL:
    library_name = ctypes.util.find_library("hidapi-hidraw")
    if library_name is None:
        library_name = "libhidapi-hidraw.so.0"
    library = ctypes.CDLL(library_name)
    library.hid_init.restype = ctypes.c_int
    library.hid_enumerate.argtypes = [ctypes.c_ushort, ctypes.c_ushort]
    library.hid_enumerate.restype = ctypes.POINTER(HidDeviceInfo)
    library.hid_free_enumeration.argtypes = [ctypes.POINTER(HidDeviceInfo)]
    library.hid_open_path.argtypes = [ctypes.c_char_p]
    library.hid_open_path.restype = ctypes.c_void_p
    library.hid_write.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t]
    library.hid_write.restype = ctypes.c_int
    library.hid_read_timeout.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_ubyte),
        ctypes.c_size_t,
        ctypes.c_int,
    ]
    library.hid_read_timeout.restype = ctypes.c_int
    library.hid_close.argtypes = [ctypes.c_void_p]
    library.hid_exit.restype = ctypes.c_int
    return library


class ViaDevice:
    def __init__(self) -> None:
        self.library = load_hid_library()
        if self.library.hid_init() != 0:
            raise RuntimeError("could not initialize hidapi")
        self.handle = self._open_flow2()

    def _open_flow2(self) -> ctypes.c_void_p:
        devices = self.library.hid_enumerate(VENDOR_ID, PRODUCT_ID)
        current = devices
        path = None
        while current:
            info = current.contents
            if info.interface_number == RAW_INTERFACE and info.path:
                path = info.path
                break
            current = info.next
        self.library.hid_free_enumeration(devices)
        if path is None:
            raise RuntimeError("Flow 2 raw HID interface was not found; connect it over USB")
        handle = self.library.hid_open_path(path)
        if not handle:
            raise RuntimeError("could not open the Flow 2 raw HID interface")
        return handle

    def close(self) -> None:
        if self.handle:
            self.library.hid_close(self.handle)
            self.handle = None
        self.library.hid_exit()

    def command(self, data: bytes) -> bytes:
        if len(data) > RAW_REPORT_SIZE:
            raise ValueError("VIA command is too large")
        payload = data + bytes(RAW_REPORT_SIZE - len(data))
        packet = (ctypes.c_ubyte * (RAW_REPORT_SIZE + 1))(*bytes([0]) + payload)
        if self.library.hid_write(self.handle, packet, len(packet)) < 0:
            raise RuntimeError("failed to write a VIA command")

        response_buffer = (ctypes.c_ubyte * (RAW_REPORT_SIZE + 1))()
        length = self.library.hid_read_timeout(
            self.handle,
            response_buffer,
            len(response_buffer),
            1000,
        )
        if length <= 0:
            raise RuntimeError("timed out waiting for the Flow 2 VIA response")
        response = bytes(response_buffer[:length])
        if response[0] != data[0]:
            raise RuntimeError(f"unexpected VIA response: {response.hex()}")
        return response

    def layer_count(self) -> int:
        return self.command(bytes([0x11]))[1]

    def get_keycode(self, layer: int, row: int, column: int) -> int:
        response = self.command(bytes([0x04, layer, row, column]))
        return (response[4] << 8) | response[5]

    def set_keycode(self, layer: int, row: int, column: int, keycode: int) -> None:
        self.command(
            bytes(
                [
                    0x05,
                    layer,
                    row,
                    column,
                    (keycode >> 8) & 0xFF,
                    keycode & 0xFF,
                ]
            )
        )
        time.sleep(0.05)

    def dump_keymap(self, layers: int) -> list[list[list[int]]]:
        total_bytes = layers * MATRIX_ROWS * MATRIX_COLS * 2
        raw = bytearray()
        for offset in range(0, total_bytes, 28):
            size = min(28, total_bytes - offset)
            response = self.command(bytes([0x12, offset >> 8, offset & 0xFF, size]))
            if response[1:3] != bytes([offset >> 8, offset & 0xFF]):
                raise RuntimeError("Flow 2 returned a mismatched keymap offset")
            raw.extend(response[3 : 3 + size])

        keymap = []
        index = 0
        for _ in range(layers):
            layer = []
            for _ in range(MATRIX_ROWS):
                row = []
                for _ in range(MATRIX_COLS):
                    row.append(raw[index] | (raw[index + 1] << 8))
                    index += 2
                layer.append(row)
            keymap.append(layer)
        return keymap


def format_keycode(keycode: int) -> str:
    if 0x3A <= keycode <= 0x45:
        return f"F{keycode - 0x39}"
    if keycode == 0x0001:
        return "TRNS"
    return f"0x{keycode:04X}"


def target_mapping(device: ViaDevice) -> dict[str, dict[str, int]]:
    mapping = {}
    for layer in FN_LAYERS:
        for column, keycode in zip(NUMBER_COLUMNS, F_KEYCODES):
            key = f"{layer}:r{TOP_ROW}c{column}"
            mapping[key] = {
                "old": device.get_keycode(layer, TOP_ROW, column),
                "new": keycode,
            }
    return mapping


def print_plan(mapping: dict[str, dict[str, int]]) -> None:
    for layer in FN_LAYERS:
        values = [
            f"{format_keycode(mapping[f'{layer}:r{TOP_ROW}c{column}']['old'])}"
            f" -> F{column}"
            for column in NUMBER_COLUMNS
        ]
        print(f"layer {layer}: " + "  ".join(values))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="write F1-F12 to both Fn layers")
    parser.add_argument("--dump", type=Path, help="write a complete keymap backup to this JSON path")
    args = parser.parse_args()

    if os.geteuid() != 0:
        print("Run this tool with: pkexec python3 scripts/lofree-flow2-fn.py [--apply]", file=sys.stderr)
        return 2

    device = None
    try:
        device = ViaDevice()
        layers = device.layer_count()
        if layers < max(FN_LAYERS):
            raise RuntimeError(f"Flow 2 reported only {layers} layers")

        if args.dump is not None:
            backup = {
                "vendor_id": f"0x{VENDOR_ID:04X}",
                "product_id": f"0x{PRODUCT_ID:04X}",
                "layers": device.dump_keymap(layers),
            }
            args.dump.write_text(json.dumps(backup, indent=2) + "\n", encoding="utf-8")
            print(f"wrote keymap backup to {args.dump}")

        mapping = target_mapping(device)
        print_plan(mapping)
        if not args.apply:
            print("dry run: no keyboard changes made")
            return 0

        for layer in FN_LAYERS:
            for column, keycode in zip(NUMBER_COLUMNS, F_KEYCODES):
                device.set_keycode(layer, TOP_ROW, column, keycode)
                actual = device.get_keycode(layer, TOP_ROW, column)
                if actual != keycode:
                    raise RuntimeError(
                        f"verification failed at layer {layer}, row {TOP_ROW}, column {column}"
                    )
        print("applied: Fn+1..Fn+0, Fn+minus, and Fn+equals now send F1..F12")
        return 0
    finally:
        if device is not None:
            device.close()


if __name__ == "__main__":
    raise SystemExit(main())
