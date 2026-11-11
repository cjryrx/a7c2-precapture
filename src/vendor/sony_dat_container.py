"""BODYDATA.DAT container: chunk layout, FDAT crypto, block checksums.

The 2.01 package for the ILCE-7CM2 (A7C II) is a Sony "UDTRFIRM" update image:

    magic        8  bytes  b"\\x89UFU\\r\\n\\x1a\\n"
    DATV         4  bytes  data format version (big-endian length prefix)
    PROV         4  bytes  provider / product id
    UDID         140 bytes unique id
    FDAT         1_139_929_360 bytes  encrypted payload
    DEND         4 bytes  big-endian CRC-32 of everything before the DEND header

Every chunk is a big-endian u32 length followed by a four byte tag.  FDAT carries
the firmware as 1024-byte self-describing blocks:

    u16 checksum   sum of the block's remaining 511 little-endian u16 words
    u16 length     1020 for a full block, (n | 0x8000) for the final short block
    1020 bytes     payload

The first 512 bytes of the first block are AES-256-ECB, the rest of the stream is
AES-256-CBC chained from a per-package IV that is stored in the FDAT trailer.
"""

from __future__ import annotations

import hashlib
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Iterator

import numpy as np
from Crypto.Cipher import AES

MAGIC = b"\x89UFU\r\n\x1a\n"
ECB_KEY = bytes.fromhex("e3b0c44298fc1c149afbf4c8996fb924")
CBC_KEY = bytes.fromhex("434589432d319010f1132727353286ce4d7ede8b9c4f7217a0e0226e0f0edc69")
BLOCK = 1024
PAYLOAD = 1020
TRAILER = 0x110
GROUP = 4096
OFFICIAL_SIZE = 1_139_929_560
OFFICIAL_PLAINTEXT_SIZE = 1_135_475_712


class DatError(ValueError):
    pass


def sha256_file(path: Path, block: int = 8 << 20) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(block), b""):
            digest.update(chunk)
    return digest.hexdigest()


def crc32_window(stream: BinaryIO, offset: int, size: int, block: int = 8 << 20) -> int:
    value = 0
    stream.seek(offset)
    remaining = size
    while remaining:
        data = stream.read(min(block, remaining))
        if not data:
            raise DatError("unexpected end of file while computing CRC-32")
        value = zlib.crc32(data, value)
        remaining -= len(data)
    return value & 0xFFFFFFFF


@dataclass(frozen=True)
class Layout:
    size: int
    chunks: dict            # tag -> (header_offset, length)
    fdat_at: int
    fdat_size: int
    trailer: bytes

    @property
    def block_count(self) -> int:
        return (self.fdat_size - TRAILER) // BLOCK

    @property
    def iv(self) -> bytes:
        return self.trailer[:16]


def parse(path: Path) -> Layout:
    path = Path(path)
    size = path.stat().st_size
    chunks: dict[bytes, tuple[int, int]] = {}
    with open(path, "rb") as handle:
        if handle.read(len(MAGIC)) != MAGIC:
            raise DatError("not a Sony update image (magic mismatch)")
        while handle.tell() < size:
            header = handle.read(8)
            if len(header) != 8:
                raise DatError("truncated chunk header")
            length, tag = struct.unpack(">I4s", header)
            if handle.tell() + length > size:
                raise DatError("chunk length runs past end of file")
            if tag in chunks:
                raise DatError("duplicate chunk tag %r" % tag)
            chunks[tag] = (handle.tell() - 8, length)
            handle.seek(length, 1)
            if tag == b"DEND":
                break
        if handle.tell() != size:
            raise DatError("trailing data after DEND")
        if b"FDAT" not in chunks:
            raise DatError("FDAT chunk missing")
        fdat_at = chunks[b"FDAT"][0] + 8
        fdat_size = chunks[b"FDAT"][1]
        if fdat_size <= TRAILER or (fdat_size - TRAILER) % BLOCK:
            raise DatError("FDAT cipher geometry is not a whole number of blocks")
        handle.seek(fdat_at + fdat_size - TRAILER)
        trailer = handle.read(TRAILER)
        if len(trailer) != TRAILER:
            raise DatError("FDAT trailer truncated")
        handle.seek(size - 4)
        recorded = struct.unpack(">I", handle.read(4))[0]
        actual = crc32_window(handle, 0, size - 12)
        if recorded != actual:
            raise DatError("package CRC-32 mismatch (file is corrupt or truncated)")
    return Layout(size=size, chunks=chunks, fdat_at=fdat_at,
                  fdat_size=fdat_size, trailer=trailer)


def _plain_groups(path: Path, layout: Layout) -> Iterator[tuple[int, int, bytes]]:
    """Yield (first_block_index, block_count, decrypted 1024-byte blocks)."""
    ecb = AES.new(ECB_KEY, AES.MODE_ECB)
    cbc = AES.new(CBC_KEY, AES.MODE_CBC, layout.iv)
    total = layout.block_count
    with open(path, "rb") as handle:
        handle.seek(layout.fdat_at)
        for start in range(0, total, GROUP):
            count = min(GROUP, total - start)
            cipher = handle.read(count * BLOCK)
            if len(cipher) != count * BLOCK:
                raise DatError("FDAT cipher truncated")
            if start == 0:
                raw = ecb.decrypt(cipher[:512]) + cbc.decrypt(cipher[512:])
            else:
                raw = cbc.decrypt(cipher)
            yield start, count, raw


def _split(raw: bytes) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    words = np.frombuffer(raw, dtype="<u2").reshape(-1, 512)
    lengths = words[:, 1].copy()
    payload = np.frombuffer(raw, dtype=np.uint8).reshape(-1, BLOCK)[:, 4:]
    return words, lengths, payload


def _check_blocks(lengths: np.ndarray, start: int, count: int, total: int) -> None:
    final = start + count == total
    if final:
        if not np.all(lengths[:-1] == PAYLOAD):
            raise DatError("block %d..%d: non-final block length is not 1020"
                           % (start, start + count))
        tail = int(lengths[-1])
        if not (0x8000 < tail <= 0x8000 + PAYLOAD):
            raise DatError("block %d: final block flag/length is invalid" % (start + count - 1))
    elif not np.all(lengths == PAYLOAD):
        raise DatError("block %d..%d: length/flag mismatch" % (start, start + count))


def peek_plaintext(path: Path, layout: Layout, size: int = 0x400) -> bytes:
    """Decrypt just the head of the image (first block group) for cheap inspection."""
    for start, count, raw in _plain_groups(path, layout):
        _words, _lengths, payload = _split(raw)
        data = payload.tobytes()
        return data[:size]
    raise DatError("empty FDAT")


def decrypt_to_plain(path: Path, layout: Layout, out_path: Path) -> str:
    """Decrypt into a header-less plaintext image and return its SHA-256."""
    digest = hashlib.sha256()
    total = layout.block_count
    with open(out_path, "wb") as out:
        for start, count, raw in _plain_groups(path, layout):
            words, lengths, payload = _split(raw)
            checks = words[:, 1:].sum(axis=1, dtype=np.uint64) & 0xFFFF
            if not np.all(checks == words[:, 0]):
                raise DatError("block checksum mismatch at block %d" % start)
            _check_blocks(lengths, start, count, total)
            if start + count == total:
                data = payload[:-1].tobytes() + payload[-1, : int(lengths[-1]) & 0x7FFF].tobytes()
            else:
                data = payload.tobytes()
            out.write(data)
            digest.update(data)
        out.flush()
    return digest.hexdigest()


def _cipher_stream(source_dat: Path, layout: Layout) -> tuple[int, int, bytes]:
    with open(source_dat, "rb") as handle:
        handle.seek(layout.fdat_at + layout.fdat_size - TRAILER)
        trailer = handle.read(TRAILER)
    if trailer != layout.trailer:
        raise DatError("source trailer changed")
    return layout.fdat_at, layout.fdat_size, trailer


def encrypt_from_plain(source_dat: Path, layout: Layout, plain_path: Path,
                       out_path: Path) -> str:
    """Re-encrypt a plaintext image into a copy of `source_dat`; return DEND CRC."""
    import shutil

    fdat_at, fdat_size, trailer = _cipher_stream(source_dat, layout)
    plain_size = Path(plain_path).stat().st_size
    blocks = (plain_size + PAYLOAD - 1) // PAYLOAD
    if blocks * BLOCK != fdat_size - TRAILER:
        raise DatError("plaintext size does not fit the FDAT geometry")
    shutil.copyfile(source_dat, out_path)
    ecb = AES.new(ECB_KEY, AES.MODE_ECB)
    cbc = AES.new(CBC_KEY, AES.MODE_CBC, trailer[:16])
    with open(plain_path, "rb") as src, open(out_path, "r+b") as dst:
        dst.seek(fdat_at)
        for start in range(0, blocks, GROUP):
            count = min(GROUP, blocks - start)
            payload = src.read(count * PAYLOAD)
            final = start + count == blocks
            if final:
                if not 1 <= len(payload) - (count - 1) * PAYLOAD <= PAYLOAD:
                    raise DatError("bad final plaintext block length")
            elif len(payload) != count * PAYLOAD:
                raise DatError("short plaintext group")
            padded = payload + b"\xff" * (count * PAYLOAD - len(payload))
            raw = np.empty((count, BLOCK), dtype=np.uint8)
            raw[:, 4:] = np.frombuffer(padded, dtype=np.uint8).reshape(count, PAYLOAD)
            words = raw.view("<u2").reshape(count, 512)
            words[:, 1] = PAYLOAD
            if final:
                words[-1, 1] = (len(payload) - (count - 1) * PAYLOAD) | 0x8000
            words[:, 0] = words[:, 1:].sum(axis=1, dtype=np.uint64) & 0xFFFF
            packed = raw.tobytes()
            if start == 0:
                cipher = ecb.encrypt(packed[:512]) + cbc.encrypt(packed[512:])
            else:
                cipher = cbc.encrypt(packed)
            dst.write(cipher)
        if src.read(1) != b"":
            raise DatError("plaintext not fully consumed")
        if dst.tell() != fdat_at + fdat_size - TRAILER:
            raise DatError("cipher stream ended at the wrong offset")
        dst.flush()
        total = dst.seek(0, 2)
        dst.seek(0)
        value = 0
        remaining = total - 12
        while remaining:
            data = dst.read(min(8 << 20, remaining))
            if not data:
                raise DatError("short read while sealing DEND")
            value = zlib.crc32(data, value)
            remaining -= len(data)
        value &= 0xFFFFFFFF
        dst.seek(total - 4)
        dst.write(struct.pack(">I", value))
        dst.flush()
    return "%08x" % value


def verify_roundtrip(out_dat: Path, layout_in: Layout, plain_path: Path) -> None:
    """Byte-for-byte compare an output package against the intended plaintext."""
    layout_out = parse(out_dat)
    if (layout_out.fdat_at, layout_out.fdat_size, layout_out.trailer) != (
            layout_in.fdat_at, layout_in.fdat_size, layout_in.trailer):
        raise DatError("output package geometry changed")
    total = layout_out.block_count
    with open(plain_path, "rb") as expected:
        for start, count, raw in _plain_groups(out_dat, layout_out):
            words, lengths, payload = _split(raw)
            checks = words[:, 1:].sum(axis=1, dtype=np.uint64) & 0xFFFF
            if not np.all(checks == words[:, 0]):
                raise DatError("output block checksum mismatch at block %d" % start)
            _check_blocks(lengths, start, count, total)
            if start + count == total:
                data = payload[:-1].tobytes() + payload[-1, : int(lengths[-1]) & 0x7FFF].tobytes()
            else:
                data = payload.tobytes()
            if expected.read(len(data)) != data:
                raise DatError("output package does not decrypt to the built plaintext")
        if expected.read(1) != b"":
            raise DatError("output plaintext length differs")
