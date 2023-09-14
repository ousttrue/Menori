---@meta
--
-- representation from [glTF JSON Schema](https://github.com/KhronosGroup/glTF/tree/master/specification/2.0/schema)
-- to [LuaCATS](https://luals.github.io/wiki/annotations/)
--

---@class GltfBuffer
---@field uri string?

---@class GltfBufferView
---@field buffer integer
---@field byteOffset integer
---@field byteLength integer

---@class GltfAccessor
---@field bufferView integer
---@field byteOffset integer?
---@field type string ["SCALAR", "VEC2", "VEC3", "VEC4", "MAT2", "MAT3", "MAT4"]
---@field componentType integer [5120:BYTE, 5121:UBYTE, 5122:SHORT, 5123:USHORT, 5125:UINT, 5126:FLOAT]
---@field count integer

---@class GltfAttributes
---@field POSITION integer
---@field NORMAL integer?
---@field TEXCOORD_0 integer?
---@field TEXCOORD_1 integer?
---@field TANGENT integer?
---@field COLOR_0 integer?
---@field JOINTS_0 integer?
---@field WEIGHTS_0 integer?

---@class GltfPrimitive
---@field attributes GltfAttributes
---@field indices integer?{
---@field material integer?

---@class GltfMesh
---@field primitives GltfPrimitive[]

---@class GltfNode
---@field name string?
---@field children integer[]?
---@field matrix number[]?
---@field rotation number[]?
---@field scale number[]?
---@field translation number[]?
---@field mesh integer?
---@field skin integer?

---@class GltfTextureInfo
---@field index integer

---@class GltfPbrMetallicRoughness
---@field baseColorFactor number[]?
---@field baseColorTexture GltfTextureInfo?
---@field metallicFactor number?
---@field roughnessFactor number?
---@field metallicRoughnessTexture GltfTextureInfo?

---@class GltfMaterial
---@field name string?
---@field pbrMetallicRoughness GltfPbrMetallicRoughness?
---@field normalTexture GltfTextureInfo?
---@field occlusionTexture GltfTextureInfo?
---@field emissiveTexture GltfTextureInfo?
---@field emissiveFactor number[]?
---@field alphaMode string ["OPAQUE", "MASK", "BLEND"]?
---@field alphaCutoff number?
---@field doubleSided boolean?

---@class GltfSampler
---@field magFilter integer [9728:NEAREST, 9729:LINEAR]
---@field minFilter integer [9728:NEAREST, 9729:LINEAR, 9984:NEAREST_MIPMAP_NEAREST, 9985:LINEAR_MIPMAP_NEAREST, 9986:NEAREST_MIPMAP_LINEAR, 9987:LINEAR_MIPMAP_LINEAR]
---@field wrapS integer [33071:CLAMP_TO_EDGE, 33648:MIRRORED_REPEAT, 10497:REPEAT]
---@field wrapT integer [33071:CLAMP_TO_EDGE, 33648:MIRRORED_REPEAT, 10497:REPEAT]

---@class GltfImage
---@field name string?
---@field uri string?
---@field mimeType string?
---@field bufferView integer?

---@class GltfTexture
---@field name string?
---@field sampler integer?
---@field source integer

---@class Gltf
---@field buffers GltfBuffer[]
---@field bufferViews GltfBufferView[]
---@field accessors GltfAccessor[]
---@field meshes GltfMesh[]
---@field nodes GltfNode[]
---@field materials GltfMaterial[]
---@field textures GltfTexture[]
---@field samplers GltfSampler[]
---@field images GltfImage[]
