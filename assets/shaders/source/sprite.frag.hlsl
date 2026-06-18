Texture2D<float4> imageTexture : register(t0, space2);
SamplerState imageSampler : register(s0, space2);

struct FragmentInput
{
    float2 texcoord : TEXCOORD0;
    float4 color : COLOR0;
};

float4 main(FragmentInput input) : SV_Target0
{
    return imageTexture.Sample(imageSampler, input.texcoord) * input.color;
}
