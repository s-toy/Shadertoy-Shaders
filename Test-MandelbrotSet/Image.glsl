#define MAX_ITERATION 100

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{ 
	vec2 p = (2.0*fragCoord.xy - iResolution.xy) / iResolution.y;
    vec2 c = p + vec2(-0.745, 0.0);
    vec2 z = vec2(0.0);
    
	int iter;
    for (iter = 0 ;iter < MAX_ITERATION && length(z) <= 20.0; ++iter) {
        z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
    }
    
    //http://iquilezles.org/www/articles/mset_smooth/mset_smooth.htm
    float smoothIter = float(iter) - log2(log2(dot(z,z))) + 4.0; 
    vec3 color = 0.5 + 0.5*cos(3.0 + smoothIter*0.15 + vec3(0.0,cos(iTime),sin(iTime)));

    fragColor = vec4(color, 1.0);
}