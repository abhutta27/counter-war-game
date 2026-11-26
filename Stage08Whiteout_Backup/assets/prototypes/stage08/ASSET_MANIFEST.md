# Stage 08 Alpine Hybrid Prototype — Asset Manifest

This folder contains only the standalone art study's third-party art files. The prototype does not use assets from the existing Stage 08 scene.

## License and provenance

All downloaded assets in this manifest are from Poly Haven and are licensed CC0. Poly Haven states that its models and textures may be used for any purpose, including commercial projects, without attribution. Source links are retained here for provenance. The downloaded model and texture choices below use the provider's **2K** variants.

## Models

| Asset | Source | Use in prototype | Package/import notes |
|---|---|---|---|
| `mountainside` | [Poly Haven Mountainside](https://polyhaven.com/a/mountainside) | Two prominent cliff faces framing the valley | glTF 2.0 `.gltf` + `.bin`; 2K JPG diffuse, packed ARM, OpenGL normal. Keep the sibling `textures/` directory beside the glTF. |
| `boulder_01` | [Poly Haven Boulder 01](https://polyhaven.com/a/boulder_01) | Four foreground/valley rock instances | glTF 2.0 `.gltf` + `.bin`; 2K JPG diffuse, packed ARM, OpenGL normal. Keep the sibling `textures/` directory beside the glTF. |
| `fir_sapling` | [Poly Haven Fir Sapling](https://polyhaven.com/a/fir_sapling) | Two fir examples | glTF 2.0 `.gltf` + `.bin`; 2K JPG branch/twig diffuse, ARM and OpenGL normal maps. Imported as supplied; inspect foliage alpha/material settings during visual review. |
| `pine_sapling_small` | [Poly Haven Pine Sapling Small](https://polyhaven.com/a/pine_sapling_small) | Two pine examples | glTF 2.0 `.gltf` + `.bin`; 2K JPG bark/twig diffuse, ARM and OpenGL normal maps. Imported as supplied; inspect foliage alpha/material settings during visual review. |

## Terrain PBR materials

| Material | Source | Maps in this prototype | Import notes |
|---|---|---|---|
| `snow_02` | [Poly Haven Snow 02](https://polyhaven.com/a/snow_02) | 2K diffuse JPG, 2K OpenGL normal PNG, packed ARM JPG, plus separate roughness/AO/displacement JPG maps | Shader uses diffuse, normal and packed ARM. Packed channels are interpreted as AO (R), roughness (G), metallic (B). Separate roughness/AO/displacement maps are retained but not loaded by the prototype shader. |
| `dark_rock` | [Poly Haven Dark Rock](https://polyhaven.com/a/dark_rock) | 2K diffuse JPG, 2K OpenGL normal PNG, packed ARM JPG, plus separate roughness/AO/displacement JPG maps | Shader uses diffuse, normal and packed ARM. Packed channels are interpreted as AO (R), roughness (G), metallic (B). Separate roughness/AO/displacement maps are retained but not loaded by the prototype shader. |

## Godot import

- Open the `.gltf` entry file in each model directory. Its referenced `.bin` and `textures/` files must remain at their downloaded relative paths.
- Godot 4.7 supports glTF scene import; this prototype imports the sources directly rather than converting the originals.
- The custom terrain shader loads the 2K PBR textures as source files. Normal maps are the publisher's OpenGL variants. Color maps use sRGB; normal, roughness and AO maps are data textures. Review import flags in the editor if map sampling differs by renderer.
- The scene repeats a small number of imported models and uses visibility-range fades on their renderable children. Distant ridges are a separate low-polygon procedural mesh.

## Files and resolution

- Every model GLTF and its referenced sidecars were downloaded from the 2K glTF endpoint.
- Terrain material maps were downloaded from the 2K endpoint; normal maps are PNG, the other selected maps are JPG.
- Some model binaries are shared geometry independent of texture resolution. Total folder size is recorded after the final import/run in the QA results.
