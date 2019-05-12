//---------------------------------------------------------------------------
//Rendering: four simple demos
//upper left:   1d perlin noise curve
//upper right:  simple 2D terrain
//lower left:   hand drawn effect
//lower right:  2D water surface
//---------------------------------------------------------------------------
#define FADE_SCALE 30.0

vec4 circle(vec2 uv, vec2 center, float radius, vec3 color, bool isSolid) 
{
	float d = (length(uv - center) - radius) * FADE_SCALE;
    d = isSolid ? d : abs(d);
	return vec4(color, 1. - clamp(d, 0., 1.));
}

vec4 rect(vec2 uv, vec2 minV, vec2 maxV, vec3 color, bool isSolid)
{
	float d = max(max(uv.x-maxV.x, minV.x-uv.x), max(uv.y-maxV.y, minV.y-uv.y)) * FADE_SCALE;
    d = isSolid ? d : abs(d);
	return vec4(color, 1. - clamp(d, 0., 1.));
}

vec4 renderUL(in vec2 uv)
{
    float noise = .5 * fbm(2.*uv.x + 4.*iTime, 4, .2);
    float d = (uv.y - noise) * FADE_SCALE;
	float t = clamp(abs(d), 0., 1.);
    
    return mix(vec4(1.), vec4(0.) + abs(uv.y)*.3, t);
}

vec4 renderUR(in vec2 uv)
{
    float noise = .5 * fbm(uv.x - iTime, 3, .2);
    float d = (uv.y - noise) * FADE_SCALE;
	float t = clamp(d, 0., 1.);
    
    vec3 skyColor = vec3(.15, .05, .0) + uv.y * .1;
    vec3 mountainColor = vec3(0.0) + .4*(uv.y+1.)*skyColor;
    return vec4(mix(mountainColor, skyColor, t), 1.);
}

vec4 renderLL(in vec2 uv)
{
    float noise = .04 * (fbm(uv.x, 5, .7) + fbm(uv.y, 5, .7));
 	vec4 layer1 = circle(uv, vec2(0.), .7 + noise, vec3(0., .6, 0.), false);
    vec4 layer2 = circle(uv, vec2(0.), .5 + noise, vec3(.6, .6, 0.), false);
    vec4 layer3 = circle(uv, vec2(0.), .3 + noise, vec3(.2), false);
    vec4 layer4 = rect(uv + noise, vec2(-.85), vec2(.85), vec3(.0, .7, .7), false);
    vec4 finalColor = vec4(.87, .83, .75, 1.) + 2.*noise;
    
    finalColor = mix(finalColor, layer1, layer1.a);
    finalColor = mix(finalColor, layer2, layer2.a);
    finalColor = mix(finalColor, layer3, layer3.a);
    finalColor = mix(finalColor, layer4, layer4.a);
    return finalColor;
}

vec4 renderLR(in vec2 uv)
{
    float noise = .04 * (fbm(uv.x, 4, .1) + fbm(uv.x + iTime, 4, .1));
    float d = (uv.y + noise + .24) * FADE_SCALE;
	float t = clamp(d, 0., 1.);
    
    vec3 skyColor = vec3(.3, .5, .8) - uv.y * .3;
    vec3 waterColor = vec3(.0, .3, .5) + .3 * uv.y;
    return vec4(mix(waterColor, skyColor, t), 1.);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float aspect = iResolution.x / iResolution.y;
    vec2 uv = (2.*fragCoord-iResolution.xy) / iResolution.y;
    float noise = .02 * fbm(uv.x + uv.y, 6, 1.);
    
    if (uv.x <= noise && uv.y > noise)
		fragColor = renderUL(2.*uv+vec2(aspect, -1.));
    else if (uv.x > noise && uv.y > noise)
        fragColor = renderUR(2.*uv+vec2(-aspect, -1.));
    else if (uv.x <= noise && uv.y <= noise)
        fragColor = renderLL(2.*uv+vec2(aspect, 1.));
    else
        fragColor = renderLR(2.*uv+vec2(-aspect, 1.));  
}