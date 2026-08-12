shader_type spatial;

uniform vec3 color : source_color = vec3(1, 1, 1); // the color of the shader
uniform sampler2D perlin_noise;

void fragment() {
	float perlin_noise_r = texture(perlin_noise, UV).r;
	float perlin_noise_g = texture(perlin_noise, UV).g;
	float perlin_noise_b = texture(perlin_noise, UV).b;
	float alpha = perlin_noise_r * perlin_noise_g * perlin_noise_b;
	
	ALBEDO = color;
	ALPHA = alpha;
}