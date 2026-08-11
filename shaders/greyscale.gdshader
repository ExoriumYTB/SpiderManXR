shader_type spatial;

global uniform float global_saturation; // Used by all greyscales shaders at the same time

uniform vec3 color : source_color = vec3(1, 0, 0); // the color of the shader

void fragment() {
	ALBEDO = color;
	vec3 final_color = ALBEDO;
	
	float luma = dot(final_color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(luma), final_color, global_saturation);
}