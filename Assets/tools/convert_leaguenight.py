#!/usr/bin/env python3
"""Convert League Night pack.glb into a RealityKit-friendly USDZ (meshes at origin)."""

from __future__ import annotations

import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "Assets/ThirdParty/LeagueNight/pack.glb"
ATLAS = ROOT / "Assets/ThirdParty/LeagueNight/atlas.png"
GEN = ROOT / "Assets/Generated/LeagueNight"
APP_USDZ = ROOT / "Multi Platform Bowling/Multi Platform Bowling/Resources/LeagueNight.usdz"

COMP_FORMAT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COMP_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    offset = 12
    json_len, json_type = struct.unpack_from("<I4s", data, offset)
    offset += 8
    doc = json.loads(data[offset : offset + json_len])
    offset += json_len
    bin_len, _bin_type = struct.unpack_from("<I4s", data, offset)
    offset += 8
    return doc, data[offset : offset + bin_len]


def accessor_values(doc: dict, blob: bytes, index: int):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = COMP_FORMAT[acc["componentType"]]
    components = COMP_COUNT[acc["type"]]
    size = struct.calcsize(fmt) * components
    stride = view.get("byteStride", size)
    values = []
    for i in range(acc["count"]):
        tup = struct.unpack_from("<" + fmt * components, blob, start + i * stride)
        values.append(tup if components > 1 else tup[0])
    return values


def fmt_floats(values, n: int) -> str:
    parts = []
    for value in values:
        if isinstance(value, tuple):
            inner = ", ".join(f"{c:.6f}" for c in value[:n])
            parts.append(f"({inner})")
        else:
            parts.append(f"{value:.6f}")
    return "[" + ", ".join(parts) + "]"


def fmt_ints(values) -> str:
    return "[" + ", ".join(str(int(v)) if not isinstance(v, tuple) else str(int(v[0])) for v in values) + "]"


def write_mesh(lines: list[str], indent: str, name: str, points, normals, uvs, indices, material_path: str):
    counts = [3] * (len(indices) // 3)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    zs = [p[2] for p in points]
    extent = f"[({min(xs):.6f}, {min(ys):.6f}, {min(zs):.6f}), ({max(xs):.6f}, {max(ys):.6f}, {max(zs):.6f})]"
    lines.append(f'{indent}def Mesh "{name}"')
    lines.append(f"{indent}{{")
    lines.append(f"{indent}    float3[] extent = {extent}")
    lines.append(f"{indent}    int[] faceVertexCounts = {fmt_ints(counts)}")
    lines.append(f"{indent}    int[] faceVertexIndices = {fmt_ints(indices)}")
    lines.append(f"{indent}    point3f[] points = {fmt_floats(points, 3)}")
    if normals:
        lines.append(f"{indent}    normal3f[] normals = {fmt_floats(normals, 3)} (")
        lines.append(f'{indent}        interpolation = "vertex"')
        lines.append(f"{indent}    )")
    if uvs:
        lines.append(f"{indent}    texCoord2f[] primvars:st = {fmt_floats(uvs, 2)} (")
        lines.append(f'{indent}        interpolation = "vertex"')
        lines.append(f"{indent}    )")
    lines.append(f'{indent}    uniform token subdivisionScheme = "none"')
    lines.append(f"{indent}    rel material:binding = <{material_path}>")
    lines.append(f"{indent}}}")


def convert() -> Path:
    if not GLB.exists():
        raise SystemExit(f"Missing {GLB}")

    GEN.mkdir(parents=True, exist_ok=True)
    atlas_dest = GEN / "atlas.png"
    shutil.copyfile(ATLAS, atlas_dest)

    doc, blob = load_glb(GLB)
    lines = [
        "#usda 1.0",
        "(",
        '    defaultPrim = "LeagueNight"',
        "    metersPerUnit = 1",
        '    upAxis = "Y"',
        ")",
        "",
        'def Xform "LeagueNight" (',
        '    kind = "assembly"',
        ")",
        "{",
        '    def Material "SharedMaterial"',
        "    {",
        "        token outputs:surface.connect = </LeagueNight/SharedMaterial/preview.outputs:surface>",
        '        def Shader "preview"',
        "        {",
        '            uniform token info:id = "UsdPreviewSurface"',
        "            color3f inputs:diffuseColor.connect = </LeagueNight/SharedMaterial/tex.outputs:rgb>",
        "            float inputs:metallic = 0",
        "            float inputs:roughness = 0.82",
        "            token outputs:surface",
        "        }",
        '        def Shader "tex"',
        "        {",
        '            uniform token info:id = "UsdUVTexture"',
        "            asset inputs:file = @atlas.png@",
        '            token inputs:wrapS = "repeat"',
        '            token inputs:wrapT = "repeat"',
        "            float2 inputs:st.connect = </LeagueNight/SharedMaterial/st.outputs:result>",
        "            float3 outputs:rgb",
        "        }",
        '        def Shader "st"',
        "        {",
        '            uniform token info:id = "UsdPrimvarReader_float2"',
        '            token inputs:varname = "st"',
        "            float2 outputs:result",
        "        }",
        "    }",
        "",
        '    def Material "EmissiveMaterial"',
        "    {",
        "        token outputs:surface.connect = </LeagueNight/EmissiveMaterial/preview.outputs:surface>",
        '        def Shader "preview"',
        "        {",
        '            uniform token info:id = "UsdPreviewSurface"',
        "            color3f inputs:diffuseColor.connect = </LeagueNight/EmissiveMaterial/tex.outputs:rgb>",
        "            color3f inputs:emissiveColor.connect = </LeagueNight/EmissiveMaterial/tex.outputs:rgb>",
        "            float inputs:metallic = 0",
        "            float inputs:roughness = 0.82",
        "            token outputs:surface",
        "        }",
        '        def Shader "tex"',
        "        {",
        '            uniform token info:id = "UsdUVTexture"',
        "            asset inputs:file = @atlas.png@",
        '            token inputs:wrapS = "repeat"',
        '            token inputs:wrapT = "repeat"',
        "            float2 inputs:st.connect = </LeagueNight/EmissiveMaterial/st.outputs:result>",
        "            float3 outputs:rgb",
        "        }",
        '        def Shader "st"',
        "        {",
        '            uniform token info:id = "UsdPrimvarReader_float2"',
        '            token inputs:varname = "st"',
        "            float2 outputs:result",
        "        }",
        "    }",
        "",
    ]

    for node in doc["nodes"]:
        mesh = doc["meshes"][node["mesh"]]
        safe = node["name"]
        lines.append(f'    def Xform "{safe}"')
        lines.append("    {")
        for prim_index, prim in enumerate(mesh["primitives"]):
            attrs = prim["attributes"]
            points = accessor_values(doc, blob, attrs["POSITION"])
            normals = accessor_values(doc, blob, attrs["NORMAL"]) if "NORMAL" in attrs else []
            uvs = accessor_values(doc, blob, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else []
            if "indices" in prim:
                indices = accessor_values(doc, blob, prim["indices"])
            else:
                indices = list(range(len(points)))
            material = doc["materials"][prim.get("material", 0)]
            material_path = (
                "/LeagueNight/EmissiveMaterial"
                if material.get("name") == "pack_emissive"
                else "/LeagueNight/SharedMaterial"
            )
            mesh_name = "mesh" if len(mesh["primitives"]) == 1 else f"mesh_{prim_index}"
            write_mesh(lines, "        ", mesh_name, points, normals, uvs, indices, material_path)
        lines.append("    }")
        lines.append("")

    lines.append("}")
    usda = GEN / "LeagueNight.usda"
    usda.write_text("\n".join(lines) + "\n")
    print(f"wrote {usda} ({usda.stat().st_size / 1e6:.1f} MB)")
    return usda


def package(usda: Path) -> None:
    usdz = GEN / "LeagueNight.usdz"
    if usdz.exists():
        usdz.unlink()
    commands = [
        ["usdzip", "--arkitAsset", str(usda), str(usdz)],
        ["usdzip", "-a", str(usda), str(usdz), str(GEN / "atlas.png")],
        ["xcrun", "scntool", "--convert", str(usda), "--format", "usdz", "--output", str(usdz)],
    ]
    last_error = None
    for command in commands:
        print("running", " ".join(command))
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0 and usdz.exists():
            print(result.stdout)
            APP_USDZ.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(usdz, APP_USDZ)
            print(f"copied {APP_USDZ} ({APP_USDZ.stat().st_size / 1e6:.1f} MB)")
            return
        last_error = (result.stdout or "") + (result.stderr or "")
        print(last_error)
    raise SystemExit(f"USDZ conversion failed:\n{last_error}")


if __name__ == "__main__":
    package(convert())
