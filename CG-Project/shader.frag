#version 430

out vec4 FragColor;
in vec2 TexCoord;
uniform sampler2D ourTexture;
uniform float iter;

void main()
{
	FragColor = vec4(texture(ourTexture, TexCoord).rgb, 1.0f/(iter + 1.0f));
}