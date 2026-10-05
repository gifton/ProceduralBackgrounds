#include <metal_stdlib>
using namespace metal;

struct InkVertex {
    float2 position;
    float4 color;
};

struct InkVarying {
    float4 position [[position]];
    float4 color;
};

vertex InkVarying inkVertex(uint id [[vertex_id]],
                           device const InkVertex* vertices [[buffer(0)]],
                           constant float4& transform [[buffer(1)]]) {
    InkVarying out;
    out.position = float4(vertices[id].position * transform.xy + transform.zw, 0, 1);
    out.color = vertices[id].color;
    return out;
}

fragment float4 inkFragment(InkVarying in [[stage_in]]) {
    return float4(in.color.rgb * in.color.a, in.color.a);
}

struct PaperVarying {
    float4 position [[position]];
    float2 uv;
};

vertex PaperVarying paperVertex(uint id [[vertex_id]]) {
    const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
    PaperVarying out;
    out.position = float4(positions[id], 0, 1);
    out.uv = float2(positions[id].x * 0.5 + 0.5, 0.5 - positions[id].y * 0.5);
    return out;
}

float paperHash(float2 p, uint seed) {
    uint2 cell = uint2(max(p, float2(0)));
    uint h = cell.x * 0x9e3779b9u ^ cell.y * 0x85ebca6bu ^ seed;
    h ^= h >> 16;
    h *= 0x7feb352du;
    h ^= h >> 15;
    h *= 0x846ca68bu;
    h ^= h >> 16;
    return float(h >> 8) * (1.0f / 16777216.0f);
}

float paperNoise(float2 p, uint seed) {
    float2 cell = floor(p);
    float2 t = fract(p);
    t = t * t * (3.0f - 2.0f * t);
    float a = mix(paperHash(cell, seed), paperHash(cell + float2(1, 0), seed), t.x);
    float b = mix(paperHash(cell + float2(0, 1), seed), paperHash(cell + float2(1, 1), seed), t.x);
    return mix(a, b, t.y);
}

fragment float4 paperFragment(PaperVarying in [[stage_in]],
                             texture2d<float> ink [[texture(0)]],
                             constant uint& seed [[buffer(0)]]) {
    constexpr sampler sampleInk(filter::linear, address::clamp_to_edge);
    float fine = paperHash(floor(in.position.xy), seed) - 0.5f;
    float mottling = paperNoise(in.position.xy / 38.0f, seed ^ 0x1643u) - 0.5f;
    float fibers = paperNoise(float2(in.position.x / 2.0f, in.position.y / 23.0f), seed ^ 0x8192u) - 0.5f;
    float grain = 0.018f * fine + 0.024f * mottling + 0.008f * fibers;
    float3 paper = float3(0.974f, 0.954f, 0.912f) + grain;
    return float4(ink.sample(sampleInk, in.uv).rgb * paper, 1);
}
