////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MToonLike.fx ver1.1
//  作成: furia
//  LICENSE: MIT license
//  
//  Code of "MToon" of "Masataka SUMI" is partly included.
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix          : WORLDVIEW;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
//接空間取得
float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}
/*
	float3x3 tangentFrame = compute_tangent_frame(In.Normal, In.Eye, In.Tex);
	float3 normal = normalize(mul(2.0f * tex2D(normalSamp, In.Tex) - 1.0f, tangentFrame));
*/

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画


struct EDGE_VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal        : TEXCOORD2;   // テクスチャ
};

// 頂点シェーダ
EDGE_VS_OUTPUT ColorRender_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, float3 Normal : NORMAL)
{
    EDGE_VS_OUTPUT Out = (EDGE_VS_OUTPUT)0;
    // カメラ視点のワールドビュー射影変換
	float len = length(mul((float3x3)transpose(WorldMatrix), Normal));
    Out.Pos = mul( Pos, WorldViewProjMatrix );
	
    // テクスチャ座標
    Out.Tex = Tex;

	Out.Normal = Normal;

    return Out;
}

// ピクセルシェーダ
float4 ColorRender_PS(EDGE_VS_OUTPUT IN) : COLOR
{
	
    // テクスチャ適用
	float2 uv = IN.Tex;
	//uv.x /= 3.0f;
    float4 TexColor = tex2D( ObjTexSampler, uv);
    
	return TexColor;

	float border = 0.5f;

	if(SpecularPower < 1.0f)
		border = SpecularPower;

	clip(TexColor.a - border);

    // 輪郭色で塗りつぶし
    return EdgeColor;
}
float4 ColorRender_PSC() : COLOR
{
	clip(-1);
    return EdgeColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;

        VertexShader = compile vs_3_0 ColorRender_VS();
        PixelShader  = compile ps_3_0 ColorRender_PSC();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float4 Pos2      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Pos2 = Out.Pos;
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    Out.Color = MaterialDiffuse;
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

#define UV_X_BORDER	(1.0f/3.0f)
#define UV_X_BORDER_D	(2.0f/3.0f)

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    float2 texUv = IN.Tex;
    texUv.x = texUv.x % UV_X_BORDER;
	//texUv.x /= 3.0f;

	float2 normalUv = texUv;
	normalUv.x += UV_X_BORDER_D;

	float2 eUv = texUv;
	eUv.x += UV_X_BORDER;

	float3x3 tangentFrame = compute_tangent_frame(IN.Normal, IN.Eye, IN.Tex);
	
	float3 normal = normalize(mul(2.0f * tex2D(ObjTexSampler, normalUv) - 1.0f, tangentFrame));

	float3 worldNormal = normal;
	worldNormal *= step(0, dot(CameraPosition.xyz - IN.Pos2.xyz, worldNormal)) * 2 - 1;
    worldNormal = normalize(worldNormal);
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    
	float sp = 5.00f;
	float spf = 0.30f;
    float3 Specular = pow( max(0,dot( HalfVector, normalize(worldNormal) )), sp ) * LightSpecular * spf;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(MaterialEmmisive, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, texUv );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }

	
	float border = 0.5f;

	if(SpecularPower < 1.0f)
		border = SpecularPower;

	clip(Color.a - border);

    // スペキュラ適用
    Color.rgb += Specular;
    
	
	float lightIntensity = dot(LightDirection, worldNormal);
    lightIntensity = lightIntensity * 0.5 + 0.5; // from [-1, +1] to [0, 1]
	
	
	float diffContrib = dot( normalize(worldNormal) , -LightDirection) * 0.5 +0.5;
	diffContrib = diffContrib*diffContrib;
	///------------



	lightIntensity = lightIntensity * 2.0 - 1.0; // from [0, 1] to [-1, +1]
    //lightIntensity = smoothstep(_ShadeShift, _ShadeShift + (1.0 - _ShadeToony), lightIntensity); // shade & tooned
	
    // lighting with color
    half3 directLighting = lightIntensity * LightDiffuse.rgb; // direct
    half3 indirectLighting = LightAmbient * diffContrib;// * ShadeSH9(half4(worldNormal, 1)); // ambient
    half3 lighting = directLighting + indirectLighting;
    //lighting = lerp(lighting, max(0.001, max(lighting.x, max(lighting.y, lighting.z))), _LightColorAttenuation); // color atten
    float4 ans = lerp(ShadowColor, Color, float4(lighting,1));
	
	if ( useSphereMap ) {
	
        float2 NormalWV = mul( normal, (float3x3)ViewMatrix );
        NormalWV.x = NormalWV.x * 0.5f + 0.5f;
        NormalWV.y = NormalWV.y * -0.5f + 0.5f;

		float3 worldCameraUp = WorldViewMatrix[1].xyz;
		float3 worldView = IN.Eye;
		float3 worldViewUp = normalize(worldCameraUp - worldView * dot(worldView, worldCameraUp));
		float3 worldViewRight = normalize(cross(worldView, worldViewUp));
		float2 rimUv = half2(dot(worldViewRight, worldNormal), dot(worldViewUp, worldNormal)) * 0.5 + 0.5;
		float3 rimLighting = tex2D(ObjSphareSampler, NormalWV);//rimUv);
		ans.rgb += rimLighting;
    }

    half3 emission = tex2D(ObjTexSampler, eUv).rgb * MaterialSpecular.rgb;
    ans.rgb += emission;

    return ans;
}

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION , float2 Tex : TEXCOORD0)
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

	Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS(VS_ZValuePlot_OUTPUT IN) : COLOR
{

    // テクスチャ適用
	float2 uv = IN.Tex;
    uv.x = uv.x % UV_X_BORDER;
	//uv.x /= 3.0f;
    float4 TexColor = tex2D( ObjTexSampler, uv);

	float border = 0.5f;

	if(SpecularPower < 1.0f)
		border = SpecularPower;

	clip(TexColor.a - border);

    // R色成分にZ値を記録する
    return float4(IN.ShadowMapTex.z/IN.ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float4 Pos2    : TEXCOORD4;	
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

	Out.Pos2 = Out.Pos;
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    Out.Color = MaterialDiffuse;
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    float2 texUv = IN.Tex;
    texUv.x = texUv.x % UV_X_BORDER;
	//texUv.x /= 3.0f;

	float2 normalUv = texUv;
	normalUv.x += UV_X_BORDER_D;

	float2 eUv = texUv;
	eUv.x += UV_X_BORDER;

	float3x3 tangentFrame = compute_tangent_frame(IN.Normal, IN.Eye, IN.Tex);
	float3 normal = normalize(mul(2.0f * tex2D(ObjTexSampler, normalUv) - 1.0f, tangentFrame));

	float3 worldNormal = normal;
	worldNormal *= step(0, dot(CameraPosition.xyz - IN.Pos2.xyz, worldNormal)) * 2 - 1;
    worldNormal = normalize(worldNormal);
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
	float sp = 5.00f;
	float spf = 0.30f;
    float3 Specular = pow( max(0,dot( HalfVector, normalize(worldNormal) )), sp ) * LightSpecular * spf;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(MaterialEmmisive, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, texUv );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }

	
	float border = 0.5f;

	if(SpecularPower < 1.0f)
		border = SpecularPower;

	clip(Color.a - border);

    // スペキュラ適用
    Color.rgb += Specular;
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
	
	float lightIntensity = dot(LightDirection, normalize(worldNormal));
    lightIntensity = lightIntensity * 0.5 + 0.5; // from [-1, +1] to [0, 1]
	
	float diffContrib = dot( normalize(worldNormal) , -LightDirection) * 0.5 +0.5;
	diffContrib = diffContrib*diffContrib;
	
    
    float comp = 1.0f;

    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
    } else {

        if(parthf) {
            // セルフシャドウ mode2
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        if ( useToon ) {
            // トゥーン適用
            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
    }
	lightIntensity = lightIntensity * comp;
	lightIntensity = lightIntensity * 2.0 - 1.0; // from [0, 1] to [-1, +1]

    // lighting with color
    half3 directLighting = lightIntensity * LightDiffuse.rgb; // direct
    half3 indirectLighting = LightAmbient * diffContrib * comp;// * ShadeSH9(half4(worldNormal, 1)); // ambient
    half3 lighting = directLighting + indirectLighting;
    //lighting = lerp(lighting, max(0.001, max(lighting.x, max(lighting.y, lighting.z))), comp);//_LightColorAttenuation); // color atten
    float4 ans = lerp(ShadowColor, Color, float4(lighting,1));
	
	
	if ( useSphereMap ) {
	
        float2 NormalWV = mul( normal, (float3x3)ViewMatrix );
        NormalWV.x = NormalWV.x * 0.5f + 0.5f;
        NormalWV.y = NormalWV.y * -0.5f + 0.5f;

		float3 worldCameraUp = WorldViewMatrix[1].xyz;
		float3 worldView = normalize(CameraPosition - IN.Pos2);
		float3 worldViewUp = normalize(worldCameraUp - worldView * dot(worldView, worldCameraUp));
		float3 worldViewRight = normalize(cross(worldView, worldViewUp));
		float2 rimUv = float2(dot(worldViewRight, worldNormal), dot(worldViewUp, worldNormal)) * 0.5f + 0.5f;
		float3 rimLighting = tex2D(ObjSphareSampler, NormalWV);//rimUv);
		ans.rgb += rimLighting;
    }

    half3 emission = tex2D(ObjTexSampler, eUv).rgb * MaterialSpecular.rgb;
    ans.rgb += emission;

    return ans;
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
